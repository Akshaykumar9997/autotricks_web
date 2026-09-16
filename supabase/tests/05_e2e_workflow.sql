-- AutoTricks Day 3: Complete Realistic End-to-End Workflow Test (Section 14)
-- Executes and verifies database state after EVERY major step:
-- 1. WEBSITE SERVICE REQUEST
-- 2. ADMIN REVIEW
-- 3. CREATE / IDENTIFY CLIENT
-- 4. CREATE / IDENTIFY VEHICLE
-- 5. LINK REQUEST
-- 6. CREATE QUOTATION
-- 7. ADD PRODUCTS
-- 8. CALCULATE TOTAL
-- 9. SEND QUOTATION
-- 10. CLIENT VIEWS
-- 11. CLIENT REQUESTS CHANGE
-- 12. ADMIN RESPONDS
-- 13. NEW REVISION
-- 14. SEND NEW REVISION
-- 15. CLIENT ACCEPTS
-- 16. CLIENT SIGNS
-- 17. ADMIN CREATES JOB
-- 18. QUOTATION ITEMS COPIED TO WORK ITEMS
-- 19. JOB PROGRESS
-- 20. ADMIN CREATES ADDITIONAL WORK
-- 21. CLIENT APPROVES
-- 22. WORK CONTINUES & JOB COMPLETED
-- 23. HISTORY REMAINS AVAILABLE

create or replace function pg_temp.act(p_role text, p_uid uuid)
returns void language plpgsql as $f$
begin
  execute 'reset role';
  if p_role = 'postgres' then
    perform set_config('request.jwt.claims', '', true);
    return;
  end if;
  perform set_config('request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('sub', p_uid, 'role', p_role)::text end, true);
  execute format('set local role %I', p_role);
end $f$;

create or replace function pg_temp.chk(p_ok boolean, p_label text)
returns text language sql as $f$
  select E'\n' || case when coalesce(p_ok, false) then 'PASS ' else 'FAIL ' end || p_label;
$f$;

do $test$
declare
  z constant uuid := '00000000-0000-0000-0000-000000000000';
  u_admin uuid := gen_random_uuid();
  u_client uuid := gen_random_uuid();
  c_id uuid; v_id uuid; sr_id uuid;
  p_oil uuid; p_pad uuid;
  q_id uuid; rev1_id uuid; rev2_id uuid;
  it1 uuid; it2 uuid;
  cr_id uuid;
  sig_path text; pdf_path text;
  job_id uuid;
  w_add_id uuid;
  doc_sig uuid;
  j jsonb; n int; n2 int; n3 int; t text; t2 text; num numeric; num2 numeric;
  res text := '';
begin
  -- Setup initial users
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (u_admin, z, 'authenticated', 'authenticated', 'workflow-admin@autotricks.test', now(), now()),
    (u_client, z, 'authenticated', 'authenticated', 'workflow-client@autotricks.test', now(), now());

  insert into public.profiles (id, role, full_name) values (u_admin, 'ADMIN', 'Workflow Admin');

  -- STEP 1: WEBSITE SERVICE REQUEST
  perform pg_temp.act('service_role', null);
  insert into public.service_requests (source, original_submission)
  values ('WEBSITE', jsonb_build_object(
    'customer_name', 'Rajesh Patel', 'phone', '9820011223', 'email', 'rajesh@patel.test',
    'car_make', 'Toyota', 'car_model', 'Fortuner', 'manufacturing_year', 2021,
    'chassis_number', 'MBJ11AB40M0054321', 'registration_number', 'MH02CP1234',
    'current_location', 'Andheri West, Mumbai', 'service_description', 'Periodic 40,000 km maintenance + brake check'
  ))
  returning id into sr_id;

  select status::text, request_number into t, t2 from public.service_requests where id = sr_id;
  res := res || pg_temp.chk(t = 'NEW' and t2 ~ '^SR-\d{4}-\d{5}$', 'STEP 1: Website service request submitted (' || t2 || ', status=NEW)');

  -- STEP 2: ADMIN REVIEW & STEP 3: CREATE / IDENTIFY CLIENT & STEP 4: CREATE / IDENTIFY VEHICLE
  perform pg_temp.act('authenticated', u_admin);
  insert into public.clients (full_name, phone, email, address, city, state, pincode)
    values ('Rajesh Patel', '9820011223', 'rajesh@patel.test', 'Flat 402, Sea View', 'Mumbai', 'Maharashtra', '400053')
    returning id into c_id;
  res := res || pg_temp.chk(c_id is not null, 'STEP 3: Admin created client profile for Rajesh Patel');

  insert into public.vehicles (client_id, make, model, manufacturing_year, chassis_number, registration_number)
    values (c_id, 'Toyota', 'Fortuner', 2021, 'MBJ11AB40M0054321', 'MH02CP1234')
    returning id into v_id;
  res := res || pg_temp.chk(v_id is not null, 'STEP 4: Admin created vehicle record linked to client');

  -- Provision Client Portal Profile
  perform pg_temp.act('service_role', null);
  insert into public.profiles (id, role, client_id, full_name) values (u_client, 'CLIENT', c_id, 'Rajesh Patel');

  -- STEP 5: LINK REQUEST
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_link_service_request(sr_id, c_id, v_id);
  select status::text into t from public.service_requests where id = sr_id;
  res := res || pg_temp.chk(t = 'UNDER_REVIEW', 'STEP 5: Admin linked request to client+vehicle; status set to UNDER_REVIEW');

  -- STEP 6: CREATE QUOTATION & STEP 7: ADD PRODUCTS & STEP 8: CALCULATE TOTAL
  insert into public.products (name, category, default_price) values ('Fully Synthetic 5W40 Engine Oil', 'OIL', 950.00) returning id into p_oil;
  insert into public.products (name, category, default_price) values ('Front Brake Pads Set', 'BRAKES', 3200.00) returning id into p_pad;

  j := public.admin_create_quotation(sr_id, '40,000 km Major Service Package', 'Payment due upon job completion');
  q_id := (j->>'quotation_id')::uuid;
  rev1_id := (j->>'revision_id')::uuid;
  select status::text into t from public.service_requests where id = sr_id;
  res := res || pg_temp.chk(t = 'QUOTATION_CREATED', 'STEP 6: Quotation created (' || (j->>'quotation_number') || '); request is QUOTATION_CREATED');

  -- STEP 7: Add products
  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity)
    values (rev1_id, p_oil, 7.0) returning id into it1; -- 7 * 950 = 6650.00
  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity)
    values (rev1_id, p_pad, 1.0) returning id into it2; -- 1 * 3200 = 3200.00
  insert into public.quotation_items (quotation_revision_id, name, quantity, final_value)
    values (rev1_id, 'Comprehensive 40K Labour', 1.0, 1800.00); -- 1800.00

  -- STEP 8: Calculate total
  -- Subtotal = 6650 + 3200 + 1800 = 11650.00
  update public.quotation_revisions set discount = 650.00, tax = 550.00 where id = rev1_id;
  select subtotal, total into num, num2 from public.quotation_revisions where id = rev1_id;
  res := res || pg_temp.chk(num = 11650.00 and num2 = 11550.00,
    'STEP 8: Server calculated revision totals: subtotal=' || num || ', total=' || num2);

  -- STEP 9: SEND QUOTATION
  j := public.admin_send_quotation_revision(rev1_id);
  select status::text into t from public.quotation_revisions where id = rev1_id;
  select status::text into t2 from public.service_requests where id = sr_id;
  res := res || pg_temp.chk(t = 'SENT' and t2 = 'QUOTATION_SENT', 'STEP 9: Quotation sent; revision=SENT, request=QUOTATION_SENT');

  -- STEP 10: CLIENT VIEWS
  perform pg_temp.act('authenticated', u_client);
  j := public.client_mark_quotation_viewed(rev1_id);
  select status::text into t from public.quotation_revisions where id = rev1_id;
  res := res || pg_temp.chk(t = 'VIEWED', 'STEP 10: Client marked quotation viewed (status=VIEWED)');

  -- STEP 11: CLIENT REQUESTS CHANGE
  j := public.client_request_quotation_change(rev1_id, 'Can we apply an additional corporate discount on labour?');
  cr_id := (j->>'change_request_id')::uuid;
  select status::text into t from public.quotation_revisions where id = rev1_id;
  res := res || pg_temp.chk(t = 'CHANGE_REQUESTED' and cr_id is not null, 'STEP 11: Client requested change (status=CHANGE_REQUESTED)');

  -- STEP 12: ADMIN RESPONDS & STEP 13: NEW REVISION & STEP 14: SEND NEW REVISION
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_respond_quotation_change_request(cr_id, 'ACCEPTED', 'Labour discount of 500 added');
  j := public.admin_create_quotation_revision(q_id);
  rev2_id := (j->>'revision_id')::uuid;

  update public.quotation_revisions set discount = 1150.00 where id = rev2_id;
  select total into num from public.quotation_revisions where id = rev2_id;
  res := res || pg_temp.chk(num = 11050.00, 'STEP 13: Revision 2 created with adjusted discount; total=' || num);

  j := public.admin_send_quotation_revision(rev2_id);
  select status::text into t from public.quotation_revisions where id = rev1_id;
  select status::text into t2 from public.quotation_revisions where id = rev2_id;
  res := res || pg_temp.chk(t = 'SUPERSEDED' and t2 = 'SENT', 'STEP 14: Revision 2 SENT, Revision 1 SUPERSEDED');

  -- STEP 15: CLIENT ACCEPTS & STEP 16: CLIENT SIGNS
  perform pg_temp.act('authenticated', u_client);
  j := public.client_accept_quotation_revision(rev2_id, true, 'I accept quotation revision 2 with 40K service terms.');
  select status::text into t from public.quotation_revisions where id = rev2_id;
  res := res || pg_temp.chk(t = 'ACCEPTED', 'STEP 15: Client accepted revision 2 (status=ACCEPTED)');

  sig_path := c_id::text || '/' || rev2_id::text || '/rajesh-patel-sig.png';
  insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('signatures', sig_path, u_client::text, '{"mimetype":"image/png"}');
  j := public.client_sign_quotation_revision(rev2_id, sig_path);
  select status::text into t from public.service_requests where id = sr_id;
  res := res || pg_temp.chk(t = 'APPROVED', 'STEP 16: Client signed quotation revision 2; request status=APPROVED');

  -- STEP 17: ADMIN CREATES JOB & STEP 18: WORK ITEMS COPIED
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_create_service_job(rev2_id, now() + interval '4 hours');
  job_id := (j->>'service_job_id')::uuid;
  select status::text into t from public.service_requests where id = sr_id;
  select status::text into t2 from public.service_jobs where id = job_id;
  res := res || pg_temp.chk(t = 'CONVERTED_TO_JOB' and t2 = 'SCHEDULED', 'STEP 17: Service Job created; request=CONVERTED_TO_JOB, job=SCHEDULED');

  select count(*) into n from public.service_work_items
  where service_job_id = job_id and source = 'QUOTATION' and approval_status = 'NOT_REQUIRED';
  res := res || pg_temp.chk(n = 3, 'STEP 18: All 3 agreed quotation items copied to service_work_items (count=' || n || ')');

  -- STEP 19: JOB PROGRESS (VEHICLE_RECEIVED -> INSPECTION -> WORK_IN_PROGRESS)
  j := public.admin_update_service_job_status(job_id, 'VEHICLE_RECEIVED');
  j := public.admin_update_service_job_status(job_id, 'INSPECTION');
  j := public.admin_update_service_job_status(job_id, 'WORK_IN_PROGRESS');
  select status::text into t from public.service_jobs where id = job_id;
  res := res || pg_temp.chk(t = 'WORK_IN_PROGRESS', 'STEP 19: Job progressed to WORK_IN_PROGRESS');

  -- STEP 20: ADMIN CREATES ADDITIONAL WORK
  j := public.admin_add_additional_work(job_id, 'Wiper Blades Replacement (Pair)', 1.0, 950.00, 'Streaking observed during inspection', 900.00);
  w_add_id := (j->>'work_item_id')::uuid;
  select approval_status::text into t from public.service_work_items where id = w_add_id;
  res := res || pg_temp.chk(t = 'PENDING', 'STEP 20: Additional work created with approval_status=PENDING');

  -- STEP 21: CLIENT APPROVES ADDITIONAL WORK
  perform pg_temp.act('authenticated', u_client);
  j := public.client_decide_additional_work(w_add_id, true, 950.00, 'Please replace both blades');
  select approval_status::text, approved_value into t, num from public.service_work_items where id = w_add_id;
  res := res || pg_temp.chk(t = 'APPROVED' and num = 950.00, 'STEP 21: Client approved additional work (approved_value=950.00)');

  -- STEP 22: WORK CONTINUES & JOB COMPLETED
  perform pg_temp.act('authenticated', u_admin);
  update public.service_work_items set status = 'COMPLETED' where service_job_id = job_id;
  j := public.admin_update_service_job_status(job_id, 'QUALITY_CHECK');
  j := public.admin_update_service_job_status(job_id, 'READY_FOR_DELIVERY');
  j := public.admin_update_service_job_status(job_id, 'COMPLETED');
  select status::text into t from public.service_jobs where id = job_id;
  res := res || pg_temp.chk(t = 'COMPLETED', 'STEP 22: All work items completed; job status is COMPLETED');

  -- Attach completed service document
  pdf_path := c_id::text || '/jobs/' || job_id::text || '/service-invoice.pdf';
  insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('service-documents', pdf_path, u_admin::text, '{"mimetype":"application/pdf"}');
  insert into public.documents (client_id, service_job_id, document_type, storage_path)
    values (c_id, job_id, 'INVOICE', pdf_path);

  -- STEP 23: HISTORY REMAINS AVAILABLE
  perform pg_temp.act('authenticated', u_client);
  select count(*) into n from public.service_jobs where id = job_id;
  select count(*) into n2 from public.service_work_items where service_job_id = job_id;
  select count(*) into n3 from public.documents where client_id = c_id;
  res := res || pg_temp.chk(n = 1 and n2 = 4 and n3 = 1,
    'STEP 23: Historical service record fully accessible to client (1 job, 4 work items, 1 invoice document)');

  -- ============ REPORT ============
  perform pg_temp.act('postgres', null);
  raise exception 'E2E WORKFLOW REPORT PASS=% FAIL=% %',
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'PASS%'),
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'FAIL%'),
    regexp_replace(res, ' \[[^]]*\]', '', 'g');
end
$test$;
