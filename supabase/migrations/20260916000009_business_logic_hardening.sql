-- AutoTricks hardening 7/7: Day 3 Business Logic Hardening
-- 1. Service Request Lifecycle Guard: Enforce strict sequential status transitions,
--    prevent arbitrary jumps, prevent status manipulation, block resurrecting CANCELLED requests,
--    and verify business prerequisites at every stage.
-- 2. Service Job Lifecycle Guard: Enforce strict sequential status transitions
--    (SCHEDULED -> VEHICLE_RECEIVED -> INSPECTION -> WORK_IN_PROGRESS -> QUALITY_CHECK -> READY_FOR_DELIVERY -> COMPLETED),
--    prevent arbitrary jumps and status reversals, prevent job creation from cancelled requests.
-- 3. Quotation Calculations & Revisions: Enforce server-side subtotal/total computation,
--    discount <= subtotal, non-negative discount and tax, sequential revision numbering,
--    and verified client-only acceptance evidence.
-- 4. Additional Work: Provide dedicated cancellation RPC and verify approval rules.
-- 5. Admin RPCs: admin_link_service_request, admin_cancel_service_request, admin_cancel_service_work_item.

-- ============================================================
-- 1. SERVICE REQUEST LIFECYCLE GUARD
-- ============================================================

create or replace function private.guard_service_request_lifecycle()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'NEW' then
      raise exception 'New service requests must have status NEW (attempted: %)', new.status;
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    -- Terminal status checks: once CONVERTED_TO_JOB or CANCELLED, status is closed
    if old.status = 'CONVERTED_TO_JOB' then
      raise exception 'Service requests converted to a job cannot change status (% -> %)', old.status, new.status;
    end if;
    if old.status = 'CANCELLED' then
      raise exception 'Cancelled service requests cannot change status (% -> %)', old.status, new.status;
    end if;

    -- Valid forward status transitions and legal cancellation
    if not (
      (old.status = 'NEW' and new.status in ('UNDER_REVIEW', 'CANCELLED'))
      or (old.status = 'UNDER_REVIEW' and new.status in ('QUOTATION_CREATED', 'CANCELLED'))
      or (old.status = 'QUOTATION_CREATED' and new.status in ('QUOTATION_SENT', 'CANCELLED'))
      or (old.status = 'QUOTATION_SENT' and new.status in ('APPROVED', 'CANCELLED'))
      or (old.status = 'APPROVED' and new.status in ('CONVERTED_TO_JOB', 'CANCELLED'))
    ) then
      raise exception 'Invalid service request status transition % -> %; arbitrary status jumps and reversals are forbidden',
        old.status, new.status;
    end if;

    -- Business prerequisites for destination states
    if new.status = 'UNDER_REVIEW' then
      if new.client_id is null or new.vehicle_id is null then
        raise exception 'Service request requires an identified client and vehicle before moving to UNDER_REVIEW';
      end if;
    elsif new.status = 'QUOTATION_CREATED' then
      if not exists (select 1 from public.quotations q where q.service_request_id = new.id) then
        raise exception 'Service request cannot transition to QUOTATION_CREATED without an existing quotation';
      end if;
    elsif new.status = 'QUOTATION_SENT' then
      if not exists (
        select 1 from public.quotation_revisions qr
        join public.quotations q on q.id = qr.quotation_id
        where q.service_request_id = new.id and qr.status in ('SENT', 'VIEWED', 'CHANGE_REQUESTED', 'ACCEPTED', 'SUPERSEDED')
      ) then
        raise exception 'Service request cannot transition to QUOTATION_SENT without a sent quotation revision';
      end if;
    elsif new.status = 'APPROVED' then
      if not exists (
        select 1 from public.quotation_signatures qs
        join public.quotation_revisions qr on qr.id = qs.quotation_revision_id
        join public.quotations q on q.id = qr.quotation_id
        where q.service_request_id = new.id
      ) then
        raise exception 'Service request cannot transition to APPROVED without an accepted and signed quotation revision';
      end if;
    elsif new.status = 'CONVERTED_TO_JOB' then
      if not exists (select 1 from public.service_jobs sj where sj.service_request_id = new.id) then
        raise exception 'Service request cannot transition to CONVERTED_TO_JOB without an existing service job';
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists service_requests_lifecycle_guard on public.service_requests;
create trigger service_requests_lifecycle_guard
before insert or update on public.service_requests
for each row execute function private.guard_service_request_lifecycle();

-- ============================================================
-- 2. QUOTATION TOTALS & REVISION INVARIANTS
-- ============================================================

-- Revision totals: total = subtotal - discount + tax (with discount <= subtotal)
create or replace function private.compute_revision_total()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' or tg_op = 'INSERT' then
    if exists (select 1 from public.quotation_items where quotation_revision_id = coalesce(new.id, old.id)) then
      new.subtotal := coalesce((
        select sum(line_total) from public.quotation_items
        where quotation_revision_id = coalesce(new.id, old.id)
      ), 0);
    end if;
  end if;

  if new.discount < 0 then
    raise exception 'Quotation discount cannot be negative';
  end if;
  if new.tax < 0 then
    raise exception 'Quotation tax cannot be negative';
  end if;
  if new.discount > new.subtotal then
    raise exception 'Quotation discount cannot exceed subtotal';
  end if;

  new.total := round(new.subtotal - new.discount + new.tax, 2);
  return new;
end;
$$;

-- Sequential revision numbers: revision_number must equal (current_max + 1)
create or replace function private.guard_sequential_revision_number()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_max integer;
begin
  select coalesce(max(revision_number), 0) into v_max
  from public.quotation_revisions
  where quotation_id = new.quotation_id;

  if new.revision_number is distinct from (v_max + 1) then
    raise exception 'Quotation revision numbers must be strictly sequential; expected %, got %',
      v_max + 1, new.revision_number;
  end if;
  return new;
end;
$$;

drop trigger if exists quotation_revisions_sequential_number on public.quotation_revisions;
create trigger quotation_revisions_sequential_number
before insert on public.quotation_revisions
for each row execute function private.guard_sequential_revision_number();

-- Hardened prevent_signed_revision_mutation with acceptance verification
create or replace function public.prevent_signed_revision_mutation()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if exists (
    select 1 from public.quotation_signatures qs
    where qs.quotation_revision_id = old.id
  ) then
    raise exception 'Signed quotation revisions are immutable';
  end if;

  if tg_op = 'DELETE' then
    if old.status <> 'DRAFT' then
      raise exception 'Only DRAFT quotation revisions can be deleted';
    end if;
    return old;
  end if;

  if new.quotation_id is distinct from old.quotation_id
     or new.revision_number is distinct from old.revision_number
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Quotation revision identity is immutable';
  end if;

  if old.status <> 'DRAFT' and (
       new.subtotal, new.discount, new.tax, new.total, new.notes, new.terms
     ) is distinct from (
       old.subtotal, old.discount, old.tax, old.total, old.notes, old.terms
     ) then
    raise exception 'Only DRAFT quotation revisions can be edited; create a new revision instead';
  end if;

  if (old.sent_at is not null and new.sent_at is distinct from old.sent_at)
     or (old.accepted_at is not null and (new.accepted_at, new.accepted_by_profile_id, new.acceptance_consent_text)
           is distinct from (old.accepted_at, old.accepted_by_profile_id, old.acceptance_consent_text))
     or (old.rejected_at is not null and (new.rejected_at, new.rejection_reason)
           is distinct from (old.rejected_at, old.rejection_reason)) then
    raise exception 'Quotation revision lifecycle evidence is immutable';
  end if;

  if new.status is distinct from old.status and not (
       (old.status = 'DRAFT' and new.status in ('SENT', 'CANCELLED'))
    or (old.status = 'SENT' and new.status in ('VIEWED', 'CHANGE_REQUESTED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'SUPERSEDED'))
    or (old.status = 'VIEWED' and new.status in ('CHANGE_REQUESTED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'SUPERSEDED'))
    or (old.status = 'CHANGE_REQUESTED' and new.status in ('ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'SUPERSEDED'))
    or (old.status = 'ACCEPTED' and new.status in ('CANCELLED', 'SUPERSEDED'))
  ) then
    raise exception 'Invalid quotation revision status transition % -> %', old.status, new.status;
  end if;

  -- Acceptance forgery protection: accepted_by_profile_id must belong to a CLIENT of the owning client
  if new.status = 'ACCEPTED' and old.status is distinct from 'ACCEPTED' then
    if new.accepted_by_profile_id is null or not exists (
      select 1 from public.profiles p
      where p.id = new.accepted_by_profile_id
        and p.role = 'CLIENT'
        and p.client_id = private.revision_client_id(new.id)
    ) then
      raise exception 'Quotation revision can only be accepted by a CLIENT profile of the owning client';
    end if;
    if nullif(btrim(new.acceptance_consent_text), '') is null then
      raise exception 'Acceptance consent text is required';
    end if;
  end if;

  return new;
end;
$$;

-- ============================================================
-- 3. SERVICE JOB LIFECYCLE GUARD HARDENING
-- ============================================================

create or replace function private.guard_service_job()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_sr record;
  v_rev record;
begin
  if tg_op = 'DELETE' then
    raise exception 'Service jobs cannot be deleted; cancel them instead';
  end if;

  if tg_op = 'INSERT' then
    select s.client_id, s.vehicle_id, s.status into v_sr
    from public.service_requests s where s.id = new.service_request_id;

    if not found then
      raise exception 'Service request not found' using errcode = 'P0002';
    end if;
    if v_sr.status = 'CANCELLED' then
      raise exception 'Cannot create a service job for a cancelled service request';
    end if;
    if v_sr.client_id is null or v_sr.vehicle_id is null then
      raise exception 'Service request must be linked to a client and vehicle before a job is created';
    end if;
    if new.vehicle_id is distinct from v_sr.vehicle_id or not exists (
      select 1 from public.vehicles v where v.id = new.vehicle_id and v.client_id = v_sr.client_id
    ) then
      raise exception 'Service job vehicle must be the service request vehicle of the same client';
    end if;

    select qr.status, q.service_request_id into v_rev
    from public.quotation_revisions qr
    join public.quotations q on q.id = qr.quotation_id
    where qr.id = new.quotation_revision_id;

    if not found or v_rev.service_request_id is distinct from new.service_request_id then
      raise exception 'Quotation revision does not belong to this service request';
    end if;
    if v_rev.status in ('CANCELLED', 'REJECTED') then
      raise exception 'Cannot create a service job from a cancelled or rejected quotation revision';
    end if;
    if not exists (
      select 1 from public.quotation_signatures qs
      where qs.quotation_revision_id = new.quotation_revision_id
    ) then
      raise exception 'A service job requires an accepted and signed quotation revision';
    end if;
    if new.status <> 'SCHEDULED' then
      raise exception 'New service jobs must start as SCHEDULED';
    end if;
    new.started_at := null;
    new.completed_at := null;
    return new;
  end if;

  if (new.job_number, new.service_request_id, new.quotation_revision_id, new.vehicle_id, new.created_at)
     is distinct from (old.job_number, old.service_request_id, old.quotation_revision_id, old.vehicle_id, old.created_at) then
    raise exception 'Service job identity is immutable';
  end if;

  if new.status is distinct from old.status then
    if old.status in ('COMPLETED', 'CANCELLED') then
      raise exception 'Closed service jobs cannot change status (% -> %)', old.status, new.status;
    end if;

    -- Strict sequential forward progression or cancellation
    if not (
      (old.status = 'SCHEDULED' and new.status in ('VEHICLE_RECEIVED', 'CANCELLED'))
      or (old.status = 'VEHICLE_RECEIVED' and new.status in ('INSPECTION', 'CANCELLED'))
      or (old.status = 'INSPECTION' and new.status in ('WORK_IN_PROGRESS', 'CANCELLED'))
      or (old.status = 'WORK_IN_PROGRESS' and new.status in ('QUALITY_CHECK', 'CANCELLED'))
      or (old.status = 'QUALITY_CHECK' and new.status in ('READY_FOR_DELIVERY', 'CANCELLED'))
      or (old.status = 'READY_FOR_DELIVERY' and new.status in ('COMPLETED', 'CANCELLED'))
    ) then
      raise exception 'Invalid service job status transition % -> %; arbitrary status jumps and reversals are forbidden',
        old.status, new.status;
    end if;

    if new.status = 'COMPLETED' and exists (
      select 1 from public.service_work_items w
      where w.service_job_id = new.id and w.status not in ('COMPLETED', 'CANCELLED')
    ) then
      raise exception 'All work items must be COMPLETED or CANCELLED before the job can be completed';
    end if;
    if old.status = 'SCHEDULED' and new.status <> 'CANCELLED' and old.started_at is null then
      new.started_at := now();
    end if;
    if new.status = 'COMPLETED' then
      new.completed_at := now();
    end if;
  elsif old.status in ('COMPLETED', 'CANCELLED') then
    raise exception 'Closed service jobs cannot be modified';
  elsif (new.started_at, new.completed_at) is distinct from (old.started_at, old.completed_at) then
    raise exception 'Job start/completion times are set by status changes';
  end if;

  return new;
end;
$$;

-- ============================================================
-- 4. WORKFLOW RPCS: NEW & HARDENED
-- ============================================================

-- Admin RPC: Link client and vehicle to a service request (moves NEW -> UNDER_REVIEW)
create or replace function public.admin_link_service_request(
  p_service_request_id uuid,
  p_client_id uuid,
  p_vehicle_id uuid
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_sr public.service_requests;
begin
  select * into v_sr from public.service_requests where id = p_service_request_id for update;
  if not found then
    raise exception 'Service request not found' using errcode = 'P0002';
  end if;
  if v_sr.status in ('CANCELLED', 'CONVERTED_TO_JOB') then
    raise exception 'Cannot link a service request with status %', v_sr.status;
  end if;
  if not exists (
    select 1 from public.vehicles v
    where v.id = p_vehicle_id and v.client_id = p_client_id
  ) then
    raise exception 'Vehicle does not belong to the specified client';
  end if;

  update public.service_requests
  set client_id = p_client_id,
      vehicle_id = p_vehicle_id,
      status = case when status = 'NEW' then 'UNDER_REVIEW'::public.service_request_status else status end
  where id = p_service_request_id
  returning * into v_sr;

  return jsonb_build_object(
    'service_request_id', v_sr.id,
    'client_id', v_sr.client_id,
    'vehicle_id', v_sr.vehicle_id,
    'status', v_sr.status
  );
end;
$$;

-- Admin RPC: Cancel a service request
create or replace function public.admin_cancel_service_request(
  p_service_request_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_sr public.service_requests;
begin
  select * into v_sr from public.service_requests where id = p_service_request_id for update;
  if not found then
    raise exception 'Service request not found' using errcode = 'P0002';
  end if;
  if v_sr.status in ('CANCELLED', 'CONVERTED_TO_JOB') then
    raise exception 'Cannot cancel a service request with status %', v_sr.status;
  end if;

  update public.service_requests
  set status = 'CANCELLED',
      admin_notes = case
        when nullif(btrim(p_reason), '') is not null then
          coalesce(admin_notes || E'\n', '') || 'Cancellation reason: ' || btrim(p_reason)
        else admin_notes
      end
  where id = p_service_request_id
  returning * into v_sr;

  return jsonb_build_object(
    'service_request_id', v_sr.id,
    'status', v_sr.status
  );
end;
$$;

-- Admin RPC: Cancel an additional work item
create or replace function public.admin_cancel_service_work_item(
  p_work_item_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_item public.service_work_items;
begin
  select * into v_item from public.service_work_items where id = p_work_item_id for update;
  if not found then
    raise exception 'Work item not found' using errcode = 'P0002';
  end if;
  if v_item.status in ('COMPLETED', 'CANCELLED') then
    raise exception 'Cannot cancel a work item that is %', v_item.status;
  end if;

  update public.service_work_items
  set status = 'CANCELLED'
  where id = p_work_item_id
  returning * into v_item;

  if nullif(btrim(p_reason), '') is not null then
    perform private.write_audit(
      'WORK_ITEM_CANCELLED',
      'service_work_items',
      p_work_item_id,
      jsonb_build_object('reason', btrim(p_reason))
    );
  end if;

  return jsonb_build_object(
    'work_item_id', v_item.id,
    'status', v_item.status
  );
end;
$$;

-- Hardened admin_create_quotation: enforce request must be UNDER_REVIEW
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
  if v_sr.status <> 'UNDER_REVIEW' then
    raise exception 'Service request must be UNDER_REVIEW before creating a quotation (current status: %)', v_sr.status;
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
  where id = v_sr.id and status = 'UNDER_REVIEW';

  return jsonb_build_object(
    'quotation_id', v_quotation.id,
    'quotation_number', v_quotation.quotation_number,
    'revision_id', v_revision_id,
    'revision_number', 1
  );
end;
$$;

-- Hardened admin_create_service_job: enforce request must be APPROVED, not CANCELLED
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
  select qr.id as revision_id, qr.status as revision_status, sr.id as service_request_id, sr.status as sr_status, sr.vehicle_id
  into v_ctx
  from public.quotation_revisions qr
  join public.quotations q on q.id = qr.quotation_id
  join public.service_requests sr on sr.id = q.service_request_id
  where qr.id = p_quotation_revision_id
  for update of sr;

  if not found then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if v_ctx.sr_status = 'CANCELLED' then
    raise exception 'Cannot create a service job for a cancelled service request';
  end if;
  if v_ctx.revision_status in ('CANCELLED', 'REJECTED') then
    raise exception 'Cannot create a service job from a cancelled or rejected quotation revision';
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

-- ============================================================
-- 5. FUNCTION PRIVILEGES
-- ============================================================

revoke all on function
  public.admin_link_service_request(uuid, uuid, uuid),
  public.admin_cancel_service_request(uuid, text),
  public.admin_cancel_service_work_item(uuid, text)
from public, anon;

grant execute on function
  public.admin_link_service_request(uuid, uuid, uuid),
  public.admin_cancel_service_request(uuid, text),
  public.admin_cancel_service_work_item(uuid, text)
to authenticated;
