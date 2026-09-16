-- AutoTricks Day 3 Final Hardening: Service Request Linking Invariant
-- 1. admin_link_service_request: Initial linking permitted ONLY when status = 'NEW' and request is unlinked.
--    Re-linking already linked or non-NEW requests is strictly rejected.
-- 2. validate_service_request_links trigger: Rejects direct table UPDATEs that attempt to alter client_id
--    or vehicle_id on an already-linked request or request moved beyond NEW status.

create or replace function public.admin_link_service_request(
  p_service_request_id uuid,
  p_client_id uuid,
  p_vehicle_id uuid
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_sr public.service_requests;
begin
  select * into v_sr from public.service_requests where id = p_service_request_id for update;
  if not found then
    raise exception 'Service request not found' using errcode = 'P0002';
  end if;

  -- Strictly allow initial linking ONLY when status is NEW
  if v_sr.status <> 'NEW' then
    raise exception 'Service request can only be linked while in NEW status (current status: %)', v_sr.status;
  end if;

  -- Do not overwrite client_id or vehicle_id if already linked
  if v_sr.client_id is not null or v_sr.vehicle_id is not null then
    raise exception 'Service request is already linked to a client and vehicle';
  end if;

  if p_client_id is null or p_vehicle_id is null then
    raise exception 'Service request linking requires both a client and a vehicle';
  end if;

  if not exists (
    select 1 from public.vehicles v
    where v.id = p_vehicle_id and v.client_id = p_client_id
  ) then
    raise exception 'Vehicle does not belong to the specified client';
  end if;

  update public.service_requests
  set client_id = p_client_id,
      vehicle_id = p_vehicle_id,
      status = 'UNDER_REVIEW'
  where id = p_service_request_id
  returning * into v_sr;

  return jsonb_build_object(
    'service_request_id', v_sr.id,
    'client_id', v_sr.client_id,
    'vehicle_id', v_sr.vehicle_id,
    'status', v_sr.status
  );
end;
$$;

create or replace function public.validate_service_request_links()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.vehicle_id is not null and new.client_id is null then
    raise exception 'A service request vehicle requires a client';
  end if;

  if new.vehicle_id is not null and not exists (
    select 1 from public.vehicles v
    where v.id = new.vehicle_id and v.client_id = new.client_id
  ) then
    raise exception 'Service request vehicle must belong to the selected client';
  end if;

  if tg_op = 'INSERT' then
    if (select auth.uid()) is not null
       and (new.source <> 'PHONE' or new.created_by is distinct from (select auth.uid())) then
      raise exception 'Staff-entered service requests must be PHONE requests created by the current user';
    end if;
    return new;
  end if;

  if new.request_number is distinct from old.request_number
     or new.source is distinct from old.source
     or new.original_submission is distinct from old.original_submission
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Service request origin data is immutable';
  end if;

  -- Once linked, client and vehicle cannot be changed or overwritten
  if (old.client_id is not null and (new.client_id is distinct from old.client_id or new.vehicle_id is distinct from old.vehicle_id))
     or (old.status <> 'NEW' and (new.client_id is distinct from old.client_id or new.vehicle_id is distinct from old.vehicle_id)) then
    raise exception 'Client and vehicle cannot be changed once a service request is linked or moved beyond NEW status';
  end if;

  if (new.client_id is distinct from old.client_id or new.vehicle_id is distinct from old.vehicle_id)
     and exists (select 1 from public.quotations q where q.service_request_id = old.id) then
    raise exception 'Client and vehicle cannot change once a quotation exists for this service request';
  end if;

  return new;
end;
$$;

revoke all on function public.admin_link_service_request(uuid, uuid, uuid) from public, anon;
grant execute on function public.admin_link_service_request(uuid, uuid, uuid) to authenticated;
