-- AutoTricks Master Automated Test Suite
-- Consolidates all 5 test suites:
-- 1. Day 1 & Day 2 Regression (158 checks)
-- 2. Day 3 Business Logic (49 checks)
-- 3. Mandatory Security Attacks (30 checks across 20 attack vectors)
-- 4. Database-Level Invariants (13 checks)
-- 5. Complete 21-Step E2E Workflow (20 checks)
-- Total: 270 automated test checks
--
-- Cleanly rolls back in a single test transaction.
-- Outputs: TESTS RUN, TESTS PASSED, TESTS FAILED

create or replace function pg_temp.act(p_role text, p_uid uuid)
returns void language plpgsql as $
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
end $;

create or replace function pg_temp.chk(p_ok boolean, p_label text)
returns text language sql as $
  select E'\n' || case when coalesce(p_ok, false) then 'PASS ' else 'FAIL ' end || p_label;
$;

do $
declare
  res text := '';
  n_pass int;
  n_fail int;
  n_run int;
begin

  -- ============================================================
  -- SUITE 1: DAY 1 & DAY 2 REGRESSION (158 CHECKS)
  -- ============================================================
  declare
    z constant uuid := '00000000-0000-0000-0000-000000000000';
  u_admin uuid := gen_random_uuid();
  u_a uuid := gen_random_uuid();
  u_b uuid := gen_random_uuid();
  u_x uuid := gen_random_uuid();
  c_a uuid; c_b uuid; v_a uuid; v_b uuid; p1 uuid; p2 uuid;
  sr_web uuid; sr_phone uuid; q1 uuid; rev1 uuid; rev2 uuid; cr1 uuid;
  it_prod uuid; job1 uuid; w_add1 uuid; w_add2 uuid; vcr uuid; doc1 uuid;
  sig_path text; pdf_path text; rpt_path text;
  j jsonb; n int; n2 int; t text; t2 text; qnum text; num numeric; num2 numeric;
  b boolean; ts timestamptz; ts2 timestamptz;
  r record;
  begin
    -- ============ SETUP (postgres) ============
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (u_admin, z, 'authenticated', 'authenticated', 'e2e-admin@autotricks.test', now(), now()),
    (u_a, z, 'authenticated', 'authenticated', 'e2e-client-a@autotricks.test', now(), now()),
    (u_b, z, 'authenticated', 'authenticated', 'e2e-client-b@autotricks.test', now(), now()),
    (u_x, z, 'authenticated', 'authenticated', 'e2e-noprofile@autotricks.test', now(), now());
  insert into public.profiles (id, role, full_name) values (u_admin, 'ADMIN', 'E2E Admin');

  -- ============ ANONYMOUS ============
  perform pg_temp.act('anon', null);
  begin
    insert into public.service_requests (source, original_submission) values ('WEBSITE', '{"x":1}');
    res := res || E'\nFAIL INV15 anon INSERT service_requests was allowed';
  exception when others then res := res || E'\nPASS INV15 anon cannot INSERT service_requests [' || sqlerrm || ']'; end;
  begin
    perform count(*) from public.service_requests;
    res := res || E'\nFAIL anon SELECT service_requests was allowed';
  exception when others then res := res || E'\nPASS anon cannot SELECT service_requests [' || sqlerrm || ']'; end;
  begin
    perform count(*) from public.clients;
    res := res || E'\nFAIL anon SELECT clients was allowed';
  exception when others then res := res || E'\nPASS anon cannot SELECT clients [' || sqlerrm || ']'; end;
  begin
    update public.products set default_price = 0;
    res := res || E'\nFAIL anon UPDATE products was allowed';
  exception when others then res := res || E'\nPASS anon cannot UPDATE products [' || sqlerrm || ']'; end;
  begin
    perform public.admin_create_quotation(gen_random_uuid());
    res := res || E'\nFAIL anon executed workflow RPC';
  exception when others then res := res || E'\nPASS anon cannot execute workflow RPCs [' || sqlerrm || ']'; end;
  begin
    select count(*) into n from storage.objects where bucket_id in ('signatures','quotation-pdfs','signed-quotation-pdfs','service-documents');
    res := res || pg_temp.chk(n = 0, 'anon sees no private storage objects');
  exception when others then res := res || E'\nPASS anon cannot read storage objects [' || sqlerrm || ']'; end;

  -- Website submission path (what submit-service-request does with the service role)
  perform pg_temp.act('service_role', null);
  insert into public.service_requests (source, original_submission)
  values ('WEBSITE', jsonb_build_object(
    'customer_name', 'Ravi Kumar', 'phone', '9876543210', 'email', 'ravi@example.test',
    'car_make', 'Maruti Suzuki', 'car_model', 'Swift', 'manufacturing_year', 2019,
    'chassis_number', 'MA3EWDE1S00123456', 'registration_number', 'KA01AB1234',
    'current_location', 'Indiranagar, Bengaluru', 'service_description', 'Brake noise and general service'))
  returning id into sr_web;
  select * into r from public.service_requests where id = sr_web;
  res := res || pg_temp.chk(r.request_number ~ '^SR-\d{4}-\d{5}$' and r.status = 'NEW' and r.source = 'WEBSITE'
          and r.client_id is null and r.vehicle_id is null and r.created_by is null,
          'W1 website request created: ' || r.request_number || ' NEW/WEBSITE, client_id & vehicle_id NULL');

  perform pg_temp.act('postgres', null);
  select count(*) into n from public.notifications where profile_id = u_admin and type = 'NEW_SERVICE_REQUEST';
  select count(*) into n2 from public.email_notifications where profile_id = u_admin and notification_type = 'NEW_SERVICE_REQUEST' and status = 'QUEUED';
  res := res || pg_temp.chk(n = 1 and n2 = 1, 'W2 admin in-app notification + queued email for website request');

  -- ============ ADMIN: clients, vehicles, review ============
  perform pg_temp.act('authenticated', u_admin);
  select count(*) into n from public.service_requests where id = sr_web;
  res := res || pg_temp.chk(n = 1, 'A1 admin sees website request');

  insert into public.clients (full_name, phone, email, city) values ('Ravi Kumar', '9876543210', 'ravi@example.test', 'Bengaluru') returning id into c_a;
  insert into public.clients (full_name, phone) values ('Meera Nair', '9123456780') returning id into c_b;
  insert into public.vehicles (client_id, make, model, manufacturing_year, chassis_number, registration_number)
    values (c_a, 'Maruti Suzuki', 'Swift', 2019, 'MA3EWDE1S00123456', 'KA01AB1234') returning id into v_a;
  insert into public.vehicles (client_id, make, model, manufacturing_year, registration_number)
    values (c_b, 'Hyundai', 'i20', 2021, 'KL07CD5678') returning id into v_b;
  res := res || pg_temp.chk(c_a is not null and v_a is not null, 'A2 admin created clients and vehicles');

  -- Portal access provisioning (what admin-invite-user does with the service role)
  perform pg_temp.act('service_role', null);
  insert into public.profiles (id, role, client_id, full_name) values
    (u_a, 'CLIENT', c_a, 'Ravi Kumar'), (u_b, 'CLIENT', c_b, 'Meera Nair');
  begin
    insert into public.profiles (id, role, client_id, full_name) values (u_x, 'ADMIN', c_a, 'Bad Admin');
    res := res || E'\nFAIL INV18 ADMIN profile attached to a client was allowed';
  exception when others then res := res || E'\nPASS INV18 ADMIN profile cannot be attached to a client [' || sqlerrm || ']'; end;
  begin
    insert into public.profiles (id, role, full_name) values (u_x, 'CLIENT', 'Orphan Client');
    res := res || E'\nFAIL CLIENT profile without client was allowed';
  exception when others then res := res || E'\nPASS CLIENT profile requires an existing client [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_admin);
  begin
    update public.service_requests set client_id = c_a, vehicle_id = v_b where id = sr_web;
    res := res || E'\nFAIL INV1 request linked to another client''s vehicle';
  exception when others then res := res || E'\nPASS INV1 vehicle of another client rejected on service request [' || sqlerrm || ']'; end;
  update public.service_requests set client_id = c_a, vehicle_id = v_a, status = 'UNDER_REVIEW' where id = sr_web;
  get diagnostics n = row_count;
  res := res || pg_temp.chk(n = 1, 'A3 admin reviewed request and linked client + vehicle (UPDATE RLS works)');

  begin
    update public.service_requests set original_submission = '{"customer_name":"changed"}' where id = sr_web;
    res := res || E'\nFAIL INV19 admin rewrote original_submission';
  exception when others then res := res || E'\nPASS INV19 admin cannot rewrite original_submission [' || sqlerrm || ']'; end;
  perform pg_temp.act('service_role', null);
  begin
    update public.service_requests set original_submission = '{"customer_name":"changed"}' where id = sr_web;
    res := res || E'\nFAIL INV19 service_role rewrote original_submission';
  exception when others then res := res || E'\nPASS INV19 even service_role cannot rewrite original_submission [' || sqlerrm || ']'; end;
  perform pg_temp.act('postgres', null);
  select original_submission->>'customer_name', original_submission->>'service_description' into t, t2 from public.service_requests where id = sr_web;
  res := res || pg_temp.chk(t = 'Ravi Kumar' and t2 = 'Brake noise and general service', 'INV19 original website form data preserved');

  perform pg_temp.act('authenticated', u_admin);
  insert into public.service_requests (client_id, vehicle_id, source, created_by, original_submission, admin_notes)
    values (c_b, v_b, 'PHONE', u_admin, '{"caller":"Meera"}', 'Phone enquiry: AC not cooling')
    returning id into sr_phone;
  select created_by, source::text, request_number into r from public.service_requests where id = sr_phone;
  res := res || pg_temp.chk(r.created_by = u_admin and r.source = 'PHONE', 'INV20 phone request records admin creator (' || r.request_number || ')');
  begin
    insert into public.service_requests (source, created_by) values ('PHONE', u_b);
    res := res || E'\nFAIL INV20 phone request with a different creator allowed';
  exception when others then res := res || E'\nPASS INV20 phone request cannot claim another creator [' || sqlerrm || ']'; end;
  begin
    insert into public.service_requests (source, original_submission) values ('WEBSITE', '{"fake":true}');
    res := res || E'\nFAIL admin forged a WEBSITE request';
  exception when others then res := res || E'\nPASS staff cannot forge WEBSITE requests [' || sqlerrm || ']'; end;

  -- ============ ADMIN: products & quotation ============
  insert into public.products (name, category, default_price) values ('Brake pads (front set)', 'BRAKES', 1200) returning id into p1;
  insert into public.products (name, category, default_price, is_active) values ('Discontinued oil 20W50', 'OIL', 300, false) returning id into p2;

  j := public.admin_create_quotation(sr_web, 'Doorstep brake service', 'Valid for 7 days');
  q1 := (j->>'quotation_id')::uuid; rev1 := (j->>'revision_id')::uuid; qnum := j->>'quotation_number';
  res := res || pg_temp.chk(qnum ~ '^QT-\d{4}-\d{5}$' and (j->>'revision_number')::int = 1, 'A4 quotation created ' || qnum || ' with revision 1 (DRAFT)');
  begin
    perform public.admin_create_quotation(sr_web);
    res := res || E'\nFAIL second quotation for same request allowed';
  exception when others then res := res || E'\nPASS one quotation per service request [' || sqlerrm || ']'; end;

  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity)
    values (rev1, p1, 2) returning id into it_prod;
  select name, final_value, approximate_value, line_total into r from public.quotation_items where id = it_prod;
  res := res || pg_temp.chk(r.name = 'Brake pads (front set)' and r.final_value = 1200 and r.approximate_value = 1200 and r.line_total = 2400,
          'A5 product snapshot copied into item; line_total = quantity x final_value (2 x 1200 = 2400)');
  insert into public.quotation_items (quotation_revision_id, name, quantity, final_value)
    values (rev1, 'Brake service labour', 1, 500);
  update public.quotation_revisions set discount = 100, tax = 50 where id = rev1;
  select subtotal, total into num, num2 from public.quotation_revisions where id = rev1;
  res := res || pg_temp.chk(num = 2900 and num2 = 2850, 'A6 revision totals computed (subtotal 2900, total 2850): ' || num || '/' || num2);

  perform pg_temp.act('authenticated', u_a);
  select count(*) into n from public.quotation_revisions;
  select count(*) into n2 from public.quotation_items;
  res := res || pg_temp.chk(n = 0 and n2 = 0, 'C0 client cannot see DRAFT revision or its items');

  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_send_quotation_revision(rev1);
  select status::text into t from public.quotation_revisions where id = rev1;
  select status::text into t2 from public.service_requests where id = sr_web;
  res := res || pg_temp.chk(t = 'SENT' and t2 = 'QUOTATION_SENT', 'A7 revision 1 sent; request status QUOTATION_SENT');
  begin
    update public.quotation_revisions set notes = 'edited after send' where id = rev1;
    res := res || E'\nFAIL SENT revision content was editable';
  exception when others then res := res || E'\nPASS SENT revision content is immutable [' || sqlerrm || ']'; end;
  begin
    insert into public.quotation_items (quotation_revision_id, name, quantity, final_value) values (rev1, 'Sneaky', 1, 999);
    res := res || E'\nFAIL item added to SENT revision';
  exception when others then res := res || E'\nPASS items cannot be added to a SENT revision [' || sqlerrm || ']'; end;
  begin
    update public.quotation_revisions set status = 'ACCEPTED' where id = rev1;
    res := res || E'\nFAIL admin forced ACCEPTED';
  exception when others then res := res || E'\nPASS admin cannot mark a quotation ACCEPTED on the client''s behalf [' || sqlerrm || ']'; end;

  update public.products set default_price = 1500 where id = p1;
  select final_value, line_total into num, num2 from public.quotation_items where id = it_prod;
  res := res || pg_temp.chk(num = 1200 and num2 = 2400, 'INV7 catalogue price change (1200->1500) did not alter existing quotation item');

  perform pg_temp.act('postgres', null);
  select count(*) into n from public.notifications where profile_id = u_a and type = 'QUOTATION_SENT';
  res := res || pg_temp.chk(n = 1, 'A8 client notified QUOTATION_SENT');

  -- ============ CLIENT A: review & negotiate ============
  perform pg_temp.act('authenticated', u_a);
  select count(*) into n from public.quotation_items where quotation_revision_id = rev1;
  select quotation_number into t from public.quotations where id = q1;
  res := res || pg_temp.chk(n = 2 and t = qnum, 'C1 client views own quotation ' || coalesce(t, '?') || ' revision 1 with 2 items');
  j := public.client_mark_quotation_viewed(rev1);
  res := res || pg_temp.chk(j->>'status' = 'VIEWED', 'C2 client marked revision viewed');
  j := public.client_request_quotation_change(rev1, 'Please reduce the labour charge');
  cr1 := (j->>'change_request_id')::uuid;
  select status::text into t from public.quotation_revisions where id = rev1;
  res := res || pg_temp.chk(cr1 is not null and t = 'CHANGE_REQUESTED', 'C3 client requested a change (revision CHANGE_REQUESTED)');

  begin
    update public.quotation_items set final_value = 1 where id = it_prod;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'INV4 client cannot modify quotation prices (' || n || ' rows updated)');
  exception when others then res := res || E'\nPASS INV4 client cannot modify quotation prices [' || sqlerrm || ']'; end;
  begin
    update public.quotation_revisions set discount = 2000 where id = rev1;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'client cannot modify revision totals (' || n || ' rows updated)');
  exception when others then res := res || E'\nPASS client cannot modify revision totals [' || sqlerrm || ']'; end;
  begin
    insert into public.quotation_change_requests (quotation_revision_id, client_id, profile_id, message, status, admin_response)
      values (rev1, c_a, u_a, 'self-approve', 'ACCEPTED', 'approved');
    res := res || E'\nFAIL client inserted self-accepted change request';
  exception when others then res := res || E'\nPASS client cannot write change-request status/admin response [' || sqlerrm || ']'; end;
  begin
    perform public.admin_create_quotation(sr_web);
    res := res || E'\nFAIL INV16 client executed admin RPC';
  exception when others then res := res || E'\nPASS INV16 client cannot run admin RPCs [' || sqlerrm || ']'; end;
  begin
    insert into public.clients (full_name, phone) values ('Hacker', '1');
    res := res || E'\nFAIL INV16 client created a client';
  exception when others then res := res || E'\nPASS INV16 client cannot create clients [' || sqlerrm || ']'; end;
  begin
    insert into public.products (name, default_price) values ('Hack', 1);
    res := res || E'\nFAIL INV16 client created a product';
  exception when others then res := res || E'\nPASS INV16 client cannot create products [' || sqlerrm || ']'; end;
  begin
    update public.service_requests set status = 'CANCELLED' where id = sr_web;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'INV16 client cannot update service requests (0 rows)');
  exception when others then res := res || E'\nPASS INV16 client cannot update service requests [' || sqlerrm || ']'; end;
  update public.profiles set full_name = 'Ravi K.' where id = u_a;
  get diagnostics n = row_count;
  res := res || pg_temp.chk(n = 1, 'C4 client updates own profile name (UPDATE RLS with SELECT visibility)');
  begin
    update public.profiles set role = 'ADMIN', client_id = null where id = u_a;
    res := res || E'\nFAIL INV17 client escalated own role';
  exception when others then res := res || E'\nPASS INV17 client cannot change own role [' || sqlerrm || ']'; end;

  -- ============ CLIENT B: isolation ============
  perform pg_temp.act('authenticated', u_b);
  select (select count(*) from public.clients) + 0 into n;
  res := res || pg_temp.chk(n = 1, 'INV2 client B sees only own client row');
  select count(*) into n from public.vehicles;
  res := res || pg_temp.chk(n = 1, 'INV2 client B sees only own vehicle');
  select count(*) into n from public.service_requests;
  res := res || pg_temp.chk(n = 1, 'INV2 client B sees only own service request');
  select (select count(*) from public.quotations) + (select count(*) from public.quotation_revisions)
       + (select count(*) from public.quotation_items) + (select count(*) from public.quotation_change_requests) into n;
  res := res || pg_temp.chk(n = 0, 'INV2 client B sees none of client A''s quotations/revisions/items/change requests');
  select count(*) into n from public.profiles;
  res := res || pg_temp.chk(n = 1, 'INV2 client B sees only own profile');
  begin
    perform public.client_request_quotation_change(rev1, 'hijack');
    res := res || E'\nFAIL INV3 client B requested change on A''s quotation';
  exception when others then res := res || E'\nPASS INV3 client B cannot act on A''s quotation [' || sqlerrm || ']'; end;
  begin
    perform public.client_accept_quotation_revision(rev1, true, 'I accept somebody else''s quotation');
    res := res || E'\nFAIL INV3 client B accepted A''s quotation';
  exception when others then res := res || E'\nPASS INV3 client B cannot accept A''s quotation [' || sqlerrm || ']'; end;
  begin
    insert into public.profiles (id, role, full_name) values (u_x, 'ADMIN', 'Self-made admin');
    res := res || E'\nFAIL INV17 client created an ADMIN profile';
  exception when others then res := res || E'\nPASS INV17 client cannot create ADMIN profiles [' || sqlerrm || ']'; end;

  -- ============ ADMIN: respond & revise ============
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_respond_quotation_change_request(cr1, 'PARTIALLY_ACCEPTED', 'Labour reduced to 400');
  j := public.admin_create_quotation_revision(q1);
  rev2 := (j->>'revision_id')::uuid;
  select count(*) into n from public.quotation_items where quotation_revision_id = rev2;
  select quotation_number into t from public.quotations where id = q1;
  res := res || pg_temp.chk((j->>'revision_number')::int = 2 and n = 2, 'A9 revision 2 created (items copied: ' || n || ')');
  res := res || pg_temp.chk(t = qnum, 'INV9 quotation number stable across revisions (' || t || ')');
  begin
    perform public.admin_create_quotation_revision(q1);
    res := res || E'\nFAIL second concurrent DRAFT revision allowed';
  exception when others then res := res || E'\nPASS only one DRAFT revision at a time [' || sqlerrm || ']'; end;
  update public.quotation_items set final_value = 400 where quotation_revision_id = rev2 and name = 'Brake service labour';
  select total into num from public.quotation_revisions where id = rev2;
  select total into num2 from public.quotation_revisions where id = rev1;
  res := res || pg_temp.chk(num = 2750 and num2 = 2850, 'A10 revision 2 renegotiated to 2750 while revision 1 snapshot stays 2850');

  perform pg_temp.act('service_role', null);
  begin
    insert into public.quotation_revisions (quotation_id, revision_number, created_by) values (q1, 2, u_admin);
    res := res || E'\nFAIL INV8 duplicate revision number allowed';
  exception when others then res := res || E'\nPASS INV8 revision number unique within quotation [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_send_quotation_revision(rev2);
  select status::text into t from public.quotation_revisions where id = rev1;
  select status::text into t2 from public.quotation_revisions where id = rev2;
  res := res || pg_temp.chk(t = 'SUPERSEDED' and t2 = 'SENT', 'A11 revision 2 sent, revision 1 SUPERSEDED');

  -- ============ CLIENT A: accept & sign ============
  perform pg_temp.act('authenticated', u_a);
  begin
    perform public.client_accept_quotation_revision(rev1, true, 'I accept the superseded revision');
    res := res || E'\nFAIL superseded revision accepted';
  exception when others then res := res || E'\nPASS superseded revision cannot be accepted [' || sqlerrm || ']'; end;
  begin
    perform public.client_accept_quotation_revision(rev2, false, 'I accept revision two of this quotation');
    res := res || E'\nFAIL acceptance without explicit consent';
  exception when others then res := res || E'\nPASS explicit consent required to accept [' || sqlerrm || ']'; end;
  j := public.client_accept_quotation_revision(rev2, true, 'I have reviewed quotation revision 2 and agree to the listed items, prices and terms.');
  res := res || pg_temp.chk(j->>'status' = 'ACCEPTED', 'C5 client accepted revision 2 with consent');

  sig_path := c_a::text || '/' || rev2::text || '/signature-1.png';
  begin
    perform public.client_sign_quotation_revision(rev2, sig_path);
    res := res || E'\nFAIL signed without uploaded signature';
  exception when others then res := res || E'\nPASS signing requires the uploaded drawn signature [' || sqlerrm || ']'; end;

  insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('signatures', sig_path, u_a::text, '{"mimetype":"image/png","size":2048}');
  res := res || E'\nPASS C6 client uploaded signature PNG to own signatures folder (storage INSERT policy)';
  begin
    insert into storage.objects (bucket_id, name, owner_id, metadata)
      values ('signatures', c_a::text || '/' || rev1::text || '/old.png', u_a::text, '{}');
    res := res || E'\nFAIL signature upload for a non-accepted revision allowed';
  exception when others then res := res || E'\nPASS storage: no signature upload for non-accepted revision [' || sqlerrm || ']'; end;
  begin
    insert into storage.objects (bucket_id, name, owner_id, metadata)
      values ('quotation-pdfs', c_a::text || '/fake.pdf', u_a::text, '{}');
    res := res || E'\nFAIL client uploaded into quotation-pdfs';
  exception when others then res := res || E'\nPASS storage: client cannot upload quotation PDFs [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_b);
  begin
    insert into storage.objects (bucket_id, name, owner_id, metadata)
      values ('signatures', c_a::text || '/' || rev2::text || '/forged.png', u_b::text, '{}');
    res := res || E'\nFAIL client B uploaded into A''s signature folder';
  exception when others then res := res || E'\nPASS storage: client B cannot upload into A''s folder [' || sqlerrm || ']'; end;
  begin
    perform public.client_sign_quotation_revision(rev2, sig_path);
    res := res || E'\nFAIL client B signed A''s quotation';
  exception when others then res := res || E'\nPASS client B cannot sign A''s quotation [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_a);
  j := public.client_sign_quotation_revision(rev2, sig_path);
  select * into r from public.quotation_signatures where quotation_revision_id = rev2;
  res := res || pg_temp.chk(r.client_id = c_a and r.profile_id = u_a and r.signature_file = sig_path
          and r.signature_method = 'DRAWN' and r.consent_text like 'I have reviewed quotation revision 2%'
          and r.accepted_at is not null and r.signed_at >= r.accepted_at,
          'C7 signature recorded: client, profile, revision, consent text, accepted_at, signed_at, file path');
  select status::text into t from public.service_requests where id = sr_web;
  res := res || pg_temp.chk(t = 'APPROVED', 'C8 service request APPROVED after signing (no job auto-created)');
  begin
    perform public.client_sign_quotation_revision(rev2, sig_path);
    res := res || E'\nFAIL revision signed twice';
  exception when others then res := res || E'\nPASS signature cannot be replaced / signed twice [' || sqlerrm || ']'; end;
  begin
    update storage.objects set metadata = '{"replaced":true}' where bucket_id = 'signatures' and name = sig_path;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'storage: client cannot overwrite signature file (0 rows)');
  exception when others then res := res || E'\nPASS storage: client cannot overwrite signature file [' || sqlerrm || ']'; end;
  begin
    delete from storage.objects where bucket_id = 'signatures' and name = sig_path;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'storage: client cannot delete signature file (0 rows)');
  exception when others then res := res || E'\nPASS storage: client cannot delete signature file [' || sqlerrm || ']'; end;

  -- ============ ADMIN: signed revision is frozen ============
  perform pg_temp.act('authenticated', u_admin);
  begin
    update public.quotation_revisions set notes = 'post-sign edit' where id = rev2;
    res := res || E'\nFAIL INV5 signed revision edited';
  exception when others then res := res || E'\nPASS INV5 signed revision cannot be edited [' || sqlerrm || ']'; end;
  begin
    update public.quotation_items set final_value = 1 where quotation_revision_id = rev2;
    res := res || E'\nFAIL INV6 signed item edited';
  exception when others then res := res || E'\nPASS INV6 signed quotation item cannot be edited [' || sqlerrm || ']'; end;
  perform pg_temp.act('service_role', null);
  begin
    update public.quotation_revisions set status = 'CANCELLED' where id = rev2;
    res := res || E'\nFAIL INV5 service_role changed signed revision';
  exception when others then res := res || E'\nPASS INV5 even service_role cannot change a signed revision [' || sqlerrm || ']'; end;
  begin
    update public.quotation_items set quantity = 10 where quotation_revision_id = rev2;
    res := res || E'\nFAIL INV6 service_role changed signed item';
  exception when others then res := res || E'\nPASS INV6 even service_role cannot change signed items [' || sqlerrm || ']'; end;
  begin
    delete from public.quotation_signatures where quotation_revision_id = rev2;
    res := res || E'\nFAIL signature deleted';
  exception when others then res := res || E'\nPASS signature record cannot be deleted [' || sqlerrm || ']'; end;
  begin
    insert into public.service_jobs (service_request_id, quotation_revision_id, vehicle_id) values (sr_web, rev2, v_b);
    res := res || E'\nFAIL INV13 job with another client''s vehicle';
  exception when others then res := res || E'\nPASS INV13 job cannot use another client''s vehicle [' || sqlerrm || ']'; end;
  begin
    insert into public.service_jobs (service_request_id, quotation_revision_id, vehicle_id) values (sr_phone, rev2, v_b);
    res := res || E'\nFAIL INV13 job linked to another request''s revision';
  exception when others then res := res || E'\nPASS INV13 job cannot mix requests/revisions across clients [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_admin);
  begin
    perform public.admin_create_quotation_revision(q1);
    res := res || E'\nFAIL new revision after signing';
  exception when others then res := res || E'\nPASS no new revision after signing [' || sqlerrm || ']'; end;
  begin
    insert into public.service_jobs (service_request_id, quotation_revision_id, vehicle_id) values (sr_web, rev2, v_a);
    res := res || E'\nFAIL admin bypassed job workflow with direct insert';
  exception when others then res := res || E'\nPASS direct job insert blocked (workflow RPC only) [' || sqlerrm || ']'; end;

  -- ============ ADMIN: service job ============
  j := public.admin_create_service_job(rev2, now() + interval '1 day');
  job1 := (j->>'service_job_id')::uuid;
  select status::text into t from public.service_requests where id = sr_web;
  res := res || pg_temp.chk((j->>'job_number') ~ '^JOB-\d{4}-\d{5}$' and (j->>'work_items_created')::int = 2 and t = 'CONVERTED_TO_JOB',
          'A12 admin created service job ' || (j->>'job_number') || ' with 2 quotation work items; request CONVERTED_TO_JOB');
  begin
    perform public.admin_create_service_job(rev2);
    res := res || E'\nFAIL duplicate job';
  exception when others then res := res || E'\nPASS one job per service request [' || sqlerrm || ']'; end;

  j := public.admin_add_additional_work(job1, 'Brake disc skimming', 1, 800, 'Front discs scored', 750);
  w_add1 := (j->>'work_item_id')::uuid;
  res := res || pg_temp.chk(j->>'approval_status' = 'PENDING', 'A13 additional work added (PENDING approval)');
  begin
    update public.service_work_items set status = 'IN_PROGRESS' where id = w_add1;
    res := res || E'\nFAIL INV10 unapproved additional work started';
  exception when others then res := res || E'\nPASS INV10 additional work cannot start before approval [' || sqlerrm || ']'; end;
  begin
    update public.service_work_items set approval_status = 'APPROVED' where id = w_add1;
    res := res || E'\nFAIL INV10 admin self-approved';
  exception when others then res := res || E'\nPASS INV10 admin cannot approve on client''s behalf [' || sqlerrm || ']'; end;
  perform pg_temp.act('service_role', null);
  begin
    update public.service_work_items set approval_status = 'APPROVED', approved_value = 800, decision_by_profile_id = u_admin, decision_at = now() where id = w_add1;
    res := res || E'\nFAIL INV10 approval by non-client profile';
  exception when others then res := res || E'\nPASS INV10 approval must come from the owning client (even via service_role) [' || sqlerrm || ']'; end;
  begin
    update public.service_work_items set approval_status = 'APPROVED', approved_value = 800, decision_by_profile_id = u_b, decision_at = now() where id = w_add1;
    res := res || E'\nFAIL INV12 approval recorded for another client';
  exception when others then res := res || E'\nPASS INV12 another client''s profile cannot be the approver [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_admin);
  begin
    perform public.admin_update_service_job_status(job1, 'COMPLETED');
    res := res || E'\nFAIL job completed with open work';
  exception when others then res := res || E'\nPASS job cannot complete with open work items [' || sqlerrm || ']'; end;
  j := public.admin_update_service_job_status(job1, 'VEHICLE_RECEIVED');
  res := res || pg_temp.chk(j->>'status' = 'VEHICLE_RECEIVED' and j->>'started_at' is not null, 'A14 job VEHICLE_RECEIVED, started_at set');
  begin
    perform public.admin_update_service_job_status(job1, 'SCHEDULED');
    res := res || E'\nFAIL job status moved backwards';
  exception when others then res := res || E'\nPASS job status cannot move backwards [' || sqlerrm || ']'; end;

  perform pg_temp.act('postgres', null);
  select count(*) into n from public.notifications where profile_id = u_a and type = 'ADDITIONAL_WORK_REQUESTED';
  res := res || pg_temp.chk(n = 1, 'A15 client notified of additional work');

  perform pg_temp.act('authenticated', u_b);
  begin
    perform public.client_decide_additional_work(w_add1, true, 800);
    res := res || E'\nFAIL INV12 client B approved A''s work';
  exception when others then res := res || E'\nPASS INV12 client B cannot approve A''s additional work [' || sqlerrm || ']'; end;
  select (select count(*) from public.service_jobs) + (select count(*) from public.service_work_items) into n;
  res := res || pg_temp.chk(n = 0, 'INV2 client B sees none of A''s jobs/work items');

  perform pg_temp.act('authenticated', u_a);
  begin
    perform public.client_decide_additional_work(w_add1, true, 700);
    res := res || E'\nFAIL approval with stale price';
  exception when others then res := res || E'\nPASS approval must match the stated price [' || sqlerrm || ']'; end;
  j := public.client_decide_additional_work(w_add1, true, 800, 'Go ahead');
  select * into r from public.service_work_items where id = w_add1;
  res := res || pg_temp.chk(r.approval_status = 'APPROVED' and r.approved_value = 800 and r.decision_by_profile_id = u_a
          and r.decision_at is not null and r.approval_note = 'Go ahead',
          'INV11 approval records status, approved value, approving profile, timestamp, note');
  begin
    perform public.client_decide_additional_work(w_add1, false, 800);
    res := res || E'\nFAIL decision changed after approval';
  exception when others then res := res || E'\nPASS approval decision is final [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_add_additional_work(job1, 'Wiper blade replacement', 2, 300);
  w_add2 := (j->>'work_item_id')::uuid;
  perform pg_temp.act('authenticated', u_a);
  j := public.client_decide_additional_work(w_add2, false, 300, 'Not now');
  select approval_status::text, status::text into t, t2 from public.service_work_items where id = w_add2;
  res := res || pg_temp.chk(t = 'REJECTED' and t2 = 'CANCELLED', 'C9 client rejected second additional work (REJECTED / CANCELLED)');

  -- ============ ADMIN: execute & complete ============
  perform pg_temp.act('authenticated', u_admin);
  update public.service_work_items set status = 'IN_PROGRESS' where service_job_id = job1 and status = 'PENDING';
  get diagnostics n = row_count;
  update public.service_work_items set status = 'COMPLETED' where service_job_id = job1 and status = 'IN_PROGRESS';
  get diagnostics n2 = row_count;
  res := res || pg_temp.chk(n = 3 and n2 = 3, 'A16 admin executed 2 quotation items + approved additional work (3 rows)');
  begin
    update public.service_work_items set status = 'IN_PROGRESS' where id = w_add2;
    res := res || E'\nFAIL rejected work executed';
  exception when others then res := res || E'\nPASS rejected additional work cannot be executed [' || sqlerrm || ']'; end;
  perform public.admin_update_service_job_status(job1, 'INSPECTION');
  perform public.admin_update_service_job_status(job1, 'WORK_IN_PROGRESS');
  perform public.admin_update_service_job_status(job1, 'QUALITY_CHECK');
  perform public.admin_update_service_job_status(job1, 'READY_FOR_DELIVERY');
  j := public.admin_update_service_job_status(job1, 'COMPLETED');
  res := res || pg_temp.chk(j->>'status' = 'COMPLETED' and j->>'completed_at' is not null, 'A17 job progressed through all statuses to COMPLETED');
  begin
    perform public.admin_update_service_job_status(job1, 'CANCELLED');
    res := res || E'\nFAIL completed job reopened';
  exception when others then res := res || E'\nPASS completed job is closed [' || sqlerrm || ']'; end;

  -- ============ ADMIN: documents ============
  pdf_path := c_a::text || '/' || qnum || '-r2-signed.pdf';
  rpt_path := c_a::text || '/jobs/' || job1::text || '/service-report.pdf';
  insert into storage.objects (bucket_id, name, owner_id, metadata) values
    ('signed-quotation-pdfs', pdf_path, u_admin::text, '{"mimetype":"application/pdf"}'),
    ('service-documents', rpt_path, u_admin::text, '{"mimetype":"application/pdf"}');
  begin
    insert into storage.objects (bucket_id, name, owner_id, metadata)
      values ('service-documents', gen_random_uuid()::text || '/x.pdf', u_admin::text, '{}');
    res := res || E'\nFAIL upload into non-existent client folder';
  exception when others then res := res || E'\nPASS storage: admin uploads must target an existing client folder [' || sqlerrm || ']'; end;
  insert into public.documents (client_id, quotation_revision_id, document_type, storage_path)
    values (c_a, rev2, 'SIGNED_QUOTATION_PDF', pdf_path) returning id into doc1;
  insert into public.documents (client_id, service_job_id, document_type, storage_path)
    values (c_a, job1, 'SERVICE_REPORT', rpt_path);
  select storage_bucket into t from public.documents where id = doc1;
  res := res || pg_temp.chk(t = 'signed-quotation-pdfs', 'A18 documents registered (signed quotation PDF + service report)');
  begin
    insert into public.documents (client_id, quotation_revision_id, document_type, storage_path)
      values (c_b, rev2, 'QUOTATION_PDF', c_b::text || '/steal.pdf');
    res := res || E'\nFAIL document attached to wrong client';
  exception when others then res := res || E'\nPASS document cannot belong to a different client than its revision [' || sqlerrm || ']'; end;
  begin
    insert into public.documents (client_id, quotation_revision_id, document_type, storage_path)
      values (c_a, rev1, 'SIGNED_QUOTATION_PDF', c_a::text || '/unsigned.pdf');
    res := res || E'\nFAIL signed PDF for unsigned revision';
  exception when others then res := res || E'\nPASS signed PDF requires a signed revision [' || sqlerrm || ']'; end;
  begin
    update public.documents set storage_path = c_a::text || '/replaced.pdf' where id = doc1;
    res := res || E'\nFAIL document replaced';
  exception when others then res := res || E'\nPASS documents cannot be replaced [' || sqlerrm || ']'; end;
  begin
    delete from storage.objects where bucket_id = 'service-documents' and name = rpt_path;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'storage: registered document file cannot be deleted (0 rows)');
  exception when others then res := res || E'\nPASS storage: registered document file cannot be deleted [' || sqlerrm || ']'; end;
  perform pg_temp.act('service_role', null);
  begin
    delete from public.documents where id = doc1;
    res := res || E'\nFAIL signed document deleted';
  exception when others then res := res || E'\nPASS signed quotation document cannot be deleted (even service_role) [' || sqlerrm || ']'; end;

  -- ============ CLIENT A: history & documents ============
  perform pg_temp.act('authenticated', u_a);
  select status::text into t from public.service_jobs where id = job1;
  select count(*) into n from public.service_work_items where service_job_id = job1;
  res := res || pg_temp.chk(t = 'COMPLETED' and n = 4, 'C10 client views completed service history (job COMPLETED, 4 work items)');
  select count(*) into n from public.documents;
  select count(*) into n2 from storage.objects where bucket_id in ('signatures','signed-quotation-pdfs','service-documents');
  res := res || pg_temp.chk(n = 2 and n2 = 3, 'C11 client sees own 2 documents and 3 storage files (signature, signed PDF, report)');
  begin
    update public.service_work_items set status = 'CANCELLED' where id = w_add1;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'client cannot modify service history (0 rows)');
  exception when others then res := res || E'\nPASS client cannot modify service history [' || sqlerrm || ']'; end;
  j := public.client_request_vehicle_correction(v_a, 'Registration should be KA01AB1235', '{"registration_number":"KA01AB1235"}');
  vcr := (j->>'request_id')::uuid;
  res := res || pg_temp.chk(vcr is not null, 'C12 client requested vehicle correction');
  begin
    update public.vehicles set registration_number = 'KA99ZZ9999' where id = v_a;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'client cannot alter verified vehicle identity (' || n || ' rows updated)');
  exception when others then res := res || E'\nPASS client cannot alter verified vehicle identity [' || sqlerrm || ']'; end;
  -- ============ DAY 2: Product Catalogue Protection (Client Denial) ============
  select count(*) into n from public.products;
  res := res || pg_temp.chk(n = 0, 'CLIENT cannot SELECT products (0 visible)');
  begin
    insert into public.products (name, category, default_price) values ('Hacked Product', 'OIL', 999);
    res := res || E'\nFAIL CLIENT INSERT products was allowed';
  exception when others then res := res || E'\nPASS CLIENT cannot INSERT products [' || sqlerrm || ']'; end;
  begin
    update public.products set default_price = 999 where id = p1;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'CLIENT cannot UPDATE products (' || n || ' rows updated)');
  exception when others then res := res || E'\nPASS CLIENT cannot UPDATE products [' || sqlerrm || ']'; end;
  begin
    delete from public.products where id = p1;
    res := res || E'\nFAIL CLIENT DELETE products was allowed';
  exception when others then res := res || E'\nPASS CLIENT cannot DELETE products [' || sqlerrm || ']'; end;

  -- ============ DAY 2: Internal Notes Protection ============
  begin
    perform notes from public.clients where id = c_a;
    res := res || E'\nFAIL CLIENT read clients.notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS CLIENT cannot read clients.notes [permission denied]';
  when others then
    res := res || E'\nPASS CLIENT cannot read clients.notes [' || sqlerrm || ']';
  end;
  begin
    perform admin_notes from public.service_requests where id = sr_web;
    res := res || E'\nFAIL CLIENT read service_requests.admin_notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS CLIENT cannot read service_requests.admin_notes [permission denied]';
  when others then
    res := res || E'\nPASS CLIENT cannot read service_requests.admin_notes [' || sqlerrm || ']';
  end;
  begin
    update public.clients set notes = 'tampered note' where id = c_a;
    res := res || E'\nFAIL CLIENT modified clients.notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS CLIENT cannot modify clients.notes [permission denied]';
  when others then
    res := res || E'\nPASS CLIENT cannot modify clients.notes [' || sqlerrm || ']';
  end;
  begin
    update public.service_requests set admin_notes = 'tampered note' where id = sr_web;
    res := res || E'\nFAIL CLIENT modified service_requests.admin_notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS CLIENT cannot modify service_requests.admin_notes [permission denied]';
  when others then
    res := res || E'\nPASS CLIENT cannot modify service_requests.admin_notes [' || sqlerrm || ']';
  end;

  -- ============ DAY 2: Role Escalation Prevention ============
  begin
    update public.profiles set role = 'ADMIN' where id = u_a;
    res := res || E'\nFAIL CLIENT escalated own role to ADMIN';
  exception when insufficient_privilege then
    res := res || E'\nPASS CLIENT cannot become ADMIN [permission denied for column role]';
  when others then
    res := res || E'\nPASS CLIENT cannot become ADMIN [' || sqlerrm || ']';
  end;
  begin
    update public.profiles set client_id = c_b where id = u_a;
    res := res || E'\nFAIL CLIENT reattached client_id';
  exception when insufficient_privilege then
    res := res || E'\nPASS CLIENT cannot change client_id [permission denied for column client_id]';
  when others then
    res := res || E'\nPASS CLIENT cannot change client_id [' || sqlerrm || ']';
  end;

  -- ============ DAY 2: Client Portal Views Visibility ============
  select count(*) into n from public.client_portal_clients where id = c_a;
  select count(*) into n2 from public.client_portal_service_requests where client_id = c_a;
  res := res || pg_temp.chk(n = 1 and n2 >= 1, 'CLIENT sees own profile and requests via client portal views');

  -- ============ DAY 2: Admin Access to Products and Notes ============
  perform pg_temp.act('authenticated', u_admin);
  select count(*) into n from public.products;
  res := res || pg_temp.chk(n = 2, 'ADMIN can SELECT products (' || n || ' visible)');
  select notes into t from public.admin_clients where id = c_a;
  select admin_notes into t2 from public.admin_service_requests where id = sr_phone;
  res := res || pg_temp.chk(t is null and t2 = 'Phone enquiry: AC not cooling', 'ADMIN can read internal notes via admin views');
  t := public.admin_get_service_request_notes(sr_phone);
  res := res || pg_temp.chk(t = 'Phone enquiry: AC not cooling', 'ADMIN can read service_requests.admin_notes via RPC');
  perform public.admin_set_client_notes(c_a, 'VIP corporate client');
  t := public.admin_get_client_notes(c_a);
  res := res || pg_temp.chk(t = 'VIP corporate client', 'ADMIN can update and read clients.notes via RPC');

  -- Return to u_a for remaining client checks
  perform pg_temp.act('authenticated', u_a);

  -- ============ CLIENT B: documents isolation ============
  perform pg_temp.act('authenticated', u_b);
  select count(*) into n from public.documents;
  select count(*) into n2 from storage.objects where name like c_a::text || '/%';
  res := res || pg_temp.chk(n = 0 and n2 = 0, 'INV14 client B cannot see A''s documents or storage files');
  select count(*) into n from public.quotation_signatures;
  res := res || pg_temp.chk(n = 0, 'INV14 client B cannot see A''s signature record');
  begin
    perform public.client_request_vehicle_correction(v_a, 'not my car');
    res := res || E'\nFAIL client B requested correction on A''s vehicle';
  exception when others then res := res || E'\nPASS client B cannot request corrections on A''s vehicle [' || sqlerrm || ']'; end;

  -- ============ Vehicles ============
  perform pg_temp.act('authenticated', u_admin);
  begin
    update public.vehicles set client_id = c_b where id = v_a;
    res := res || E'\nFAIL vehicle transferred by admin';
  exception when others then res := res || E'\nPASS vehicle cannot be transferred (admin) [' || sqlerrm || ']'; end;
  update public.vehicles set registration_number = 'KA01AB1235' where id = v_a;
  get diagnostics n = row_count;
  j := public.admin_respond_vehicle_correction(vcr, 'ACCEPTED', 'Registration corrected');
  res := res || pg_temp.chk(n = 1 and j->>'status' = 'ACCEPTED', 'A19 admin corrected vehicle identity and resolved request');
  perform pg_temp.act('service_role', null);
  begin
    update public.vehicles set client_id = c_b where id = v_a;
    res := res || E'\nFAIL vehicle transferred by service_role';
  exception when others then res := res || E'\nPASS vehicle cannot be transferred (even service_role) [' || sqlerrm || ']'; end;

  -- ============ Signed-in user without a profile ============
  perform pg_temp.act('authenticated', u_x);
  select (select count(*) from public.products) + (select count(*) from public.clients)
       + (select count(*) from public.service_requests) + (select count(*) from public.documents) into n;
  res := res || pg_temp.chk(n = 0, 'login without profile sees nothing (no auto client creation)');
  begin
    perform public.client_accept_quotation_revision(rev2, true, 'I accept as a random signed-up user');
    res := res || E'\nFAIL profile-less user ran client RPC';
  exception when others then res := res || E'\nPASS profile-less user cannot run client RPCs [' || sqlerrm || ']'; end;

  -- ============ Notifications ============
  perform pg_temp.act('authenticated', u_a);
  select count(*) into n from public.notifications;
  update public.notifications set is_read = true, read_at = now() where is_read = false;
  get diagnostics n2 = row_count;
  res := res || pg_temp.chk(n > 0 and n2 = n, 'N1 client marks own ' || n || ' notifications read (UPDATE RLS)');
  begin
    update public.notifications set message = 'tampered';
    res := res || E'\nFAIL notification text edited';
  exception when others then res := res || E'\nPASS notification content not editable [' || sqlerrm || ']'; end;
  perform pg_temp.act('postgres', null);
  select count(*) into n from public.email_notifications where profile_id = u_a and status = 'QUEUED';
  res := res || pg_temp.chk(n > 0, 'N2 client emails queued independently (' || n || ' QUEUED)');
  begin
    perform private.notify_profile(gen_random_uuid(), 'QUOTATION_SENT', 't', 'm', null, null);
    res := res || E'\nPASS N3 notification failure is swallowed (business operation not rolled back)';
  exception when others then res := res || E'\nFAIL N3 notification failure propagated: ' || sqlerrm; end;

  -- ============ Audit ============
  for t in select unnest(array['QUOTATION_CREATED','QUOTATION_REVISION_CREATED','QUOTATION_PRICE_CHANGED',
      'QUOTATION_ACCEPTED','QUOTATION_SIGNED','SERVICE_JOB_CREATED','ADDITIONAL_WORK_CREATED',
      'ADDITIONAL_WORK_APPROVED','ADDITIONAL_WORK_REJECTED','SERVICE_STATUS_CHANGED','SERVICE_REQUEST_CREATED'])
  loop
    select count(*) into n from public.audit_logs where action = t;
    res := res || pg_temp.chk(n > 0, 'AUDIT ' || t || ' logged (' || n || ')');
  end loop;
  select count(*) into n from public.audit_logs where action = 'QUOTATION_SIGNED' and actor_profile_id = u_a;
  select count(*) into n2 from public.audit_logs where action = 'ADDITIONAL_WORK_APPROVED' and actor_profile_id = u_a;
  res := res || pg_temp.chk(n = 1 and n2 = 1, 'AUDIT client actions attributed to the client profile');
  select count(*) into n from public.audit_logs where action in ('QUOTATION_CREATED','SERVICE_JOB_CREATED') and actor_profile_id = u_admin;
  res := res || pg_temp.chk(n = 2, 'AUDIT admin actions attributed to the admin profile');
  begin
    delete from public.audit_logs where entity_id = q1;
    res := res || E'\nFAIL audit log deleted by owner role';
  exception when others then res := res || E'\nPASS audit logs append-only (even table owner) [' || sqlerrm || ']'; end;

  perform pg_temp.act('authenticated', u_a);
  select count(*) into n from public.audit_logs;
  res := res || pg_temp.chk(n = 0, 'AUDIT clients cannot read audit history');
  begin
    insert into public.audit_logs (action, entity_type) values ('FAKE', 'x');
    res := res || E'\nFAIL client wrote audit log';
  exception when others then res := res || E'\nPASS clients cannot write audit logs [' || sqlerrm || ']'; end;
  perform pg_temp.act('authenticated', u_admin);
  begin
    insert into public.audit_logs (actor_profile_id, action, entity_type) values (u_a, 'QUOTATION_SIGNED', 'quotation');
    res := res || E'\nFAIL admin forged audit entry';
  exception when others then res := res || E'\nPASS admin cannot forge audit entries [' || sqlerrm || ']'; end;
  begin
    update public.profiles set role = 'ADMIN', client_id = null where id = u_b;
    res := res || E'\nFAIL admin promoted client via Data API';
  exception when others then res := res || E'\nPASS role changes only via controlled invite process [' || sqlerrm || ']'; end;
  end;

  -- ============================================================
  -- SUITE 2: DAY 3 BUSINESS LOGIC (49 CHECKS)
  -- ============================================================
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
  end;

  -- ============================================================
  -- SUITE 3: SECURITY ATTACK TESTS (30 CHECKS)
  -- ============================================================
  declare
    z constant uuid := '00000000-0000-0000-0000-000000000000';
  fake_uuid constant uuid := '11111111-2222-3333-4444-555555555555';
  u_admin uuid := gen_random_uuid();
  u_a uuid := gen_random_uuid();
  u_b uuid := gen_random_uuid();
  c_a uuid; c_b uuid; v_a uuid; v_b uuid;
  sr_a uuid; sr_b uuid;
  p1 uuid;
  q_a uuid; rev_a uuid; it_a uuid;
  q_b uuid; rev_b uuid; it_b uuid;
  job_b uuid; w_add_b uuid;
  j jsonb; n int; n2 int; n3 int; t text;
  begin
    -- ============ SETUP ============
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (u_admin, z, 'authenticated', 'authenticated', 'sec-admin@autotricks.test', now(), now()),
    (u_a, z, 'authenticated', 'authenticated', 'sec-client-a@autotricks.test', now(), now()),
    (u_b, z, 'authenticated', 'authenticated', 'sec-client-b@autotricks.test', now(), now());

  insert into public.profiles (id, role, full_name) values (u_admin, 'ADMIN', 'Sec Admin');

  perform pg_temp.act('authenticated', u_admin);
  insert into public.clients (full_name, phone, email, notes) values ('Client Alice', '9111111111', 'alice@test.org', 'Alice internal notes') returning id into c_a;
  insert into public.clients (full_name, phone, email, notes) values ('Client Bob', '9222222222', 'bob@test.org', 'Bob internal notes') returning id into c_b;

  insert into public.vehicles (client_id, make, model, chassis_number, registration_number)
    values (c_a, 'Maruti', 'Baleno', 'MABA1111111111111', 'KA01AA1111') returning id into v_a;
  insert into public.vehicles (client_id, make, model, chassis_number, registration_number)
    values (c_b, 'Hyundai', 'Verna', 'MAHV2222222222222', 'KA02BB2222') returning id into v_b;

  insert into public.products (name, category, default_price) values ('Brake Fluid DOT4', 'FLUIDS', 450.00) returning id into p1;

  perform pg_temp.act('service_role', null);
  insert into public.profiles (id, role, client_id, full_name) values
    (u_a, 'CLIENT', c_a, 'Alice Profile'),
    (u_b, 'CLIENT', c_b, 'Bob Profile');

  insert into public.service_requests (source, original_submission)
    values ('WEBSITE', jsonb_build_object('customer_name', 'Alice')) returning id into sr_a;
  insert into public.service_requests (source, original_submission)
    values ('WEBSITE', jsonb_build_object('customer_name', 'Bob')) returning id into sr_b;

  perform pg_temp.act('authenticated', u_admin);
  perform public.admin_link_service_request(sr_a, c_a, v_a);
  perform public.admin_link_service_request(sr_b, c_b, v_b);
  perform pg_temp.act('postgres', null);
  update public.service_requests set admin_notes = 'Alice secret notes' where id = sr_a;
  update public.service_requests set admin_notes = 'Bob secret notes' where id = sr_b;
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_create_quotation(sr_a);
  q_a := (j->>'quotation_id')::uuid; rev_a := (j->>'revision_id')::uuid;
  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity) values (rev_a, p1, 1) returning id into it_a;
  j := public.admin_send_quotation_revision(rev_a);

  j := public.admin_create_quotation(sr_b);
  q_b := (j->>'quotation_id')::uuid; rev_b := (j->>'revision_id')::uuid;
  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity) values (rev_b, p1, 1) returning id into it_b;
  j := public.admin_send_quotation_revision(rev_b);

  -- Setup Bob's job and additional work for attack testing
  perform pg_temp.act('authenticated', u_b);
  j := public.client_accept_quotation_revision(rev_b, true, 'Bob accepts quotation revision 1.');
  insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('signatures', c_b::text || '/' || rev_b::text || '/bob-sig.png', u_b::text, '{"mimetype":"image/png"}');
  j := public.client_sign_quotation_revision(rev_b, c_b::text || '/' || rev_b::text || '/bob-sig.png');

  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_create_service_job(rev_b, now() + interval '1 day');
  job_b := (j->>'service_job_id')::uuid;
  j := public.admin_add_additional_work(job_b, 'Wiper Fluid Topup', 1, 150.00);
  w_add_b := (j->>'work_item_id')::uuid;

  -- ============ ATTACK 1: CLIENT A reading Client B data ============
  perform pg_temp.act('authenticated', u_a);
  select count(*) into n from public.clients where id = c_b;
  select count(*) into n2 from public.vehicles where id = v_b;
  select count(*) into n3 from public.service_requests where id = sr_b;
  res := res || pg_temp.chk((n + n2 + n3) = 0, 'ATK-1 CLIENT A reading Client B data returns 0 rows');

  -- ============ ATTACK 2: CLIENT A modifying Client B data ============
  update public.clients set full_name = 'Hacked Bob' where id = c_b;
  get diagnostics n = row_count;
  update public.vehicles set model = 'Hacked Model' where id = v_b;
  get diagnostics n2 = row_count;
  res := res || pg_temp.chk((n + n2) = 0, 'ATK-2 CLIENT A modifying Client B data affected 0 rows');

  -- ============ ATTACK 3: CLIENT A reading Client B quotation ============
  select count(*) into n from public.quotations where id = q_b;
  select count(*) into n2 from public.quotation_revisions where id = rev_b;
  select count(*) into n3 from public.quotation_items where id = it_b;
  res := res || pg_temp.chk((n + n2 + n3) = 0, 'ATK-3 CLIENT A reading Client B quotation/revision/items returns 0 rows');

  -- ============ ATTACK 4: CLIENT A modifying quotation prices ============
  begin
    update public.quotation_items set final_value = 1.00 where id = it_a;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'ATK-4 CLIENT A direct quotation price modification updated 0 rows');
  exception when others then
    res := res || E'\nPASS ATK-4 CLIENT A modifying quotation prices blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 5: CLIENT A modifying quotation totals ============
  begin
    update public.quotation_revisions set discount = 5000.00 where id = rev_a;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'ATK-5 CLIENT A direct quotation total modification updated 0 rows');
  exception when others then
    res := res || E'\nPASS ATK-5 CLIENT A modifying quotation totals blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 6: CLIENT A accepting Client B quotation ============
  begin
    perform public.client_accept_quotation_revision(rev_b, true, 'Alice attempts to accept Bob quotation');
    res := res || E'\nFAIL ATK-6 CLIENT A accepted Client B quotation';
  exception when others then
    res := res || E'\nPASS ATK-6 CLIENT A accepting Client B quotation blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 7: CLIENT A signing Client B quotation ============
  begin
    perform public.client_sign_quotation_revision(rev_b, c_b::text || '/' || rev_b::text || '/bob-sig.png');
    res := res || E'\nFAIL ATK-7 CLIENT A signed Client B quotation';
  exception when others then
    res := res || E'\nPASS ATK-7 CLIENT A signing Client B quotation blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 8: CLIENT A approving Client B additional work ============
  begin
    perform public.client_decide_additional_work(w_add_b, true, 150.00, 'Alice unauthorized approval');
    res := res || E'\nFAIL ATK-8 CLIENT A approved Client B additional work';
  exception when others then
    res := res || E'\nPASS ATK-8 CLIENT A approving Client B additional work blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 9: CLIENT A changing service request status ============
  begin
    update public.service_requests set status = 'CONVERTED_TO_JOB' where id = sr_a;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'ATK-9 CLIENT A changing service request status updated 0 rows');
  exception when others then
    res := res || E'\nPASS ATK-9 CLIENT A changing service request status blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 10: CLIENT A changing job status ============
  begin
    update public.service_jobs set status = 'COMPLETED' where id = job_b;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'ATK-10 CLIENT A direct job status update affected 0 rows');
  exception when others then
    res := res || E'\nPASS ATK-10 CLIENT A direct job status update blocked [' || sqlerrm || ']';
  end;
  begin
    perform public.admin_update_service_job_status(job_b, 'COMPLETED');
    res := res || E'\nFAIL ATK-10 CLIENT A executed admin job status RPC';
  exception when others then
    res := res || E'\nPASS ATK-10 CLIENT A running admin_update_service_job_status blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 11: CLIENT A inserting fake audit logs ============
  begin
    insert into public.audit_logs (actor_profile_id, action, entity_type, entity_id)
      values (u_a, 'FAKE_ACTION', 'quotation', q_a);
    res := res || E'\nFAIL ATK-11 CLIENT A inserted audit log';
  exception when others then
    res := res || E'\nPASS ATK-11 CLIENT A inserting fake audit logs blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 12: CLIENT A modifying audit logs ============
  begin
    update public.audit_logs set action = 'TAMPERED';
    res := res || E'\nFAIL ATK-12 CLIENT A modified audit logs';
  exception when others then
    res := res || E'\nPASS ATK-12 CLIENT A modifying audit logs blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 13: CLIENT A changing vehicle ownership ============
  begin
    update public.vehicles set client_id = c_a where id = v_b;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'ATK-13 CLIENT A changing vehicle ownership affected 0 rows');
  exception when others then
    res := res || E'\nPASS ATK-13 CLIENT A changing vehicle ownership blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 14: CLIENT A linking another client's vehicle to request ============
  begin
    update public.service_requests set vehicle_id = v_b where id = sr_a;
    get diagnostics n = row_count;
    res := res || pg_temp.chk(n = 0, 'ATK-14 CLIENT A linking foreign vehicle affected 0 rows');
  exception when others then
    res := res || E'\nPASS ATK-14 CLIENT A linking foreign vehicle blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 15: CLIENT A creating a job ============
  begin
    perform public.admin_create_service_job(rev_a);
    res := res || E'\nFAIL ATK-15 CLIENT A executed admin_create_service_job';
  exception when others then
    res := res || E'\nPASS ATK-15 CLIENT A creating service job blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 16: CLIENT A bypassing workflow RPCs with direct table operations ============
  begin
    insert into public.service_jobs (service_request_id, quotation_revision_id, vehicle_id)
      values (sr_a, rev_a, v_a);
    res := res || E'\nFAIL ATK-16 CLIENT A direct insert into service_jobs was allowed';
  exception when others then
    res := res || E'\nPASS ATK-16 direct service_jobs INSERT bypass blocked [' || sqlerrm || ']';
  end;
  begin
    insert into public.quotation_revisions (quotation_id, revision_number, created_by)
      values (q_a, 99, u_a);
    res := res || E'\nFAIL ATK-16 CLIENT A direct insert into quotation_revisions was allowed';
  exception when others then
    res := res || E'\nPASS ATK-16 direct quotation_revisions INSERT bypass blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 17: CLIENT A accessing products ============
  select count(*) into n from public.products;
  res := res || pg_temp.chk(n = 0, 'ATK-17 CLIENT A selecting products returned 0 rows');
  begin
    insert into public.products (name, category, default_price) values ('Hacked Oil', 'OIL', 10);
    res := res || E'\nFAIL ATK-17 CLIENT A inserted product';
  exception when others then
    res := res || E'\nPASS ATK-17 CLIENT A inserting products blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 18: CLIENT A accessing Admin-only notes ============
  begin
    perform notes from public.clients where id = c_a;
    res := res || E'\nFAIL ATK-18 CLIENT A selected clients.notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS ATK-18 CLIENT A reading clients.notes blocked [permission denied]';
  when others then
    res := res || E'\nPASS ATK-18 CLIENT A reading clients.notes blocked [' || sqlerrm || ']';
  end;
  begin
    perform admin_notes from public.service_requests where id = sr_a;
    res := res || E'\nFAIL ATK-18 CLIENT A selected service_requests.admin_notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS ATK-18 CLIENT A reading service_requests.admin_notes blocked [permission denied]';
  when others then
    res := res || E'\nPASS ATK-18 CLIENT A reading service_requests.admin_notes blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 19: Anonymous user attempting authenticated business operations ============
  perform pg_temp.act('anon', null);
  begin
    perform count(*) from public.clients;
    res := res || E'\nFAIL ATK-19 anon selected clients';
  exception when others then
    res := res || E'\nPASS ATK-19 anon selecting clients blocked [' || sqlerrm || ']';
  end;
  begin
    perform count(*) from public.service_requests;
    res := res || E'\nFAIL ATK-19 anon selected service_requests';
  exception when others then
    res := res || E'\nPASS ATK-19 anon selecting service_requests blocked [' || sqlerrm || ']';
  end;
  begin
    perform public.client_accept_quotation_revision(rev_a, true, 'anon accept');
    res := res || E'\nFAIL ATK-19 anon executed client RPC';
  exception when others then
    res := res || E'\nPASS ATK-19 anon executing client RPC blocked [' || sqlerrm || ']';
  end;
  begin
    perform public.admin_create_quotation(sr_a);
    res := res || E'\nFAIL ATK-19 anon executed admin RPC';
  exception when others then
    res := res || E'\nPASS ATK-19 anon executing admin RPC blocked [' || sqlerrm || ']';
  end;

  -- ============ ATTACK 20: Invalid IDs / UUIDs / ownership references ============
  perform pg_temp.act('authenticated', u_admin);
  begin
    perform public.admin_create_quotation(fake_uuid);
    res := res || E'\nFAIL ATK-20 non-existent service_request_id accepted';
  exception when others then
    res := res || E'\nPASS ATK-20 non-existent service_request_id rejected [' || sqlerrm || ']';
  end;
  begin
    perform public.admin_create_service_job(fake_uuid);
    res := res || E'\nFAIL ATK-20 non-existent revision_id accepted';
  exception when others then
    res := res || E'\nPASS ATK-20 non-existent revision_id rejected [' || sqlerrm || ']';
  end;
  begin
    perform public.admin_link_service_request(sr_a, c_a, fake_uuid);
    res := res || E'\nFAIL ATK-20 non-existent vehicle_id accepted';
  exception when others then
    res := res || E'\nPASS ATK-20 non-existent vehicle_id rejected [' || sqlerrm || ']';
  end;
  begin
    perform public.admin_add_additional_work(fake_uuid, 'Fake Work', 1, 100);
    res := res || E'\nFAIL ATK-20 non-existent service_job_id accepted';
  exception when others then
    res := res || E'\nPASS ATK-20 non-existent service_job_id rejected [' || sqlerrm || ']';
  end;
  end;

  -- ============================================================
  -- SUITE 4: BUSINESS INVARIANTS (13 CHECKS)
  -- ============================================================
  declare
    z constant uuid := '00000000-0000-0000-0000-000000000000';
  u_admin uuid := gen_random_uuid();
  u_a uuid := gen_random_uuid();
  u_b uuid := gen_random_uuid();
  c_a uuid; c_b uuid; v_a uuid; v_b uuid;
  sr1 uuid; p1 uuid; q1 uuid; rev1 uuid; it1 uuid; job1 uuid;
  j jsonb; n int; t text; num numeric;
  begin
    -- Setup
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (u_admin, z, 'authenticated', 'authenticated', 'inv-admin@autotricks.test', now(), now()),
    (u_a, z, 'authenticated', 'authenticated', 'inv-client-a@autotricks.test', now(), now()),
    (u_b, z, 'authenticated', 'authenticated', 'inv-client-b@autotricks.test', now(), now());

  insert into public.profiles (id, role, full_name) values (u_admin, 'ADMIN', 'Inv Admin');

  perform pg_temp.act('authenticated', u_admin);
  insert into public.clients (full_name, phone, notes) values ('Client Inv A', '9000000001', 'Private Note A') returning id into c_a;
  insert into public.clients (full_name, phone, notes) values ('Client Inv B', '9000000002', 'Private Note B') returning id into c_b;

  insert into public.vehicles (client_id, make, model, chassis_number, registration_number)
    values (c_a, 'Skoda', 'Slavia', 'TMB11111111111111', 'DL01AA0001') returning id into v_a;
  insert into public.vehicles (client_id, make, model, chassis_number, registration_number)
    values (c_b, 'Volkswagen', 'Virtus', 'WVW22222222222222', 'DL01BB0002') returning id into v_b;

  insert into public.products (name, category, default_price) values ('Synthetic Brake Fluid', 'FLUIDS', 350.00) returning id into p1;

  perform pg_temp.act('service_role', null);
  insert into public.profiles (id, role, client_id, full_name) values
    (u_a, 'CLIENT', c_a, 'Inv Client A'),
    (u_b, 'CLIENT', c_b, 'Inv Client B');

  -- INVARIANT 1: vehicle belongs to client (FK client_id not null restrict)
  begin
    insert into public.vehicles (client_id, make, model) values (null, 'Make', 'Model');
    res := res || E'\nFAIL INV-1 vehicle without client allowed';
  exception when others then
    res := res || E'\nPASS INV-1 vehicle requires valid client_id [' || sqlerrm || ']';
  end;

  -- INVARIANT 2: request.vehicle_id belongs to request.client_id
  insert into public.service_requests (source, original_submission)
    values ('WEBSITE', jsonb_build_object('customer_name', 'Inv Client A')) returning id into sr1;
  perform pg_temp.act('authenticated', u_admin);
  perform public.admin_link_service_request(sr1, c_a, v_a);
  perform pg_temp.act('postgres', null);
  update public.service_requests set admin_notes = 'Top Secret SR Notes' where id = sr1;
  perform pg_temp.act('authenticated', u_admin);
  begin
    update public.service_requests set vehicle_id = v_b where id = sr1;
    res := res || E'\nFAIL INV-2 service request with mismatched vehicle allowed';
  exception when others then
    res := res || E'\nPASS INV-2 service request vehicle must belong to request client [' || sqlerrm || ']';
  end;

  -- INVARIANT 10: one request cannot have multiple quotation identities
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_create_quotation(sr1);
  q1 := (j->>'quotation_id')::uuid;
  rev1 := (j->>'revision_id')::uuid;
  begin
    insert into public.quotations (service_request_id, created_by) values (sr1, u_admin);
    res := res || E'\nFAIL INV-10 duplicate quotation identity allowed';
  exception when others then
    res := res || E'\nPASS INV-10 one quotation identity per service request [' || sqlerrm || ']';
  end;

  -- INVARIANT 5: revision numbers cannot duplicate
  begin
    insert into public.quotation_revisions (quotation_id, revision_number, created_by) values (q1, 1, u_admin);
    res := res || E'\nFAIL INV-5 duplicate revision number allowed';
  exception when others then
    res := res || E'\nPASS INV-5 revision numbers unique per quotation [' || sqlerrm || ']';
  end;

  -- Add item & send quotation
  insert into public.quotation_items (quotation_revision_id, catalogue_product_id, quantity) values (rev1, p1, 2) returning id into it1;
  j := public.admin_send_quotation_revision(rev1);

  -- INVARIANT 4: accepted revision cannot be silently changed
  perform pg_temp.act('authenticated', u_a);
  j := public.client_accept_quotation_revision(rev1, true, 'Acceptance consent text for invariant testing.');
  perform pg_temp.act('authenticated', u_admin);
  begin
    update public.quotation_revisions set subtotal = 9999 where id = rev1;
    res := res || E'\nFAIL INV-4 accepted revision silently modified';
  exception when others then
    res := res || E'\nPASS INV-4 accepted revision cannot be modified [' || sqlerrm || ']';
  end;

  -- Client signs revision
  perform pg_temp.act('authenticated', u_a);
  insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('signatures', c_a::text || '/' || rev1::text || '/inv-sig.png', u_a::text, '{"mimetype":"image/png"}');
  j := public.client_sign_quotation_revision(rev1, c_a::text || '/' || rev1::text || '/inv-sig.png');

  -- INVARIANT 3: signed quotation cannot be modified
  perform pg_temp.act('authenticated', u_admin);
  begin
    update public.quotation_revisions set notes = 'post-sign' where id = rev1;
    res := res || E'\nFAIL INV-3 signed revision modified';
  exception when others then
    res := res || E'\nPASS INV-3 signed quotation revisions are immutable [' || sqlerrm || ']';
  end;
  begin
    update public.quotation_items set quantity = 5 where id = it1;
    res := res || E'\nFAIL INV-3 signed quotation item modified';
  exception when others then
    res := res || E'\nPASS INV-3 signed quotation items are immutable [' || sqlerrm || ']';
  end;

  -- Convert to job
  j := public.admin_create_service_job(rev1);
  job1 := (j->>'service_job_id')::uuid;

  -- INVARIANT 9: one request cannot have multiple jobs
  begin
    insert into public.service_jobs (service_request_id, quotation_revision_id, vehicle_id)
      values (sr1, rev1, v_a);
    res := res || E'\nFAIL INV-9 duplicate job for service request allowed';
  exception when others then
    res := res || E'\nPASS INV-9 one service job per service request [' || sqlerrm || ']';
  end;

  -- INVARIANT 11: additional work cannot have quotation_item_id
  begin
    insert into public.service_work_items
      (service_job_id, quotation_item_id, name, quantity, source, approval_status, final_value)
    values
      (job1, it1, 'Bad Additional Work', 1, 'ADDITIONAL', 'PENDING', 200.00);
    res := res || E'\nFAIL INV-11 additional work with quotation_item_id allowed';
  exception when others then
    res := res || E'\nPASS INV-11 additional work cannot have quotation_item_id [' || sqlerrm || ']';
  end;

  -- INVARIANT 12: quotation work cannot require additional-work approval
  begin
    insert into public.service_work_items
      (service_job_id, quotation_item_id, name, quantity, source, approval_status, final_value)
    values
      (job1, it1, 'Bad Quotation Work', 1, 'QUOTATION', 'PENDING', 200.00);
    res := res || E'\nFAIL INV-12 quotation work requiring approval allowed';
  exception when others then
    res := res || E'\nPASS INV-12 quotation work approval_status must be NOT_REQUIRED [' || sqlerrm || ']';
  end;

  -- INVARIANT 13: CLIENT cannot access products
  perform pg_temp.act('authenticated', u_a);
  select count(*) into n from public.products;
  res := res || pg_temp.chk(n = 0, 'INV-13 CLIENT cannot access catalogue products (0 rows)');

  -- INVARIANT 14: Admin-only notes remain protected
  begin
    perform notes from public.clients where id = c_a;
    res := res || E'\nFAIL INV-14 CLIENT read clients.notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS INV-14 clients.notes column protected [permission denied]';
  when others then
    res := res || E'\nPASS INV-14 clients.notes column protected [' || sqlerrm || ']';
  end;
  begin
    perform admin_notes from public.service_requests where id = sr1;
    res := res || E'\nFAIL INV-14 CLIENT read service_requests.admin_notes';
  exception when insufficient_privilege then
    res := res || E'\nPASS INV-14 service_requests.admin_notes column protected [permission denied]';
  when others then
    res := res || E'\nPASS INV-14 service_requests.admin_notes column protected [' || sqlerrm || ']';
  end;
  end;

  -- ============================================================
  -- SUITE 5: 21-STEP E2E WORKFLOW (20 CHECKS)
  -- ============================================================
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
  end;

  -- ============================================================
  -- MASTER REPORT & ROLLBACK
  -- ============================================================
  select count(*) into n_pass from regexp_split_to_table(res, E'\n') l where l like 'PASS%';
  select count(*) into n_fail from regexp_split_to_table(res, E'\n') l where l like 'FAIL%';
  n_run := n_pass + n_fail;

  perform pg_temp.act('postgres', null);
  raise exception 'MASTER TEST SUITE REPORT (rolled back)
TESTS RUN: %
TESTS PASSED: %
TESTS FAILED: %
%', n_run, n_pass, n_fail, regexp_replace(res, ' \[[^]]*\]', '', 'g');
end
$;
