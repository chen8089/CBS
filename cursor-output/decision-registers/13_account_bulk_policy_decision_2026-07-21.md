# Account Bulk Policy Decision Record

- Recorded: 2026-07-21T14:06:57+08:00
- Scope: 52 masked Account baseline rows
- DML/status changes: none
- Implementation authorisation: none

## Selected policy

1. 47 Accounts with no CBS indicator or lifecycle/access evidence remain HOLD pending per-Account CBS-client classification; they are exclusion candidates only, not approved exclusions.
2. `H-4dfe138aba56a92d`, whose notification email is the sole positive indicator, remains a separate business-classification HOLD.
3. The Active Account with a populated unique Client Code is selected for a new onboarding cycle.
4. The Active Account with a missing Client Code remains HOLD for approved Client Code remediation, then a new onboarding cycle.
5. The two Accounts with active external linked Users remain HOLD for access entitlement and historical approval review.

These selections are recorded as bulk policy direction. A named CBS business/data owner, per-Account classification where required, and written sign-off are still mandatory. No Account value was changed.

## Business owner approval

- Approved: 2026-07-21T14:50:26+08:00
- Approver: 陈财 / CBS系统负责人
- Scope: AP-01 through AP-05 and cross-cutting confirmations in `18_account_baseline_business_owner_approval_2026-07-21.md`
- AP-02 batch rule: approved as classification HOLD for exclusion candidates; not approved exclusions
- Implementation: not authorised
