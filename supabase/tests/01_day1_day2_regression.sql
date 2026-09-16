-- AutoTricks end-to-end business & security test.
-- Runs every workflow as the real database roles (anon, service_role,
-- authenticated ADMIN / CLIENT A / CLIENT B / signed-in user without profile)
-- by switching role + request.jwt.claims exactly like PostgREST does.
-- Everything happens in one transaction that is rolled back by the final
-- RAISE, whose message is the PASS/FAIL report. Nothing persists
-- (sequence values are consumed; reset them afterwards if needed).

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
  u_x uuid := gen_random_uuid();
  c_a uuid; c_b uuid; v_a uuid; v_b uuid; p1 uuid; p2 uuid;
  sr_web uuid; sr_phone uuid; q1 uuid; rev1 uuid; rev2 uuid; cr1 uuid;
  it_prod uuid; job1 uuid; w_add1 uuid; w_add2 uuid; vcr uuid; doc1 uuid;
  sig_path text; pdf_path text; rpt_path text;
  j jsonb; n int; n2 int; t text; t2 text; qnum text; num numeric; num2 numeric;
  b boolean; ts timestamptz; ts2 timestamptz;
  r record;
  res text := '';
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

  perform pg_temp.act('postgres', null);
  raise exception 'E2E REPORT (rolled back) PASS=% FAIL=% %',
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'PASS%'),
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'FAIL%'),
    regexp_replace(res, ' \[[^]]*\]', '', 'g');
end
$test$;
