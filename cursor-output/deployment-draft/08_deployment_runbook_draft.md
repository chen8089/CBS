# A-IMP-03 Deployment Runbook — Draft

This document is planning evidence only. It does not authorise build, deployment, activation, data change, Production operation or UAT.

## Gate 0 — approvals and baseline

Stop unless all are true:

1. Exact Manifest and all proposed amendments are approved in writing.
2. A-IMP-02 has final approval and an approved as-built metadata retrieve/commit.
3. The A-IMP-03 implementation branch is rebased onto that baseline and the diff is revalidated.
4. R01–R12 evidence and masked exports are complete and reviewed.
5. Every existing Account has an approved baseline disposition (**Step 7 complete — 陈财 / CBS系统负责人, 2026-07-21**).
6. Client Code duplicates/missing values and Inactive mapping have owner-approved remediation plans.
7. Flow Approval Process metadata type, feature availability, limits, routing and checker population are confirmed.
8. Checklist idempotency/concurrency design is approved without unlisted components.
9. A-IMP-02 and Category B–F regression scope is approved.

## Proposed metadata build waves

### Wave 1 — inert values and fields

- Add approved Account onboarding fields.
- Add approved Task fields and `Client Onboarding` Task Type only if their Manifest amendments are approved.
- Keep validation, approval and Flows inactive.
- Do not assign external FLS or expose commercial/onboarding evidence.

Run static validation and check-only deployment in the approved Sandbox release process.

### Wave 2 — approved runtime data preparation

Separate approval required:

- Export protected before-values and expected counts.
- Execute only owner-approved Client Code/status/baseline remediation.
- Reconcile counts and decisions.
- Do not mark existing Active Accounts as onboarding-approved without explicit per-Account/rule approval.

This wave is not metadata deployment and is not authorised by Manifest approval alone. It requires a separate Wave 2 data-remediation approval referencing `decision-registers/05_existing_account_baseline_decision_register.csv`.

### Wave 3 — validation, uniqueness and history

- Enable only after dry-run queries report no unresolved records.
- Apply approved Client Code enforcement and protected-field controls.
- Enable only the approved history fields after capacity verification.
- Verify ordinary Account/Task operations remain valid.

### Wave 4 — automation and approval

- Deploy approved Flows inactive.
- Deploy/configure the approved approval process inactive.
- Confirm named checker, maker-checker separation, queues, notification/fault mechanism and permissions.
- Execute T01–T23 in controlled Sandbox context.
- Activate in dependency order only under separate activation approval:
  1. Task synchronisation/control dependencies.
  2. Start onboarding.
  3. Mark Ready/Submit.
  4. Approval and return/cancel paths.
  5. Completion notification.

### Wave 5 — assignments and exposure

Deferred to A-IMP-08/A-IMP-11 unless expressly added to the approved Manifest:

- Business Development permissions/roles/application.
- Final layouts, Lightning page, Path and actions.
- External access remains denied and unchanged.

## Verification

1. Execute T01–T24 and A-IMP-02 regression.
2. Requery lifecycle, Tasks, approval evidence and access gates.
3. Confirm zero unintended external visibility and zero User activation.
4. Fresh retrieve, SHA-256 and diff against the approved Manifest.
5. Produce as-built manifest and deviation register.

## Independent approval gates

- Metadata build approval.
- Check-only/Sandbox deployment approval.
- Data remediation approval.
- Validation/uniqueness/history activation approval.
- Flow/approval activation approval.
- Production release approval.
- UAT approval.

Passing one gate does not imply approval of any later gate.
