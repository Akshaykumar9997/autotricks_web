# AutoTricks Mobile App — DESIGN.md

**Version:** 1.0  
**Status:** Canonical Source of Truth  
**Scope:** Flutter mobile application only — Admin App + Client App  
**Design direction:** Premium, cinematic automotive, dark-first, operationally clean

---

## 0. Purpose

This document is the UI/UX constitution for the AutoTricks mobile application.

It defines:

- Product structure
- Navigation
- User flows
- Business/UI rules
- Visual design tokens
- Reusable components
- System states
- Approved visual assets
- Stitch generation rules
- Flutter implementation expectations

### Source-of-truth rule

Stitch and Flutter should **compose this system**, not redefine it.

Do not invent new navigation patterns, colors, fonts, workflows, feature areas, or visual styles unless the product requirements are intentionally changed.

---

# 1. Product Scope

AutoTricks has one Flutter mobile application with role-based experiences:

```text
AUTHENTICATION
      |
      +---- ADMIN APP
      |
      +---- CLIENT APP
```

## Admin App

Primary operational areas:

- Home
- Service Requests
- Create actions
- Quotes
- More / management

Admin manages:

- Requests
- Clients
- Vehicles
- Quotations
- Quote revisions
- Change requests
- Service Jobs
- Work Items
- Additional Work
- Products
- Services & Pricing
- Notifications
- Documents
- Settings

## Client App

The client experience centers on:

```text
My Car
   ↓
My Request
   ↓
My Quote
   ↓
My Service
   ↓
My Documents
```

Client manages/views only their own information.

---

# 2. Product Design Principles

1. **Operational first**
   - This is a service-management application, not a marketing app.

2. **One clear primary action**
   - Each operational screen should make the next valid action obvious.

3. **Status first**
   - Current business status must be visible.

4. **Context over navigation clutter**
   - Do not create a navigation tab for every database entity.

5. **Mobile-first**
   - Never squeeze a desktop dashboard into a phone layout.

6. **Progressive disclosure**
   - Show the important information first; secondary information comes later.

7. **Consistency over novelty**
   - Reuse established components instead of inventing screen-specific UI.

8. **Backend remains authoritative**
   - UI may hide invalid actions, but backend validation remains the final enforcement layer.

9. **No feature creep**
   - Do not add analytics, chat, marketplace, social features, extra dashboards, or other unapproved functionality.

10. **Automotive atmosphere, restrained UI**
   - Automotive imagery establishes identity; the actual business UI stays clean.

---

# 3. Visual Direction

## Brand Feel

AutoTricks should feel:

**Premium · Automotive · Modern · Confident · Professional · Practical**

It should not feel like:

- Generic SaaS
- Old-fashioned garage software
- Banking software
- Gaming UI
- Over-designed futuristic AI software

## Visual formula

```text
NEAR-BLACK FOUNDATION
        +
CHARCOAL SURFACES
        +
ORANGE BRAND ACTIONS
        +
CONTROLLED SEMANTIC COLORS
        +
MANROPE TYPOGRAPHY
        +
8-POINT SPACING
        +
CLEAN MOBILE COMPONENTS
        +
CINEMATIC AUTOMOTIVE VISUALS
```

---

# 4. Color Tokens

## Base

| Token | Value | Purpose |
|---|---|---|
| `background` | `#0B0D0F` | App background |
| `surface-1` | `#14171D` | Cards / main surfaces |
| `surface-2` | `#1C2129` | Elevated surfaces |
| `border` | `#242A35` | Borders / dividers |
| `text-primary` | `#F5F5F5` | Main text |
| `text-secondary` | `#A7ADB7` | Supporting text |
| `text-muted` | `#6F7682` | Low-priority information |

## Brand

| Token | Value |
|---|---|
| `primary` | `#FF6B00` |
| `primary-strong` | `#FF5200` |
| `primary-soft` | `#FF6B001A` |

## Semantic

| Token | Value | Meaning |
|---|---|---|
| `success` | `#10B981` | Accepted / completed |
| `warning` | `#FFB703` | Pending / attention |
| `danger` | `#E63946` | Rejected / cancelled / destructive |
| `info` | `#2196F3` | Informational / active review |

Do not use semantic colors as decoration.

---

# 5. Typography

**Primary font: Manrope**

| Style | Size | Weight | Use |
|---|---:|---:|---|
| Display | 32 | 700 | Major visual headings |
| H1 | 28 | 700 | Page title |
| H2 | 22 | 700 | Section heading |
| H3 | 18 | 700 | Card/detail heading |
| Body | 15–16 | 400 | Main content |
| Body Medium | 15–16 | 600 | Emphasis |
| Caption | 12–13 | 500 | Secondary information |
| Button | 14–15 | 600/700 | Actions |
| Numeric Highlight | 24–30 | 700 | Totals / important values |

Typography must stay readable on small phones.

---

# 6. Spacing

Use an 8-point spacing system:

```text
4   micro
8   small
12  compact
16  standard
24  section
32  large
40  major
48  hero
64  exceptional
```

Most interfaces should primarily use:

**8 / 12 / 16 / 24 / 32**

Default mobile horizontal content padding:

**16 px**

---

# 7. Corner Radius

| Token | Radius | Use |
|---|---:|---|
| `radius-sm` | 8 | Small controls |
| `radius-md` | 12 | Inputs / compact cards |
| `radius-lg` | 16 | Main cards |
| `radius-xl` | 20 | Large surfaces |
| `radius-pill` | 999 | Chips / badges |

Avoid rounding every element excessively.

---

# 8. Elevation

Prefer:

**Surface contrast + subtle borders**

over heavy shadows.

Standard card:

```text
surface-1
+ subtle border
+ minimal elevation
```

Modal/bottom sheet:

```text
surface-2
+ subtle border
+ modest elevation
```

Avoid constant orange glow effects.

---

# 9. Core Components

These are the reusable UI vocabulary.

1. `AutoAppBar`
2. `AutoButton`
3. `AutoCard`
4. `AutoInput`
5. `AutoSelect`
6. `AutoBadge`
7. `AutoListTile`
8. `AutoDialog`
9. `AutoBottomSheet`
10. `AutoToast`
11. `AutoSkeleton`
12. `AutoEmptyState`
13. `AutoErrorState`
14. `AutoTimeline`
15. `AutoSectionHeader`
16. `AutoBottomNav`

No screen should create its own unrelated visual equivalent of an existing component.

---

# 10. Component Rules

## Buttons

Variants:

- Primary
- Secondary
- Ghost
- Destructive

States:

```text
Default
Pressed
Disabled
Loading
```

Primary buttons use the orange brand treatment.

Use specific verbs:

- Create Quote
- Send Quote
- Add Vehicle
- Approve Additional Work
- Create Service Job

Avoid generic labels such as "Click Here."

## Cards

Cards are for meaningful groups of information.

Hierarchy:

```text
Status
Title / identifier
Important context
Supporting information
Action
```

## Lists

Lists are preferred for large collections of similar records.

Use them for:

- Requests
- Clients
- Vehicles
- Quotes
- Jobs
- Products

## Forms

Rules:

- Labels must remain visible.
- Placeholder is not the only label.
- Show validation beside the relevant field.
- Group related fields.
- Avoid giant unstructured forms.

## Bottom Sheets

Use for:

- Quick creation
- Filters
- Short selections
- Focused contextual actions
- Confirmations where appropriate

Do not turn them into giant application screens.

## Dialogs

Use for focused decisions.

Structure:

```text
Title
Short consequence/explanation

[Secondary] [Primary]
```

## Toasts

Use for lightweight completion feedback:

- Quote saved
- Vehicle added
- Client created
- Changes requested

Do not use toasts as the sole place for critical business information.

---

# 11. Screen Templates

## List Template

```text
App Bar
Search / Filter
Section
List
Contextual action
```

## Detail Template

```text
App Bar
Status
Primary information
Primary action
Detail sections
Related records
Timeline
```

## Create/Edit Template

```text
App Bar
Form sections
Validation
Primary action
```

## Workflow Template

```text
Current status
Context
Required decision/action
Supporting information
Primary action
Secondary action
```

## System State Template

```text
Icon / illustration
Message
Short explanation
Recovery/action
```

---

# 12. Admin Navigation

Bottom navigation:

```text
HOME | REQUESTS | + | QUOTES | MORE
```

The center `+` is a creation entry point, not a data section.

## Home

Shows:

- Requests needing attention
- Open requests
- Active jobs
- Recent activity

No giant analytics dashboard.

## Requests

Filters/states:

- All
- New
- Under Review
- Quotation Created
- Quotation Sent
- Approved
- Converted to Job
- Cancelled

Request Detail links to:

- Client
- Vehicle
- Quote
- Job

## + Create

Primary choices:

- Service Request
- Client
- Vehicle

Other records should normally be created contextually.

Example:

```text
Request Detail → Create Quote
Accepted + Signed Quote → Create Service Job
```

## Quotes

Filters/states:

- All
- Draft
- Sent
- Viewed
- Change Requested
- Accepted
- Rejected
- Expired
- Cancelled

## More

- Clients
- Vehicles
- Service Jobs
- Services & Pricing
- Products
- Notifications
- Settings
- Help

---

# 13. Client Navigation

Bottom navigation:

```text
HOME | VEHICLES | SERVICES | PROFILE
```

## Home

Prioritize:

- Pending action
- Current quote
- Active service
- Relevant vehicle
- Documents

## Vehicles

```text
Vehicles
  ↓
Vehicle Detail
  ├── Requests
  ├── Quotes
  └── Service History
```

## Services

```text
Services
  ↓
Service Requests / Service Detail
  ├── Quote
  ├── Progress
  ├── Additional Work
  └── Documents
```

## Profile

- Personal information
- Account
- Notifications
- Help

---

# 14. Authentication Navigation

```text
App Launch
   ↓
Auth Check
   |
   +-- Not authenticated → Login
   |
   +-- Authenticated → Role Check
                          |
                          +-- ADMIN → Admin Home
                          |
                          +-- CLIENT → Client Home
```

No public Admin signup.

Invalid/missing role:

```text
Role validation failure
↓
Clear recovery path
```

---

# 15. Global UI States

Every major screen must define:

- Initial loading
- Refreshing
- Empty
- Error
- Validation error
- Processing
- Success
- Confirmation
- Permission denied
- Network/offline recovery

Rules:

- Loading should preserve layout structure.
- Existing content may remain visible during refresh.
- Empty states need explanation + relevant action.
- Errors need a human-readable message + recovery action where possible.
- Processing states prevent duplicate submission.
- Destructive actions require confirmation.

---

# 16. Status Display Rules

Status is always visible on important business screens.

Conceptual mapping:

```text
Neutral     → New / Draft
Info        → Under Review / active informational state
Warning     → Pending approval / attention
Success     → Accepted / Completed
Danger      → Rejected / Cancelled
```

Do not communicate status through color alone. Include the status text.

---

# 17. Service Request Rules

Website-originated intake is outside the mobile UI scope, but Admin must see the resulting request correctly.

For a new unprocessed intake:

```text
NEW
↓
Review
↓
UNDER_REVIEW
```

Linking a client/vehicle should only be presented when the business state permits it.

A request that has progressed should not look like an unprocessed intake request.

Primary action should follow the current state.

---

# 18. Quotation Rules

## Draft

Editable fields may include:

- Items
- Quantity
- Values
- Discount
- Tax
- Notes
- Terms

## Sent

Revision becomes immutable.

Do not show normal editing controls.

Use:

**Create New Revision**

when a change requires a new revision.

## Snapshot behavior

Quotation item values are historical snapshots.

Later catalogue changes must not alter old quotation revisions.

## Calculation

```text
Line Total = Quantity × Final Value

Subtotal = Sum(Line Totals)

Total = Subtotal - Discount + Tax
```

Server is authoritative for final calculations.

---

# 19. Quote Negotiation

```text
Quote
  ↓
Client reviews
  |
  +-- Accept → Consent → Signature
  |
  +-- Request Changes → CHANGE_REQUESTED
  |
  +-- Reject → Reason → REJECTED
```

Client cannot directly change quote pricing.

A new revision is created when required.

Revision number must be obvious.

---

# 20. Digital Signature

Signature is:

- Drawn using finger/stylus
- Transparent PNG
- Attached to an exact quotation revision
- One signature per revision
- Client-only
- Not an uploaded signature file

Flow:

```text
Empty canvas
↓
Draw
↓
Clear / Redraw
↓
Submit
↓
Processing
↓
Signed
```

After signing, the signature is locked.

---

# 21. Service Job Rules

Job creation occurs only after the applicable quote has been accepted and signed.

Signing does **not** automatically create a job.

Job workflow:

```text
SCHEDULED
↓
VEHICLE_RECEIVED
↓
INSPECTION
↓
WORK_IN_PROGRESS
↓
QUALITY_CHECK
↓
READY_FOR_DELIVERY
↓
COMPLETED
```

Cancellation is separate.

UI should present the next valid transition rather than an unrestricted status dropdown.

---

# 22. Work Item Rules

Quotation work:

```text
source = QUOTATION
approval = NOT_REQUIRED
```

Typical execution:

```text
PENDING
↓
IN_PROGRESS
↓
COMPLETED
```

---

# 23. Additional Work Rules

Additional work:

```text
DISCOVERED
↓
PENDING CLIENT APPROVAL
↓
APPROVED / REJECTED
```

Only approved additional work can proceed into execution.

Client action should say:

**Approve Additional Work**

rather than generic "Continue."

Admin should clearly see:

**Waiting for client approval**

when applicable.

---

# 24. Documents

Supported client-facing document types:

- Quotation PDF
- Signed Quotation PDF
- Service Report
- Receipt
- Invoice

Use icons and metadata in the normal UI.

Do not create separate image assets for document types.

Primary client actions:

**View / Open / Download**

---

# 25. Product Rules

Products are physical catalogue items.

Admin can:

- Create
- View
- Edit
- Deactivate

Client cannot access the product catalogue.

Catalogue values used in a quotation are copied into the quotation snapshot and do not dynamically update historical quotes.

Prefer **Deactivate** over destructive deletion for historical catalogue data.

---

# 26. Client Data Model UI Implication

A customer record and a portal identity are not the same thing.

Conceptually:

```text
Client Record
      ≠
Auth Identity
```

Admin UI should be able to distinguish:

- Customer exists
- Customer has portal access

Do not assume every client already has an app account.

---

# 27. Permission Principles

Client:

- Own profile only
- Own vehicles only
- Own requests only
- Own quotes only
- Own service history only
- Own documents only
- Own notifications only

Client cannot:

- Access Admin screens
- Access other customers
- Access Products
- Change quote pricing
- Modify service history
- Replace signed documents
- Replace stored signatures
- Execute Admin-only actions

UI permission controls improve usability.

Backend authorization remains the final security boundary.

---

# 28. Detail Screen Hierarchy

Every major detail page should approximately follow:

```text
HEADER
↓
STATUS
↓
PRIMARY INFORMATION
↓
PRIMARY ACTION
↓
DETAIL SECTIONS
↓
RELATED RECORDS
↓
TIMELINE / HISTORY
```

Avoid putting all information at equal visual weight.

---

# 29. Timeline

One reusable timeline component supports:

- Request progression
- Quote lifecycle
- Job progress
- Service history

The timeline should show:

- Event/state
- Timestamp when available
- Current position

---

# 30. Empty States

Use one approved generic visual system rather than a different illustration on every empty screen.

Recommended structure:

```text
Approved visual
↓
Short title
↓
One-sentence explanation
↓
Relevant action
```

Examples:

- No vehicles yet
- No service requests yet
- No active quotes
- No notifications

Where a simple icon is sufficient, do not force an illustration.

---

# 31. Error States

Structure:

```text
Icon / visual
↓
What happened?
↓
What can the user do?
↓
Retry / recovery action
```

Avoid exposing raw technical/database messages.

---

# 32. Loading

Use:

- Skeletons for content screens
- Progress indication for actions
- Approved branded loading visual where an actual branded loading experience is appropriate

Do not use a blank screen with a tiny spinner as the universal loading state.

---

# 33. Touch & Mobile Rules

Target widths:

- 360–374 px
- 375–389 px
- 390–430 px

The app must remain usable across these widths.

Do not simply shrink a desktop layout.

Interactive elements must be comfortably tappable.

Avoid tiny icon-only controls where a larger target or text label is more appropriate.

---

# 34. Motion

Motion is restrained.

Allowed:

- Fade
- Small slide
- Bottom-sheet transition
- Button/loading transition
- Subtle status transitions

Avoid:

- Long animations
- Bouncing UI
- Gimmicky vehicle animations
- Constant glowing effects

The product should feel fast and professional.

---

# 35. Approved Asset Library

## Brand

### `autotricks_logo_master.png`

**Status:** Approved / Canonical

Rules:

- User-provided original logo
- Do not redraw
- Do not replace with AI-generated logo
- Do not distort
- Do not recolor
- Preserve proportions

## App Identity

### `autotricks_app_icon_approved.png`

**Status:** Approved / Canonical

Use for:

- App launcher identity
- Mobile app icon preparation

## Loading

### `autotricks_loading_visual_approved.png`

**Status:** User-approved

Use as the branded loading visual where appropriate.

## Empty State

### `autotricks_generic_empty_state_approved.png`

**Status:** User-approved

Use as the reusable generic empty-state visual.

## Service Experience

### `autotricks_service_progress_visual_approved.png`

**Status:** User-approved

Use to support the client service-progress experience.

## Asset rule

Do not generate additional static imagery unless a real product requirement identifies:

1. The screen using it
2. The reason it is needed
3. Why normal UI/iconography is insufficient

---

# 36. Icons

Use one coherent icon family throughout.

Characteristics:

- Clean
- Simple
- Outline-first where practical
- Consistent stroke weight

Use icons for:

- Navigation
- Status support
- Documents
- Notifications
- Vehicles
- Requests
- Service actions

Do not mix random icon styles, emoji, 3D icons, and unrelated libraries.

---

# 37. Screen Inventory — Admin

```text
A01 Login
A02 Home
A03 Service Requests
A04 Service Request Detail
A05 Create Service Request

A06 Client List
A07 Client Detail
A08 Create/Edit Client

A09 Vehicle List
A10 Vehicle Detail
A11 Create/Edit Vehicle

A12 Quote List
A13 Quote Detail
A14 Create Quote
A15 Edit Quote Revision
A16 Quote Change Requests

A17 Service Jobs
A18 Service Job Detail
A19 Create Service Job
A20 Work Items
A21 Additional Work Approval

A22 Products
A23 Product Detail / Edit
A24 Services & Pricing
A25 Notifications
A26 More / Settings
```

---

# 38. Screen Inventory — Client

```text
C01 Login
C02 Home
C03 My Vehicles
C04 Vehicle Detail
C05 Service Requests
C06 Service Request Detail

C07 My Quotes
C08 Quote Detail
C09 Request Quote Changes
C10 Accept Quote + Consent
C11 Digital Signature
C12 Quote Rejected

C13 Service Job / Progress
C14 Additional Work Approval
C15 Documents
C16 Document Viewer
C17 Profile
C18 Notifications
```

---

# 39. Screen Batches for Stitch

Do not generate all screens in one request.

## Batch 1 — Admin Foundation

```text
A01
A02
A03
A04
A05
```

## Batch 2 — Admin CRM

```text
A06–A11
```

## Batch 3 — Admin Quotes

```text
A12–A16
```

## Batch 4 — Admin Jobs

```text
A17–A21
```

## Batch 5 — Admin Catalogue/System

```text
A22–A26
```

## Batch 6 — Client Foundation

```text
C01–C06
```

## Batch 7 — Client Quotes

```text
C07–C12
```

## Batch 8 — Client Service

```text
C13–C18
```

---

# 40. Stitch Rules

Before generating a screen, Stitch must respect this document.

## Stitch may

- Compose layouts
- Arrange approved components
- Select appropriate screen template
- Use approved assets
- Adapt spacing for mobile
- Create visual hierarchy within the defined system

## Stitch must not

- Invent new navigation
- Invent new product features
- Replace the logo
- Change the color system
- Change typography
- Create a light theme
- Add giant analytics dashboards
- Add marketplace/chat/social features
- Add random decorative widgets
- Create desktop-style tables
- Create new visual language per screen

## Asset rule

The canonical uploaded logo takes precedence over any generated logo representation.

---

# 41. Flutter Handoff Rules

Approved Stitch screens become visual references for Flutter.

Flutter implementation must preserve:

- Token values
- Typography
- Component styles
- Navigation structure
- Business states
- Empty/loading/error treatment
- Approved assets
- Mobile spacing
- Action hierarchy

Do not copy a single screen as an isolated design.

Build reusable Flutter components from the design system.

---

# 42. Visual QA Checklist

For every approved screen verify:

### Structure

- Correct route
- Correct navigation
- Correct content hierarchy
- Correct primary action

### Business

- Only valid actions are visible
- Immutable states look immutable
- Pending approvals are obvious
- Status is accurate

### Visual

- Correct dark background
- Correct surfaces
- Correct orange accent
- Correct typography
- Correct spacing
- Correct radius
- Correct icon family
- Correct asset usage

### Mobile

- No horizontal overflow
- Comfortable tap targets
- Readable at 360 px width
- Readable at 390–430 px widths
- No desktop-table behavior

### States

- Loading
- Empty
- Error
- Processing
- Success
- Confirmation

must be checked where applicable.

---

# 43. Change Protocol

When changing an approved screen, use a **delta-change approach**.

State:

```text
CHANGE:
Replace X with Y.

KEEP:
Navigation
Typography
Colors
Spacing
Components
Business rules
```

Do not regenerate the entire design unnecessarily.

When a requirement genuinely changes the system, update this document first, then propagate the change to Stitch and Flutter.

---

# 44. Feature Control

A feature belongs in the MVP only when it has a clear requirement and a place in:

- Product Map
- User Flow
- Screen Inventory
- Business Rules
- Navigation

A beautiful feature without a product requirement is not automatically a valid feature.

---

# 45. Canonical Workflow

```text
AUTOTRICKS REQUIREMENTS
        ↓
PRODUCT MAP
        ↓
USER FLOWS
        ↓
SCREEN INVENTORY
        ↓
STATE MATRIX
        ↓
NAVIGATION MAP
        ↓
BUSINESS & UI RULES
        ↓
DESIGN SYSTEM
        ↓
ASSET LIBRARY
        ↓
DESIGN.md
        ↓
STITCH
        ↓
APPROVED SCREENS
        ↓
FLUTTER IMPLEMENTATION
        ↓
VISUAL QA
```

---

# 46. Current Project Status

```text
Step 1  Product Map          ✅
Step 2  User Flows           ✅
Step 3  Screen Inventory     ✅
Step 4  State Matrix         ✅
Step 5  Navigation Map       ✅
Step 6  Business/UI Rules   ✅
Step 7  Design System        ✅
Step 8  Asset Library        ✅
Step 9  DESIGN.md             ✅
```

## Next

**Step 10 — Google Stitch**

The first design batch should be:

```text
ADMIN FOUNDATION

A01 Login
A02 Home
A03 Service Requests
A04 Service Request Detail
A05 Create Service Request
```

Use this `DESIGN.md` as the governing specification for the batch.
