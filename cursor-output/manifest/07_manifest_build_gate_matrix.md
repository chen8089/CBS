# Manifest Build Gate Matrix

This matrix separates **metadata build**, **runtime data preparation**, **control enablement** and **automation activation**. Each column is an independent approval gate.

| Manifest row | Metadata build | Runtime data prep | Control enablement | Automation activation |
|---|---|---|---|---|
| A03-003 Onboarding_Status__c | Wave 1 after Manifest approval | Not applicable | With validation rules if approved | With start/submit Flows |
| A03-004 Onboarding_Cycle__c | Wave 1 after Manifest approval | Not applicable | With validation rules if approved | With start Flow |
| A03-001 Client_Code__c | Wave 1 modify inactive | Wave 2 remediation required | Wave 3 uniqueness after dry-run | Used by start/submit Flows |
| A03-002 Client_Status__c | Wave 1 modify inactive | Wave 2 mapping required | Wave 3 validation after mapping | Used by completion path |
| A03-006 to A03-011 audit fields | Wave 1 create inactive | Not applicable | FLS after A-IMP-08 amendment | With submit/approval/completion |
| A03-012 Task.Type | Wave 1 modify inactive | Migrate only approved Tasks | Before checklist automation | Before start/sync Flows |
| A03-013 Start Flow | Wave 4 deploy inactive | Requires approved test fixtures | Requires approved checklist design | Separate activation approval |
| A03-014 Sync Flow | HOLD — no build | Not applicable | Requires idempotency approval | Separate activation approval |
| A03-015 Submit Flow | Wave 4 deploy inactive | Requires Contract/File fixtures | Requires approval routing | Separate activation approval |
| A03-016 Approval | HOLD — no build | Not applicable | Requires feature confirmation | Separate activation approval |
| A03-005 Progress | HOLD — no build | Not applicable | HOLD | HOLD |
| A03-P01 to A03-P07 proposed rows | HOLD — amendment required | Case-by-case | Case-by-case | Case-by-case |
| A03-P09 baseline remediation | ANALYSIS ONLY | Wave 2 separate approval | Not a metadata row | Not applicable |
| A03-P10 A-IMP-02 retention | ANALYSIS ONLY | Not applicable | Not applicable | Not applicable |

## Minimum Phase 2 entry conditions

1. Written Manifest approval.
2. Rebase onto final approved A-IMP-02 as-built and rerun diff/regression.
3. Close or explicitly defer every HOLD row affecting the chosen build slice.
4. Preserve Step 7 rule: no automatic `Onboarding_Approved__c` backfill.

## Test mapping

- Wave 1–3 evidence: T02, T18, T19, T24
- Start/sync/submit: T01–T12, T22
- Approval/return/cancel: T13–T17
- Regression: T20, T21
- Fault handling: T23

Reference: `test-plan/07_test_plan.md`
