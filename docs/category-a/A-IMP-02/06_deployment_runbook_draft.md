# A-IMP-02 Deployment Runbook Draft

Status: Gate 1 planning only
Production deployment: prohibited
Target org placeholder: `TARGET_ORG`

## Hard gates

Do not execute deployment commands unless all applicable conditions hold:

1. Exact statement `APPROVE A-IMP-02 MANIFEST` is recorded.
2. Repository drift from `baseline-A-IMP-02` is reconciled.
3. M018, M030 and R06 conflicts have approved resolutions.
4. R01-R09 evidence is complete.
5. Required remediation registers have owner approval.
6. CBS Processing Queue has an active member.
7. Deployment user can create the sanitised fault Case.
8. Category B-I dry-run and regression prerequisites pass.

## Controlled waves

### Wave 0 - Read-only evidence

- Execute R01-R08 in the connected Sandbox.
- Capture R09 Setup evidence.
- Produce masked review extracts.
- Obtain record-level owner dispositions.
- Perform no update, delete, merge, conversion or backfill.

### Wave 1 - Conditional metadata build

- Implement only approved Manifest rows.
- Keep runtime-gated rules and automation inactive.
- Exclude M021 and M026-M028 changes.
- Exclude unresolved M018/M030 scope.
- Review every changed file against the physical-file list.

### Wave 2 - Check-only validation

Documentation-only command:

```powershell
sf project deploy validate --manifest docs/category-a/A-IMP-02/package-A-IMP-02.xml --target-org TARGET_ORG --test-level RunSpecifiedTests
```

Stop on any metadata collision, compile failure, Flow error or regression.

### Wave 3 - Separately approved data preparation

Not authorised by this runbook. Requires:

- approved record-level register;
- backup export;
- signed execution plan;
- before/after reconciliation.

### Wave 4 - Sandbox activation

Not authorised until Wave 0-3 evidence is approved. Activation must preserve the
M001-M004/M009A-M009C atomic package and individual runtime gates.

### Wave 5 - As-built verification

- Retrieve fresh metadata.
- Hash the new archive.
- Compare deployed components with the exact Manifest.
- Re-run R01-R09 and the complete regression suite.
- Record all deviations.

## Explicit exclusions

- Production deployment
- UAT generation or execution
- A-IMP-08 Business Development permissions
- A-IMP-09 Experience Cloud redesign
- Automatic data remediation
- Destructive changes

## Stop conditions

- Material baseline drift
- Unapproved mixed-purpose Client User
- Unresolved active consent duplicate
- Queue or Case permission failure
- Category B-I regression
- Broader external access
- Unapproved API name or component
- Failed check-only deployment or test
