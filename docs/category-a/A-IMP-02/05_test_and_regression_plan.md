# A-IMP-02 Test and Regression Plan

Status: Gate 1 draft; no tests executed
Target org placeholder: `TARGET_ORG`

## Entry gates

- Exact Phase 2 approval statement has been received.
- Current HEAD drift is reconciled against `baseline-A-IMP-02`.
- M018 sixth layout and M030 exact test API names are approved.
- R06 evidence rule detects duplicates across all active statuses.
- R01-R09 evidence and required owner dispositions are approved.
- All runtime-gated controls remain inactive until their individual gates pass.

## Approved M030 exact test set

Deployment-blocking:

- `AImp02ContactSeparationTest` — create
- `BatchExcelUploadControllerTest` — modify
- `ReportRequestItemTriggerHandlerTest` — retain and run
- `ConsentStateTransitionServiceTest` — retain and run
- `ConsentRequestResolverServiceTest` — retain and run
- `ExperienceClientDataIsolationTest` — retain and run

Sandbox UAT only:

- `UatClientUserIsolationE2ETest` — retain and run separately; because it uses
  `SeeAllData=true` and may skip, it cannot be the sole deployment evidence.

## Static and metadata validation

1. Validate every changed path against M001-M030.
2. Confirm no A-IMP-08 permission or A-IMP-09 route/sharing change.
3. Confirm M001-M004 and M009A-M009C are one atomic package.
4. Confirm M008A-M008C, M010, M013C, M022 and M023 are inactive.
5. Confirm no destructive metadata entry.
6. Confirm no PII/MyInfo field has `trackHistory=true`.

## Functional scenarios

- T01: Minimal Client User saves with Account, First Name, Last Name and Email.
- T02: Client User creation with Email creates or reuses zero consent requests.
- T03: Prohibited Client User data is blocked only after remediation approval and
  activation.
- T04: Data Subject, Singpass and Non_Singpass active-stage requiredness works;
  terminal historical records are not blocked solely for legacy gaps.
- T05: Batch upload populates none of Portal Role, Can Approve or Active Client
  User on the Data Subject family.
- T06: Repeat invitation reuses the existing Pending/Sent/Viewed request.
- T07: Terminal requests remain immutable and a valid new cycle is allowed.
- T08: Concurrent active request creation is rejected by the unique key.
- T09: Flow failure creates one sanitised High-priority Case owned by CBS
  Processing Queue without PII.
- T10: Client User duplicate by exact normalised Email plus Account is blocked.
- T11: Client User layout/page contains only approved business fields/actions.
- T12: Data Subject-family layouts contain no client-access fields.
- T13: Current external access is not broadened.
- T14: Business Development permissions remain deferred to A-IMP-08.
- T15: Rollback restores prior Flow, Apex, layout and validation state.

## Cross-category regression

- Category B consent creation and status progression
- Existing-hire and pre-hire batch upload
- Singpass and Non-Singpass staging
- Categories C-D report processing
- Categories B-I Contact and Consent Request Item automation
- Existing PartnerCommunity2 routes and current-state external access

## Negative tests

- No hard-coded Record Type IDs.
- No automatic PII clearing, merge, deletion or record-type conversion.
- No second active consent request across different active statuses.
- No Case fault description containing identity number, DOB or MyInfo values.
- No Lead matching in the new Client User matching rule.
- No Business Development user can activate access by editing Contact.

## Future check-only commands

These commands are documentation only and must not be run before approval:

```powershell
sf project deploy validate --manifest docs/category-a/A-IMP-02/package-A-IMP-02.xml --target-org TARGET_ORG --test-level RunSpecifiedTests
```

```powershell
sf apex run test --target-org TARGET_ORG --test-level RunLocalTests --wait 60 --result-format human
```

## Required evidence

- Command, timestamp, org ID and executing user
- Deploy-validation ID and component failures
- Apex/Flow test results and coverage
- Masked runtime extracts and approved disposition registers
- Admin, Data Subject-family and current external-context screenshots
- Fresh post-change metadata ZIP and SHA-256

No check-only deployment or test has been run in Gate 1.
