-- AutoTricks hardening 1/5: private helpers, schema additions,
-- integrity and immutability guards.
-- Every guard here was added because a live probe against v1.0 showed
-- the corresponding invariant could be violated.

-- ============================================================
-- PRIVATE SCHEMA (not exposed through the Data API)
-- ============================================================

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;
alter default privileges in schema private revoke execute on functions from public;

-- Caller-identity helpers. SECURITY DEFINER so RLS policies can read
-- profiles without re-entering profiles RLS. They only ever describe the
-- caller (auth.uid()), never arbitrary users.
create or replace function private.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'ADMIN'
  );
$$;

create or replace function private.current_client_id()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select p.client_id from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'CLIENT';
$$;

create or replace function private.current_profile_id()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select p.id from public.profiles p where p.id = (select auth.uid());
$$;

-- Owning client of a quotation revision / service job.
create or replace function private.revision_client_id(p_revision_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select sr.client_id
  from public.quotation_revisions qr
  join public.quotations q on q.id = qr.quotation_id
  join public.service_requests sr on sr.id = q.service_request_id
  where qr.id = p_revision_id;
$$;

create or replace function private.service_job_client_id(p_job_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select sr.client_id
  from public.service_jobs sj
  join public.service_requests sr on sr.id = sj.service_request_id
  where sj.id = p_job_id;
$$;

-- ============================================================
-- REFERENCE NUMBERS  e.g. SR-2026-00001 / QT-2026-00125 / JOB-2026-00007
-- ============================================================

create sequence if not exists private.service_request_number_seq;
create sequence if not exists private.quotation_number_seq;
create sequence if not exists private.service_job_number_seq;

create or replace function private.next_reference(p_prefix text, p_seq regclass)
returns text
language sql volatile set search_path = ''
as $$
  select p_prefix || '-' || to_char(now() at time zone 'Asia/Kolkata', 'YYYY')
         || '-' || lpad(nextval(p_seq)::text, 5, '0');
$$;

alter table public.service_requests
  alter column request_number set default private.next_reference('SR', 'private.service_request_number_seq');
alter table public.quotations
  alter column quotation_number set default private.next_reference('QT', 'private.quotation_number_seq');
alter table public.service_jobs
  alter column job_number set default private.next_reference('JOB', 'private.service_job_number_seq');

-- ============================================================
-- SCHEMA ADDITIONS
-- ============================================================

-- Acceptance evidence lives on the revision (accept and sign are separate
-- client steps; the signature copies accepted_at/consent from here).
alter table public.quotation_revisions
  add column updated_at timestamptz not null default now(),
  add column sent_at timestamptz,
  add column accepted_at timestamptz,
  add column accepted_by_profile_id uuid references public.profiles(id) on delete restrict,
  add column acceptance_consent_text text,
  add column rejected_at timestamptz,
  add column rejection_reason text;

alter table public.quotation_revisions
  add constraint quotation_revisions_acceptance_ck check (
    status <> 'ACCEPTED'
    or (accepted_at is not null
        and accepted_by_profile_id is not null
        and nullif(btrim(acceptance_consent_text), '') is not null)
  );

create trigger quotation_revisions_set_updated_at
before update on public.quotation_revisions
for each row execute function public.set_updated_at();

alter table public.service_jobs add column scheduled_at timestamptz;

-- Which private bucket a document lives in.
alter table public.documents
  add column storage_bucket text generated always as (
    case document_type
      when 'QUOTATION_PDF' then 'quotation-pdfs'
      when 'SIGNED_QUOTATION_PDF' then 'signed-quotation-pdfs'
      else 'service-documents'
    end
  ) stored;

-- Client portal: "request vehicle corrections" (verified identity is admin-only).
create table public.vehicle_correction_requests (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  message text not null,
  requested_changes jsonb,
  status public.change_request_status not null default 'PENDING',
  admin_response text,
  responded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint vehicle_correction_requests_message_ck check (length(btrim(message)) between 1 and 2000)
);
alter table public.vehicle_correction_requests enable row level security;
revoke all on public.vehicle_correction_requests from anon, authenticated;

-- ============================================================
-- INDEXES (unindexed FKs reported by the performance advisor + new columns)
-- ============================================================

create index idx_audit_logs_actor on public.audit_logs(actor_profile_id);
create index idx_email_notifications_profile on public.email_notifications(profile_id);
create index idx_change_requests_profile_id on public.quotation_change_requests(profile_id);
create index idx_quotation_items_product_id on public.quotation_items(catalogue_product_id);
create index idx_quotation_revisions_created_by on public.quotation_revisions(created_by);
create index idx_quotation_revisions_accepted_by on public.quotation_revisions(accepted_by_profile_id);
create index idx_signatures_profile_id on public.quotation_signatures(profile_id);
create index idx_quotations_created_by on public.quotations(created_by);
create index idx_service_jobs_revision_id on public.service_jobs(quotation_revision_id);
create index idx_service_requests_created_by on public.service_requests(created_by);
create index idx_work_items_decision_by on public.service_work_items(decision_by_profile_id);
create index idx_work_items_quotation_item_id on public.service_work_items(quotation_item_id);
create index idx_vehicle_corrections_vehicle_id on public.vehicle_correction_requests(vehicle_id);
create index idx_vehicle_corrections_client_id on public.vehicle_correction_requests(client_id);
create index idx_vehicle_corrections_profile_id on public.vehicle_correction_requests(profile_id);
create index idx_vehicle_corrections_responded_by on public.vehicle_correction_requests(responded_by);
create index idx_vehicle_corrections_status on public.vehicle_correction_requests(status);
-- Website submission throttle lookup.
create index idx_service_requests_website_phone
  on public.service_requests ((original_submission->>'phone'), created_at)
  where source = 'WEBSITE';

-- ============================================================
-- GUARDS
-- ============================================================

alter function public.set_updated_at() set search_path = '';

-- Service requests: vehicle/client consistency, preserved origin data,
-- correct PHONE creator, no re-linking once quoted.
create or replace function public.validate_service_request_links()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.vehicle_id is not null and new.client_id is null then
    raise exception 'A service request vehicle requires a client';
  end if;

  if new.vehicle_id is not null and not exists (
    select 1 from public.vehicles v
    where v.id = new.vehicle_id and v.client_id = new.client_id
  ) then
    raise exception 'Service request vehicle must belong to the selected client';
  end if;

  if tg_op = 'INSERT' then
    -- Rows inserted by a signed-in user through the Data API are staff PHONE
    -- entries by that user. WEBSITE rows come only from the trusted endpoint.
    if (select auth.uid()) is not null
       and (new.source <> 'PHONE' or new.created_by is distinct from (select auth.uid())) then
      raise exception 'Staff-entered service requests must be PHONE requests created by the current user';
    end if;
    return new;
  end if;

  if new.request_number is distinct from old.request_number
     or new.source is distinct from old.source
     or new.original_submission is distinct from old.original_submission
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Service request origin data is immutable';
  end if;

  if (new.client_id is distinct from old.client_id or new.vehicle_id is distinct from old.vehicle_id)
     and exists (select 1 from public.quotations q where q.service_request_id = old.id) then
    raise exception 'Client and vehicle cannot change once a quotation exists for this service request';
  end if;

  return new;
end;
$$;

-- Vehicles are never transferred between clients.
create or replace function private.guard_vehicle()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.client_id is distinct from old.client_id then
    raise exception 'Vehicles cannot be transferred between clients; create a new vehicle record for the new owner';
  end if;
  return new;
end;
$$;

create trigger vehicles_guard
before update on public.vehicles
for each row execute function private.guard_vehicle();

-- Revision totals: total = subtotal - discount + tax.
create or replace function private.compute_revision_total()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.total := new.subtotal - new.discount + new.tax;
  if new.total < 0 then
    raise exception 'Quotation discount cannot exceed subtotal plus tax';
  end if;
  return new;
end;
$$;

create trigger quotation_revisions_compute_total
before insert or update on public.quotation_revisions
for each row execute function private.compute_revision_total();

-- Revisions: content editable only in DRAFT, signed = fully immutable,
-- valid status transitions, acceptance evidence write-once.
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

  return new;
end;
$$;

drop trigger quotation_revisions_prevent_signed_update on public.quotation_revisions;
create trigger quotation_revisions_prevent_signed_update
before update or delete on public.quotation_revisions
for each row execute function public.prevent_signed_revision_mutation();

-- Items: only while the revision is DRAFT (covers INSERT/DELETE too),
-- snapshot catalogue data, compute line_total = quantity x final_value.
create or replace function public.prevent_signed_item_mutation()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_revision_id uuid;
  v_status public.quotation_revision_status;
  v_product record;
begin
  if tg_op = 'DELETE' then
    v_revision_id := old.quotation_revision_id;
  else
    v_revision_id := new.quotation_revision_id;
  end if;

  if tg_op = 'UPDATE' and new.quotation_revision_id is distinct from old.quotation_revision_id then
    raise exception 'Quotation items cannot move between revisions';
  end if;

  if exists (
    select 1 from public.quotation_signatures qs
    where qs.quotation_revision_id = v_revision_id
  ) then
    raise exception 'Items of a signed quotation revision are immutable';
  end if;

  select qr.status into v_status
  from public.quotation_revisions qr where qr.id = v_revision_id;

  if v_status is distinct from 'DRAFT' then
    raise exception 'Quotation items can only be changed while the revision is DRAFT';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  if new.catalogue_product_id is not null
     and (tg_op = 'INSERT' or new.catalogue_product_id is distinct from old.catalogue_product_id) then
    select p.name, p.description, p.default_price into v_product
    from public.products p where p.id = new.catalogue_product_id;
    if not found then
      raise exception 'Catalogue product not found';
    end if;
    new.name := coalesce(new.name, v_product.name);
    new.description := coalesce(new.description, v_product.description);
    new.approximate_value := coalesce(new.approximate_value, v_product.default_price);
    new.final_value := coalesce(new.final_value, v_product.default_price);
  end if;

  new.line_total := round(new.quantity * new.final_value, 2);
  return new;
end;
$$;

drop trigger quotation_items_prevent_signed_update on public.quotation_items;
create trigger quotation_items_prevent_signed_update
before insert or update or delete on public.quotation_items
for each row execute function public.prevent_signed_item_mutation();

-- Keep revision subtotal in sync with its items. SECURITY DEFINER because
-- subtotal is not a client/admin-writable column.
create or replace function private.recalculate_revision_subtotal()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_revision_id uuid := coalesce(new.quotation_revision_id, old.quotation_revision_id);
begin
  update public.quotation_revisions qr
  set subtotal = coalesce((
    select sum(i.line_total) from public.quotation_items i
    where i.quotation_revision_id = v_revision_id
  ), 0)
  where qr.id = v_revision_id;
  return null;
end;
$$;

create trigger quotation_items_recalculate_subtotal
after insert or update or delete on public.quotation_items
for each row execute function private.recalculate_revision_subtotal();

-- Change requests: owner consistency, content immutable, resolve once.
create or replace function private.guard_quotation_change_request()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if private.revision_client_id(new.quotation_revision_id) is distinct from new.client_id then
      raise exception 'Change request client does not own the quotation revision';
    end if;
    if not exists (
      select 1 from public.profiles p
      where p.id = new.profile_id and p.role = 'CLIENT' and p.client_id = new.client_id
    ) then
      raise exception 'Change request must be made by a CLIENT profile of the owning client';
    end if;
    return new;
  end if;

  if (new.quotation_revision_id, new.client_id, new.profile_id, new.message, new.created_at)
     is distinct from (old.quotation_revision_id, old.client_id, old.profile_id, old.message, old.created_at) then
    raise exception 'Change request content is immutable';
  end if;
  if old.status <> 'PENDING' and new.status is distinct from old.status then
    raise exception 'Change request has already been resolved';
  end if;
  return new;
end;
$$;

create trigger quotation_change_requests_guard
before insert or update on public.quotation_change_requests
for each row execute function private.guard_quotation_change_request();

create or replace function private.guard_vehicle_correction_request()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not exists (
      select 1 from public.vehicles v where v.id = new.vehicle_id and v.client_id = new.client_id
    ) then
      raise exception 'Vehicle does not belong to this client';
    end if;
    if not exists (
      select 1 from public.profiles p
      where p.id = new.profile_id and p.role = 'CLIENT' and p.client_id = new.client_id
    ) then
      raise exception 'Correction request must be made by a CLIENT profile of the owning client';
    end if;
    return new;
  end if;

  if (new.vehicle_id, new.client_id, new.profile_id, new.message, new.requested_changes, new.created_at)
     is distinct from (old.vehicle_id, old.client_id, old.profile_id, old.message, old.requested_changes, old.created_at) then
    raise exception 'Vehicle correction request content is immutable';
  end if;
  if old.status <> 'PENDING' and new.status is distinct from old.status then
    raise exception 'Vehicle correction request has already been resolved';
  end if;
  return new;
end;
$$;

create trigger vehicle_correction_requests_guard
before insert or update on public.vehicle_correction_requests
for each row execute function private.guard_vehicle_correction_request();

-- Signatures: only for an ACCEPTED revision of the same client, made by a
-- CLIENT profile of that client; never updated or deleted.
create or replace function private.guard_quotation_signature()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_rev record;
begin
  if tg_op <> 'INSERT' then
    raise exception 'Quotation signatures are immutable';
  end if;

  select qr.status, qr.accepted_at, qr.accepted_by_profile_id, qr.acceptance_consent_text
  into v_rev
  from public.quotation_revisions qr where qr.id = new.quotation_revision_id;

  if not found or v_rev.status <> 'ACCEPTED' then
    raise exception 'Only an ACCEPTED quotation revision can be signed';
  end if;
  if private.revision_client_id(new.quotation_revision_id) is distinct from new.client_id then
    raise exception 'Signature client does not own the quotation revision';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = new.profile_id and p.role = 'CLIENT' and p.client_id = new.client_id
  ) then
    raise exception 'Signature must be made by a CLIENT profile of the owning client';
  end if;
  if new.accepted_at is distinct from v_rev.accepted_at
     or new.consent_text is distinct from v_rev.acceptance_consent_text then
    raise exception 'Signature acceptance evidence must match the accepted revision';
  end if;
  return new;
end;
$$;

create trigger quotation_signatures_guard
before insert or update or delete on public.quotation_signatures
for each row execute function private.guard_quotation_signature();

-- Documents: owner/path consistency, no DRAFT attachments, immutable rows,
-- signed quotation PDFs can never be deleted.
create or replace function public.validate_document_owner()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'Documents are immutable; upload a new document instead';
  end if;
  if tg_op = 'DELETE' then
    if old.document_type = 'SIGNED_QUOTATION_PDF' then
      raise exception 'Signed quotation documents cannot be deleted';
    end if;
    return old;
  end if;

  if split_part(new.storage_path, '/', 1) <> new.client_id::text then
    raise exception 'Document storage path must start with the owning client id';
  end if;

  if new.quotation_revision_id is not null then
    if private.revision_client_id(new.quotation_revision_id) is distinct from new.client_id then
      raise exception 'Document client does not own the quotation revision';
    end if;
    if exists (
      select 1 from public.quotation_revisions qr
      where qr.id = new.quotation_revision_id and qr.status = 'DRAFT'
    ) then
      raise exception 'Documents cannot be attached to a DRAFT quotation revision';
    end if;
  end if;

  if new.document_type = 'SIGNED_QUOTATION_PDF' and not exists (
    select 1 from public.quotation_signatures qs
    where qs.quotation_revision_id = new.quotation_revision_id
  ) then
    raise exception 'A signed quotation PDF requires a signed quotation revision';
  end if;

  if new.service_job_id is not null
     and private.service_job_client_id(new.service_job_id) is distinct from new.client_id then
    raise exception 'Document client does not own the service job';
  end if;

  return new;
end;
$$;

drop trigger documents_validate_owner on public.documents;
create trigger documents_validate_owner
before insert or update or delete on public.documents
for each row execute function public.validate_document_owner();

-- Service jobs: created only from a signed revision of the same request,
-- vehicle must be the request's vehicle of the same client, forward-only
-- status, completion requires all work closed.
create or replace function private.guard_service_job()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_sr record;
begin
  if tg_op = 'DELETE' then
    raise exception 'Service jobs cannot be deleted; cancel them instead';
  end if;

  if tg_op = 'INSERT' then
    select s.client_id, s.vehicle_id into v_sr
    from public.service_requests s where s.id = new.service_request_id;

    if v_sr.client_id is null or v_sr.vehicle_id is null then
      raise exception 'Service request must be linked to a client and vehicle before a job is created';
    end if;
    if new.vehicle_id is distinct from v_sr.vehicle_id or not exists (
      select 1 from public.vehicles v where v.id = new.vehicle_id and v.client_id = v_sr.client_id
    ) then
      raise exception 'Service job vehicle must be the service request vehicle of the same client';
    end if;
    if not exists (
      select 1 from public.quotation_revisions qr
      join public.quotations q on q.id = qr.quotation_id
      where qr.id = new.quotation_revision_id and q.service_request_id = new.service_request_id
    ) then
      raise exception 'Quotation revision does not belong to this service request';
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
    if old.status in ('COMPLETED', 'CANCELLED') or new.status < old.status then
      raise exception 'Invalid service job status transition % -> %', old.status, new.status;
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

create trigger service_jobs_guard
before insert or update or delete on public.service_jobs
for each row execute function private.guard_service_job();

-- Work items: QUOTATION items come from the job's signed revision;
-- ADDITIONAL work needs owning-client approval before execution; agreed
-- scope/price and approval evidence are immutable.
create or replace function private.guard_service_work_item()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_job record;
begin
  if tg_op = 'DELETE' then
    raise exception 'Work items cannot be deleted; cancel them instead';
  end if;

  select sj.status, sj.quotation_revision_id into v_job
  from public.service_jobs sj where sj.id = new.service_job_id;

  if tg_op = 'INSERT' then
    if v_job.status in ('COMPLETED', 'CANCELLED') then
      raise exception 'Cannot add work to a closed service job';
    end if;
    if new.source = 'QUOTATION' then
      if not exists (
        select 1 from public.quotation_items qi
        where qi.id = new.quotation_item_id and qi.quotation_revision_id = v_job.quotation_revision_id
      ) then
        raise exception 'Quotation work items must reference an item of the job''s signed revision';
      end if;
    else
      if new.approval_status <> 'PENDING'
         or new.decision_by_profile_id is not null
         or new.decision_at is not null
         or new.approved_value is not null then
        raise exception 'Additional work must start with PENDING client approval';
      end if;
      if new.final_value is null then
        raise exception 'Additional work requires a stated price (final_value)';
      end if;
      if new.status <> 'PENDING' then
        raise exception 'Additional work cannot start before client approval';
      end if;
    end if;
    return new;
  end if;

  if (new.service_job_id, new.source, new.quotation_item_id, new.created_at)
     is distinct from (old.service_job_id, old.source, old.quotation_item_id, old.created_at) then
    raise exception 'Work item identity is immutable';
  end if;

  if v_job.status in ('COMPLETED', 'CANCELLED') then
    raise exception 'Work items of a closed service job cannot be modified';
  end if;

  if (new.name, new.description, new.quantity, new.approximate_value, new.final_value)
     is distinct from (old.name, old.description, old.quantity, old.approximate_value, old.final_value)
     and (old.source = 'QUOTATION' or old.approval_status <> 'PENDING') then
    raise exception 'Agreed work item scope and price cannot be changed';
  end if;

  if new.approval_status is distinct from old.approval_status then
    if old.approval_status <> 'PENDING' or new.approval_status not in ('APPROVED', 'REJECTED') then
      raise exception 'Invalid approval transition % -> %', old.approval_status, new.approval_status;
    end if;
    if new.decision_by_profile_id is null or new.decision_at is null or not exists (
      select 1 from public.profiles p
      where p.id = new.decision_by_profile_id
        and p.role = 'CLIENT'
        and p.client_id = private.service_job_client_id(new.service_job_id)
    ) then
      raise exception 'Additional work can only be approved or rejected by the owning client';
    end if;
    if new.approval_status = 'APPROVED' and new.approved_value is distinct from new.final_value then
      raise exception 'Approved value must equal the stated price';
    end if;
    if new.approval_status = 'REJECTED' and new.approved_value is not null then
      raise exception 'Rejected work cannot carry an approved value';
    end if;
  elsif (new.approved_value, new.decision_by_profile_id, new.decision_at, new.approval_note)
        is distinct from (old.approved_value, old.decision_by_profile_id, old.decision_at, old.approval_note) then
    raise exception 'Approval evidence is immutable';
  end if;

  if new.status is distinct from old.status and old.status in ('COMPLETED', 'CANCELLED') then
    raise exception 'Work item is already closed';
  end if;

  if new.source = 'ADDITIONAL'
     and new.status in ('IN_PROGRESS', 'COMPLETED')
     and new.approval_status <> 'APPROVED' then
    raise exception 'Additional work cannot be executed before client approval';
  end if;

  return new;
end;
$$;

create trigger service_work_items_guard
before insert or update or delete on public.service_work_items
for each row execute function private.guard_service_work_item();

-- Audit logs are append-only (the only permitted update is the FK's
-- ON DELETE SET NULL of actor_profile_id).
create or replace function private.guard_audit_log()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and new.actor_profile_id is null and old.actor_profile_id is not null
     and (new.id, new.action, new.entity_type, new.entity_id, new.metadata, new.created_at)
         is not distinct from (old.id, old.action, old.entity_type, old.entity_id, old.metadata, old.created_at) then
    return new;
  end if;
  raise exception 'Audit logs are append-only';
end;
$$;

create trigger audit_logs_append_only
before update or delete on public.audit_logs
for each row execute function private.guard_audit_log();

-- ============================================================
-- FUNCTION PRIVILEGES
-- ============================================================

revoke all on all functions in schema private from public;

grant execute on function
  private.is_admin(),
  private.current_client_id(),
  private.current_profile_id(),
  private.revision_client_id(uuid),
  private.service_job_client_id(uuid),
  private.next_reference(text, regclass)
to authenticated, service_role;

grant usage on sequence private.service_request_number_seq to authenticated, service_role;
grant usage on sequence private.quotation_number_seq, private.service_job_number_seq to service_role;
