-- AutoTricks Phase 3.1: Notification Hardening, Push Idempotency, and Retention

-- 1. Push notification delivery tracking table for idempotency
create table if not exists public.notification_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  device_token_id uuid not null references public.device_tokens(id) on delete cascade,
  status text not null check (status in ('PENDING', 'SENT', 'FAILED')),
  attempt_count integer not null default 1,
  sent_at timestamptz,
  last_attempt_at timestamptz not null default now(),
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_notification_device_delivery unique (notification_id, device_token_id)
);

create index if not exists idx_push_deliveries_notif_token 
  on public.notification_push_deliveries (notification_id, device_token_id);

create index if not exists idx_push_deliveries_status 
  on public.notification_push_deliveries (status);

drop trigger if exists notification_push_deliveries_updated_at on public.notification_push_deliveries;
create trigger notification_push_deliveries_updated_at
  before update on public.notification_push_deliveries
  for each row execute function public.set_updated_at();

alter table public.notification_push_deliveries enable row level security;
grant all on public.notification_push_deliveries to service_role;
grant select on public.notification_push_deliveries to authenticated;

drop policy if exists notification_push_deliveries_select_own on public.notification_push_deliveries;
create policy notification_push_deliveries_select_own
  on public.notification_push_deliveries for select to authenticated
  using (
    exists (
      select 1 from public.notifications n
      where n.id = notification_push_deliveries.notification_id
        and n.profile_id = (select auth.uid())
    )
  );

-- 2. Notification 90-Day Retention Cleanup Function & Schedule
create or replace function private.cleanup_old_notifications()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.notifications
  where created_at < (now() - interval '90 days');
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

-- Schedule daily cleanup at 02:00 UTC using pg_cron
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('daily-notifications-cleanup')
    where exists (select 1 from cron.job where jobname = 'daily-notifications-cleanup');
    
    perform cron.schedule(
      'daily-notifications-cleanup',
      '0 2 * * *',
      'select private.cleanup_old_notifications()'
    );
  end if;
end;
$$;

-- 3. Comprehensive Row Change Notification Trigger Function
-- Completes missing events: QUOTATION_ACCEPTED, QUOTATION_REJECTED, QUOTATION_CHANGE_RESPONDED
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
        elsif new.status = 'ACCEPTED' then
          perform private.notify_admins('QUOTATION_ACCEPTED',
            'Quotation revision ' || new.revision_number::text || ' accepted',
            'Quotation revision ' || new.revision_number::text || ' was accepted by the client and is awaiting signature.',
            'quotation_revision', new.id);
        elsif new.status = 'REJECTED' then
          perform private.notify_admins('QUOTATION_REJECTED',
            'Quotation revision ' || new.revision_number::text || ' rejected',
            coalesce(nullif(new.rejection_reason, ''), 'Quotation revision ' || new.revision_number::text || ' was rejected by the client.'),
            'quotation_revision', new.id);
        end if;
      end if;

    when 'quotation_change_requests' then
      if tg_op = 'INSERT' then
        perform private.notify_admins('QUOTATION_CHANGE_REQUESTED',
          'Client requested quotation changes', left(new.message, 500),
          'quotation_change_request', new.id);
      elsif new.status is distinct from old.status then
        if new.profile_id is not null then
          perform private.notify_profile(new.profile_id, 'QUOTATION_CHANGE_RESPONDED',
            'Your quotation change request was reviewed',
            'Status: ' || new.status::text || coalesce('. ' || new.admin_response, ''),
            'quotation_change_request', new.id);
        else
          perform private.notify_client(new.client_id, 'QUOTATION_CHANGE_RESPONDED',
            'Your quotation change request was reviewed',
            'Status: ' || new.status::text || coalesce('. ' || new.admin_response, ''),
            'quotation_change_request', new.id);
        end if;
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
