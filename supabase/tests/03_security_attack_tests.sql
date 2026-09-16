-- AutoTricks Day 3: Mandatory Security Attack Test Suite
-- Tests all 20 attack vectors specified in Day 3 Section 12:
-- 1. CLIENT A reading Client B data
-- 2. CLIENT A modifying Client B data
-- 3. CLIENT A reading Client B quotation
-- 4. CLIENT A modifying quotation prices
-- 5. CLIENT A modifying quotation totals
-- 6. CLIENT A accepting Client B quotation
-- 7. CLIENT A signing Client B quotation
-- 8. CLIENT A approving Client B additional work
-- 9. CLIENT A changing service request status
-- 10. CLIENT A changing job status
-- 11. CLIENT A inserting fake audit logs
-- 12. CLIENT A modifying audit logs
-- 13. CLIENT A changing vehicle ownership
-- 14. CLIENT A linking another client's vehicle to their request
-- 15. CLIENT A creating a job
-- 16. CLIENT A bypassing workflow RPCs using direct table operations
-- 17. CLIENT A accessing products
-- 18. CLIENT A accessing Admin-only notes
-- 19. Anonymous user attempting authenticated business operations
-- 20. Invalid IDs / UUIDs / ownership references

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
  res text := '';
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

  -- ============ REPORT ============
  perform pg_temp.act('postgres', null);
  raise exception 'SECURITY ATTACK REPORT PASS=% FAIL=% %',
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'PASS%'),
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'FAIL%'),
    regexp_replace(res, ' \[[^]]*\]', '', 'g');
end
$test$;
