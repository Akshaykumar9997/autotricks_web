-- AutoTricks hardening 4/5: workflow RPCs (called with supabase.rpc()).
-- SECURITY DEFINER is required: these perform state transitions on columns
-- that neither clients nor admins can write directly. Each function checks
-- the caller's role and ownership itself, pins search_path, and is
-- executable by `authenticated` only (never anon).

create or replace function private.require_admin()
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  return (select auth.uid());
end;
$$;

create or replace function private.require_client()
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_client_id uuid := private.current_client_id();
begin
  if v_client_id is null then
    raise exception 'Client access required' using errcode = '42501';
  end if;
  return v_client_id;
end;
$$;

revoke all on function private.require_admin(), private.require_client() from public;

-- ============================================================
-- ADMIN: QUOTATIONS
-- ============================================================

create or replace function public.admin_create_quotation(
  p_service_request_id uuid,
  p_notes text default null,
  p_terms text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_sr public.service_requests;
  v_quotation public.quotations;
  v_revision_id uuid;
begin
  select * into v_sr from public.service_requests where id = p_service_request_id for update;
  if not found then
    raise exception 'Service request not found' using errcode = 'P0002';
  end if;
  if v_sr.client_id is null or v_sr.vehicle_id is null then
    raise exception 'Link the service request to a client and vehicle before creating a quotation';
  end if;
  if v_sr.status in ('CANCELLED', 'CONVERTED_TO_JOB') then
    raise exception 'Cannot quote a service request with status %', v_sr.status;
  end if;
  if exists (select 1 from public.quotations q where q.service_request_id = v_sr.id) then
    raise exception 'A quotation already exists for this service request';
  end if;

  insert into public.quotations (service_request_id, created_by)
  values (v_sr.id, v_admin)
  returning * into v_quotation;

  insert into public.quotation_revisions (quotation_id, revision_number, created_by, notes, terms)
  values (v_quotation.id, 1, v_admin, p_notes, p_terms)
  returning id into v_revision_id;

  update public.service_requests set status = 'QUOTATION_CREATED'
  where id = v_sr.id and status in ('NEW', 'UNDER_REVIEW');

  return jsonb_build_object(
    'quotation_id', v_quotation.id,
    'quotation_number', v_quotation.quotation_number,
    'revision_id', v_revision_id,
    'revision_number', 1
  );
end;
$$;

-- New DRAFT revision copied from the latest revision (items snapshot included).
create or replace function public.admin_create_quotation_revision(p_quotation_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_source public.quotation_revisions;
  v_new_id uuid;
begin
  perform 1 from public.quotations where id = p_quotation_id for update;
  if not found then
    raise exception 'Quotation not found' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from public.quotation_revisions qr
    join public.quotation_signatures qs on qs.quotation_revision_id = qr.id
    where qr.quotation_id = p_quotation_id
  ) then
    raise exception 'This quotation already has a signed revision and cannot be revised';
  end if;
  if exists (
    select 1 from public.quotation_revisions
    where quotation_id = p_quotation_id and status = 'DRAFT'
  ) then
    raise exception 'A DRAFT revision already exists for this quotation; edit it instead';
  end if;

  select * into v_source from public.quotation_revisions
  where quotation_id = p_quotation_id
  order by revision_number desc
  limit 1;

  insert into public.quotation_revisions
    (quotation_id, revision_number, created_by, subtotal, discount, tax, notes, terms)
  values
    (p_quotation_id, v_source.revision_number + 1, v_admin,
     v_source.subtotal, v_source.discount, v_source.tax, v_source.notes, v_source.terms)
  returning id into v_new_id;

  insert into public.quotation_items
    (quotation_revision_id, catalogue_product_id, name, description, quantity, approximate_value, final_value, line_total)
  select v_new_id, i.catalogue_product_id, i.name, i.description, i.quantity, i.approximate_value, i.final_value, i.line_total
  from public.quotation_items i
  where i.quotation_revision_id = v_source.id
  order by i.created_at;

  return jsonb_build_object(
    'revision_id', v_new_id,
    'revision_number', v_source.revision_number + 1,
    'copied_from_revision_id', v_source.id
  );
end;
$$;

create or replace function public.admin_send_quotation_revision(p_revision_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_rev public.quotation_revisions;
begin
  select * into v_rev from public.quotation_revisions where id = p_revision_id for update;
  if not found then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  perform 1 from public.quotations where id = v_rev.quotation_id for update;

  if v_rev.status <> 'DRAFT' then
    raise exception 'Only DRAFT revisions can be sent (current status: %)', v_rev.status;
  end if;
  if not exists (select 1 from public.quotation_items where quotation_revision_id = v_rev.id) then
    raise exception 'Add at least one item before sending the quotation';
  end if;
  if exists (
    select 1 from public.quotation_revisions qr
    join public.quotation_signatures qs on qs.quotation_revision_id = qr.id
    where qr.quotation_id = v_rev.quotation_id
  ) then
    raise exception 'This quotation already has a signed revision';
  end if;

  update public.quotation_revisions
  set status = 'SUPERSEDED'
  where quotation_id = v_rev.quotation_id
    and id <> v_rev.id
    and status in ('SENT', 'VIEWED', 'CHANGE_REQUESTED', 'ACCEPTED');

  update public.quotation_revisions
  set status = 'SENT', sent_at = now()
  where id = v_rev.id;

  update public.service_requests sr
  set status = 'QUOTATION_SENT'
  from public.quotations q
  where q.id = v_rev.quotation_id
    and sr.id = q.service_request_id
    and sr.status in ('NEW', 'UNDER_REVIEW', 'QUOTATION_CREATED');

  return jsonb_build_object('revision_id', v_rev.id, 'status', 'SENT');
end;
$$;

create or replace function public.admin_close_quotation_revision(
  p_revision_id uuid,
  p_status public.quotation_revision_status default 'CANCELLED'
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
begin
  if p_status not in ('CANCELLED', 'EXPIRED') then
    raise exception 'Revisions can only be closed as CANCELLED or EXPIRED';
  end if;
  update public.quotation_revisions set status = p_status where id = p_revision_id;
  if not found then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object('revision_id', p_revision_id, 'status', p_status);
end;
$$;

create or replace function public.admin_respond_quotation_change_request(
  p_change_request_id uuid,
  p_status public.change_request_status,
  p_response text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
begin
  if p_status = 'PENDING' then
    raise exception 'Choose a resolution status';
  end if;
  update public.quotation_change_requests
  set status = p_status,
      admin_response = nullif(btrim(p_response), ''),
      responded_at = now()
  where id = p_change_request_id and status = 'PENDING';
  if not found then
    raise exception 'Pending change request not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object('change_request_id', p_change_request_id, 'status', p_status);
end;
$$;

create or replace function public.admin_respond_vehicle_correction(
  p_request_id uuid,
  p_status public.change_request_status,
  p_response text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
begin
  if p_status = 'PENDING' then
    raise exception 'Choose a resolution status';
  end if;
  update public.vehicle_correction_requests
  set status = p_status,
      admin_response = nullif(btrim(p_response), ''),
      responded_by = v_admin,
      responded_at = now()
  where id = p_request_id and status = 'PENDING';
  if not found then
    raise exception 'Pending vehicle correction request not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object('request_id', p_request_id, 'status', p_status);
end;
$$;

-- ============================================================
-- ADMIN: SERVICE JOBS
-- ============================================================

create or replace function public.admin_create_service_job(
  p_quotation_revision_id uuid,
  p_scheduled_at timestamptz default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_ctx record;
  v_job public.service_jobs;
  v_items integer;
begin
  select qr.id as revision_id, sr.id as service_request_id, sr.vehicle_id
  into v_ctx
  from public.quotation_revisions qr
  join public.quotations q on q.id = qr.quotation_id
  join public.service_requests sr on sr.id = q.service_request_id
  where qr.id = p_quotation_revision_id
  for update of sr;
  if not found then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.quotation_signatures where quotation_revision_id = p_quotation_revision_id
  ) then
    raise exception 'The quotation revision must be accepted and signed before creating a service job';
  end if;
  if exists (select 1 from public.service_jobs where service_request_id = v_ctx.service_request_id) then
    raise exception 'A service job already exists for this service request';
  end if;

  insert into public.service_jobs (service_request_id, quotation_revision_id, vehicle_id, scheduled_at)
  values (v_ctx.service_request_id, p_quotation_revision_id, v_ctx.vehicle_id, p_scheduled_at)
  returning * into v_job;

  insert into public.service_work_items
    (service_job_id, quotation_item_id, name, description, quantity, source, approval_status, approximate_value, final_value)
  select v_job.id, i.id, i.name, i.description, i.quantity, 'QUOTATION', 'NOT_REQUIRED', i.approximate_value, i.final_value
  from public.quotation_items i
  where i.quotation_revision_id = p_quotation_revision_id
  order by i.created_at;
  get diagnostics v_items = row_count;

  update public.service_requests set status = 'CONVERTED_TO_JOB' where id = v_ctx.service_request_id;

  return jsonb_build_object(
    'service_job_id', v_job.id,
    'job_number', v_job.job_number,
    'work_items_created', v_items
  );
end;
$$;

create or replace function public.admin_add_additional_work(
  p_service_job_id uuid,
  p_name text,
  p_quantity numeric,
  p_final_value numeric,
  p_description text default null,
  p_approximate_value numeric default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_id uuid;
begin
  if nullif(btrim(p_name), '') is null then
    raise exception 'Work name is required';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero';
  end if;
  if p_final_value is null or p_final_value < 0 then
    raise exception 'A non-negative price is required';
  end if;
  if not exists (select 1 from public.service_jobs where id = p_service_job_id) then
    raise exception 'Service job not found' using errcode = 'P0002';
  end if;

  insert into public.service_work_items
    (service_job_id, name, description, quantity, source, approval_status, approximate_value, final_value)
  values
    (p_service_job_id, btrim(p_name), p_description, p_quantity, 'ADDITIONAL', 'PENDING', p_approximate_value, p_final_value)
  returning id into v_id;

  return jsonb_build_object('work_item_id', v_id, 'approval_status', 'PENDING');
end;
$$;

create or replace function public.admin_update_service_job_status(
  p_service_job_id uuid,
  p_status public.service_job_status
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_job public.service_jobs;
begin
  update public.service_jobs set status = p_status
  where id = p_service_job_id
  returning * into v_job;
  if not found then
    raise exception 'Service job not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object(
    'service_job_id', v_job.id, 'status', v_job.status,
    'started_at', v_job.started_at, 'completed_at', v_job.completed_at
  );
end;
$$;

-- ============================================================
-- CLIENT: QUOTATIONS
-- ============================================================

create or replace function public.client_mark_quotation_viewed(p_revision_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_client uuid := private.require_client();
  v_rev public.quotation_revisions;
begin
  select * into v_rev from public.quotation_revisions where id = p_revision_id for update;
  if not found or v_rev.status = 'DRAFT'
     or private.revision_client_id(p_revision_id) is distinct from v_client then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if v_rev.status = 'SENT' then
    update public.quotation_revisions set status = 'VIEWED' where id = p_revision_id;
    return jsonb_build_object('revision_id', p_revision_id, 'status', 'VIEWED');
  end if;
  return jsonb_build_object('revision_id', p_revision_id, 'status', v_rev.status);
end;
$$;

create or replace function public.client_request_quotation_change(p_revision_id uuid, p_message text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_client uuid := private.require_client();
  v_rev public.quotation_revisions;
  v_id uuid;
begin
  if nullif(btrim(p_message), '') is null or length(p_message) > 2000 then
    raise exception 'Message must be between 1 and 2000 characters';
  end if;
  select * into v_rev from public.quotation_revisions where id = p_revision_id for update;
  if not found or v_rev.status = 'DRAFT'
     or private.revision_client_id(p_revision_id) is distinct from v_client then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if v_rev.status not in ('SENT', 'VIEWED', 'CHANGE_REQUESTED') then
    raise exception 'Changes cannot be requested on a quotation revision that is %', v_rev.status;
  end if;

  insert into public.quotation_change_requests (quotation_revision_id, client_id, profile_id, message)
  values (p_revision_id, v_client, (select auth.uid()), btrim(p_message))
  returning id into v_id;

  if v_rev.status <> 'CHANGE_REQUESTED' then
    update public.quotation_revisions set status = 'CHANGE_REQUESTED' where id = p_revision_id;
  end if;

  return jsonb_build_object('change_request_id', v_id, 'revision_status', 'CHANGE_REQUESTED');
end;
$$;

create or replace function public.client_accept_quotation_revision(
  p_revision_id uuid,
  p_consent_given boolean,
  p_consent_text text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_client uuid := private.require_client();
  v_rev public.quotation_revisions;
begin
  if p_consent_given is not true then
    raise exception 'Explicit consent is required to accept the quotation';
  end if;
  if length(btrim(coalesce(p_consent_text, ''))) < 10 or length(p_consent_text) > 5000 then
    raise exception 'The consent statement shown to the client must be recorded';
  end if;

  select * into v_rev from public.quotation_revisions where id = p_revision_id for update;
  if not found or v_rev.status = 'DRAFT'
     or private.revision_client_id(p_revision_id) is distinct from v_client then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if v_rev.status not in ('SENT', 'VIEWED', 'CHANGE_REQUESTED') then
    raise exception 'A quotation revision that is % cannot be accepted', v_rev.status;
  end if;

  update public.quotation_revisions
  set status = 'ACCEPTED',
      accepted_at = now(),
      accepted_by_profile_id = (select auth.uid()),
      acceptance_consent_text = btrim(p_consent_text)
  where id = p_revision_id
  returning * into v_rev;

  return jsonb_build_object('revision_id', v_rev.id, 'status', v_rev.status, 'accepted_at', v_rev.accepted_at);
end;
$$;

create or replace function public.client_reject_quotation_revision(p_revision_id uuid, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_client uuid := private.require_client();
  v_rev public.quotation_revisions;
begin
  if length(coalesce(p_reason, '')) > 2000 then
    raise exception 'Reason must be at most 2000 characters';
  end if;
  select * into v_rev from public.quotation_revisions where id = p_revision_id for update;
  if not found or v_rev.status = 'DRAFT'
     or private.revision_client_id(p_revision_id) is distinct from v_client then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if v_rev.status not in ('SENT', 'VIEWED', 'CHANGE_REQUESTED') then
    raise exception 'A quotation revision that is % cannot be rejected', v_rev.status;
  end if;

  update public.quotation_revisions
  set status = 'REJECTED', rejected_at = now(), rejection_reason = nullif(btrim(p_reason), '')
  where id = p_revision_id;

  return jsonb_build_object('revision_id', p_revision_id, 'status', 'REJECTED');
end;
$$;

-- The client first uploads the drawn PNG to the private `signatures` bucket at
-- {client_id}/{revision_id}/{file}.png (storage policy only allows this for
-- their own ACCEPTED, unsigned revision), then calls this function.
create or replace function public.client_sign_quotation_revision(p_revision_id uuid, p_signature_path text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_client uuid := private.require_client();
  v_uid uuid := (select auth.uid());
  v_rev public.quotation_revisions;
  v_signature public.quotation_signatures;
begin
  select * into v_rev from public.quotation_revisions where id = p_revision_id for update;
  if not found or v_rev.status = 'DRAFT'
     or private.revision_client_id(p_revision_id) is distinct from v_client then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.quotation_signatures where quotation_revision_id = p_revision_id) then
    raise exception 'This quotation revision is already signed';
  end if;
  if v_rev.status <> 'ACCEPTED' then
    raise exception 'Accept the quotation revision before signing it';
  end if;
  if v_rev.accepted_by_profile_id is distinct from v_uid then
    raise exception 'The quotation must be signed by the same user who accepted it';
  end if;
  if p_signature_path is null
     or p_signature_path !~ ('^' || v_client::text || '/' || p_revision_id::text || '/[A-Za-z0-9_-]{1,64}\.png$') then
    raise exception 'Invalid signature file path';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'signatures'
      and o.name = p_signature_path
      and o.owner_id = v_uid::text
  ) then
    raise exception 'Signature image has not been uploaded';
  end if;

  insert into public.quotation_signatures
    (quotation_revision_id, client_id, profile_id, signature_file, signature_method,
     consent_text, accepted_at, signed_at)
  values
    (p_revision_id, v_client, v_uid, p_signature_path, 'DRAWN',
     v_rev.acceptance_consent_text, v_rev.accepted_at, now())
  returning * into v_signature;

  -- Any leftover draft of this quotation can no longer be used.
  update public.quotation_revisions set status = 'CANCELLED'
  where quotation_id = v_rev.quotation_id and status = 'DRAFT';

  update public.service_requests sr
  set status = 'APPROVED'
  from public.quotations q
  where q.id = v_rev.quotation_id
    and sr.id = q.service_request_id
    and sr.status not in ('CONVERTED_TO_JOB', 'CANCELLED');

  return jsonb_build_object(
    'signature_id', v_signature.id,
    'revision_id', p_revision_id,
    'signed_at', v_signature.signed_at
  );
end;
$$;

-- ============================================================
-- CLIENT: ADDITIONAL WORK & VEHICLE CORRECTIONS
-- ============================================================

create or replace function public.client_decide_additional_work(
  p_work_item_id uuid,
  p_approve boolean,
  p_expected_final_value numeric,
  p_note text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_client uuid := private.require_client();
  v_item public.service_work_items;
begin
  if p_approve is null then
    raise exception 'Choose approve or reject';
  end if;
  if length(coalesce(p_note, '')) > 2000 then
    raise exception 'Note must be at most 2000 characters';
  end if;

  select * into v_item from public.service_work_items where id = p_work_item_id for update;
  if not found or private.service_job_client_id(v_item.service_job_id) is distinct from v_client then
    raise exception 'Work item not found' using errcode = 'P0002';
  end if;
  if v_item.source <> 'ADDITIONAL' then
    raise exception 'Only additional work requires client approval';
  end if;
  if v_item.approval_status <> 'PENDING' then
    raise exception 'This additional work has already been %', lower(v_item.approval_status::text);
  end if;
  if p_expected_final_value is distinct from v_item.final_value then
    raise exception 'The stated price has changed; please review the latest amount';
  end if;

  update public.service_work_items
  set approval_status = (case when p_approve then 'APPROVED' else 'REJECTED' end)::public.additional_work_approval_status,
      approved_value = case when p_approve then v_item.final_value end,
      decision_by_profile_id = (select auth.uid()),
      decision_at = now(),
      approval_note = nullif(btrim(p_note), ''),
      status = case when p_approve then v_item.status else 'CANCELLED'::public.work_item_status end
  where id = p_work_item_id
  returning * into v_item;

  return jsonb_build_object(
    'work_item_id', v_item.id,
    'approval_status', v_item.approval_status,
    'approved_value', v_item.approved_value,
    'decision_at', v_item.decision_at
  );
end;
$$;

create or replace function public.client_request_vehicle_correction(
  p_vehicle_id uuid,
  p_message text,
  p_requested_changes jsonb default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_client uuid := private.require_client();
  v_id uuid;
begin
  if nullif(btrim(p_message), '') is null or length(p_message) > 2000 then
    raise exception 'Message must be between 1 and 2000 characters';
  end if;
  if p_requested_changes is not null
     and (jsonb_typeof(p_requested_changes) <> 'object' or octet_length(p_requested_changes::text) > 4000) then
    raise exception 'requested_changes must be a JSON object under 4KB';
  end if;
  if not exists (select 1 from public.vehicles where id = p_vehicle_id and client_id = v_client) then
    raise exception 'Vehicle not found' using errcode = 'P0002';
  end if;

  insert into public.vehicle_correction_requests (vehicle_id, client_id, profile_id, message, requested_changes)
  values (p_vehicle_id, v_client, (select auth.uid()), btrim(p_message), p_requested_changes)
  returning id into v_id;

  return jsonb_build_object('request_id', v_id, 'status', 'PENDING');
end;
$$;

-- ============================================================
-- PRIVILEGES: authenticated only
-- ============================================================

revoke all on function
  public.admin_create_quotation(uuid, text, text),
  public.admin_create_quotation_revision(uuid),
  public.admin_send_quotation_revision(uuid),
  public.admin_close_quotation_revision(uuid, public.quotation_revision_status),
  public.admin_respond_quotation_change_request(uuid, public.change_request_status, text),
  public.admin_respond_vehicle_correction(uuid, public.change_request_status, text),
  public.admin_create_service_job(uuid, timestamptz),
  public.admin_add_additional_work(uuid, text, numeric, numeric, text, numeric),
  public.admin_update_service_job_status(uuid, public.service_job_status),
  public.client_mark_quotation_viewed(uuid),
  public.client_request_quotation_change(uuid, text),
  public.client_accept_quotation_revision(uuid, boolean, text),
  public.client_reject_quotation_revision(uuid, text),
  public.client_sign_quotation_revision(uuid, text),
  public.client_decide_additional_work(uuid, boolean, numeric, text),
  public.client_request_vehicle_correction(uuid, text, jsonb)
from public, anon;

grant execute on function
  public.admin_create_quotation(uuid, text, text),
  public.admin_create_quotation_revision(uuid),
  public.admin_send_quotation_revision(uuid),
  public.admin_close_quotation_revision(uuid, public.quotation_revision_status),
  public.admin_respond_quotation_change_request(uuid, public.change_request_status, text),
  public.admin_respond_vehicle_correction(uuid, public.change_request_status, text),
  public.admin_create_service_job(uuid, timestamptz),
  public.admin_add_additional_work(uuid, text, numeric, numeric, text, numeric),
  public.admin_update_service_job_status(uuid, public.service_job_status),
  public.client_mark_quotation_viewed(uuid),
  public.client_request_quotation_change(uuid, text),
  public.client_accept_quotation_revision(uuid, boolean, text),
  public.client_reject_quotation_revision(uuid, text),
  public.client_sign_quotation_revision(uuid, text),
  public.client_decide_additional_work(uuid, boolean, numeric, text),
  public.client_request_vehicle_correction(uuid, text, jsonb)
to authenticated;
