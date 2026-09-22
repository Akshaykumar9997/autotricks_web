# AutoTricks backend (Supabase `extsmeyxnzhhvcmwyvbi`)

## Layout

| Path | What |
|---|---|
| `migrations/20260913000001_master_schema_v1_0.sql` | Supplied master schema, applied unchanged |
| `migrations/…002` – `…007` | Hardening: notification types, integrity guards, least-privilege grants + RLS, audit/notifications, workflow RPCs, Storage |
| `migrations/20260913000008_auth_security_hardening.sql` | Day 2 hardening: product catalogue admin-only, internal notes protection (clients.notes & service_requests.admin_notes), dedicated admin views/RPCs, client portal views, notifications Realtime publication |
| `migrations/20260916000009_business_logic_hardening.sql` | Day 3 hardening: Service request lifecycle guard, service job lifecycle guard, server-calculated totals, decimal math, quotation immutability, client-only acceptance, additional work rules, admin workflow RPCs |
| `migrations/20260916000010_service_request_link_hardening.sql` | Day 3 final closure: Service request linking invariant guard & trigger protection |
| `functions/submit-service-request` | Public website form endpoint (`verify_jwt=false`, validates + throttles, service role insert) |
| `functions/admin-invite-user` | ADMIN-only portal access provisioning (invite + profile) |
| `types/database.types.ts` | Generated from the live database schema |
| `tests/01_day1_day2_regression.sql` | Baseline regression suite (158 PASS / 0 FAIL) |
| `tests/02_day3_business_logic.sql` | Day 3 business logic verification suite (49 PASS / 0 FAIL) |
| `tests/03_security_attack_tests.sql` | 20 mandatory security attack vectors suite (30 PASS / 0 FAIL) |
| `tests/04_business_invariants.sql` | Direct PostgreSQL integrity invariants suite (13 PASS / 0 FAIL) |
| `tests/05_e2e_workflow.sql` | Complete 21-step realistic lifecycle flow (20 PASS / 0 FAIL) |
| `tests/06_link_hardening_tests.sql` | Service request linking invariant tests (8 PASS / 0 FAIL) |
| `tests/e2e_business_rules.sql` | Consolidated master test suite (278 PASS / 0 FAIL) |

## Test & Production Accounts

### 1. Admin Accounts (`role = ADMIN`, `client_id = NULL`)
- `autotricks08@gmail.com` / `Admin@123` (AutoTricks Admin)
- `akshaykumar07.m@gmail.com` / `Admin@123` (Akshay Kumar)

### 2. Client Portal Test Accounts (`role = CLIENT`, linked to `client_id`)
- `rahul.kumar@gmail.com` / `Client@12345` (Client ID: `2bd5d7fb-3b55-48b1-931f-69896d3f0838`, Vehicle: Honda City `KA-01-MJ-4412`)
- `arun.prakash@gmail.com` / `Client@12345` (Client ID: `6282f38a-1455-4a94-a839-3e70587f473f`, Vehicle: Hyundai Creta `KA-05-NB-7821`)

All subsequent users (both Client portal users and additional Admins) are provisioned through the `admin-invite-user` Edge Function.

## Public Signups Configuration

To prevent unauthorized public visitors from creating empty Auth accounts:
1. Open **Supabase Dashboard → Authentication → Configuration / Providers**.
2. Toggle OFF **"Allow new users to sign up"** (or email signups).
3. The database layer also enforces defense-in-depth: uninvited users have no row in `public.profiles`, so RLS filters all business tables to 0 rows and rejects all workflow RPCs.

## Frontend Integration

### Public Website Form
- `POST /functions/v1/submit-service-request` with the publishable key in `apikey`.
- Body fields: `customer_name`, `phone`, `email?`, `car_make`, `car_model`, `manufacturing_year?`,
  `chassis_number?`, `registration_number?`, `current_location`, `service_description`, plus hidden
  honeypot `company_website` (leave empty). Returns `201 { request_number }`, `422 { fields }`, `429`.

### Admin Dashboard Access
- **Products**: Direct SELECT / INSERT / UPDATE on `public.products` (deactivate via `is_active = false`, do not delete). Clients cannot view or touch catalogue products.
- **Clients with Notes**: Query `public.admin_clients` view or use RPC `admin_get_client_notes(client_id)` / `admin_set_client_notes(client_id, notes)`.
- **Service Requests with Admin Notes**: Query `public.admin_service_requests` view or use RPC `admin_get_service_request_notes(sr_id)` / `admin_set_service_request_notes(sr_id, notes)`.
- **Direct Admin Writes Allowed**:
  - `vehicles` (insert/update, cannot change `client_id`)
  - `PHONE` service requests (`created_by = auth.uid()`)
  - DRAFT revision `discount/tax/notes/terms`
  - DRAFT quotation items (insert/update/delete; `line_total` and subtotal/total are computed)
  - `documents` (insert)
  - `service_jobs.scheduled_at`
  - `service_work_items.status`
  - `notifications.is_read/read_at`
  - `profiles.full_name`
- **State Transitions via RPC**:
  - `admin_create_quotation`, `admin_create_quotation_revision`, `admin_send_quotation_revision`
  - `admin_close_quotation_revision`, `admin_respond_quotation_change_request`, `admin_respond_vehicle_correction`
  - `admin_create_service_job`, `admin_add_additional_work`, `admin_update_service_job_status`

### Client Portal Access
- **Profile & Requests**: Query `public.client_portal_clients` and `public.client_portal_service_requests` (these views securely omit internal notes columns).
- **Vehicles & History**: Normal `supabase.from('vehicles')`, `supabase.from('quotations')`, `supabase.from('service_jobs')`, `supabase.from('documents')` — RLS scopes clients to their own records; clients never see DRAFT revisions or internal operational notes.
- **State Transitions via RPC**:
  - `client_mark_quotation_viewed`, `client_request_quotation_change`, `client_accept_quotation_revision`
  - `client_reject_quotation_revision`, `client_sign_quotation_revision`, `client_decide_additional_work`
  - `client_request_vehicle_correction`

### Realtime Notifications
- Table `public.notifications` is added to the `supabase_realtime` publication.
- In the frontend, subscribe to `notifications` filtered by `profile_id=eq.{auth.uid()}` to receive live in-app updates.

## Signing Flow (Client)

1. `rpc('client_accept_quotation_revision', { p_revision_id, p_consent_given: true, p_consent_text })` — store the exact consent wording shown.
2. Export the drawn canvas as a transparent PNG and upload to bucket `signatures` at
   `{client_id}/{revision_id}/{any-name}.png` (`upsert: false`).
3. `rpc('client_sign_quotation_revision', { p_revision_id, p_signature_path })`.

## Storage Buckets (All Private)

| Bucket | Path | Who writes |
|---|---|---|
| `signatures` | `{client_id}/{revision_id}/{file}.png` | Client (own accepted revision only, write-once) |
| `quotation-pdfs` | `{client_id}/…` | Admin |
| `signed-quotation-pdfs` | `{client_id}/…` | Admin, write-once |
| `service-documents` | `{client_id}/…` | Admin |

Clients read only their own `{client_id}/` folder; use `createSignedUrl` for downloads.
`documents.storage_bucket` tells you which bucket a document row lives in.

---

## Day 3 Business Logic & State Machines

### 1. Service Request Lifecycle
Strict sequential progression enforced by database trigger `private.guard_service_request_lifecycle()`:
- `NEW` -> `UNDER_REVIEW`: Triggered by `admin_link_service_request(sr_id, client_id, vehicle_id)`. Prerequisites: linked client and vehicle required.
- `UNDER_REVIEW` -> `QUOTATION_CREATED`: Triggered by `admin_create_quotation(sr_id)`. Prerequisite: quotation must exist.
- `QUOTATION_CREATED` -> `QUOTATION_SENT`: Triggered by `admin_send_quotation_revision(revision_id)`. Prerequisite: quotation revision in `SENT` status.
- `QUOTATION_SENT` -> `APPROVED`: Triggered by `client_sign_quotation_revision(revision_id, signature_path)`. Prerequisite: signed quotation revision.
- `APPROVED` -> `CONVERTED_TO_JOB`: Triggered by `admin_create_service_job(revision_id)`. Prerequisite: service job created.
- Cancellation: `admin_cancel_service_request(sr_id, reason)` is permitted from any pre-conversion state. Once cancelled or converted to a job, status is permanently closed; resurrection attempts are strictly rejected.

### 2. Client & Vehicle Management
- One client can own multiple vehicles (`vehicles.client_id` foreign key).
- Vehicle ownership transfer is prevented directly (`vehicle.client_id` is immutable).
- When a vehicle is sold, a new vehicle record is registered for the new owner while preserving historical records.
- Service request validation enforces that `service_requests.vehicle_id` must belong to `service_requests.client_id`.

### 3. Quotation & Pricing Rules
- Decimal quantities and unit prices are fully supported (e.g., 3.5 liters of engine oil).
- Zero or negative quantities and negative unit prices are rejected by database constraints.
- Line totals are computed server-side: `quantity * final_value`.
- Revision totals are computed server-side: `total = round(subtotal - discount + tax, 2)`.
- Constraints: `discount >= 0`, `tax >= 0`, and `discount <= subtotal`.
- Product pricing snapshot rule: Catalogue product price updates never retroactively alter agreed quotation items.
- Revision numbering is strictly sequential (`1, 2, 3...`) per quotation, enforced by trigger.

### 4. Quotation Acceptance & Signatures
- Acceptance forgery protection: Quotations can only be accepted by a `CLIENT` profile of the owning client with explicit consent text.
- Signing requires client acceptance and an uploaded drawn signature PNG stored in the private `signatures` bucket.
- Signed revisions are strictly immutable.

### 5. Service Job Conversion
- Jobs are created exclusively from accepted and signed quotation revisions via `admin_create_service_job`.
- Direct table inserts to `service_jobs` are blocked.
- All quotation items from the signed revision are automatically snapshotted into `service_work_items` (`source = 'QUOTATION'`, `approval_status = 'NOT_REQUIRED'`).
- Exactly one service job per service request is enforced.

### 6. Additional Work Lifecycle
- Discovered additional work is created via `admin_add_additional_work` (`source = 'ADDITIONAL'`, `approval_status = 'PENDING'`).
- Execution is strictly blocked until the owning client approves.
- Client decides via `client_decide_additional_work(work_item_id, approve, expected_price, note)`.
- If client approves: `approval_status = 'APPROVED'`, `approved_value = stated_price`.
- If client rejects: `approval_status = 'REJECTED'`, `status = 'CANCELLED'`.
- Admins can cancel work items via `admin_cancel_service_work_item(work_item_id, reason)`.

### 7. Service Job Lifecycle
Strict forward progression enforced by database trigger `private.guard_service_job()`:
`SCHEDULED` -> `VEHICLE_RECEIVED` -> `INSPECTION` -> `WORK_IN_PROGRESS` -> `QUALITY_CHECK` -> `READY_FOR_DELIVERY` -> `COMPLETED`
- Status jumps and backwards reversals are blocked.
- Completing a job requires that all work items are either `COMPLETED` or `CANCELLED`.
- Once completed or cancelled, a service job is closed and immutable.

