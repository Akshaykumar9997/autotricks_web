-- AutoTricks hardening 2/5: least-privilege grants and RLS policies.
-- Policies are recreated on the private.* helpers; state-changing workflow
-- columns (statuses, approvals, acceptance, signatures) are NOT directly
-- writable and go through the workflow RPCs instead.

do $$
declare
  r record;
begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public' loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end;
$$;

drop function public.is_admin();
drop function public.current_client_id();
drop function public.current_profile_id();

-- ============================================================
-- GRANTS
-- ============================================================

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

-- profiles: role/client_id only via the controlled invite process.
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

grant select on public.clients to authenticated;
grant insert (full_name, phone, email, address, city, state, pincode, notes, is_active) on public.clients to authenticated;
grant update (full_name, phone, email, address, city, state, pincode, notes, is_active) on public.clients to authenticated;

grant select on public.vehicles to authenticated;
grant insert (client_id, make, model, manufacturing_year, chassis_number, registration_number) on public.vehicles to authenticated;
grant update (make, model, manufacturing_year, chassis_number, registration_number) on public.vehicles to authenticated;

grant select on public.service_requests to authenticated;
grant insert (client_id, vehicle_id, source, original_submission, admin_notes, created_by) on public.service_requests to authenticated;
grant update (client_id, vehicle_id, status, admin_notes) on public.service_requests to authenticated;

grant select on public.products to authenticated;
grant insert (name, description, category, default_price, is_active) on public.products to authenticated;
grant update (name, description, category, default_price, is_active) on public.products to authenticated;

grant select on public.quotations to authenticated;

grant select on public.quotation_revisions to authenticated;
grant update (discount, tax, notes, terms) on public.quotation_revisions to authenticated;

grant select, delete on public.quotation_items to authenticated;
grant insert (quotation_revision_id, catalogue_product_id, name, description, quantity, approximate_value, final_value) on public.quotation_items to authenticated;
grant update (catalogue_product_id, name, description, quantity, approximate_value, final_value) on public.quotation_items to authenticated;

grant select on public.quotation_change_requests to authenticated;
grant select on public.quotation_signatures to authenticated;

grant select on public.documents to authenticated;
grant insert (client_id, quotation_revision_id, service_job_id, document_type, storage_path) on public.documents to authenticated;

grant select on public.service_jobs to authenticated;
grant update (scheduled_at) on public.service_jobs to authenticated;

grant select on public.service_work_items to authenticated;
grant update (status) on public.service_work_items to authenticated;

grant select on public.notifications to authenticated;
grant update (is_read, read_at) on public.notifications to authenticated;

grant select on public.email_notifications to authenticated;
grant select on public.audit_logs to authenticated;
grant select on public.vehicle_correction_requests to authenticated;

-- ============================================================
-- POLICIES
-- ============================================================

-- Profiles
create policy profiles_select_own_or_admin
on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select private.is_admin()));

create policy profiles_update_own_or_admin
on public.profiles for update to authenticated
using (id = (select auth.uid()) or (select private.is_admin()))
with check (id = (select auth.uid()) or (select private.is_admin()));

-- Clients
create policy clients_select_admin_or_own
on public.clients for select to authenticated
using ((select private.is_admin()) or id = (select private.current_client_id()));

create policy clients_insert_admin
on public.clients for insert to authenticated
with check ((select private.is_admin()));

create policy clients_update_admin
on public.clients for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Vehicles
create policy vehicles_select_admin_or_own
on public.vehicles for select to authenticated
using ((select private.is_admin()) or client_id = (select private.current_client_id()));

create policy vehicles_insert_admin
on public.vehicles for insert to authenticated
with check ((select private.is_admin()));

create policy vehicles_update_admin
on public.vehicles for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Service requests (website rows are inserted by the trusted Edge Function)
create policy service_requests_select_admin_or_own
on public.service_requests for select to authenticated
using ((select private.is_admin()) or client_id = (select private.current_client_id()));

create policy service_requests_insert_admin_phone
on public.service_requests for insert to authenticated
with check (
  (select private.is_admin())
  and source = 'PHONE'
  and created_by = (select auth.uid())
);

create policy service_requests_update_admin
on public.service_requests for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Products (catalogue visible to portal users; writes admin-only)
create policy products_select_portal_users
on public.products for select to authenticated
using (
  (select private.is_admin())
  or (is_active = true and (select private.current_profile_id()) is not null)
);

create policy products_insert_admin
on public.products for insert to authenticated
with check ((select private.is_admin()));

create policy products_update_admin
on public.products for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Quotations
create policy quotations_select_admin_or_own
on public.quotations for select to authenticated
using (
  (select private.is_admin())
  or exists (
    select 1 from public.service_requests sr
    where sr.id = quotations.service_request_id
      and sr.client_id = (select private.current_client_id())
  )
);

-- Revisions: clients never see DRAFTs
create policy revisions_select_admin_or_own_sent
on public.quotation_revisions for select to authenticated
using (
  (select private.is_admin())
  or (
    status <> 'DRAFT'
    and exists (
      select 1
      from public.quotations q
      join public.service_requests sr on sr.id = q.service_request_id
      where q.id = quotation_revisions.quotation_id
        and sr.client_id = (select private.current_client_id())
    )
  )
);

create policy revisions_update_admin
on public.quotation_revisions for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Quotation items
create policy quotation_items_select_admin_or_own_sent
on public.quotation_items for select to authenticated
using (
  (select private.is_admin())
  or exists (
    select 1
    from public.quotation_revisions qr
    join public.quotations q on q.id = qr.quotation_id
    join public.service_requests sr on sr.id = q.service_request_id
    where qr.id = quotation_items.quotation_revision_id
      and qr.status <> 'DRAFT'
      and sr.client_id = (select private.current_client_id())
  )
);

create policy quotation_items_insert_admin
on public.quotation_items for insert to authenticated
with check ((select private.is_admin()));

create policy quotation_items_update_admin
on public.quotation_items for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy quotation_items_delete_admin
on public.quotation_items for delete to authenticated
using ((select private.is_admin()));

-- Change requests (created via client_request_quotation_change)
create policy change_requests_select_admin_or_own
on public.quotation_change_requests for select to authenticated
using ((select private.is_admin()) or client_id = (select private.current_client_id()));

-- Signatures (created via client_sign_quotation_revision)
create policy signatures_select_admin_or_own
on public.quotation_signatures for select to authenticated
using ((select private.is_admin()) or client_id = (select private.current_client_id()));

-- Documents
create policy documents_select_admin_or_own
on public.documents for select to authenticated
using ((select private.is_admin()) or client_id = (select private.current_client_id()));

create policy documents_insert_admin
on public.documents for insert to authenticated
with check ((select private.is_admin()));

-- Service jobs
create policy service_jobs_select_admin_or_own
on public.service_jobs for select to authenticated
using (
  (select private.is_admin())
  or exists (
    select 1 from public.service_requests sr
    where sr.id = service_jobs.service_request_id
      and sr.client_id = (select private.current_client_id())
  )
);

create policy service_jobs_update_admin
on public.service_jobs for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Service work items
create policy work_items_select_admin_or_own
on public.service_work_items for select to authenticated
using (
  (select private.is_admin())
  or exists (
    select 1
    from public.service_jobs sj
    join public.service_requests sr on sr.id = sj.service_request_id
    where sj.id = service_work_items.service_job_id
      and sr.client_id = (select private.current_client_id())
  )
);

create policy work_items_update_admin
on public.service_work_items for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Notifications (mark read only)
create policy notifications_select_own
on public.notifications for select to authenticated
using (profile_id = (select auth.uid()));

create policy notifications_update_own
on public.notifications for update to authenticated
using (profile_id = (select auth.uid()))
with check (profile_id = (select auth.uid()));

-- Email queue (written by backend only)
create policy email_notifications_select_admin_or_own
on public.email_notifications for select to authenticated
using ((select private.is_admin()) or profile_id = (select auth.uid()));

-- Audit logs (written by triggers only)
create policy audit_logs_select_admin
on public.audit_logs for select to authenticated
using ((select private.is_admin()));

-- Vehicle correction requests (created via client_request_vehicle_correction)
create policy vehicle_corrections_select_admin_or_own
on public.vehicle_correction_requests for select to authenticated
using ((select private.is_admin()) or client_id = (select private.current_client_id()));
