
-- AutoTricks Backend Schema v1.0
-- Reviewed 2026-09-13
-- PostgreSQL / Supabase
-- NOTE: Apply only to the dedicated AutoTricks Supabase project.

create extension if not exists pgcrypto;

-- ============================================================
-- ENUMS
-- ============================================================

create type public.user_role as enum ('ADMIN', 'CLIENT');
create type public.request_source as enum ('WEBSITE', 'PHONE');
create type public.service_request_status as enum (
  'NEW',
  'UNDER_REVIEW',
  'QUOTATION_CREATED',
  'QUOTATION_SENT',
  'APPROVED',
  'CONVERTED_TO_JOB',
  'CANCELLED'
);
create type public.quotation_revision_status as enum (
  'DRAFT',
  'SENT',
  'VIEWED',
  'CHANGE_REQUESTED',
  'ACCEPTED',
  'REJECTED',
  'EXPIRED',
  'CANCELLED',
  'SUPERSEDED'
);
create type public.change_request_status as enum (
  'PENDING',
  'ACCEPTED',
  'PARTIALLY_ACCEPTED',
  'REJECTED',
  'CANCELLED'
);
create type public.service_job_status as enum (
  'SCHEDULED',
  'VEHICLE_RECEIVED',
  'INSPECTION',
  'WORK_IN_PROGRESS',
  'QUALITY_CHECK',
  'READY_FOR_DELIVERY',
  'COMPLETED',
  'CANCELLED'
);
create type public.work_item_source as enum ('QUOTATION', 'ADDITIONAL');
create type public.work_item_status as enum (
  'PENDING',
  'IN_PROGRESS',
  'COMPLETED',
  'ON_HOLD',
  'CANCELLED'
);
create type public.additional_work_approval_status as enum (
  'NOT_REQUIRED',
  'PENDING',
  'APPROVED',
  'REJECTED'
);
create type public.signature_method as enum ('DRAWN');
create type public.document_type as enum (
  'QUOTATION_PDF',
  'SIGNED_QUOTATION_PDF',
  'SERVICE_REPORT',
  'INVOICE',
  'RECEIPT'
);
create type public.email_delivery_status as enum ('QUEUED', 'SENT', 'FAILED');
create type public.notification_type as enum (
  'NEW_SERVICE_REQUEST',
  'QUOTATION_SENT',
  'QUOTATION_REVISED',
  'QUOTATION_CHANGE_REQUESTED',
  'QUOTATION_ACCEPTED',
  'QUOTATION_SIGNED',
  'ADDITIONAL_WORK_REQUESTED',
  'ADDITIONAL_WORK_APPROVED',
  'ADDITIONAL_WORK_REJECTED',
  'SERVICE_STATUS_UPDATED',
  'SERVICE_JOB_COMPLETED'
);

-- ============================================================
-- SHARED UPDATED_AT TRIGGER
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- PROFILES / CLIENTS / VEHICLES
-- ============================================================

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null,
  email text,
  address text,
  city text,
  state text,
  pincode text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  role public.user_role not null,
  client_id uuid references public.clients(id) on delete restrict,
  full_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_client_role_ck check (
    (role = 'CLIENT' and client_id is not null)
    or
    (role = 'ADMIN' and client_id is null)
  )
);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  make text not null,
  model text not null,
  manufacturing_year integer,
  chassis_number text,
  registration_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicles_year_ck check (
    manufacturing_year is null or manufacturing_year between 1886 and extract(year from now())::integer + 1
  )
);

-- ============================================================
-- SERVICE REQUESTS
-- ============================================================

create table public.service_requests (
  id uuid primary key default gen_random_uuid(),
  request_number text not null unique,
  client_id uuid references public.clients(id) on delete restrict,
  vehicle_id uuid references public.vehicles(id) on delete restrict,
  source public.request_source not null,
  status public.service_request_status not null default 'NEW',
  original_submission jsonb,
  admin_notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_requests_source_submission_ck check (
    (source = 'WEBSITE' and original_submission is not null and created_by is null)
    or
    (source = 'PHONE' and created_by is not null)
  )
);

-- ============================================================
-- PRODUCTS
-- ============================================================

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  category text,
  default_price numeric(12,2) not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_default_price_ck check (default_price >= 0)
);

-- ============================================================
-- QUOTATIONS / REVISIONS / ITEMS / CHANGE REQUESTS
-- ============================================================

create table public.quotations (
  id uuid primary key default gen_random_uuid(),
  quotation_number text not null unique,
  service_request_id uuid not null unique references public.service_requests(id) on delete restrict,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.quotation_revisions (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.quotations(id) on delete restrict,
  revision_number integer not null,
  status public.quotation_revision_status not null default 'DRAFT',
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  tax numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  notes text,
  terms text,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint quotation_revisions_unique_number unique (quotation_id, revision_number),
  constraint quotation_revisions_money_ck check (
    subtotal >= 0 and discount >= 0 and tax >= 0 and total >= 0
  ),
  constraint quotation_revisions_number_ck check (revision_number >= 1)
);

create table public.quotation_items (
  id uuid primary key default gen_random_uuid(),
  quotation_revision_id uuid not null references public.quotation_revisions(id) on delete restrict,
  catalogue_product_id uuid references public.products(id) on delete set null,
  name text not null,
  description text,
  quantity numeric(10,2) not null,
  approximate_value numeric(12,2),
  final_value numeric(12,2) not null,
  line_total numeric(12,2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quotation_items_quantity_ck check (quantity > 0),
  constraint quotation_items_values_ck check (
    (approximate_value is null or approximate_value >= 0)
    and final_value >= 0
    and line_total >= 0
  )
);

create table public.quotation_change_requests (
  id uuid primary key default gen_random_uuid(),
  quotation_revision_id uuid not null references public.quotation_revisions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  message text not null,
  status public.change_request_status not null default 'PENDING',
  admin_response text,
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

-- ============================================================
-- SIGNATURES / DOCUMENTS
-- ============================================================

create table public.quotation_signatures (
  id uuid primary key default gen_random_uuid(),
  quotation_revision_id uuid not null unique references public.quotation_revisions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  signature_file text not null,
  signature_method public.signature_method not null default 'DRAWN',
  consent_text text not null,
  accepted_at timestamptz not null,
  signed_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint quotation_signatures_dates_ck check (signed_at >= accepted_at)
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  quotation_revision_id uuid references public.quotation_revisions(id) on delete restrict,
  service_job_id uuid,
  document_type public.document_type not null,
  storage_path text not null unique,
  created_at timestamptz not null default now(),
  constraint documents_source_ck check (
    quotation_revision_id is not null or service_job_id is not null
  )
);

-- service_job_id FK is added after service_jobs is created.

-- ============================================================
-- SERVICE JOBS / WORK ITEMS
-- ============================================================

create table public.service_jobs (
  id uuid primary key default gen_random_uuid(),
  job_number text not null unique,
  service_request_id uuid not null unique references public.service_requests(id) on delete restrict,
  quotation_revision_id uuid not null references public.quotation_revisions(id) on delete restrict,
  vehicle_id uuid not null references public.vehicles(id) on delete restrict,
  status public.service_job_status not null default 'SCHEDULED',
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_jobs_dates_ck check (
    completed_at is null or started_at is null or completed_at >= started_at
  )
);

alter table public.documents
  add constraint documents_service_job_fk
  foreign key (service_job_id) references public.service_jobs(id) on delete restrict;

create table public.service_work_items (
  id uuid primary key default gen_random_uuid(),
  service_job_id uuid not null references public.service_jobs(id) on delete restrict,
  quotation_item_id uuid references public.quotation_items(id) on delete set null,
  name text not null,
  description text,
  quantity numeric(10,2) not null default 1,
  source public.work_item_source not null,
  status public.work_item_status not null default 'PENDING',
  approval_status public.additional_work_approval_status not null default 'NOT_REQUIRED',
  approximate_value numeric(12,2),
  final_value numeric(12,2),
  approved_value numeric(12,2),
  decision_by_profile_id uuid references public.profiles(id) on delete set null,
  decision_at timestamptz,
  approval_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_work_items_quantity_ck check (quantity > 0),
  constraint service_work_items_values_ck check (
    (approximate_value is null or approximate_value >= 0)
    and (final_value is null or final_value >= 0)
    and (approved_value is null or approved_value >= 0)
  ),
  constraint service_work_items_source_approval_ck check (
    (source = 'QUOTATION' and approval_status = 'NOT_REQUIRED' and quotation_item_id is not null)
    or
    (source = 'ADDITIONAL' and approval_status <> 'NOT_REQUIRED' and quotation_item_id is null)
  ),
  constraint service_work_items_approval_evidence_ck check (
    (approval_status = 'APPROVED' and decision_by_profile_id is not null and decision_at is not null and approved_value is not null)
    or
    (approval_status <> 'APPROVED')
  )
);

-- ============================================================
-- NOTIFICATIONS / EMAIL / AUDIT
-- ============================================================

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  type public.notification_type not null,
  title text not null,
  message text not null,
  entity_type text,
  entity_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint notifications_read_ck check (
    (is_read = false and read_at is null)
    or
    (is_read = true and read_at is not null)
  )
);

create table public.email_notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  notification_type public.notification_type not null,
  recipient_email text not null,
  subject text not null,
  status public.email_delivery_status not null default 'QUEUED',
  related_entity_type text,
  related_entity_id uuid,
  sent_at timestamptz,
  failed_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- INDEXES
-- ============================================================

create index idx_profiles_client_id on public.profiles(client_id);
create index idx_vehicles_client_id on public.vehicles(client_id);

create index idx_service_requests_client_id on public.service_requests(client_id);
create index idx_service_requests_vehicle_id on public.service_requests(vehicle_id);
create index idx_service_requests_status on public.service_requests(status);
create index idx_service_requests_created_at on public.service_requests(created_at desc);

create index idx_products_active_category on public.products(is_active, category);

create index idx_quotation_revisions_quotation_id on public.quotation_revisions(quotation_id);
create index idx_quotation_items_revision_id on public.quotation_items(quotation_revision_id);
create index idx_change_requests_revision_id on public.quotation_change_requests(quotation_revision_id);
create index idx_change_requests_client_id on public.quotation_change_requests(client_id);
create index idx_change_requests_status on public.quotation_change_requests(status);

create index idx_signatures_client_id on public.quotation_signatures(client_id);
create index idx_documents_client_id on public.documents(client_id);
create index idx_documents_revision_id on public.documents(quotation_revision_id);
create index idx_documents_service_job_id on public.documents(service_job_id);

create index idx_service_jobs_vehicle_id on public.service_jobs(vehicle_id);
create index idx_service_jobs_status on public.service_jobs(status);
create index idx_service_work_items_job_id on public.service_work_items(service_job_id);
create index idx_service_work_items_status on public.service_work_items(status);

create index idx_notifications_profile_unread
  on public.notifications(profile_id, is_read, created_at desc);

create index idx_email_notifications_status
  on public.email_notifications(status, created_at);

create index idx_audit_logs_entity
  on public.audit_logs(entity_type, entity_id, created_at desc);

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================

create trigger clients_set_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger vehicles_set_updated_at
before update on public.vehicles
for each row execute function public.set_updated_at();

create trigger service_requests_set_updated_at
before update on public.service_requests
for each row execute function public.set_updated_at();

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create trigger quotations_set_updated_at
before update on public.quotations
for each row execute function public.set_updated_at();

create trigger quotation_items_set_updated_at
before update on public.quotation_items
for each row execute function public.set_updated_at();

create trigger service_jobs_set_updated_at
before update on public.service_jobs
for each row execute function public.set_updated_at();

create trigger service_work_items_set_updated_at
before update on public.service_work_items
for each row execute function public.set_updated_at();


-- ============================================================
-- IMMUTABILITY / CONSISTENCY GUARDS
-- ============================================================


create or replace function public.validate_service_request_links()
returns trigger
language plpgsql
as $$
begin
  if new.vehicle_id is not null and new.client_id is not null then
    if not exists (
      select 1 from public.vehicles v
      where v.id = new.vehicle_id and v.client_id = new.client_id
    ) then
      raise exception 'Service request vehicle must belong to the selected client';
    end if;
  end if;
  return new;
end;
$$;

create trigger service_requests_validate_links
before insert or update on public.service_requests
for each row execute function public.validate_service_request_links();

create or replace function public.validate_document_owner()
returns trigger
language plpgsql
as $$
begin
  if new.quotation_revision_id is not null then
    if not exists (
      select 1
      from public.quotation_revisions qr
      join public.quotations q on q.id = qr.quotation_id
      join public.service_requests sr on sr.id = q.service_request_id
      where qr.id = new.quotation_revision_id
        and sr.client_id = new.client_id
    ) then
      raise exception 'Document client does not own the quotation revision';
    end if;
  end if;

  if new.service_job_id is not null then
    if not exists (
      select 1
      from public.service_jobs sj
      join public.service_requests sr on sr.id = sj.service_request_id
      where sj.id = new.service_job_id
        and sr.client_id = new.client_id
    ) then
      raise exception 'Document client does not own the service job';
    end if;
  end if;

  return new;
end;
$$;

create trigger documents_validate_owner
before insert or update on public.documents
for each row execute function public.validate_document_owner();



create or replace function public.prevent_signed_revision_mutation()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1 from public.quotation_signatures qs
    where qs.quotation_revision_id = old.id
  ) then
    raise exception 'Signed quotation revisions are immutable';
  end if;
  return new;
end;
$$;

create trigger quotation_revisions_prevent_signed_update
before update on public.quotation_revisions
for each row execute function public.prevent_signed_revision_mutation();

create or replace function public.prevent_signed_item_mutation()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from public.quotation_signatures qs
    where qs.quotation_revision_id = old.quotation_revision_id
  ) then
    raise exception 'Items of a signed quotation revision are immutable';
  end if;
  return new;
end;
$$;

create trigger quotation_items_prevent_signed_update
before update on public.quotation_items
for each row execute function public.prevent_signed_item_mutation();

-- ============================================================
-- RLS
-- ============================================================

alter table public.clients enable row level security;
alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.service_requests enable row level security;
alter table public.products enable row level security;
alter table public.quotations enable row level security;
alter table public.quotation_revisions enable row level security;
alter table public.quotation_items enable row level security;
alter table public.quotation_change_requests enable row level security;
alter table public.quotation_signatures enable row level security;
alter table public.documents enable row level security;
alter table public.service_jobs enable row level security;
alter table public.service_work_items enable row level security;
alter table public.notifications enable row level security;
alter table public.email_notifications enable row level security;
alter table public.audit_logs enable row level security;

-- Revoke broad Data API access; grant back only what the application needs.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select on public.clients to authenticated;
grant select on public.vehicles to authenticated;
grant select on public.service_requests to authenticated;
grant select on public.products to authenticated;
grant select on public.quotations to authenticated;
grant select on public.quotation_revisions to authenticated;
grant select on public.quotation_items to authenticated;
grant select, insert on public.quotation_change_requests to authenticated;
grant select on public.quotation_signatures to authenticated;
grant select on public.documents to authenticated;
grant select on public.service_jobs to authenticated;
grant select on public.service_work_items to authenticated;
grant select, update on public.notifications to authenticated;
grant select on public.email_notifications to authenticated;
grant select on public.audit_logs to authenticated;

-- Admins need operational write access. These grants do not bypass RLS.
grant insert, update on public.clients to authenticated;
grant insert, update on public.vehicles to authenticated;
grant insert, update on public.service_requests to authenticated;
grant insert, update on public.products to authenticated;
grant insert, update on public.quotations to authenticated;
grant insert, update on public.quotation_revisions to authenticated;
grant insert, update on public.quotation_items to authenticated;
grant update on public.quotation_change_requests to authenticated;
-- No direct INSERT/UPDATE/DELETE grant on quotation_signatures.
-- Trusted backend code performs the signature transaction.
grant insert, update on public.documents to authenticated;
grant insert, update on public.service_jobs to authenticated;
grant insert, update on public.service_work_items to authenticated;
grant insert on public.email_notifications to authenticated;
grant insert on public.audit_logs to authenticated;

-- Helper: current user's profile.
create or replace function public.current_profile_id()
returns uuid
language sql
stable
as $$
  select id from public.profiles where id = (select auth.uid());
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and role = 'ADMIN'
  );
$$;

create or replace function public.current_client_id()
returns uuid
language sql
stable
as $$
  select client_id from public.profiles
  where id = (select auth.uid())
    and role = 'CLIENT';
$$;

-- Profiles
create policy profiles_select_own
on public.profiles for select to authenticated
using ((select auth.uid()) = id or (select public.is_admin()));

create policy profiles_update_own
on public.profiles for update to authenticated
using ((select auth.uid()) = id or (select public.is_admin()))
with check (
  (select public.is_admin())
  or (
    (select auth.uid()) = id
    and role = 'CLIENT'
    and client_id = (select public.current_client_id())
  )
);

-- Clients
create policy clients_select_admin_or_own
on public.clients for select to authenticated
using ((select public.is_admin()) or id = (select public.current_client_id()));

create policy clients_insert_admin
on public.clients for insert to authenticated
with check ((select public.is_admin()));

create policy clients_update_admin
on public.clients for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Vehicles
create policy vehicles_select_admin_or_own
on public.vehicles for select to authenticated
using ((select public.is_admin()) or client_id = (select public.current_client_id()));

create policy vehicles_insert_admin
on public.vehicles for insert to authenticated
with check ((select public.is_admin()));

create policy vehicles_update_admin
on public.vehicles for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Service requests
create policy service_requests_select_admin_or_own
on public.service_requests for select to authenticated
using ((select public.is_admin()) or client_id = (select public.current_client_id()));

create policy service_requests_insert_admin
on public.service_requests for insert to authenticated
with check ((select public.is_admin()));

create policy service_requests_update_admin
on public.service_requests for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Products
create policy products_select_authenticated
on public.products for select to authenticated
using ((select public.is_admin()) or is_active = true);

create policy products_insert_admin
on public.products for insert to authenticated
with check ((select public.is_admin()));

create policy products_update_admin
on public.products for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Quotations
create policy quotations_select_admin_or_own
on public.quotations for select to authenticated
using (
  (select public.is_admin())
  or exists (
    select 1
    from public.service_requests sr
    where sr.id = quotations.service_request_id
      and sr.client_id = (select public.current_client_id())
  )
);

create policy quotations_insert_admin
on public.quotations for insert to authenticated
with check ((select public.is_admin()));

create policy quotations_update_admin
on public.quotations for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Revisions
create policy revisions_select_admin_or_own
on public.quotation_revisions for select to authenticated
using (
  (select public.is_admin())
  or exists (
    select 1
    from public.quotations q
    join public.service_requests sr on sr.id = q.service_request_id
    where q.id = quotation_revisions.quotation_id
      and sr.client_id = (select public.current_client_id())
  )
);

create policy revisions_insert_admin
on public.quotation_revisions for insert to authenticated
with check ((select public.is_admin()));

create policy revisions_update_admin
on public.quotation_revisions for update to authenticated
using (
  (select public.is_admin())
  and not exists (
    select 1 from public.quotation_signatures qs
    where qs.quotation_revision_id = quotation_revisions.id
  )
)
with check ((select public.is_admin()));

-- Quotation items
create policy quotation_items_select_admin_or_own
on public.quotation_items for select to authenticated
using (
  (select public.is_admin())
  or exists (
    select 1
    from public.quotation_revisions qr
    join public.quotations q on q.id = qr.quotation_id
    join public.service_requests sr on sr.id = q.service_request_id
    where qr.id = quotation_items.quotation_revision_id
      and sr.client_id = (select public.current_client_id())
  )
);

create policy quotation_items_insert_admin
on public.quotation_items for insert to authenticated
with check ((select public.is_admin()));

create policy quotation_items_update_admin
on public.quotation_items for update to authenticated
using (
  (select public.is_admin())
  and not exists (
    select 1
    from public.quotation_signatures qs
    where qs.quotation_revision_id = quotation_items.quotation_revision_id
  )
)
with check ((select public.is_admin()));

-- Change requests
create policy change_requests_select_admin_or_own
on public.quotation_change_requests for select to authenticated
using ((select public.is_admin()) or client_id = (select public.current_client_id()));

create policy change_requests_insert_own_client
on public.quotation_change_requests for insert to authenticated
with check (
  client_id = (select public.current_client_id())
  and profile_id = (select auth.uid())
  and exists (
    select 1
    from public.quotation_revisions qr
    join public.quotations q on q.id = qr.quotation_id
    join public.service_requests sr on sr.id = q.service_request_id
    where qr.id = quotation_change_requests.quotation_revision_id
      and sr.client_id = (select public.current_client_id())
      and qr.status in ('SENT', 'VIEWED', 'CHANGE_REQUESTED')
  )
);

create policy change_requests_update_admin
on public.quotation_change_requests for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Signatures
create policy signatures_select_admin_or_own
on public.quotation_signatures for select to authenticated
using ((select public.is_admin()) or client_id = (select public.current_client_id()));

-- Signature creation is intentionally NOT granted directly to clients.
-- It must go through a trusted backend operation that validates:
-- client ownership, revision state, explicit consent, one-signature rule,
-- signature file path, and server-side timestamps.


-- Documents
create policy documents_select_admin_or_own
on public.documents for select to authenticated
using ((select public.is_admin()) or client_id = (select public.current_client_id()));

create policy documents_insert_admin
on public.documents for insert to authenticated
with check ((select public.is_admin()));

create policy documents_update_admin
on public.documents for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Service jobs
create policy service_jobs_select_admin_or_own
on public.service_jobs for select to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.service_requests sr
  where sr.id = service_jobs.service_request_id
    and sr.client_id = (select public.current_client_id())
));

create policy service_jobs_insert_admin
on public.service_jobs for insert to authenticated
with check ((select public.is_admin()));

create policy service_jobs_update_admin
on public.service_jobs for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Service work items
create policy work_items_select_admin_or_own
on public.service_work_items for select to authenticated
using ((select public.is_admin()) or exists (
  select 1
  from public.service_jobs sj
  join public.service_requests sr on sr.id = sj.service_request_id
  where sj.id = service_work_items.service_job_id
    and sr.client_id = (select public.current_client_id())
));

create policy work_items_insert_admin
on public.service_work_items for insert to authenticated
with check ((select public.is_admin()));

create policy work_items_update_admin
on public.service_work_items for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

-- Notifications
create policy notifications_select_own
on public.notifications for select to authenticated
using ((select auth.uid()) = profile_id);

create policy notifications_update_own
on public.notifications for update to authenticated
using ((select auth.uid()) = profile_id)
with check ((select auth.uid()) = profile_id);

-- Email notifications
create policy email_notifications_select_admin_or_own
on public.email_notifications for select to authenticated
using ((select public.is_admin()) or profile_id = (select auth.uid()));

create policy email_notifications_insert_admin
on public.email_notifications for insert to authenticated
with check ((select public.is_admin()));

-- Audit logs
create policy audit_logs_select_admin
on public.audit_logs for select to authenticated
using ((select public.is_admin()));

create policy audit_logs_insert_admin
on public.audit_logs for insert to authenticated
with check ((select public.is_admin()));

-- ============================================================
-- IMPORTANT IMPLEMENTATION NOTES
-- ============================================================
-- 1. Sensitive workflows should be implemented as trusted backend
--    operations (Edge Functions / RPCs) rather than client-side updates.
-- 2. In particular: signing, creating a service job from a signed
--    revision, revision creation, status transitions, and approving
--    additional work must validate state and ownership server-side.
-- 3. Signed revisions must be immutable. The application should prevent
--    UPDATE/DELETE after a signature exists; use privileged backend
--    operations for controlled state transitions.
-- 4. Public website submissions should use a controlled server endpoint
--    or Edge Function. Do not grant anon INSERT directly to the core
--    service_requests table.
-- 5. Storage buckets for signatures/documents must have their own Storage
--    policies; database RLS does not protect Storage objects.
