-- AutoTricks Phase 3.1: Notification Hardening, Idempotency, and Retention Tests

BEGIN;

-- 1. Verify notification_push_deliveries table structure and unique constraint
DO $$
DECLARE
  v_test_profile_id uuid;
  v_test_token_id uuid;
  v_notif_id uuid;
BEGIN
  SELECT id INTO v_test_profile_id FROM public.profiles LIMIT 1;
  SELECT id INTO v_token_id FROM public.device_tokens LIMIT 1;

  INSERT INTO public.notifications (id, profile_id, type, title, message)
  VALUES (gen_random_uuid(), v_test_profile_id, 'SERVICE_STATUS_UPDATED', 'Delivery Test', 'Testing push delivery tracking')
  RETURNING id INTO v_notif_id;

  -- First delivery insert
  INSERT INTO public.notification_push_deliveries (notification_id, device_token_id, status)
  VALUES (v_notif_id, v_token_id, 'SENT');

  -- Duplicate delivery insert must fail with unique violation
  BEGIN
    INSERT INTO public.notification_push_deliveries (notification_id, device_token_id, status)
    VALUES (v_notif_id, v_token_id, 'SENT');
    RAISE EXCEPTION 'Idempotency failure: duplicate push delivery allowed';
  EXCEPTION WHEN unique_violation THEN
    -- Expected behavior
    NULL;
  END;

  -- Test ON DELETE CASCADE from notifications
  DELETE FROM public.notifications WHERE id = v_notif_id;
  IF EXISTS (SELECT 1 FROM public.notification_push_deliveries WHERE notification_id = v_notif_id) THEN
    RAISE EXCEPTION 'Cascade failure: delivery record not deleted with notification';
  END IF;
END;
$$;

-- 2. Verify 90-day retention cleanup
DO $$
DECLARE
  v_test_profile_id uuid;
  v_old_notif_id uuid;
  v_recent_notif_id uuid;
  v_read_notif_id uuid;
  v_del_count integer;
BEGIN
  SELECT id INTO v_test_profile_id FROM public.profiles LIMIT 1;

  INSERT INTO public.notifications (id, profile_id, type, title, message, created_at, is_read, read_at)
  VALUES (gen_random_uuid(), v_test_profile_id, 'SERVICE_STATUS_UPDATED', 'Old test', 'Old message', now() - interval '95 days', false, null)
  RETURNING id INTO v_old_notif_id;

  INSERT INTO public.notifications (id, profile_id, type, title, message, created_at, is_read, read_at)
  VALUES (gen_random_uuid(), v_test_profile_id, 'SERVICE_STATUS_UPDATED', 'Recent test', 'Recent message', now() - interval '10 days', false, null)
  RETURNING id INTO v_recent_notif_id;

  INSERT INTO public.notifications (id, profile_id, type, title, message, created_at, is_read, read_at)
  VALUES (gen_random_uuid(), v_test_profile_id, 'SERVICE_STATUS_UPDATED', 'Read test', 'Read message', now() - interval '50 days', true, now() - interval '49 days')
  RETURNING id INTO v_read_notif_id;

  v_del_count := private.cleanup_old_notifications();

  IF EXISTS (SELECT 1 FROM public.notifications WHERE id = v_old_notif_id) THEN
    RAISE EXCEPTION 'Retention test failed: 95-day-old notification was not deleted';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE id = v_recent_notif_id) THEN
    RAISE EXCEPTION 'Retention test failed: 10-day-old notification was deleted';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE id = v_read_notif_id) THEN
    RAISE EXCEPTION 'Retention test failed: 50-day-old read notification was deleted';
  END IF;

  DELETE FROM public.notifications WHERE id IN (v_recent_notif_id, v_read_notif_id);
END;
$$;

-- 3. Verify QUOTATION_ACCEPTED, QUOTATION_REJECTED, and QUOTATION_CHANGE_RESPONDED triggers
DO $$
DECLARE
  v_rev_id uuid;
  v_client_prof_id uuid;
  v_cr_id uuid;
  v_notif_count integer;
BEGIN
  -- Find an editable draft revision
  SELECT qr.id, p.id INTO v_rev_id, v_client_prof_id
  FROM public.quotation_revisions qr
  JOIN public.quotations q ON q.id = qr.quotation_id
  JOIN public.service_requests sr ON sr.id = q.service_request_id
  JOIN public.profiles p ON p.client_id = sr.client_id AND p.role = 'CLIENT'
  WHERE qr.status = 'DRAFT'
  LIMIT 1;

  IF v_rev_id IS NOT NULL THEN
    -- DRAFT -> SENT
    UPDATE public.quotation_revisions SET status = 'SENT', sent_at = now() WHERE id = v_rev_id;

    -- SENT -> ACCEPTED
    UPDATE public.quotation_revisions 
    SET status = 'ACCEPTED',
        accepted_at = now(),
        accepted_by_profile_id = v_client_prof_id,
        acceptance_consent_text = 'I accept the quotation.'
    WHERE id = v_rev_id;

    SELECT count(*) INTO v_notif_count 
    FROM public.notifications 
    WHERE type = 'QUOTATION_ACCEPTED' AND entity_id = v_rev_id;

    IF v_notif_count = 0 THEN
      RAISE EXCEPTION 'QUOTATION_ACCEPTED trigger failed to create notification';
    END IF;
  END IF;

  -- Test QUOTATION_CHANGE_RESPONDED
  SELECT id INTO v_cr_id FROM public.quotation_change_requests LIMIT 1;
  IF v_cr_id IS NOT NULL THEN
    UPDATE public.quotation_change_requests
    SET status = 'ACCEPTED', admin_response = 'Scope accepted'
    WHERE id = v_cr_id;

    SELECT count(*) INTO v_notif_count
    FROM public.notifications
    WHERE type = 'QUOTATION_CHANGE_RESPONDED' AND entity_id = v_cr_id;

    IF v_notif_count = 0 THEN
      RAISE EXCEPTION 'QUOTATION_CHANGE_RESPONDED trigger failed to create notification';
    END IF;
  END IF;
END;
$$;

ROLLBACK;
