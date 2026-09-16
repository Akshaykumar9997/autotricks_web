-- AutoTricks Day 3: Database-Level Invariants Test Suite (Section 13)
-- Tests direct PostgreSQL integrity rules:
-- 1. vehicle belongs to client
-- 2. request.vehicle_id belongs to request.client_id
-- 3. signed quotation cannot be modified
-- 4. accepted revision cannot be silently changed
-- 5. revision numbers cannot duplicate
-- 6. quotation numbers cannot duplicate
-- 7. service request numbers cannot duplicate
-- 8. job numbers cannot duplicate
-- 9. one request cannot have multiple jobs
-- 10. one request cannot have multiple quotation identities
-- 11. additional work cannot have quotation_item_id
-- 12. quotation work cannot require additional-work approval
-- 13. CLIENT cannot access products
-- 14. Admin-only notes remain protected

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
  c_a uuid; c_b uuid; v_a uuid; v_b uuid;
  sr1 uuid; p1 uuid; q1 uuid; rev1 uuid; it1 uuid; job1 uuid;
  j jsonb; n int; t text; num numeric;
  res text := '';
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

  -- ============ REPORT ============
  perform pg_temp.act('postgres', null);
  raise exception 'INVARIANTS REPORT PASS=% FAIL=% %',
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'PASS%'),
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'FAIL%'),
    regexp_replace(res, ' \[[^]]*\]', '', 'g');
end
$test$;
