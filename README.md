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
    │   └── 20260916000009_business_logic_hardening.sql
    ├── tests/                                   # Transactional test suites (270 checks, 100% pass)
    │   ├── 01_day1_day2_regression.sql          # 158 baseline regression checks
    │   ├── 02_day3_business_logic.sql           # 49 business logic & state checks
    │   ├── 03_security_attack_tests.sql         # 30 checks across 20 attack vectors
    │   ├── 04_business_invariants.sql           # 13 direct PostgreSQL integrity invariants
    │   ├── 05_e2e_workflow.sql                  # 20 checks verifying 21-step realistic lifecycle
    │   └── e2e_business_rules.sql               # Master consolidated test suite
    └── types/
        └── database.types.ts                    # Strongly-typed TypeScript definitions from live DB
```

---

## Verification & Test Results

The backend includes 5 automated test suites running in isolated PostgreSQL rollback transactions:

| Test Suite | Purpose | Tests Run | Result |
|---|---|:---:|:---:|
| `01_day1_day2_regression.sql` | Baseline Day 1 & Day 2 regression | 158 | **158 PASS / 0 FAIL** |
| `02_day3_business_logic.sql` | Day 3 state machines & business rules | 49 | **49 PASS / 0 FAIL** |
| `03_security_attack_tests.sql` | 20 mandatory attack vectors | 30 | **30 PASS / 0 FAIL** |
| `04_business_invariants.sql` | Database integrity & foreign key constraints | 13 | **13 PASS / 0 FAIL** |
| `05_e2e_workflow.sql` | Complete realistic 21-step customer flow | 20 | **20 PASS / 0 FAIL** |
| **`e2e_business_rules.sql`** | **Master Consolidated Suite** | **270** | **270 PASS / 0 FAIL** |

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
