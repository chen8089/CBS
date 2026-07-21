# Account Baseline Pending Approval Summary

- Generated: 2026-07-21T14:47:33+08:00
- Org: 00DBK00000C9kEP2AZ (ChenTest)
- Accounts in baseline register: 52
- Accounts with written business/data-owner approval: 52 (policy direction only)
- Implementation authorised: none
- DML/status changes: none

## Step 7 status

The baseline decision register is populated for all 52 Accounts. Every row remains pending named CBS business/data-owner written approval. No Account may be treated as onboarding-approved or automatically updated.

## Approval packages

- **AP-01** (1 item): Assign named CBS Business Owner and Data Owner for Account baseline sign-off.
- **AP-02** (48 items): Per-Account CBS-client classification for Accounts with blank status and no lifecycle/access evidence. Bulk direction: exclusion candidate pending classification; not an approved exclusion.
- **AP-03** (2 items): External-access and historical-approval review for Accounts with active linked external Users but no Opportunity/Contract/File/Task evidence.
- **AP-04** (1 item): Approve start of a new onboarding cycle for an Active Account with a populated unique Client Code but no qualifying prerequisite evidence.
- **AP-05** (1 item): Approve Client Code remediation source and then a new onboarding cycle for an Active Account with missing Client Code.

## Accounts requiring individual attention (5)

| Account token | Status | Client Code | External users | Selected policy | Approval package |
|---|---|---|---|---|---|
| H-0ccf5d877077f67a | Inactive | Present | 1 | Access/history review HOLD | AP-03 |
| H-901b28a9b096504e | Active | Present | 1 | Access/history review HOLD | AP-03 |
| H-3afd39c385c74a37 | Active | Present | 0 | New onboarding cycle selected | AP-04 |
| H-b52d9048500f523e | Active | Missing | 0 | Remediate Client Code then new cycle | AP-05 |
| H-4dfe138aba56a92d | Blank | Missing | 0 | CBS classification HOLD (notification only) | AP-02 |

## Bulk classification batch (48 AP-02 Accounts)

Forty-seven Accounts share the same pending decision pattern: **HOLD - CBS CLIENT CLASSIFICATION REQUIRED** with blank status, missing Client Code, no Opportunity/Contract/File/Task evidence and no active external Users. One additional Account (H-4dfe138aba56a92d) is also AP-02 because it has blank status but only a notification-email indicator. Business may approve one written batch rule with named exceptions, or require per-Account classification.

Full token list: see 17_account_baseline_pending_approval_register.csv where Approval_Package=AP-02.

## Cross-cutting approvals still required

1. Confirm no existing Active/Inactive Account is grandfathered as onboarding-complete without evidence.
2. Approve disposition for 49 missing Client Codes before any uniqueness/enforcement control is enabled.
3. Approve handling of 2 active external linked Users before any access change or onboarding activation.
4. Record named approver name, role and approval date for every AP package.

## Files

- Baseline register: 05_existing_account_baseline_decision_register.csv
- Proposals: 12_account_business_decision_proposals.csv
- Pending approvals: 17_account_baseline_pending_approval_register.csv
- Bulk policy record: 13_account_bulk_policy_decision_2026-07-21.md
