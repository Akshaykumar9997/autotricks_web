-- AutoTricks hardening 3/5: audit trail and notifications.
-- Both are written by triggers so every path (Data API, RPC, Edge Function)
-- is covered. Notification/email queueing failures never roll back the
-- business operation.

create or replace function private.write_audit(
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_metadata jsonb
)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.audit_logs (actor_profile_id, action, entity_type, entity_id, metadata)
  values (
    (select p.id from public.profiles p where p.id = (select auth.uid())),
    p_action, p_entity_type, p_entity_id, p_metadata
  );
end;
$$;

create or replace function private.notify_profile(
  p_profile_id uuid,
  p_type public.notification_type,
  p_title text,
  p_message text,
  p_entity_type text,
  p_entity_id uuid
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_email text;
begin
  begin
    insert into public.notifications (profile_id, type, title, message, entity_type, entity_id)
    values (p_profile_id, p_type, p_title, p_message, p_entity_type, p_entity_id);
  exception when others then
    raise warning 'In-app notification failed for profile %: %', p_profile_id, sqlerrm;
  end;

  begin
    select u.email into v_email from auth.users u where u.id = p_profile_id;
    if v_email is not null then
      insert into public.email_notifications
        (profile_id, notification_type, recipient_email, subject, related_entity_type, related_entity_id)
      values (p_profile_id, p_type, v_email, p_title, p_entity_type, p_entity_id);
    end if;
  exception when others then
    raise warning 'Email queueing failed for profile %: %', p_profile_id, sqlerrm;
  end;
end;
$$;

create or replace function private.notify_admins(
  p_type public.notification_type,
  p_title text,
  p_message text,
  p_entity_type text,
  p_entity_id uuid
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
begin
  for r in select p.id from public.profiles p where p.role = 'ADMIN' loop
    perform private.notify_profile(r.id, p_type, p_title, p_message, p_entity_type, p_entity_id);
  end loop;
end;
$$;

create or replace function private.notify_client(
  p_client_id uuid,
  p_type public.notification_type,
  p_title text,
  p_message text,
  p_entity_type text,
  p_entity_id uuid
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select p.id from public.profiles p
    where p.role = 'CLIENT' and p.client_id = p_client_id
  loop
    perform private.notify_profile(r.id, p_type, p_title, p_message, p_entity_type, p_entity_id);
  end loop;
end;
$$;

-- ============================================================
-- AUDIT TRIGGER
-- ============================================================

create or replace function private.audit_row_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  case tg_table_name
    when 'clients' then
      if tg_op = 'INSERT' then
        perform private.write_audit('CLIENT_CREATED', 'client', new.id,
          jsonb_build_object('full_name', new.full_name));
      end if;

    when 'vehicles' then
      if tg_op = 'INSERT' then
        perform private.write_audit('VEHICLE_CREATED', 'vehicle', new.id,
          jsonb_build_object('client_id', new.client_id, 'registration_number', new.registration_number));
      elsif (new.make, new.model, new.manufacturing_year, new.chassis_number, new.registration_number)
            is distinct from (old.make, old.model, old.manufacturing_year, old.chassis_number, old.registration_number) then
        perform private.write_audit('VEHICLE_IDENTITY_CHANGED', 'vehicle', new.id, jsonb_build_object(
          'before', jsonb_build_object('make', old.make, 'model', old.model, 'manufacturing_year', old.manufacturing_year,
                                       'chassis_number', old.chassis_number, 'registration_number', old.registration_number),
          'after', jsonb_build_object('make', new.make, 'model', new.model, 'manufacturing_year', new.manufacturing_year,
                                      'chassis_number', new.chassis_number, 'registration_number', new.registration_number)));
      end if;

    when 'profiles' then
      if tg_op = 'INSERT' then
        perform private.write_audit('PROFILE_CREATED', 'profile', new.id,
          jsonb_build_object('role', new.role, 'client_id', new.client_id));
      elsif (new.role, new.client_id) is distinct from (old.role, old.client_id) then
        perform private.write_audit('PROFILE_ACCESS_CHANGED', 'profile', new.id, jsonb_build_object(
          'from_role', old.role, 'to_role', new.role, 'from_client_id', old.client_id, 'to_client_id', new.client_id));
      end if;

    when 'service_requests' then
      if tg_op = 'INSERT' then
        perform private.write_audit('SERVICE_REQUEST_CREATED', 'service_request', new.id,
          jsonb_build_object('request_number', new.request_number, 'source', new.source));
      else
        if new.status is distinct from old.status then
          perform private.write_audit('SERVICE_REQUEST_STATUS_CHANGED', 'service_request', new.id,
            jsonb_build_object('from', old.status, 'to', new.status));
        end if;
        if (new.client_id, new.vehicle_id) is distinct from (old.client_id, old.vehicle_id) then
          perform private.write_audit('SERVICE_REQUEST_LINKED', 'service_request', new.id,
            jsonb_build_object('client_id', new.client_id, 'vehicle_id', new.vehicle_id));
        end if;
      end if;

    when 'products' then
      if tg_op = 'INSERT' then
        perform private.write_audit('PRODUCT_CREATED', 'product', new.id,
          jsonb_build_object('name', new.name, 'default_price', new.default_price));
      else
        if new.default_price is distinct from old.default_price then
          perform private.write_audit('PRODUCT_PRICE_CHANGED', 'product', new.id,
            jsonb_build_object('from', old.default_price, 'to', new.default_price));
        end if;
        if new.is_active is distinct from old.is_active then
          perform private.write_audit(
            case when new.is_active then 'PRODUCT_ACTIVATED' else 'PRODUCT_DEACTIVATED' end,
            'product', new.id, null);
        end if;
      end if;

    when 'quotations' then
      if tg_op = 'INSERT' then
        perform private.write_audit('QUOTATION_CREATED', 'quotation', new.id,
          jsonb_build_object('quotation_number', new.quotation_number, 'service_request_id', new.service_request_id));
      end if;

    when 'quotation_revisions' then
      if tg_op = 'INSERT' then
        perform private.write_audit('QUOTATION_REVISION_CREATED', 'quotation_revision', new.id,
          jsonb_build_object('quotation_id', new.quotation_id, 'revision_number', new.revision_number));
      else
        if new.status is distinct from old.status then
          perform private.write_audit(
            case new.status
              when 'SENT' then 'QUOTATION_SENT'
              when 'VIEWED' then 'QUOTATION_VIEWED'
              when 'ACCEPTED' then 'QUOTATION_ACCEPTED'
              when 'REJECTED' then 'QUOTATION_REJECTED'
              else 'QUOTATION_REVISION_STATUS_CHANGED'
            end,
            'quotation_revision', new.id,
            jsonb_build_object('from', old.status, 'to', new.status, 'revision_number', new.revision_number));
        end if;
        if (new.discount, new.tax) is distinct from (old.discount, old.tax) then
          perform private.write_audit('QUOTATION_PRICE_CHANGED', 'quotation_revision', new.id, jsonb_build_object(
            'discount_from', old.discount, 'discount_to', new.discount, 'tax_from', old.tax, 'tax_to', new.tax));
        end if;
      end if;

    when 'quotation_items' then
      if tg_op = 'INSERT' then
        perform private.write_audit('QUOTATION_ITEM_ADDED', 'quotation_item', new.id, jsonb_build_object(
          'quotation_revision_id', new.quotation_revision_id, 'name', new.name,
          'quantity', new.quantity, 'final_value', new.final_value));
      elsif tg_op = 'DELETE' then
        perform private.write_audit('QUOTATION_ITEM_REMOVED', 'quotation_item', old.id, jsonb_build_object(
          'quotation_revision_id', old.quotation_revision_id, 'name', old.name));
      elsif (new.quantity, new.final_value) is distinct from (old.quantity, old.final_value) then
        perform private.write_audit('QUOTATION_PRICE_CHANGED', 'quotation_item', new.id, jsonb_build_object(
          'quotation_revision_id', new.quotation_revision_id,
          'quantity_from', old.quantity, 'quantity_to', new.quantity,
          'final_value_from', old.final_value, 'final_value_to', new.final_value));
      end if;

    when 'quotation_change_requests' then
      if tg_op = 'INSERT' then
        perform private.write_audit('QUOTATION_CHANGE_REQUESTED', 'quotation_change_request', new.id,
          jsonb_build_object('quotation_revision_id', new.quotation_revision_id));
      elsif new.status is distinct from old.status then
        perform private.write_audit('QUOTATION_CHANGE_REQUEST_RESPONDED', 'quotation_change_request', new.id,
          jsonb_build_object('status', new.status));
      end if;

    when 'quotation_signatures' then
      if tg_op = 'INSERT' then
        perform private.write_audit('QUOTATION_SIGNED', 'quotation_revision', new.quotation_revision_id,
          jsonb_build_object('signature_id', new.id, 'client_id', new.client_id, 'profile_id', new.profile_id,
                             'signed_at', new.signed_at));
      end if;

    when 'documents' then
      if tg_op = 'INSERT' then
        perform private.write_audit('DOCUMENT_CREATED', 'document', new.id, jsonb_build_object(
          'document_type', new.document_type, 'client_id', new.client_id, 'storage_path', new.storage_path));
      end if;

    when 'service_jobs' then
      if tg_op = 'INSERT' then
        perform private.write_audit('SERVICE_JOB_CREATED', 'service_job', new.id, jsonb_build_object(
          'job_number', new.job_number, 'quotation_revision_id', new.quotation_revision_id));
      elsif new.status is distinct from old.status then
        perform private.write_audit('SERVICE_STATUS_CHANGED', 'service_job', new.id,
          jsonb_build_object('from', old.status, 'to', new.status));
      end if;

    when 'service_work_items' then
      if tg_op = 'INSERT' then
        if new.source = 'ADDITIONAL' then
          perform private.write_audit('ADDITIONAL_WORK_CREATED', 'service_work_item', new.id, jsonb_build_object(
            'service_job_id', new.service_job_id, 'name', new.name,
            'quantity', new.quantity, 'final_value', new.final_value));
        end if;
      else
        if new.approval_status is distinct from old.approval_status then
          perform private.write_audit(
            case when new.approval_status = 'APPROVED' then 'ADDITIONAL_WORK_APPROVED' else 'ADDITIONAL_WORK_REJECTED' end,
            'service_work_item', new.id, jsonb_build_object(
              'approved_value', new.approved_value, 'decision_by_profile_id', new.decision_by_profile_id,
              'decision_at', new.decision_at, 'approval_note', new.approval_note));
        end if;
        if new.status is distinct from old.status then
          perform private.write_audit('WORK_ITEM_STATUS_CHANGED', 'service_work_item', new.id,
            jsonb_build_object('from', old.status, 'to', new.status));
        end if;
      end if;

    when 'vehicle_correction_requests' then
      if tg_op = 'INSERT' then
        perform private.write_audit('VEHICLE_CORRECTION_REQUESTED', 'vehicle_correction_request', new.id,
          jsonb_build_object('vehicle_id', new.vehicle_id));
      elsif new.status is distinct from old.status then
        perform private.write_audit('VEHICLE_CORRECTION_RESPONDED', 'vehicle_correction_request', new.id,
          jsonb_build_object('status', new.status));
      end if;

    else
      null;
  end case;

  return null;
end;
$$;

create trigger clients_audit after insert on public.clients
for each row execute function private.audit_row_change();
create trigger vehicles_audit after insert or update on public.vehicles
for each row execute function private.audit_row_change();
create trigger profiles_audit after insert or update on public.profiles
for each row execute function private.audit_row_change();
create trigger service_requests_audit after insert or update on public.service_requests
for each row execute function private.audit_row_change();
create trigger products_audit after insert or update on public.products
for each row execute function private.audit_row_change();
create trigger quotations_audit after insert on public.quotations
for each row execute function private.audit_row_change();
create trigger quotation_revisions_audit after insert or update on public.quotation_revisions
for each row execute function private.audit_row_change();
create trigger quotation_items_audit after insert or update or delete on public.quotation_items
for each row execute function private.audit_row_change();
create trigger quotation_change_requests_audit after insert or update on public.quotation_change_requests
for each row execute function private.audit_row_change();
create trigger quotation_signatures_audit after insert on public.quotation_signatures
for each row execute function private.audit_row_change();
create trigger documents_audit after insert on public.documents
for each row execute function private.audit_row_change();
create trigger service_jobs_audit after insert or update on public.service_jobs
for each row execute function private.audit_row_change();
create trigger service_work_items_audit after insert or update on public.service_work_items
for each row execute function private.audit_row_change();
create trigger vehicle_correction_requests_audit after insert or update on public.vehicle_correction_requests
for each row execute function private.audit_row_change();

-- ============================================================
-- NOTIFICATION TRIGGER
-- ============================================================

create or replace function private.notify_row_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_quotation_number text;
begin
  case tg_table_name
    when 'service_requests' then
      if tg_op = 'INSERT' and new.source = 'WEBSITE' then
        perform private.notify_admins('NEW_SERVICE_REQUEST',
          'New service request ' || new.request_number,
          coalesce(nullif(new.original_submission->>'customer_name', ''), 'A customer')
            || ' submitted a service request on the website.',
          'service_request', new.id);
      end if;

    when 'quotation_revisions' then
      if tg_op = 'UPDATE' and new.status is distinct from old.status then
        select q.quotation_number into v_quotation_number
        from public.quotations q where q.id = new.quotation_id;

        if new.status = 'SENT' then
          perform private.notify_client(
            private.revision_client_id(new.id),
            (case when new.revision_number = 1 then 'QUOTATION_SENT' else 'QUOTATION_REVISED' end)::public.notification_type,
            case when new.revision_number = 1
              then 'Quotation ' || v_quotation_number || ' is ready'
              else 'Quotation ' || v_quotation_number || ' revised (revision ' || new.revision_number || ')'
            end,
            'Please review the quotation in your client portal.',
            'quotation_revision', new.id);
        elsif new.status = 'ACCEPTED' then
          perform private.notify_admins('QUOTATION_ACCEPTED',
            'Quotation ' || v_quotation_number || ' accepted',
            'Revision ' || new.revision_number || ' was accepted by the client and is awaiting signature.',
            'quotation_revision', new.id);
        elsif new.status = 'REJECTED' then
          perform private.notify_admins('QUOTATION_REJECTED',
            'Quotation ' || v_quotation_number || ' rejected',
            'Revision ' || new.revision_number || ' was rejected. Reason: '
              || coalesce(nullif(new.rejection_reason, ''), 'not given'),
            'quotation_revision', new.id);
        end if;
      end if;

    when 'quotation_change_requests' then
      if tg_op = 'INSERT' then
        perform private.notify_admins('QUOTATION_CHANGE_REQUESTED',
          'Quotation change requested', left(new.message, 500),
          'quotation_change_request', new.id);
      elsif new.status is distinct from old.status then
        perform private.notify_profile(new.profile_id, 'QUOTATION_CHANGE_RESPONDED',
          'Your quotation change request was reviewed',
          'Status: ' || new.status::text || coalesce('. ' || new.admin_response, ''),
          'quotation_change_request', new.id);
      end if;

    when 'quotation_signatures' then
      select q.quotation_number into v_quotation_number
      from public.quotation_revisions qr
      join public.quotations q on q.id = qr.quotation_id
      where qr.id = new.quotation_revision_id;
      perform private.notify_admins('QUOTATION_SIGNED',
        'Quotation ' || v_quotation_number || ' signed',
        'The client signed the accepted quotation. A service job can now be created.',
        'quotation_revision', new.quotation_revision_id);

    when 'service_jobs' then
      if tg_op = 'INSERT' then
        perform private.notify_client(private.service_job_client_id(new.id), 'SERVICE_STATUS_UPDATED',
          'Service job ' || new.job_number || ' scheduled', 'Your service has been scheduled.',
          'service_job', new.id);
      elsif new.status is distinct from old.status then
        if new.status = 'COMPLETED' then
          perform private.notify_client(private.service_job_client_id(new.id), 'SERVICE_JOB_COMPLETED',
            'Service job ' || new.job_number || ' completed', 'Your vehicle service is complete.',
            'service_job', new.id);
        else
          perform private.notify_client(private.service_job_client_id(new.id), 'SERVICE_STATUS_UPDATED',
            'Service job ' || new.job_number || ' updated',
            'Status: ' || replace(new.status::text, '_', ' '),
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

create trigger service_requests_notify after insert on public.service_requests
for each row execute function private.notify_row_change();
create trigger quotation_revisions_notify after update on public.quotation_revisions
for each row execute function private.notify_row_change();
create trigger quotation_change_requests_notify after insert or update on public.quotation_change_requests
for each row execute function private.notify_row_change();
create trigger quotation_signatures_notify after insert on public.quotation_signatures
for each row execute function private.notify_row_change();
create trigger service_jobs_notify after insert or update on public.service_jobs
for each row execute function private.notify_row_change();
create trigger service_work_items_notify after insert or update on public.service_work_items
for each row execute function private.notify_row_change();
create trigger vehicle_correction_requests_notify after insert or update on public.vehicle_correction_requests
for each row execute function private.notify_row_change();

revoke all on all functions in schema private from public;
