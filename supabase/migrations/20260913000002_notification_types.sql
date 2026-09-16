-- AutoTricks hardening 0/5: extra notification types.
-- Kept in its own migration because new enum values cannot be used
-- in the same transaction that adds them.

alter type public.notification_type add value if not exists 'QUOTATION_REJECTED';
alter type public.notification_type add value if not exists 'QUOTATION_CHANGE_RESPONDED';
alter type public.notification_type add value if not exists 'VEHICLE_CORRECTION_REQUESTED';
alter type public.notification_type add value if not exists 'VEHICLE_CORRECTION_RESPONDED';
