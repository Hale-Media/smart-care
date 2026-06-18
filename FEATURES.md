# Smart Care — App Features

## Authentication

- **Login** — Email/password login for staff
- **Register** — New staff account creation

## Dashboard

- Active alert count and quick navigation
- Open incident summary
- Resident census overview
- Compliance warnings at a glance

## Residents

- **Residents Screen** — Tabbed list separating residential care residents from home care clients; search and filter support
- **Resident Detail** — Full resident profile with editable personal and medical information; tabbed access to vitals, medications, incidents, and care calls
- **Visit History** — Historical list of completed home care visits for community-based clients
- **Care Plan** — Domain-based care plan sections with version history, review scheduling, and inline interventions
- **Risk Assessments** — Resident risk assessments linked to care plan sections
- **Care Interventions** — Planned intervention actions embedded within each care plan section; add, view, and stop interventions without leaving the care plan

## Care Operations

### Rounds

- Daily welfare, repositioning, and continence care rounds
- Round completion tracking per resident
- Due medications displayed alongside round tasks

### Medications

- Resident medication list (active drugs)
- Medication administration recording (MAR)
- MAR history and due medication tracking

### Vitals

- Clinical vital signs recording
- NEWS2 score calculation and trend chart
- Historical readings per resident

### Handover

- Shift-to-shift handover notes
- Care priorities communicated between staff

### Home Care Calls

- Schedule generation for community-based residents
- Visit confirmation and completion recording
- Full visit history per client

### Incidents

- Incident reporting (home-wide or resident-specific)
- Status filtering — open vs. resolved

## Alerts

- **Alerts Screen** — Open and resolved alert list with acknowledgment and resolution actions
- **Alert Detail** — Individual alert context and full action history

## Compliance & Quality

### Compliance Dashboard

- Organisation-wide compliance metrics
- Missing training and DBS record identification
- Linked actions to resolve compliance gaps

### CQC

- CQC location lookup and provider verification
- Link CQC registrations to homes

### Staff Competency

- Individual staff training and competency records (create, view, delete)
- Home-wide competency compliance overview

## Administration

### Homes Management

- Multi-home support — create, edit, delete homes
- Per-home resident census and CQC registration details

### Staff Management

- Full staff roster with role assignment
- Competency-based access controls

### Settings

- Admin navigation to homes, staff, compliance, CQC
- Logout

## Backend API Coverage

| Area | Endpoints |
| --- | --- |
| Auth | Login, Register |
| Residents | CRUD, discharge |
| Medications | Create, administer, update, MAR history, MAR due |
| Vitals | Record with NEWS2 scoring, history |
| Rounds | Daily schedules, completion, history |
| Alerts | Create, acknowledge, resolve, list |
| Incidents | Report, list, update status |
| Handover | Create notes, list by shift |
| Home Care Calls | Generate schedules, confirm, history |
| Staff | CRUD, competency create/list/delete/summary |
| Compliance | Organisation-wide summary |
| CQC | Location lookup, provider verify, link to home |
| Care Plans | CRUD sections, version history |
| Risk Assessments | CRUD assessments |
| Care Interventions | Create, update, stop, soft delete |

## Data Models

`Resident` · `CareRound` · `Medication` · `DueMedication` · `VitalReading` · `CareAlert` · `Incident` · `HandoverNote` · `HomeCareCall` · `StaffUser` · `StaffCompetencyRecord` · `StaffCompetencySummary` · `ComplianceSummary` · `CqcLocation` · `Home` · `CarePlanSection` · `RiskAssessment` · `CareIntervention`
