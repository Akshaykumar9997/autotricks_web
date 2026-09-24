-- AutoTricks Day 12: Service Job & Live Progress Workflow Hardening
-- 1. Create service_job_status_history table with strict RLS and immutability.
-- 2. Update private.guard_service_job() to enforce strictly sequential status transitions:
--    SCHEDULED -> VEHICLE_RECEIVED -> INSPECTION -> WORK_IN_PROGRESS -> QUALITY_CHECK -> READY_FOR_DELIVERY -> COMPLETED
--    (with CANCELLED allowed from any active status; no backwards transitions or arbitrary jumps).
-- 3. Update admin_create_service_job() to record initial history and strictly require revision status = 'ACCEPTED'.
-- 4. Update admin_update_service_job_status() to record status history and accept optional note.
-- 5. Update notification trigger with humanized client copy.
-- 6. Add service_jobs and service_job_status_history to supabase_realtime.

-- ============================================================
-- 1. STATUS HISTORY TABLE & RLS
-- ============================================================

create table if not exists public.service_job_status_history (
  id uuid primary key default gen_random_uuid(),
  service_job_id uuid not null references public.service_jobs(id) on delete cascade,
  from_status public.service_job_status,
  to_status public.service_job_status not null,
  changed_by_profile_id uuid references public.profiles(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_service_job_status_history_job_id
  on public.service_job_status_history(service_job_id);

create index if not exists idx_service_job_status_history_created_at
  on public.service_job_status_history(created_at);

alter table public.service_job_status_history enable row level security;

-- Client can view history for their own service jobs; Admin can view all
drop policy if exists service_job_status_history_select_admin_or_own on public.service_job_status_history;
create policy service_job_status_history_select_admin_or_own
on public.service_job_status_history for select to authenticated
using (
  (select private.is_admin())
  or
  exists (
    select 1
    from public.service_jobs sj
    join public.service_requests sr on sr.id = sj.service_request_id
    where sj.id = service_job_status_history.service_job_id
      and sr.client_id = (select private.current_client_id())
  )
);

-- Only Admin can insert status history directly (also inserted by security definer RPCs)
drop policy if exists service_job_status_history_insert_admin on public.service_job_status_history;
create policy service_job_status_history_insert_admin
on public.service_job_status_history for insert to authenticated
with check ((select private.is_admin()));

-- Status history is strictly immutable: NO UPDATE or DELETE policies

grant select on public.service_job_status_history to authenticated;

-- ============================================================
-- 2. INTEGRITY GUARD: STRICT SEQUENTIAL STATUS TRANSITIONS
-- ============================================================

create or replace function private.guard_service_job()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  v_sr record;
begin
  if tg_op = 'DELETE' then
    raise exception 'Service jobs cannot be deleted; cancel them instead';
  end if;

  if tg_op = 'INSERT' then
    select s.client_id, s.vehicle_id into v_sr
    from public.service_requests s where s.id = new.service_request_id;

    if v_sr.client_id is null or v_sr.vehicle_id is null then
      raise exception 'Service request must be linked to a client and vehicle before a job is created';
    end if;
    if new.vehicle_id is distinct from v_sr.vehicle_id or not exists (
      select 1 from public.vehicles v where v.id = new.vehicle_id and v.client_id = v_sr.client_id
    ) then
      raise exception 'Service job vehicle must be the service request vehicle of the same client';
    end if;
    if not exists (
      select 1 from public.quotation_revisions qr
      join public.quotations q on q.id = qr.quotation_id
      where qr.id = new.quotation_revision_id and q.service_request_id = new.service_request_id
    ) then
      raise exception 'Quotation revision does not belong to this service request';
    end if;
    if not exists (
      select 1 from public.quotation_signatures qs
      where qs.quotation_revision_id = new.quotation_revision_id
    ) then
      raise exception 'A service job requires an accepted and signed quotation revision';
    end if;
    if new.status <> 'SCHEDULED' then
      raise exception 'New service jobs must start as SCHEDULED';
    end if;
    new.started_at := null;
    new.completed_at := null;
    return new;
  end if;

  if (new.job_number, new.service_request_id, new.quotation_revision_id, new.vehicle_id, new.created_at)
     is distinct from (old.job_number, old.service_request_id, old.quotation_revision_id, old.vehicle_id, old.created_at) then
    raise exception 'Service job identity is immutable';
  end if;

  if new.status is distinct from old.status then
    -- Verify strictly valid transitions:
    -- SCHEDULED -> VEHICLE_RECEIVED -> INSPECTION -> WORK_IN_PROGRESS -> QUALITY_CHECK -> READY_FOR_DELIVERY -> COMPLETED
    -- CANCELLED is allowed from any non-closed status
    if old.status in ('COMPLETED', 'CANCELLED') then
      raise exception 'Closed service jobs cannot be modified';
    elsif old.status = 'SCHEDULED' and new.status not in ('VEHICLE_RECEIVED', 'CANCELLED') then
      raise exception 'Invalid service job status transition from % to %', old.status, new.status;
    elsif old.status = 'VEHICLE_RECEIVED' and new.status not in ('INSPECTION', 'CANCELLED') then
      raise exception 'Invalid service job status transition from % to %', old.status, new.status;
    elsif old.status = 'INSPECTION' and new.status not in ('WORK_IN_PROGRESS', 'CANCELLED') then
      raise exception 'Invalid service job status transition from % to %', old.status, new.status;
    elsif old.status = 'WORK_IN_PROGRESS' and new.status not in ('QUALITY_CHECK', 'CANCELLED') then
      raise exception 'Invalid service job status transition from % to %', old.status, new.status;
    elsif old.status = 'QUALITY_CHECK' and new.status not in ('READY_FOR_DELIVERY', 'CANCELLED') then
      raise exception 'Invalid service job status transition from % to %', old.status, new.status;
    elsif old.status = 'READY_FOR_DELIVERY' and new.status not in ('COMPLETED', 'CANCELLED') then
      raise exception 'Invalid service job status transition from % to %', old.status, new.status;
    end if;

    if new.status = 'COMPLETED' and exists (
      select 1 from public.service_work_items w
      where w.service_job_id = new.id and w.status not in ('COMPLETED', 'CANCELLED')
    ) then
      raise exception 'All work items must be COMPLETED or CANCELLED before the job can be completed';
    end if;

    if old.status = 'SCHEDULED' and new.status <> 'CANCELLED' and old.started_at is null then
      new.started_at := now();
    end if;
    if new.status = 'COMPLETED' then
      new.completed_at := now();
    end if;
  elsif old.status in ('COMPLETED', 'CANCELLED') then
    raise exception 'Closed service jobs cannot be modified';
  elsif (new.started_at, new.completed_at) is distinct from (old.started_at, old.completed_at) then
    raise exception 'Job start/completion times are set by status changes';
  end if;

  return new;
end;
$$;

-- ============================================================
-- 3. ADMIN CREATE SERVICE JOB (ACCEPTED CHECK + HISTORY RECORD)
-- ============================================================

create or replace function public.admin_create_service_job(
  p_quotation_revision_id uuid,
  p_scheduled_at timestamptz default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_ctx record;
  v_job public.service_jobs;
  v_items integer;
begin
  select qr.id as revision_id, qr.status as revision_status, sr.id as service_request_id, sr.status as sr_status, sr.vehicle_id
  into v_ctx
  from public.quotation_revisions qr
  join public.quotations q on q.id = qr.quotation_id
  join public.service_requests sr on sr.id = q.service_request_id
  where qr.id = p_quotation_revision_id
  for update of sr;

  if not found then
    raise exception 'Quotation revision not found' using errcode = 'P0002';
  end if;
  if v_ctx.sr_status = 'CANCELLED' then
    raise exception 'Cannot create a service job for a cancelled service request';
  end if;
  if v_ctx.revision_status <> 'ACCEPTED' then
    raise exception 'Only accepted quotation revisions can be converted to a service job (current status: %)', v_ctx.revision_status;
  end if;
  if not exists (
    select 1 from public.quotation_signatures where quotation_revision_id = p_quotation_revision_id
  ) then
    raise exception 'The quotation revision must be accepted and signed before creating a service job';
  end if;
  if exists (select 1 from public.service_jobs where service_request_id = v_ctx.service_request_id) then
    raise exception 'A service job already exists for this service request';
  end if;

  insert into public.service_jobs (service_request_id, quotation_revision_id, vehicle_id, scheduled_at)
  values (v_ctx.service_request_id, p_quotation_revision_id, v_ctx.vehicle_id, p_scheduled_at)
  returning * into v_job;

  insert into public.service_work_items
    (service_job_id, quotation_item_id, name, description, quantity, source, approval_status, approximate_value, final_value)
  select v_job.id, i.id, i.name, i.description, i.quantity, 'QUOTATION', 'NOT_REQUIRED', i.approximate_value, i.final_value
  from public.quotation_items i
  where i.quotation_revision_id = p_quotation_revision_id
  order by i.created_at;
  get diagnostics v_items = row_count;

  -- Record initial SCHEDULED status in history
  insert into public.service_job_status_history (
    service_job_id,
    from_status,
    to_status,
    changed_by_profile_id,
    note
  ) values (
    v_job.id,
    null,
    'SCHEDULED',
    v_admin,
    'Service job created and scheduled'
  );

  update public.service_requests set status = 'CONVERTED_TO_JOB' where id = v_ctx.service_request_id;

  return jsonb_build_object(
    'service_job_id', v_job.id,
    'job_number', v_job.job_number,
    'work_items_created', v_items
  );
end;
$$;

-- ============================================================
-- 4. ADMIN UPDATE SERVICE JOB STATUS (WITH NOTE & HISTORY)
-- ============================================================

-- Drop legacy 2-argument signature to prevent PostgREST PGRST203 ambiguity
drop function if exists public.admin_update_service_job_status(uuid, public.service_job_status);

create or replace function public.admin_update_service_job_status(
  p_service_job_id uuid,
  p_status public.service_job_status,
  p_note text default null
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_job public.service_jobs;
  v_old_status public.service_job_status;
begin
  select status into v_old_status from public.service_jobs where id = p_service_job_id for update;
  if not found then
    raise exception 'Service job not found' using errcode = 'P0002';
  end if;

  update public.service_jobs set status = p_status
  where id = p_service_job_id
  returning * into v_job;

  insert into public.service_job_status_history (
    service_job_id,
    from_status,
    to_status,
    changed_by_profile_id,
    note
  ) values (
    v_job.id,
    v_old_status,
    p_status,
    v_admin,
    p_note
  );

  return jsonb_build_object(
    'service_job_id', v_job.id,
    'job_number', v_job.job_number,
    'status', v_job.status,
    'started_at', v_job.started_at,
    'completed_at', v_job.completed_at
  );
end;
$$;

revoke all on function public.admin_update_service_job_status(uuid, public.service_job_status, text) from public, anon;
grant execute on function public.admin_update_service_job_status(uuid, public.service_job_status, text) to authenticated;

-- ============================================================
-- 5. NOTIFICATION COPY REFINEMENT
-- ============================================================

create or replace function private.notify_row_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  case tg_table_name
    when 'service_requests' then
      if tg_op = 'INSERT' then
        perform private.notify_admins('NEW_SERVICE_REQUEST',
          'New service request: ' || new.request_number,
          coalesce(new.original_submission->>'description', 'New service request submitted.'),
          'service_request', new.id);
      end if;

    when 'quotation_revisions' then
      if tg_op = 'UPDATE' and old.status is distinct from new.status then
        if new.status = 'SENT' then
          if new.revision_number = 1 then
            perform private.notify_client(private.revision_client_id(new.id), 'QUOTATION_SENT',
              'Quotation ready for review', 'Quotation revision 1 is ready for your review.',
              'quotation_revision', new.id);
          else
            perform private.notify_client(private.revision_client_id(new.id), 'QUOTATION_REVISED',
              'Quotation revised', 'Quotation revision ' || new.revision_number::text || ' is ready for your review.',
              'quotation_revision', new.id);
          end if;
        end if;
      end if;

    when 'quotation_change_requests' then
      if tg_op = 'INSERT' then
        perform private.notify_admins('QUOTATION_CHANGE_REQUESTED',
          'Client requested quotation changes', left(new.message, 500),
          'quotation_change_request', new.id);
      end if;

    when 'quotation_signatures' then
      if tg_op = 'INSERT' then
        perform private.notify_admins('QUOTATION_SIGNED',
          'Quotation signed by client',
          'The client signed the accepted quotation. A service job can now be created.',
          'quotation_revision', new.quotation_revision_id);
      end if;

    when 'service_jobs' then
      if tg_op = 'INSERT' then
        perform private.notify_client(private.service_job_client_id(new.id), 'SERVICE_STATUS_UPDATED',
          'Service job ' || new.job_number || ' scheduled', 'Your service has been scheduled.',
          'service_job', new.id);
      elsif new.status is distinct from old.status then
        if new.status = 'COMPLETED' then
          perform private.notify_client(private.service_job_client_id(new.id), 'SERVICE_JOB_COMPLETED',
            'Service job ' || new.job_number || ' completed', 'Your service has been completed.',
            'service_job', new.id);
        else
          perform private.notify_client(private.service_job_client_id(new.id), 'SERVICE_STATUS_UPDATED',
            'Service job ' || new.job_number || ' updated',
            case new.status
              when 'VEHICLE_RECEIVED' then 'Your vehicle has been received.'
              when 'INSPECTION' then 'Your vehicle is currently under inspection.'
              when 'WORK_IN_PROGRESS' then 'Work has started on your vehicle.'
              when 'QUALITY_CHECK' then 'Your vehicle is undergoing quality checks.'
              when 'READY_FOR_DELIVERY' then 'Your vehicle is ready for delivery.'
              when 'CANCELLED' then 'Your service job has been cancelled.'
              else 'Status: ' || replace(new.status::text, '_', ' ')
            end,
            'service_job', new.id);
        end if;
      end if;

    when 'service_work_items' then
      if tg_op = 'INSERT' and new.source = 'ADDITIONAL' then
        perform private.notify_client(private.service_job_client_id(new.service_job_id), 'ADDITIONAL_WORK_REQUESTED',
          'Additional work needs your approval',
          new.name || ': Rs. ' || to_char(new.final_value, 'FM999999990.00') || ' per unit x ' || new.quantity::text,
          'service_work_item', new.id);
      elsif tg_op = 'UPDATE' and new.approval_status is distinct from old.approval_status then
        perform private.notify_admins(
          (case when new.approval_status = 'APPROVED' then 'ADDITIONAL_WORK_APPROVED' else 'ADDITIONAL_WORK_REJECTED' end)::public.notification_type,
          'Additional work ' || lower(new.approval_status::text),
          new.name || coalesce(' (note: ' || new.approval_note || ')', ''),
          'service_work_item', new.id);
      end if;

    when 'vehicle_correction_requests' then
      if tg_op = 'INSERT' then
        perform private.notify_admins('VEHICLE_CORRECTION_REQUESTED',
          'Vehicle correction requested', left(new.message, 500),
          'vehicle_correction_request', new.id);
      elsif new.status is distinct from old.status then
        perform private.notify_profile(new.profile_id, 'VEHICLE_CORRECTION_RESPONDED',
          'Your vehicle correction request was reviewed',
          'Status: ' || new.status::text || coalesce('. ' || new.admin_response, ''),
          'vehicle_correction_request', new.id);
      end if;

    else
      null;
  end case;

  return null;
end;
$$;

-- ============================================================
-- 6. REALTIME PUBLICATION
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'service_jobs'
  ) then
    alter publication supabase_realtime add table public.service_jobs;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'service_job_status_history'
  ) then
    alter publication supabase_realtime add table public.service_job_status_history;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'service_work_items'
  ) then
    alter publication supabase_realtime add table public.service_work_items;
  end if;
end;
$$;
