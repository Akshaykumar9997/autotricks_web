-- ============================================================
-- FIX: DROP OVERLOADED admin_update_service_job_status FUNCTION
-- ============================================================
-- The legacy 2-argument overload from 20260913000006_workflow_rpcs.sql:
--   public.admin_update_service_job_status(uuid, public.service_job_status)
-- collided with Day 12's 3-argument function with default parameter:
--   public.admin_update_service_job_status(uuid, public.service_job_status, text DEFAULT NULL)
-- causing PostgREST error PGRST203 (Multiple Choices).
--
-- This migration drops the legacy 2-argument signature to ensure
-- exactly ONE canonical function exists.

DROP FUNCTION IF EXISTS public.admin_update_service_job_status(uuid, public.service_job_status);
