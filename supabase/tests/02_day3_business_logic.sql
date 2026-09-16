-- AutoTricks Day 3: Business Logic Test Suite
-- Tests:
-- 1. Service Request Lifecycle (transitions, jumps, prerequisites, cancellations)
-- 2. Client & Vehicle Management (ownership, transfers, multi-vehicle, history isolation)
-- 3. Quotation Business Logic (calculations, decimals, zero/negative, snapshotting, revisions)
-- 4. Negotiation & Change Requests (client change request, admin response, revisioning)
-- 5. Service Job Conversion (signed quotation required, quotation work items copied)
-- 6. Additional Work (creation, approval, rejection, pricing, execution rules, cancellation)
-- 7. Service Job Lifecycle (strict sequential transitions, no jumps, completion rules)

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
  u_a uuid := gen_random_uuid();
  u_b uuid := gen_random_uuid();
  c_a uuid; c_b uuid; v_a1 uuid; v_a2 uuid; v_b uuid;
  sr1 uuid; sr2 uuid; sr_cancel uuid;
  p_oil uuid; p_filter uuid;
  q1 uuid; rev1 uuid; rev2 uuid;
  it1 uuid; it2 uuid;
  cr1 uuid;
  sig_path text;
  job1 uuid;
  w_add1 uuid; w_add2 uuid;
  j jsonb; n int; num numeric; num2 numeric; t text; t2 text;
  res text := '';
begin
  -- ============ SETUP ============
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (u_admin, z, 'authenticated', 'authenticated', 'day3-admin@autotricks.test', now(), now()),
    (u_a, z, 'authenticated', 'authenticated', 'day3-client-a@autotricks.test', now(), now()),
    (u_b, z, 'authenticated', 'authenticated', 'day3-client-b@autotricks.test', now(), now());

  insert into public.profiles (id, role, full_name) values (u_admin, 'ADMIN', 'Day 3 Admin');

  perform pg_temp.act('authenticated', u_admin);
  insert into public.clients (full_name, phone, email, city) values ('Vikram Sharma', '9888877771', 'vikram@example.test', 'Bengaluru') returning id into c_a;
  insert into public.clients (full_name, phone, email, city) values ('Ananya Roy', '9888877772', 'ananya@example.test', 'Bengaluru') returning id into c_b;

  -- One Client can have multiple Vehicles
  insert into public.vehicles (client_id, make, model, manufacturing_year, chassis_number, registration_number)
    values (c_a, 'Honda', 'City', 2020, 'MAKGM2650N0001111', 'KA01MH1111') returning id into v_a1;
  insert into public.vehicles (client_id, make, model, manufacturing_year, chassis_number, registration_number)
    values (c_a, 'Toyota', 'Innova', 2022, 'MBJ11AB40P0002222', 'KA01MH2222') returning id into v_a2;
  insert into public.vehicles (client_id, make, model, manufacturing_year, chassis_number, registration_number)
    values (c_b, 'Hyundai', 'Creta', 2021, 'MALC141CM0003333', 'KA03NC3333') returning id into v_b;

  select count(*) into n from public.vehicles where client_id = c_a;
  res := res || pg_temp.chk(n = 2, 'BL-V1 one client can own multiple vehicles (Client A has 2 vehicles)');

  perform pg_temp.act('service_role', null);
  insert into public.profiles (id, role, client_id, full_name) values
    (u_a, 'CLIENT', c_a, 'Vikram Sharma'),
    (u_b, 'CLIENT', c_b, 'Ananya Roy');

  -- ============ 1. SERVICE REQUEST LIFECYCLE ============
  perform pg_temp.act('service_role', null);
  insert into public.service_requests (source, original_submission)
  values ('WEBSITE', jsonb_build_object('customer_name', 'Vikram Sharma', 'phone', '9888877771', 'car_make', 'Honda', 'car_model', 'City'))
  returning id into sr1;

  perform pg_temp.act('authenticated', u_admin);
  -- Invalid jump: NEW -> QUOTATION_SENT
  begin
    update public.service_requests set status = 'QUOTATION_SENT' where id = sr1;
    res := res || E'\nFAIL BL-SR1 arbitrary jump NEW -> QUOTATION_SENT was allowed';
  exception when others then
    res := res || E'\nPASS BL-SR1 arbitrary jump NEW -> QUOTATION_SENT blocked [' || sqlerrm || ']';
  end;

  -- Invalid jump: NEW -> CONVERTED_TO_JOB
  begin
    update public.service_requests set status = 'CONVERTED_TO_JOB' where id = sr1;
    res := res || E'\nFAIL BL-SR2 arbitrary jump NEW -> CONVERTED_TO_JOB was allowed';
  exception when others then
    res := res || E'\nPASS BL-SR2 arbitrary jump NEW -> CONVERTED_TO_JOB blocked [' || sqlerrm || ']';
  end;

  -- Invalid jump: NEW -> QUOTATION_CREATED without UNDER_REVIEW
  begin
    update public.service_requests set status = 'QUOTATION_CREATED' where id = sr1;
    res := res || E'\nFAIL BL-SR3 skipping UNDER_REVIEW step (NEW -> QUOTATION_CREATED) was allowed';
  exception when others then
    res := res || E'\nPASS BL-SR3 skipping UNDER_REVIEW step (NEW -> QUOTATION_CREATED) blocked [' || sqlerrm || ']';
  end;

  -- Prerequisite check: UNDER_REVIEW requires linked client and vehicle
  begin
    update public.service_requests set status = 'UNDER_REVIEW' where id = sr1;
    res := res || E'\nFAIL BL-SR4 UNDER_REVIEW without client and vehicle was allowed';
  exception when others then
    res := res || E'\nPASS BL-SR4 UNDER_REVIEW requires client and vehicle [' || sqlerrm || ']';
  end;

  -- Valid transition: admin links request via RPC -> UNDER_REVIEW
  j := public.admin_link_service_request(sr1, c_a, v_a1);
  select status::text into t from public.service_requests where id = sr1;
  res := res || pg_temp.chk(t = 'UNDER_REVIEW', 'BL-SR5 admin_link_service_request linked client+vehicle and set UNDER_REVIEW');

  -- Cancellation and resurrection prevention (insert via service_role, cancel via admin)
  perform pg_temp.act('service_role', null);
  insert into public.service_requests (source, original_submission)
    values ('WEBSITE', jsonb_build_object('customer_name', 'Test Cancel', 'phone', '9888877779'))
    returning id into sr_cancel;

  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_cancel_service_request(sr_cancel, 'Duplicate enquiry');
  select status::text into t from public.service_requests where id = sr_cancel;
  res := res || pg_temp.chk(t = 'CANCELLED', 'BL-SR6 admin_cancel_service_request cancelled request');

  -- Resurrection attempt: CANCELLED -> NEW
  begin
    update public.service_requests set status = 'NEW' where id = sr_cancel;
    res := res || E'\nFAIL BL-SR7 CANCELLED -> NEW resurrection was allowed';
  exception when others then
    res := res || E'\nPASS BL-SR7 CANCELLED -> NEW resurrection blocked [' || sqlerrm || ']';
  end;

  -- Resurrection attempt: CANCELLED -> QUOTATION_CREATED
  begin
    update public.service_requests set status = 'QUOTATION_CREATED' where id = sr_cancel;
    res := res || E'\nFAIL BL-SR8 CANCELLED -> QUOTATION_CREATED resurrection was allowed';
  exception when others then
    res := res || E'\nPASS BL-SR8 CANCELLED -> QUOTATION_CREATED resurrection blocked [' || sqlerrm || ']';
  end;

  -- Cannot create quotation against CANCELLED request
  begin
    perform public.admin_create_quotation(sr_cancel);
    res := res || E'\nFAIL BL-SR9 quotation creation against cancelled request was allowed';
  exception when others then
    res := res || E'\nPASS BL-SR9 quotation creation against cancelled request blocked [' || sqlerrm || ']';
  end;

  -- ============ 2. CLIENT + VEHICLE MANAGEMENT ============
  -- Attempt linking vehicle belonging to Client B to Client A's request
  begin
    perform public.admin_link_service_request(sr1, c_a, v_b);
    res := res || E'\nFAIL BL-V2 linking Client B vehicle to Client A request was allowed';
  exception when others then
    res := res || E'\nPASS BL-V2 linking Client B vehicle to Client A request blocked [' || sqlerrm || ']';
  end;

  -- Direct update attempt linking Client B vehicle to Client A request
  begin
    update public.service_requests set vehicle_id = v_b where id = sr1;
    res := res || E'\nFAIL BL-V3 direct UPDATE linking Client B vehicle was allowed';
  exception when others then
    res := res || E'\nPASS BL-V3 direct UPDATE linking Client B vehicle blocked [' || sqlerrm || ']';
  end;

  -- Vehicle ownership transfer prevention
  begin
    update public.vehicles set client_id = c_b where id = v_a1;
    res := res || E'\nFAIL BL-V4 changing vehicle.client_id directly was allowed';
  exception when others then
    res := res || E'\nPASS BL-V4 changing vehicle.client_id blocked [' || sqlerrm || ']';
  end;

  -- Vehicle sold: create NEW vehicle record for new owner with same chassis
  declare
    v_sold uuid;
  begin
    insert into public.vehicles (client_id, make, model, manufacturing_year, chassis_number, registration_number)
      values (c_b, 'Honda', 'City', 2020, 'MAKGM2650N0001111', 'KA01MH9999')
      returning id into v_sold;
    res := res || pg_temp.chk(v_sold is not null and v_sold <> v_a1,
      'BL-V5 sold vehicle registered as new record for new owner while preserving original vehicle record');
  end;

  -- ============ 3. QUOTATION BUSINESS LOGIC & CALCULATIONS ============
  insert into public.products (name, category, default_price) values ('Synthetic Engine Oil 5W30', 'OIL', 850.50) returning id into p_oil;
  insert into public.products (name, category, default_price) values ('Oil Filter OEM', 'FILTERS', 220.00) returning id into p_filter;

  j := public.admin_create_quotation(sr1, 'Regular Scheduled Service', 'Standard warranty applies');
  q1 := (j->>'quotation_id')::uuid;
  rev1 := (j->>'revision_id')::uuid;

  -- One Service Request has one quotation identity in MVP
  begin
    perform public.admin_create_quotation(sr1);
    res := res || E'\nFAIL BL-Q1 duplicate quotation identity for same service request was allowed';
  exception when others then
    res := res || E'\nPASS BL-Q1 one quotation identity per service request [' || sqlerrm || ']';
  end;

  -- Add items: decimal price calculation and quantity
  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity)
    values (rev1, p_oil, 3.5) returning id into it1; -- 3.5 L * 850.50 = 2976.75
  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity)
    values (rev1, p_filter, 1) returning id into it2; -- 1 * 220.00 = 220.00

  select line_total into num from public.quotation_items where id = it1;
  res := res || pg_temp.chk(num = 2976.75, 'BL-Q2 decimal quantity & price calculated correctly: 3.5 * 850.50 = ' || num);

  -- Zero quantity rejection
  begin
    insert into public.quotation_items (quotation_revision_id, name, quantity, final_value)
      values (rev1, 'Zero test', 0, 100);
    res := res || E'\nFAIL BL-Q3 zero quantity was allowed';
  exception when others then
    res := res || E'\nPASS BL-Q3 zero quantity rejected [' || sqlerrm || ']';
  end;

  -- Negative quantity rejection
  begin
    insert into public.quotation_items (quotation_revision_id, name, quantity, final_value)
      values (rev1, 'Negative qty test', -2, 100);
    res := res || E'\nFAIL BL-Q4 negative quantity was allowed';
  exception when others then
    res := res || E'\nPASS BL-Q4 negative quantity rejected [' || sqlerrm || ']';
  end;

  -- Negative price rejection
  begin
    insert into public.quotation_items (quotation_revision_id, name, quantity, final_value)
      values (rev1, 'Negative price test', 1, -500);
    res := res || E'\nFAIL BL-Q5 negative price was allowed';
  exception when others then
    res := res || E'\nPASS BL-Q5 negative price rejected [' || sqlerrm || ']';
  end;

  -- Server-side subtotal, discount, tax, total
  -- Subtotal is 2976.75 + 220.00 = 3196.75
  update public.quotation_revisions set discount = 196.75, tax = 150.00 where id = rev1;
  select subtotal, total into num, num2 from public.quotation_revisions where id = rev1;
  res := res || pg_temp.chk(num = 3196.75 and num2 = 3150.00,
    'BL-Q6 server calculated revision total (subtotal 3196.75 - discount 196.75 + tax 150.00 = 3150.00): ' || num2);

  -- Discount exceeding subtotal rejected
  begin
    update public.quotation_revisions set discount = 3500.00 where id = rev1;
    res := res || E'\nFAIL BL-Q7 discount exceeding subtotal was allowed';
  exception when others then
    res := res || E'\nPASS BL-Q7 discount exceeding subtotal rejected [' || sqlerrm || ']';
  end;

  -- Sequential revision number enforcement: cannot insert revision 5 when only revision 1 exists
  begin
    insert into public.quotation_revisions (quotation_id, revision_number, created_by)
      values (q1, 5, u_admin);
    res := res || E'\nFAIL BL-Q8 non-sequential revision number (revision 5) was allowed';
  exception when others then
    res := res || E'\nPASS BL-Q8 non-sequential revision numbers rejected [' || sqlerrm || ']';
  end;

  -- Catalogue product changes do NOT affect existing quotation items
  update public.products set default_price = 1200.00 where id = p_oil;
  select final_value, line_total into num, num2 from public.quotation_items where id = it1;
  res := res || pg_temp.chk(num = 850.50 and num2 = 2976.75,
    'BL-Q9 catalogue product price change does NOT alter existing quotation item snapshot');

  -- Send quotation revision
  j := public.admin_send_quotation_revision(rev1);
  select status::text into t from public.quotation_revisions where id = rev1;
  select status::text into t2 from public.service_requests where id = sr1;
  res := res || pg_temp.chk(t = 'SENT' and t2 = 'QUOTATION_SENT', 'BL-Q10 revision sent; service request updated to QUOTATION_SENT');

  -- Item modification after SENT is rejected
  begin
    insert into public.quotation_items (quotation_revision_id, name, quantity, final_value)
      values (rev1, 'Post-send item', 1, 100);
    res := res || E'\nFAIL BL-Q11 adding item to SENT revision was allowed';
  exception when others then
    res := res || E'\nPASS BL-Q11 adding item to SENT revision rejected [' || sqlerrm || ']';
  end;

  -- ============ 4. NEGOTIATION / CHANGE REQUESTS ============
  perform pg_temp.act('authenticated', u_a);
  j := public.client_request_quotation_change(rev1, 'Can you provide a discount on the engine oil?');
  cr1 := (j->>'change_request_id')::uuid;
  select status::text into t from public.quotation_revisions where id = rev1;
  res := res || pg_temp.chk(t = 'CHANGE_REQUESTED', 'BL-N1 client requested change; revision status is CHANGE_REQUESTED');

  -- Admin responds and creates revision 2
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_respond_quotation_change_request(cr1, 'ACCEPTED', 'Additional discount applied on revision 2');
  j := public.admin_create_quotation_revision(q1);
  rev2 := (j->>'revision_id')::uuid;
  res := res || pg_temp.chk((j->>'revision_number')::int = 2, 'BL-N2 revision 2 created sequentially after negotiation');

  -- Revision 2 gets extra discount; Revision 1 remains immutable
  update public.quotation_revisions set discount = 300.00 where id = rev2;
  select total into num from public.quotation_revisions where id = rev2;
  select total into num2 from public.quotation_revisions where id = rev1;
  res := res || pg_temp.chk(num = 3046.75 and num2 = 3150.00,
    'BL-N3 revision 2 total updated to 3046.75 while historical revision 1 total preserved at 3150.00');

  j := public.admin_send_quotation_revision(rev2);
  select status::text into t from public.quotation_revisions where id = rev1;
  select status::text into t2 from public.quotation_revisions where id = rev2;
  res := res || pg_temp.chk(t = 'SUPERSEDED' and t2 = 'SENT', 'BL-N4 revision 2 SENT, revision 1 SUPERSEDED');

  -- Client accepts and signs revision 2
  perform pg_temp.act('authenticated', u_a);
  j := public.client_accept_quotation_revision(rev2, true, 'I agree to quotation revision 2 terms and final pricing.');
  sig_path := c_a::text || '/' || rev2::text || '/sig-day3.png';

  insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('signatures', sig_path, u_a::text, '{"mimetype":"image/png"}');
  j := public.client_sign_quotation_revision(rev2, sig_path);
  select status::text into t from public.service_requests where id = sr1;
  res := res || pg_temp.chk(t = 'APPROVED', 'BL-N5 client signed quotation; service request status is APPROVED');

  -- Signed revision is immutable
  perform pg_temp.act('authenticated', u_admin);
  begin
    update public.quotation_revisions set notes = 'tampered' where id = rev2;
    res := res || E'\nFAIL BL-N6 signed revision modification was allowed';
  exception when others then
    res := res || E'\nPASS BL-N6 signed revision is strictly immutable [' || sqlerrm || ']';
  end;

  -- ============ 5. SERVICE JOB CONVERSION ============
  -- Convert to job
  j := public.admin_create_service_job(rev2, now() + interval '2 hours');
  job1 := (j->>'service_job_id')::uuid;
  select status::text into t from public.service_requests where id = sr1;
  res := res || pg_temp.chk(t = 'CONVERTED_TO_JOB', 'BL-J1 admin converted request to service job; request status is CONVERTED_TO_JOB');

  -- Work items copied from quotation with agreed snapshot
  select count(*) into n from public.service_work_items
  where service_job_id = job1 and source = 'QUOTATION' and approval_status = 'NOT_REQUIRED' and quotation_item_id is not null;
  res := res || pg_temp.chk(n = 2, 'BL-J2 quotation items copied to service_work_items (source=QUOTATION, approval_status=NOT_REQUIRED, count=2)');

  -- Duplicate job creation rejected
  begin
    perform public.admin_create_service_job(rev2);
    res := res || E'\nFAIL BL-J3 duplicate service job creation was allowed';
  exception when others then
    res := res || E'\nPASS BL-J3 duplicate service job creation rejected [' || sqlerrm || ']';
  end;

  -- Cannot cancel request once converted to job
  begin
    update public.service_requests set status = 'CANCELLED' where id = sr1;
    res := res || E'\nFAIL BL-J4 cancelling request after job conversion was allowed';
  exception when others then
    res := res || E'\nPASS BL-J4 cannot cancel service request after conversion to job [' || sqlerrm || ']';
  end;

  -- ============ 6. ADDITIONAL WORK BUSINESS LOGIC ============
  -- Admin creates additional work
  j := public.admin_add_additional_work(job1, 'AC Cabin Filter Replacement', 1, 450.00, 'Cabin filter clogged', 400.00);
  w_add1 := (j->>'work_item_id')::uuid;
  select source::text, approval_status::text, quotation_item_id into t, t2, it1 from public.service_work_items where id = w_add1;
  res := res || pg_temp.chk(t = 'ADDITIONAL' and t2 = 'PENDING' and it1 is null,
    'BL-AW1 additional work created with source=ADDITIONAL, approval_status=PENDING, quotation_item_id=NULL');

  -- Cannot execute additional work before approval
  begin
    update public.service_work_items set status = 'IN_PROGRESS' where id = w_add1;
    res := res || E'\nFAIL BL-AW2 unapproved additional work executed';
  exception when others then
    res := res || E'\nPASS BL-AW2 unapproved additional work cannot be executed [' || sqlerrm || ']';
  end;

  -- Client approves additional work
  perform pg_temp.act('authenticated', u_a);
  j := public.client_decide_additional_work(w_add1, true, 450.00, 'Approved replacement');
  select approval_status::text, approved_value into t, num from public.service_work_items where id = w_add1;
  res := res || pg_temp.chk(t = 'APPROVED' and num = 450.00, 'BL-AW3 client approved additional work with exact approved_value 450.00');

  -- Client cannot alter approved value
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_add_additional_work(job1, 'Brake Fluid Flush', 1, 600.00);
  w_add2 := (j->>'work_item_id')::uuid;
  perform pg_temp.act('authenticated', u_a);
  begin
    perform public.client_decide_additional_work(w_add2, true, 500.00); -- mismatch price
    res := res || E'\nFAIL BL-AW4 client altered approved amount';
  exception when others then
    res := res || E'\nPASS BL-AW4 client cannot alter stated price during approval [' || sqlerrm || ']';
  end;

  -- Client rejects additional work
  j := public.client_decide_additional_work(w_add2, false, 600.00, 'Decline for now');
  select approval_status::text, status::text into t, t2 from public.service_work_items where id = w_add2;
  res := res || pg_temp.chk(t = 'REJECTED' and t2 = 'CANCELLED', 'BL-AW5 client rejected additional work; status cancelled');

  -- Admin cancels work item via RPC
  perform pg_temp.act('authenticated', u_admin);
  declare
    w_add3 uuid;
  begin
    j := public.admin_add_additional_work(job1, 'Tire Rotation', 1, 300.00);
    w_add3 := (j->>'work_item_id')::uuid;
    j := public.admin_cancel_service_work_item(w_add3, 'Client declined over phone');
    select status::text into t from public.service_work_items where id = w_add3;
    res := res || pg_temp.chk(t = 'CANCELLED', 'BL-AW6 admin_cancel_service_work_item cancelled work item');
  end;

  -- ============ 7. SERVICE JOB LIFECYCLE ============
  -- Start with SCHEDULED
  select status::text into t from public.service_jobs where id = job1;
  res := res || pg_temp.chk(t = 'SCHEDULED', 'BL-JL1 service job starts as SCHEDULED');

  -- Invalid arbitrary jump: SCHEDULED -> WORK_IN_PROGRESS
  begin
    perform public.admin_update_service_job_status(job1, 'WORK_IN_PROGRESS');
    res := res || E'\nFAIL BL-JL2 arbitrary jump SCHEDULED -> WORK_IN_PROGRESS allowed';
  exception when others then
    res := res || E'\nPASS BL-JL2 arbitrary jump SCHEDULED -> WORK_IN_PROGRESS blocked [' || sqlerrm || ']';
  end;

  -- Invalid arbitrary jump: SCHEDULED -> COMPLETED
  begin
    perform public.admin_update_service_job_status(job1, 'COMPLETED');
    res := res || E'\nFAIL BL-JL3 arbitrary jump SCHEDULED -> COMPLETED allowed';
  exception when others then
    res := res || E'\nPASS BL-JL3 arbitrary jump SCHEDULED -> COMPLETED blocked [' || sqlerrm || ']';
  end;

  -- Valid progression: SCHEDULED -> VEHICLE_RECEIVED
  j := public.admin_update_service_job_status(job1, 'VEHICLE_RECEIVED');
  select status::text into t from public.service_jobs where id = job1;
  res := res || pg_temp.chk(t = 'VEHICLE_RECEIVED', 'BL-JL4 valid step: SCHEDULED -> VEHICLE_RECEIVED');

  -- Invalid reversal: VEHICLE_RECEIVED -> SCHEDULED
  begin
    perform public.admin_update_service_job_status(job1, 'SCHEDULED');
    res := res || E'\nFAIL BL-JL5 status reversal VEHICLE_RECEIVED -> SCHEDULED allowed';
  exception when others then
    res := res || E'\nPASS BL-JL5 status reversal VEHICLE_RECEIVED -> SCHEDULED blocked [' || sqlerrm || ']';
  end;

  -- Valid progression: VEHICLE_RECEIVED -> INSPECTION -> WORK_IN_PROGRESS
  j := public.admin_update_service_job_status(job1, 'INSPECTION');
  j := public.admin_update_service_job_status(job1, 'WORK_IN_PROGRESS');
  select status::text into t from public.service_jobs where id = job1;
  res := res || pg_temp.chk(t = 'WORK_IN_PROGRESS', 'BL-JL6 sequential progression to WORK_IN_PROGRESS');

  -- Complete work items
  update public.service_work_items set status = 'COMPLETED'
  where service_job_id = job1 and status in ('PENDING', 'IN_PROGRESS') and approval_status in ('NOT_REQUIRED', 'APPROVED');

  -- Continue progression: QUALITY_CHECK -> READY_FOR_DELIVERY -> COMPLETED
  j := public.admin_update_service_job_status(job1, 'QUALITY_CHECK');
  j := public.admin_update_service_job_status(job1, 'READY_FOR_DELIVERY');
  j := public.admin_update_service_job_status(job1, 'COMPLETED');
  select status::text into t from public.service_jobs where id = job1;
  res := res || pg_temp.chk(t = 'COMPLETED', 'BL-JL7 sequential progression to COMPLETED');

  -- Completed job is closed (cannot change status)
  begin
    perform public.admin_update_service_job_status(job1, 'READY_FOR_DELIVERY');
    res := res || E'\nFAIL BL-JL8 modifying completed job was allowed';
  exception when others then
    res := res || E'\nPASS BL-JL8 completed job cannot change status [' || sqlerrm || ']';
  end;

  -- ============ REPORT ============
  perform pg_temp.act('postgres', null);
  raise exception 'DAY 3 BUSINESS LOGIC REPORT PASS=% FAIL=% %',
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'PASS%'),
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'FAIL%'),
    regexp_replace(res, ' \[[^]]*\]', '', 'g');
end
$test$;
