-- AutoTricks Day 3 Final Hardening: Service Request Linking Invariant Tests
-- Tests:
-- TEST A: Valid initial linking (NEW -> UNDER_REVIEW with Client A + Vehicle A)
-- TEST B: Re-link existing UNDER_REVIEW request rejected (Client/Vehicle/status unchanged, no audit entry)
-- TEST C: Cross-client vehicle linking rejected (Client B with Vehicle A)
-- TEST D: Re-link on QUOTATION_CREATED request rejected
-- TEST E: Re-link on CANCELLED request rejected
-- TEST F: Re-link on CONVERTED_TO_JOB request rejected
-- TEST G: Direct table UPDATE bypass rejected (trigger protection)
-- TEST H: Re-link on already-linked NEW phone request rejected

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
  sr_a uuid; sr_b uuid; sr_c uuid; sr_phone uuid;
  q1 uuid; rev1 uuid; it1 uuid; job1 uuid;
  sig_path text;
  j jsonb; n_audit_before int; n_audit_after int;
  t text; cid uuid; vid uuid;
  res text := '';
begin
  -- ============ SETUP ============
  insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values
    (u_admin, z, 'authenticated', 'authenticated', 'link-admin@autotricks.test', now(), now()),
    (u_a, z, 'authenticated', 'authenticated', 'link-client-a@autotricks.test', now(), now()),
    (u_b, z, 'authenticated', 'authenticated', 'link-client-b@autotricks.test', now(), now());

  insert into public.profiles (id, role, full_name) values (u_admin, 'ADMIN', 'Link Hardening Admin');

  perform pg_temp.act('authenticated', u_admin);
  insert into public.clients (full_name, phone, email) values ('Client Alpha', '9800000001', 'alpha@test.org') returning id into c_a;
  insert into public.clients (full_name, phone, email) values ('Client Beta', '9800000002', 'beta@test.org') returning id into c_b;

  insert into public.vehicles (client_id, make, model, chassis_number, registration_number)
    values (c_a, 'Hyundai', 'Creta', 'MALC1000000000001', 'KA01AA9001') returning id into v_a;
  insert into public.vehicles (client_id, make, model, chassis_number, registration_number)
    values (c_b, 'Kia', 'Seltos', 'MZBS2000000000002', 'KA02BB9002') returning id into v_b;

  perform pg_temp.act('service_role', null);
  insert into public.profiles (id, role, client_id, full_name) values
    (u_a, 'CLIENT', c_a, 'Client Alpha Profile'),
    (u_b, 'CLIENT', c_b, 'Client Beta Profile');

  -- Create website request sr_a
  insert into public.service_requests (source, original_submission)
    values ('WEBSITE', jsonb_build_object('customer_name', 'Client Alpha', 'phone', '9800000001'))
    returning id into sr_a;

  -- ============ TEST A: Valid initial linking ============
  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_link_service_request(sr_a, c_a, v_a);
  select status::text, client_id, vehicle_id into t, cid, vid from public.service_requests where id = sr_a;
  res := res || pg_temp.chk(t = 'UNDER_REVIEW' and cid = c_a and vid = v_a,
    'TEST A: Valid initial linking moved NEW -> UNDER_REVIEW with Client A + Vehicle A');

  -- ============ TEST B: Re-link existing UNDER_REVIEW request rejected ============
  select count(*) into n_audit_before from public.audit_logs where entity_id = sr_a;
  begin
    perform public.admin_link_service_request(sr_a, c_b, v_b);
    res := res || E'\nFAIL TEST B: Re-linking UNDER_REVIEW request was allowed';
  exception when others then
    select status::text, client_id, vehicle_id into t, cid, vid from public.service_requests where id = sr_a;
    select count(*) into n_audit_after from public.audit_logs where entity_id = sr_a;
    res := res || pg_temp.chk(
      t = 'UNDER_REVIEW' and cid = c_a and vid = v_a and n_audit_before = n_audit_after,
      'TEST B: Re-linking UNDER_REVIEW request rejected; Client/Vehicle/status unchanged and no audit created [' || sqlerrm || ']'
    );
  end;

  -- ============ TEST C: Cross-client vehicle attempt ============
  perform pg_temp.act('service_role', null);
  insert into public.service_requests (source, original_submission)
    values ('WEBSITE', jsonb_build_object('customer_name', 'Client Beta', 'phone', '9800000002'))
    returning id into sr_b;

  perform pg_temp.act('authenticated', u_admin);
  begin
    perform public.admin_link_service_request(sr_b, c_b, v_a); -- v_a belongs to c_a, not c_b
    res := res || E'\nFAIL TEST C: Linking Client B with Client A vehicle was allowed';
  exception when others then
    select status::text, client_id, vehicle_id into t, cid, vid from public.service_requests where id = sr_b;
    res := res || pg_temp.chk(
      t = 'NEW' and cid is null and vid is null,
      'TEST C: Cross-client vehicle linking rejected; request remains NEW/unlinked [' || sqlerrm || ']'
    );
  end;

  -- ============ TEST D: Quotation-created request ============
  j := public.admin_create_quotation(sr_a, 'Hardening test quotation');
  q1 := (j->>'quotation_id')::uuid;
  rev1 := (j->>'revision_id')::uuid;
  select status::text into t from public.service_requests where id = sr_a;
  -- sr_a is now QUOTATION_CREATED
  begin
    perform public.admin_link_service_request(sr_a, c_b, v_b);
    res := res || E'\nFAIL TEST D: Re-linking QUOTATION_CREATED request was allowed';
  exception when others then
    select status::text, client_id into t, cid from public.service_requests where id = sr_a;
    res := res || pg_temp.chk(
      t = 'QUOTATION_CREATED' and cid = c_a,
      'TEST D: Re-linking QUOTATION_CREATED request rejected [' || sqlerrm || ']'
    );
  end;

  -- ============ TEST E: Cancelled request ============
  perform pg_temp.act('service_role', null);
  insert into public.service_requests (source, original_submission)
    values ('WEBSITE', jsonb_build_object('customer_name', 'Client Cancel', 'phone', '9800000003'))
    returning id into sr_c;

  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_cancel_service_request(sr_c, 'Testing cancel rejection');
  select status::text into t from public.service_requests where id = sr_c;

  begin
    perform public.admin_link_service_request(sr_c, c_a, v_a);
    res := res || E'\nFAIL TEST E: Linking CANCELLED request was allowed';
  exception when others then
    select status::text into t from public.service_requests where id = sr_c;
    res := res || pg_temp.chk(
      t = 'CANCELLED',
      'TEST E: Linking CANCELLED request rejected [' || sqlerrm || ']'
    );
  end;

  -- ============ TEST F: Converted-to-job request ============
  -- Progress sr_a through quotation acceptance and signing to job conversion
  insert into public.quotation_items (quotation_revision_id, name, quantity, final_value)
    values (rev1, 'Inspection Labour', 1, 1000.00) returning id into it1;
  j := public.admin_send_quotation_revision(rev1);

  perform pg_temp.act('authenticated', u_a);
  j := public.client_accept_quotation_revision(rev1, true, 'Accepting for link hardening test');
  sig_path := c_a::text || '/' || rev1::text || '/link-sig.png';
  insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('signatures', sig_path, u_a::text, '{"mimetype":"image/png"}');
  j := public.client_sign_quotation_revision(rev1, sig_path);

  perform pg_temp.act('authenticated', u_admin);
  j := public.admin_create_service_job(rev1);
  job1 := (j->>'service_job_id')::uuid;
  select status::text into t from public.service_requests where id = sr_a;
  -- sr_a is now CONVERTED_TO_JOB

  begin
    perform public.admin_link_service_request(sr_a, c_b, v_b);
    res := res || E'\nFAIL TEST F: Linking CONVERTED_TO_JOB request was allowed';
  exception when others then
    select status::text, client_id into t, cid from public.service_requests where id = sr_a;
    res := res || pg_temp.chk(
      t = 'CONVERTED_TO_JOB' and cid = c_a,
      'TEST F: Linking CONVERTED_TO_JOB request rejected [' || sqlerrm || ']'
    );
  end;

  -- ============ TEST G: Direct table UPDATE bypass protection ============
  -- Even via direct table UPDATE, linked request cannot have client/vehicle altered
  begin
    update public.service_requests set client_id = c_b, vehicle_id = v_b where id = sr_a;
    res := res || E'\nFAIL TEST G: Direct UPDATE changing client/vehicle was allowed';
  exception when others then
    select client_id, vehicle_id into cid, vid from public.service_requests where id = sr_a;
    res := res || pg_temp.chk(
      cid = c_a and vid = v_a,
      'TEST G: Direct table UPDATE changing client/vehicle blocked by trigger [' || sqlerrm || ']'
    );
  end;

  -- ============ TEST H: Already-linked NEW phone request ============
  -- Staff-entered PHONE request already linked at creation time
  insert into public.service_requests (client_id, vehicle_id, source, created_by, original_submission)
    values (c_a, v_a, 'PHONE', u_admin, '{"caller":"Alpha"}')
    returning id into sr_phone;

  begin
    perform public.admin_link_service_request(sr_phone, c_b, v_b);
    res := res || E'\nFAIL TEST H: Overwriting already-linked PHONE request was allowed';
  exception when others then
    select status::text, client_id, vehicle_id into t, cid, vid from public.service_requests where id = sr_phone;
    res := res || pg_temp.chk(
      t = 'NEW' and cid = c_a and vid = v_a,
      'TEST H: Overwriting already-linked PHONE request rejected [' || sqlerrm || ']'
    );
  end;

  -- ============ REPORT ============
  perform pg_temp.act('postgres', null);
  raise exception 'LINK HARDENING REPORT PASS=% FAIL=% %',
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'PASS%'),
    (select count(*) from regexp_split_to_table(res, E'\n') l where l like 'FAIL%'),
    regexp_replace(res, ' \[[^]]*\]', '', 'g');
end
$test$;
