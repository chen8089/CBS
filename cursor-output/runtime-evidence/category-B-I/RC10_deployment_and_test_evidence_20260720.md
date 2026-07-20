# RC10 ChenTest deployment and automated regression evidence

## Execution identity

- Org alias: `ChenTest CBS`
- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- Executing user ID: `005d50000060YnpAAE`
- Evidence date: `2026-07-20`

## Controlled deployment sequence

| Stage | ID | UTC result |
|---|---|---|
| New-field check-only | `0AfBK00000BUBsX0AX` | PASS at 2026-07-20T12:04:49Z |
| New-field deployment | `0AfBK00000BUBu90AH` | PASS at 2026-07-20T12:05:02Z |
| Field-visibility check-only | `0AfBK00000BUByz0AH` | PASS at 2026-07-20T12:08:00Z |
| Field-visibility deployment | `0AfBK00000BUC0b0AH` | PASS at 2026-07-20T12:08:19Z |
| Core Flow/M030 check-only | `0AfBK00000BUCDV0A5` | PASS; 6/6 AImp02 methods |
| Full scoped check-only | `0AfBK00000BUCWr0AP` | PASS at 2026-07-20T12:19:48Z |
| Quick deployment | `0AfBK00000BUCYT0A5` | PASS at 2026-07-20T12:20:19Z; 15/15 components |
| Final account-scoped key check-only | `0AfBK00000BUB4Y0AX` | PASS at 2026-07-20T12:31Z; 60/60 methods |
| Final account-scoped key deployment | `0AfBK00000BUCob0AH` | PASS at 2026-07-20T12:31:39Z; 15/15 components |

The full check-only ran the six approved blocking classes plus
`ConsentUploadControllerTest` as a coverage-support test. It executed 60
methods with zero failures. `BatchExcelUploadController` reached exactly
609/812 covered lines (75.0%) in that validated deployment.

## Post-deployment blocking tests

- Test run ID: `707BK00001B1HY3`
- Started: `2026-07-20T12:31:51Z`
- Result: PASS
- Methods: 59 passed, 0 failed, 0 skipped
- Execution time: 31,638 ms
- The six approved blocking classes all passed.
- Post-deployment `BatchExcelUploadController` coverage: 605/812 lines,
  reported by Salesforce as 75% after rounding. The deployment-validating
  coverage remains the exact 75.0% result above.

## Supplemental Sandbox UAT

- Test run ID: `707BK00001B0xaX`
- Started: `2026-07-20T12:22:28Z`
- Class: `UatClientUserIsolationE2ETest`
- Result: PASS; 1 passed, 0 failed, 0 skipped
- Read-only population check found two active portal users mapped to two
  different Accounts, so the top-level two-user prerequisite was satisfied.
- This SeeAllData test remains supplemental and is not deployment-blocking
  evidence.

## Deployed Flow state

Tooling API inspection after deployment:

- `contactApproveCreateConsentRequest` version 6: Active
- `ConsentRequestResolveActiveRequest` version 2: Active
- `Consent_Request_Item_Maintain_Active_Key` version 2: Active

The two new Flows run in System Mode without Sharing. Salesforce emitted an
informational data-safety warning. Their object scope is constrained to
Contact, Consent Request Item, Group lookup and sanitised Case creation.

## Runtime data checks

- Active request keys with duplicate counts: 0 groups.
- Active requests with a populated key: 0.
- Legacy Pending/Sent/Viewed requests without a key: 31.
- Client User Contacts: 3.
- Historical CRIs linked to Client User Contacts: 4, created between
  2026-06-11T01:58:33Z and 2026-07-06T10:04:32Z.

The four Client User-linked CRIs pre-date this deployment. The automated
new-record gate passed, but the existing data means RC10 cannot be closed
without an approved disposition. No runtime data was changed.

## Result

Automated implementation, deployment and approved blocking tests: **PASS**.

At execution time RC10 was stopped pending:

1. approved disposition for four historical Client User-linked CRIs;
2. manual B-08, D-01 and F-02 UAT evidence;
3. B/C/D/F/I owner approvals.

These items were subsequently closed by explicit written risk acceptance from
the user representing all named owners and the project owner. Final status:
**RESOLVED_APPROVED_EXCEPTION**.

