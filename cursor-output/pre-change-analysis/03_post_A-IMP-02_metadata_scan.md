# A-IMP-03 Step 5 — Post-A-IMP-02 Metadata Scan

## Scan control

- Scan date: 2026-07-21 (UTC+8)
- Repository: `https://github.com/chen8089/CBS.git`
- Branch: `feature/A-IMP-03-account-onboarding`
- Parent: `origin/feature/A-IMP-02-contact-separation`
- Commit / merge base: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- Source API: 67.0
- `force-app` parent delta: 0 files
- `force-app` working-tree changes: 0
- Scope: read-only static scan; no deployment, activation, DML or UAT

## Manifest validation

| Item | Component | Static classification | Current state | Dependency / disposition |
|---|---|---|---|---|
| A03-001 | `Account.Client_Code__c` | FOUND, DEPENDENCY | Text(255), required=false, unique=false, Chinese source label | R01–R03; RUNTIME GATED |
| A03-002 | `Account.Client_Status__c` | FOUND, DEPENDENCY | Active/Inactive only, required=false, Chinese source label | R01/R03 and status mapping; RUNTIME GATED |
| A03-003 | `Account.Onboarding_Status__c` | NOT FOUND, DEPENDENCY | No field/path collision | A-IMP-08/11 exposure; READY after Manifest approval |
| A03-004 | `Account.Onboarding_Cycle__c` | NOT FOUND, DEPENDENCY | No field/path collision | Start/idempotency design |
| A03-005 | `Account.Onboarding_Progress__c` | NOT FOUND, DEPENDENCY | No field/path collision | Progress/concurrency proof; HOLD |
| A03-006 | `Account.Onboarding_Submitted_By__c` | NOT FOUND, DEPENDENCY | No field/path collision | R09/R10 approval/FLS gate |
| A03-007 | `Account.Onboarding_Submitted_At__c` | NOT FOUND, DEPENDENCY | No field/path collision | R10 approval gate |
| A03-008 | `Account.Onboarding_Approved__c` | NOT FOUND, DEPENDENCY | No field/path collision | R09/R10 and A-IMP-06 interface |
| A03-009 | `Account.Onboarding_Approved_By__c` | NOT FOUND, DEPENDENCY | No field/path collision | R09/R10 checker gate |
| A03-010 | `Account.Onboarding_Approved_At__c` | NOT FOUND, DEPENDENCY | No field/path collision | R10 approval gate |
| A03-011 | `Account.Onboarding_Completed_At__c` | NOT FOUND, DEPENDENCY | No Account field/path collision; same suffix on Case is not a collision | R10 and A-IMP-06 interface |
| A03-012 | `Task.Type` / `TaskType` | FOUND, DEPENDENCY | Call, Meeting, Other; no Client Onboarding value | R07/R12; RUNTIME GATED |
| A03-013 | `CBS_Start_Client_Onboarding` | NOT FOUND, DEPENDENCY | No Flow or FlowDefinition collision | R01–R05/R07/R10; HOLD until idempotency/prerequisites close |
| A03-014 | `CBS_Onboarding_Task_Synchronisation` | NOT FOUND, DEPENDENCY | No Flow or FlowDefinition collision | R07/R10; HOLD |
| A03-015 | `CBS_Submit_Onboarding_Review` | NOT FOUND, DEPENDENCY | No Flow or FlowDefinition collision | R04–R06/R09/R10 |
| A03-016 | `CBS_Onboarding_Approval` | NOT FOUND, DEPENDENCY | No Approval Process/Flow collision; no approval-process files retrieved | R09/R10 feature/type/routing confirmation; HOLD |

No canonical A-IMP-03 API name is occupied by a different component. Source labels/target-value gaps on A03-001/A03-002/A03-012 are not API-name mismatches.

## Domain findings

### Account

- `Client_Code__c`, `Client_Status__c`, `Notification_Email__c`, `Email_Domain__c`, `SLA_Days__c`, `Approval_Required__c` and `Active__c` exist.
- `Client_Code__c` is not field-required or unique; `Client_Status__c` contains only Active/Inactive.
- `Active__c`, Account Type Prospect and `Client_Status__c` are overlapping lifecycle indicators requiring R01/R03 business mapping.
- Account history is disabled.
- No Account validation rule, Account trigger, Account onboarding Flow or Client Code matching/duplicate rule was found.
- Standard Account duplicate rule exists but does not provide controlled Client Code uniqueness.

### Task

- Task Type contains Call, Meeting and Other.
- Task Status contains Open and Completed.
- No A-IMP-03 Task custom field, validation rule, trigger or Account/Task Flow was found.
- Existing Task usage/collision remains R07 runtime evidence.

### Opportunity, Contract and Files

- Standard Opportunity/Contract metadata and value sets exist.
- Static source cannot prove per-Account Closed Won, valid Contract or signed Contract File evidence.
- No A-IMP-03 source change to Opportunity/Contract is authorised; R04–R06 remain runtime gates.
- Existing `ContentDocumentLink` code is consent/report/contact/case oriented, not an approved Contract onboarding evidence implementation.

### Automation and approval

- Eight Flows are retrieved; six are active and two draft.
- Active automation is Contact/Consent/Departure/Report oriented. No Flow starts on Account or Task.
- Four Apex triggers exist for Contact, Case, Consent Request Item and Report Request Item; none targets Account or Task.
- No approval-process metadata is retrieved.
- No A-IMP-03 onboarding Apex or LWC exists.

### Layout, FlexiPage and application

- Account layouts remain generic; CBS layout makes Client Code/Status layout-required while field metadata remains optional.
- `Account_Record_Page_Three_Column` is the only Account FlexiPage and contains no onboarding workspace.
- A-IMP-02 introduced `CBS_Client_User_Record_Page`, Contact layout separation and `Credit_Bureau` Contact overrides. These must not regress.
- Final Account page, app navigation and Business Development exposure remain A-IMP-08/A-IMP-11 scope.

### Permissions

- No onboarding-field FLS exists because the fields are absent.
- Existing profiles expose baseline Account fields inconsistently; the profile named `Read Only` has editable Client Code/Status FLS.
- A-IMP-03 must not create/assign final Business Development or external permissions without approved A-IMP-08 scope.

## A-IMP-02 overlap and drift result

A-IMP-02 changes 41 `force-app` files relative to remote main, including Contact fields/validation/layouts, Consent Request fields/Flows, Apex/tests, `CBS_Client_User_Record_Page`, `Credit_Bureau` and profiles. It changes zero direct Account/Task/TaskType/Account-page files in the scanned A-IMP-03 domain.

Mandatory no-regression overlaps:

1. Client User zero-consent creation and Contact purpose guards.
2. Consent active-request reuse/uniqueness and fault evidence.
3. Data Subject upload role separation.
4. Client User/Data Subject layouts and Lightning page.
5. `Credit_Bureau` Contact overrides.
6. Profiles, Contact history and effective access.
7. Experience Cloud external isolation boundaries.

## Manifest gaps already recorded as proposed amendments

The supplied 16-row template omits:

- `Account.Onboarding_Return_Reason__c`
- `Account.Onboarding_Cancel_Reason__c`
- seven Task checklist/audit fields
- `CBS_Onboarding_Return_Cancel`
- `CBS_Onboarding_Completion_Notification`
- exact validation/history/minimum-test-access components

These remain HOLD/DEFERRED proposal rows in `02_exact_metadata_manifest.csv` and `06_candidate_file_change_list.csv`. They are not authorised for build.

## Stop-condition assessment

- Unrecorded Account/Task automation: **not found statically**
- Canonical API-name collision: **not found**
- Need for a new onboarding object, Account Record Type, Apex service or LWC: **not demonstrated by static scan**
- A-IMP-02 direct Account/Task file overlap: **none**
- Runtime-only drift/feature/data evidence: **R01–R12 executed and all 61 original paths classified on 2026-07-21**. Decisions are recorded for FlowDefinition, Contact layout, queue, all 26 Profile paths and Site.com. Executable Flow-body drift is 0; 28 controlled A-IMP-02/A-IMP-08 baseline reconciliations remain.
- Checklist idempotency without an approved unique mechanism: **HOLD for design/runtime proof, not silently resolved**

Result: **Step 5 static metadata scan passed. Step 6 passed on 2026-07-21 after rebase verification, approved comparison-baseline synchronisation and fresh R11/R12 rerun.** All 10 checks passed and unexplained drift is 0. Account classifications, named owner records and Manifest amendments remain Step 7–8 blockers and do not authorise Phase 2.
