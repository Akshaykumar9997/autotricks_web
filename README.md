# AutoTricks Lead & Quotation System

Enterprise-grade automotive service quotation, lead management, and workshop lifecycle backend built on **Supabase** (PostgreSQL 17.6).

---

## Architecture Overview

AutoTricks manages the complete customer and vehicle service lifecycle:
1. **Public Lead Capture**: Website service requests ingested via a hardened, rate-limited Edge Function (`submit-service-request`).
2. **Staff Review & Customer Identity**: Admin reviews requests, identifies/provisions clients and vehicles, and securely links them (`admin_link_service_request`).
3. **Quotation & Revisions**: Multi-revision quotation drafting, catalogue product snapshotting, server-computed subtotals and totals, and sequential revision numbers.
4. **Client Portal & Negotiation**: Scoped client access via RLS, digital change requests, consent-backed acceptance, and transparent canvas signature uploads (`signatures` private bucket).
5. **Job Lifecycle**: Explicit admin conversion to service jobs, strict sequential status progression (`SCHEDULED` -> `VEHICLE_RECEIVED` -> `INSPECTION` -> `WORK_IN_PROGRESS` -> `QUALITY_CHECK` -> `READY_FOR_DELIVERY` -> `COMPLETED`), and client-approved additional work.
6. **Defense-in-Depth Security**: Product catalogue protection, internal staff notes segregation (`clients.notes`, `service_requests.admin_notes`), append-only audit trail (`audit_logs`), and non-blocking in-app/email notifications.

---

## Repository Structure

```
.
├── .gitignore                                   # Ignore IDE configs, secrets, build artifacts
├── AutoTricks_Backend_Implementation_Report.pdf # Comprehensive architecture implementation report
├── AutoTricks_Master_Schema_v1.0.sql            # Master database schema v1.0
├── README.md                                    # Repository overview (this file)
└── supabase/
    ├── README.md                                # Backend documentation, state machines & RPC reference
    ├── functions/
    │   ├── admin-invite-user/                   # Admin-only user provisioning Edge Function
    │   └── submit-service-request/              # Public lead capture & validation Edge Function
    ├── migrations/                              # Incremental schema & security migrations
    │   ├── 20260913000001_master_schema_v1_0.sql
    │   ├── 20260913000002_notification_types.sql
    │   ├── 20260913000003_integrity_guards.sql
    │   ├── 20260913000004_grants_and_rls.sql
    │   ├── 20260913000005_audit_and_notifications.sql
    │   ├── 20260913000006_workflow_rpcs.sql
    │   ├── 20260913000007_storage.sql
    │   ├── 20260913000008_auth_security_hardening.sql
    │   ├── 20260916000009_business_logic_hardening.sql
    │   └── 20260916000010_service_request_link_hardening.sql
    ├── tests/                                   # Transactional test suites (278 checks, 100% pass)
    │   ├── 01_day1_day2_regression.sql          # 158 baseline regression checks
    │   ├── 02_day3_business_logic.sql           # 49 business logic & state checks
    │   ├── 03_security_attack_tests.sql         # 30 checks across 20 attack vectors
    │   ├── 04_business_invariants.sql           # 13 direct PostgreSQL integrity invariants
    │   ├── 05_e2e_workflow.sql                  # 20 checks verifying 21-step realistic lifecycle
    │   ├── 06_link_hardening_tests.sql          # 8 checks for service request linking invariants
    │   └── e2e_business_rules.sql               # Master consolidated test suite (278 checks)
    └── types/
        └── database.types.ts                    # Strongly-typed TypeScript definitions from live DB
```

---

## Verification & Test Results

The backend includes 6 automated test suites running in isolated PostgreSQL rollback transactions:

| Test Suite | Purpose | Tests Run | Result |
|---|---|:---:|:---:|
| `01_day1_day2_regression.sql` | Baseline Day 1 & Day 2 regression | 158 | **158 PASS / 0 FAIL** |
| `02_day3_business_logic.sql` | Day 3 state machines & business rules | 49 | **49 PASS / 0 FAIL** |
| `03_security_attack_tests.sql` | 20 mandatory attack vectors | 30 | **30 PASS / 0 FAIL** |
| `04_business_invariants.sql` | Database integrity & foreign key constraints | 13 | **13 PASS / 0 FAIL** |
| `05_e2e_workflow.sql` | Complete realistic 21-step customer flow | 20 | **20 PASS / 0 FAIL** |
| `06_link_hardening_tests.sql` | Service request linking invariant tests | 8 | **8 PASS / 0 FAIL** |
| **`e2e_business_rules.sql`** | **Master Consolidated Suite** | **278** | **278 PASS / 0 FAIL** |

---

## State Machines

### 1. Service Request Lifecycle
`NEW` -> `UNDER_REVIEW` -> `QUOTATION_CREATED` -> `QUOTATION_SENT` -> `APPROVED` -> `CONVERTED_TO_JOB` (or `CANCELLED`)

### 2. Service Job Lifecycle
`SCHEDULED` -> `VEHICLE_RECEIVED` -> `INSPECTION` -> `WORK_IN_PROGRESS` -> `QUALITY_CHECK` -> `READY_FOR_DELIVERY` -> `COMPLETED` (or `CANCELLED`)

---

## Connecting to Supabase

- **Project Ref**: `extsmeyxnzhhvcmwyvbi`
- **Database Engine**: PostgreSQL 17.6
- See `supabase/README.md` for complete RPC documentation, storage buckets policies, and client portal views.

---

## Flutter Mobile Application (Frontend Foundation)

The AutoTricks client and workshop admin frontend is a mobile-first Flutter application designed for iOS, Android, and Web.

### Visual Identity
- **Atmosphere**: Dark charcoal & near-black automotive workshop aesthetic.
- **Accents**: High-contrast energetic orange (`#FF6B00`) for primary actions, crimson red (`#E63946`) for attention/danger cues.
- **Typography**: Clean geometric typography (Manrope).
- **Core Dashboard**: Focused on workshop live status ("What is happening right now?") with cinematic mechanic repairing car visual, 72% progress gauge, and 3 core metrics (`OPEN`, `IN SERVICE`, `READY`).

### Running the Application

```bash
# Get Flutter dependencies
flutter pub get

# Run on Chrome or connected mobile device
flutter run -d chrome

# Run with custom Supabase configuration (optional compile-time defines)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://extsmeyxnzhhvcmwyvbi.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_public_anon_key
```

### Running Tests & Code Analysis

```bash
# Static analysis (0 errors, 0 warnings)
flutter analyze

# Automated test suite (unit, widget, routing, and responsive mobile tests)
flutter test
```

---

## Test & Development Accounts / Credentials

The following credentials are provided for testing both the Workshop Admin Portal and the Client Garage Portal:

### 1. Workshop Admin Portal (`/login`)

| User / Role | Email / Login | Password | Role | Notes |
|---|---|---|:---:|---|
| **AutoTricks Admin** | `autotricks08@gmail.com` | `Admin@123` | `ADMIN` | Default pre-filled credentials on `/login` |
| **Akshay Kumar** | `akshaykumar07.m@gmail.com` | `Admin@123` | `ADMIN` | Workshop administrative account |

- **Login Route**: `/login` (Admin Portal)
- **Features Available**: Dashboard analytics, Service Requests management, Product Catalogue, Vehicle registry, Multi-revision Quotation creation & dispatch, Job conversion.

---

### 2. Client Garage Portal (`/client/login`)

| Client Name | Email / Login | Password | Client ID | Associated Test Data |
|---|---|---|---|---|
| **Rahul Kumar** | `rahul.kumar@gmail.com` | `Client@12345` | `2bd5d7fb-3b55-48b1-931f-69896d3f0838` | Honda City (`KA-01-MJ-4412`), Quotation `QT-2026-00037` (`SENT`), Service Request `SR-2026-00075` |
| **Arun Prakash** | `arun.prakash@gmail.com` | `Client@12345` | `6282f38a-1455-4a94-a839-3e70587f473f` | Hyundai Creta (`KA-05-NB-7821`), Service Requests |

- **Login Route**: `/client/login` (Client Garage Portal)
- **Features Available**: Client Home Dashboard, My Vehicles & Specs, Service Requests Tracking, My Quotes (`C07`), Quote Detail (`C08`), Request Changes (`C09`), Accept Quote + Legal Consent (`C10`), Declined Estimates (`C12`).


