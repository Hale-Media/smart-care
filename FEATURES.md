# Smart Care — App Features

Smart Care is a Flutter-based digital care management platform for residential care homes and home-care services. It covers the full operational workflow from daily rounds and medication administration through to legal safeguarding records, compliance monitoring, and UK GDPR data-subject rights.

---

## Authentication & Security

- **Login** — Email/password authentication with JWT token issued on success
- **Register** — New staff account creation with role assignment
- **JWT revocation** — Server-side token invalidation on logout; all sessions for a user can be revoked simultaneously
- **Role-based access** — Four roles: `carer`, `senior`, `manager`, `admin`; UI gates features by role (e.g. GDPR panel visible only to managers and above)
- **Multi-home switching** — Staff with `can_switch` permission can change active home without re-logging in; new JWT issued per switch
- **Audit trail** — All create/update/delete operations pass through `AuditedRepository`, storing a before/after record with staff ID, home ID, and client IP for every change

---

## Dashboard

- **KPI grid (3×2)** — Live tiles for: Residents, Open alerts, Critical alerts, Open incidents, Overdue medications, Rounds due; each tile taps through to the relevant screen
- **Active alerts list** — Up to 8 most-recent open alerts shown inline with severity colour-coding and elapsed time
- **Shift handover card** — One-tap access to read the last shift's notes or write a new one
- **Compliance shortcut** — Card linking to the organisation-wide compliance dashboard
- **Home identity** — Home name switcher and linked CQC registration badge shown in the header
- **Auto-refresh** — Background `Timer` polls all four data sources every 60 seconds while the screen is mounted
- **Stale data banner** — Shown when resident or alert data is being served from local cache after a network failure, with a Retry button
- **Pull-to-refresh** — Manual refresh of all data sources simultaneously

---

## Residents

### Resident List

- **Dual-tab view** — Separate tabs for Residential care and Home Care service users
- **Live search** — Filter by name + room number (residential) or name + address (home care)
- **Status chips** — Visual indicators per tile: `DNACPR`, `FALL RISK` (high), `NUTRITION` (high risk), `REVIEW DUE` (outcome review date passed)
- **Offline cache** — Resident list persisted to `SharedPreferences`; stale-data `MaterialBanner` with Retry shown when serving cached data
- **Add resident / service user** — FAB opens create form, pre-seeted to the active tab's care level

### Resident Profile

- **Full profile editing** — First/last name, date of birth, room number, NHS number, address (home care), photo URL, GP name, next-of-kin name and phone
- **Medical tags** — Chip-based entry for conditions, allergies, current medications, and monitoring methods; pending text auto-flushed on save
- **Clinical flags** — DNACPR status, fall risk level, nutrition risk level, outcome review date
- **Care level** — Residential, EMI, nursing, or home care; editable per resident
- **Discharge** — Soft-discharge action removes the resident from the active list

### Resident Detail Tabs

From a resident's profile, staff can navigate to:

| Tab | Description |
| --- | --- |
| Vitals | Clinical observations and NEWS2 history |
| Medications | Active drug list and MAR |
| Incidents | Incidents linked to this resident |
| Care Plan | Domain-based care plan with interventions |
| Risk Assessments | Linked risk assessments |
| DoLS | Deprivation of Liberty Safeguards records |
| LPA | Lasting Power of Attorney registrations |
| Advance Decisions | Advance directives / ADRT records |
| Capacity | Mental Capacity Assessments |
| Safeguarding | Safeguarding concerns and referrals |
| Calls / Visits | Home care call schedule and history |

---

## Medications

- **Active medication list** — All current prescribed medications per resident
- **Schedule view** — Medications grouped by time slot (08:00, 12:00, etc.) with a `Give` button per slot
- **Medication Administration Recording (MAR)** — Record outcome (`given`, `refused`, `omitted`, `unavailable`, `asleep`, `hospital`) with optional notes; `administered_at` and `scheduled_for` stored in UTC
- **Controlled drug (CD) validation** — CD medications require a witness name before the Confirm button activates; server-side two-person witness enforcement via `cd_register`
- **CD register** — Stock ledger per CD medication tracking `receipt`, `disposal`, `adjustment`, and `return` movements with running balance; every movement requires two signatories
- **PRN medications** — As-needed drug administration with a free-text indication field
- **PRN effectiveness follow-up** — After a PRN dose the system flags it as awaiting an effectiveness check; staff record `effective`, `partial`, or `not_effective` to close the loop (meets CQC expectation)
- **MAR history** — Full administration history per resident with outcome colour-coding
- **Due medications view** — Today's outstanding doses pulled from the schedule for the rounds screen

---

## Care Rounds

- **Daily schedule** — Care rounds (welfare checks, repositioning, continence) and medication slots shown together in one chronological list
- **Progress header** — Combined tally of completed rounds + given medications out of total for the day; progress bar colour-coded green/amber/red; overdue count badge
- **Round completion** — Tap a round tile to mark it done; optimistic UI update with error recovery
- **Overdue highlighting** — Rounds and medication slots past their due time shown with a critical colour
- **Administering from rounds** — Medication `Give` → `_AdministerSheet` → Confirm records the MAR entry and refreshes the list
- **Round history** — Completed and skipped rounds for past shifts

---

## Vitals

- **Vital signs form** — Record heart rate, systolic/diastolic BP, SpO2, temperature, respiratory rate, and AVPU consciousness level
- **NEWS2 auto-scoring** — Score calculated server-side on every recording using the Royal College of Physicians algorithm
- **NEWS2 trend chart** — Line chart with date labels on the x-axis and horizontal risk-zone bands (green 0–4 low, amber 4–6 medium, red 6–14 high)
- **Vital sparklines** — Four compact inline charts (HR, SpO2, systolic BP, temperature) each showing the trend and current value colour-coded against normal ranges
- **History list** — Full chronological list of readings with NEWS2 score and recording timestamp

---

## Handover

- **Create handover note** — Free-text notes tagged to a shift with timestamp and author
- **Shift list** — View notes by shift; most recent shown on the dashboard
- **Read mode** — Previous shift's notes surfaced first when entering the handover screen

---

## Home Care Calls

- **Schedule generation** — Automatically generate a visit schedule for community-based service users
- **Visit confirmation** — Carers confirm arrival and record visit completion
- **Visit history** — Full chronological record of completed visits per client

---

## Alerts

- **Alert list** — All open and resolved alerts ordered by creation time; open count and critical count exposed for the dashboard
- **Alert severity** — `low`, `medium`, `high`, `critical`; colour-coded throughout
- **Acknowledge** — Staff acknowledge receipt of an alert, logging the action
- **Resolve** — Close an alert with optional resolution notes
- **Alert detail** — Full context: resident, location, type, severity, creation time, and full action history
- **Background polling** — `AlertProvider` polls the server on a configurable interval; new alerts since the last-seen ID trigger a local push notification
- **Push notifications** — Standard notifications for new alerts; full-screen intent for critical severity
- **Offline cache** — Alert list cached to `SharedPreferences`; `isStale` flag shown on dashboard when serving cached data

---

## Incidents

- **Report incident** — Log an incident with type, description, date/time, and optional resident link; incidents can be home-wide or resident-specific
- **Status filtering** — View open vs. resolved incidents separately
- **Update status** — Change incident status (e.g. open → under investigation → resolved)
- **Open incident count** — Exposed to the dashboard KPI tile

---

## Legal & Safeguarding (per resident)

### DoLS (Deprivation of Liberty Safeguards)

- Create, update, and soft-delete DoLS authorisation records
- Status tracking: `pending`, `granted`, `refused`, `expired`
- Expiry date alerts — query for all DoLS records expiring within N days across the home
- All writes require a senior role and are fully audit-logged

### Lasting Powers of Attorney (LPA)

- Register LPA records per resident (property/financial and health/welfare types)
- Record attorney name, registration date, and notes

### Advance Decisions (ADRT)

- Record advance decisions to refuse treatment
- Status chips (`active`, `revoked`) shown in the list
- Date signed and witnessing details stored

### Mental Capacity Assessments (MCA)

- Record capacity assessments per decision domain
- Outcome: `has capacity` or `lacks capacity`
- Assessment date, assessor, and supporting rationale stored

### Safeguarding

- Log safeguarding concerns with category (physical, financial, emotional, etc.) and status
- Record referral details and resolution outcome
- All records audit-logged with senior-role gate

---

## Compliance & Quality

### Compliance Dashboard

- Organisation-wide compliance overview covering: consent records, overdue outcome reviews, missed visits, high-risk residents, and staff competency status
- Linked action tiles navigate directly to the relevant resident or staff record
- Error surface with Retry for each section independently

### CQC

- **Location lookup** — Search and verify CQC-registered locations by name or provider
- **Provider verification** — Look up CQC provider details
- **Link registration** — Associate a CQC location with a home in the system

### Staff Competency

- **Individual records** — Add, view, and delete competency records per staff member (training certificates, observations, sign-offs)
- **Home-wide overview** — Aggregated competency compliance summary across all staff
- **Compliance gap identification** — Missing or expired competencies surfaced in the compliance dashboard

---

## Administration

### Homes Management

- Create, edit, and delete care homes
- Per-home view of resident census and linked CQC registration
- Home switcher available to authorised staff without re-authentication

### Staff Management

- Full staff roster with name, email, role, and status
- Create, update, and deactivate staff accounts
- Role assignment controlling feature access throughout the app

### Settings Screen

- Logged-in user profile card (name, role, email)
- Data protection panel (manager+ only) — GDPR subject access, restriction, and erasure
- Alert notification description
- About / version info
- Admin-only section: Manage Homes, Manage Staff, Compliance Dashboard, CQC
- Logout (server-side token revocation + local session clear)

---

## UK GDPR / Data Protection

- **Subject access export** — Full resident data export (personal details, care records, MAR, vitals, incidents, etc.) as structured JSON; renderable as a PDF for printing or sharing
- **Right to restrict processing** — Flag a resident record as restricted; restricts further data operations
- **Right to erasure** — Pseudonymise all personal identifiers (name, DoB, NHS number, address, GP, next-of-kin, photo) while retaining anonymised care records for audit purposes
- **Audit log** — Every data access and modification stored with staff ID, timestamp, home ID, client IP, and before/after payload
- **Role gates** — Export and restriction: `manager`+; erasure: `admin` only

---

## Offline Resilience

- Residents and alerts persisted to `SharedPreferences` after every successful load
- On network failure, cached data is loaded automatically with `isStale = true`
- Dashboard and residents screen show a stale-data banner with a Retry action
- All screens show a shared `ErrorView` (cloud-off icon + message + Retry) when data cannot be loaded and no cache exists

---

## Backend API Coverage

| Area | Endpoints |
| --- | --- |
| Auth | Login, Register, Logout (revoke all sessions) |
| Residents | Create, read, update, list, discharge |
| Medications | Create, update, list, administer (MAR), MAR history, MAR due-today |
| CD Register | Stock movements (receipt, disposal, adjustment, return), running balance |
| PRN Follow-up | List awaiting follow-up, record effectiveness |
| Vitals | Record (with NEWS2 scoring), history |
| Rounds | Due-today schedule, complete, history |
| Alerts | Create, acknowledge, resolve, list |
| Incidents | Report, list, update status |
| Handover | Create note, list by shift |
| Home Care Calls | Generate schedule, confirm, completion, history |
| Care Plans | CRUD sections, version history |
| Risk Assessments | CRUD |
| Care Interventions | Create, update, stop, soft delete |
| DoLS | Create, update, delete, expiry-window query |
| LPA | Create, update, delete, list |
| Advance Decisions | Create, update, delete, list |
| Capacity Assessments | Create, update, delete, list |
| Safeguarding | Create, update, delete, list |
| Staff | CRUD, competency create/list/delete, competency summary |
| Compliance | Organisation-wide summary |
| CQC | Location lookup, provider verify, link to home |
| Homes | Create, edit, delete, list, switch |
| GDPR | Subject access export, restrict, unrestrict, erase |
| Audit | Immutable append-only log (via AuditedRepository) |

---

## Data Models

`Resident` · `CareRound` · `DueMedication` · `Medication` · `MarEntry` · `VitalReading` · `CareAlert` · `Incident` · `HandoverNote` · `HomeCareCall` · `CarePlanSection` · `RiskAssessment` · `CareIntervention` · `DoLsAuthorisation` · `LastingPower` · `AdvanceDecision` · `CapacityAssessment` · `SafeguardingConcern` · `StaffUser` · `StaffCompetencyRecord` · `StaffCompetencySummary` · `ComplianceSummary` · `CqcLocation` · `Home` · `GdprExport`
