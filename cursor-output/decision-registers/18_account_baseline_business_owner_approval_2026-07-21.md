# Account Baseline Business Owner Approval Record

- Recorded: 2026-07-21T14:50:26+08:00
- Org: 00DBK00000C9kEP2AZ (ChenTest)
- Approval channel: Cursor business-owner confirmation
- CBS Business Owner: 陈财 / CBS系统负责人
- CBS Data Owner: 陈财 / CBS系统负责人
- DML/status changes: none
- Salesforce implementation authorised: none (Phase 2 planning only)

## Approval scope

The business owner approved AP-01 through AP-05 and the bulk policy direction recorded in `13_account_bulk_policy_decision_2026-07-21.md`. This approval authorises Phase 1 closure of Step 7 and Phase 2 planning. It does **not** authorise deployment, activation, DML, or writing `Onboarding_Approved__c`.

## Package decisions

| Package | Decision |
|---|---|
| AP-01 | Named CBS business/data owner: 陈财 / CBS系统负责人 |
| AP-02 | Batch hold rule approved for 48 Accounts: exclusion candidates remain on classification HOLD; no automatic exclusion |
| AP-03 | H-0ccf5d877077f67a: deactivate external access and exclude |
| AP-03 | H-901b28a9b096504e: documented grandfather exception; **not** onboarding-complete |
| AP-04 | H-3afd39c385c74a37: new onboarding cycle approved |
| AP-05 | H-b52d9048500f523e: Client Code remediation then new onboarding cycle approved |

## Cross-cutting confirmations

1. No existing Active/Inactive Account is grandfathered as onboarding-complete without evidence.
2. Missing Client Code disposition is approved only as planning input for Phase 2 remediation design.
3. External-user handling for the two affected Accounts follows the AP-03 decisions above.
4. Phase 2, deployment, activation and Production/UAT remain separately gated.

## Account counts after approval

- Total Accounts: 52
- Batch hold rule (AP-02): 48
- Deactivate/exclude (AP-03): 1
- Grandfather exception not onboarding-complete (AP-03): 1
- New onboarding cycle (AP-04): 1
- Remediate Client Code then new cycle (AP-05): 1
