-- AutoTricks hardening 6/6: Day 2 Auth & Security Finalization
-- 1. Restrict product catalogue access: CLIENT users cannot SELECT, INSERT, UPDATE, DELETE products.
--    Only ADMIN can SELECT, INSERT, UPDATE products.
-- 2. Restrict internal notes visibility: clients.notes and service_requests.admin_notes
--    are strictly admin-only. Revoke SELECT and UPDATE on these columns from authenticated,
--    while preserving INSERT for phone request creation by admin.
-- 3. Provide dedicated Admin views (admin_clients, admin_service_requests) with security_invoker = false
--    and Admin helper RPCs (admin_get_client_notes, admin_set_client_notes, admin_get_service_request_notes,
--    admin_set_service_request_notes) for secure management.
-- 4. Provide dedicated Client portal views (client_portal_clients, client_portal_service_requests)
--    with security_invoker = true, omitting internal notes columns.
-- 5. Prepare public.notifications for Realtime subscriptions.

-- ============================================================
-- 1. PRODUCT CATALOGUE ACCESS (ADMIN ONLY)
-- ============================================================

drop policy if exists products_select_portal_users on public.products;
drop policy if exists products_select_admin on public.products;

create policy products_select_admin
on public.products for select to authenticated
using ((select private.is_admin()));

-- ============================================================
-- 2. INTERNAL NOTES PROTECTION (COLUMN PRIVILEGES)
-- ============================================================

-- Table clients: revoke whole-table SELECT and UPDATE (notes) from authenticated
revoke select on public.clients from authenticated;
grant select (id, full_name, phone, email, address, city, state, pincode, is_active, created_at, updated_at)
  on public.clients to authenticated;

revoke update (notes) on public.clients from authenticated;

-- Table service_requests: revoke whole-table SELECT and UPDATE (admin_notes) from authenticated
revoke select on public.service_requests from authenticated;
grant select (id, request_number, client_id, vehicle_id, source, status, original_submission, created_by, created_at, updated_at)
  on public.service_requests to authenticated;

revoke update (admin_notes) on public.service_requests from authenticated;

-- ============================================================
-- 3. DEDICATED ADMIN VIEWS (SECURITY_INVOKER = FALSE)
-- ============================================================

create or replace view public.admin_clients
with (security_invoker = false) as
  select * from public.clients
  where (select private.is_admin());

create or replace view public.admin_service_requests
with (security_invoker = false) as
  select * from public.service_requests
  where (select private.is_admin());

revoke all on public.admin_clients from public, anon;
revoke all on public.admin_service_requests from public, anon;

grant select, update on public.admin_clients to authenticated;
grant select, update on public.admin_service_requests to authenticated;

-- ============================================================
-- 4. DEDICATED ADMIN RPCS FOR INTERNAL NOTES
-- ============================================================

create or replace function public.admin_get_client_notes(p_client_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notes text;
begin
  perform private.require_admin();
  select notes into v_notes from public.clients where id = p_client_id;
  return v_notes;
end;
$$;

create or replace function public.admin_set_client_notes(p_client_id uuid, p_notes text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  update public.clients set notes = p_notes where id = p_client_id;
end;
$$;

create or replace function public.admin_get_service_request_notes(p_service_request_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notes text;
begin
  perform private.require_admin();
  select admin_notes into v_notes from public.service_requests where id = p_service_request_id;
  return v_notes;
end;
$$;

create or replace function public.admin_set_service_request_notes(p_service_request_id uuid, p_admin_notes text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  update public.service_requests set admin_notes = p_admin_notes where id = p_service_request_id;
end;
$$;

revoke execute on function public.admin_get_client_notes(uuid) from public, anon;
revoke execute on function public.admin_set_client_notes(uuid, text) from public, anon;
revoke execute on function public.admin_get_service_request_notes(uuid) from public, anon;
revoke execute on function public.admin_set_service_request_notes(uuid, text) from public, anon;

grant execute on function public.admin_get_client_notes(uuid) to authenticated;
grant execute on function public.admin_set_client_notes(uuid, text) to authenticated;
grant execute on function public.admin_get_service_request_notes(uuid) to authenticated;
grant execute on function public.admin_set_service_request_notes(uuid, text) to authenticated;

-- ============================================================
-- 5. CLIENT PORTAL VIEWS (NO INTERNAL NOTES COLUMNS)
-- ============================================================

create or replace view public.client_portal_clients
with (security_invoker = true) as
  select id, full_name, phone, email, address, city, state, pincode, is_active, created_at, updated_at
  from public.clients;

create or replace view public.client_portal_service_requests
with (security_invoker = true) as
  select id, request_number, client_id, vehicle_id, source, status, original_submission, created_by, created_at, updated_at
  from public.service_requests;

revoke all on public.client_portal_clients from public, anon;
revoke all on public.client_portal_service_requests from public, anon;

grant select on public.client_portal_clients to authenticated;
grant select on public.client_portal_service_requests to authenticated;

-- ============================================================
-- 6. REALTIME PREPARATION
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;
