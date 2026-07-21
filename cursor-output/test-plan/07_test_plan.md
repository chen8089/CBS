# A-IMP-03 T01–T24 Test Plan

Status: **Step 8 finalized draft**. No test was executed; implementation, Sandbox deployment and UAT are not authorised.

Manifest linkage: see `manifest/07_manifest_build_gate_matrix.md` and `manifest/19_manifest_disposition_summary.csv`.

Common prerequisites:

- Approved Exact Manifest and post-A-IMP-02 rebased build.
- Masked test data and approved Account baseline decisions.
- Authorised Business Development maker, independent Administrator checker and external negative-test user.
- Runtime gates R01–R12 completed.
- Preserve query output, screenshots, Flow/approval history, debug/fault reference and fresh metadata diff as controlled evidence.

| ID | Setup / user context | Test action | Expected result | Required evidence |
|---|---|---|---|---|
| T01 | Eligible Prospect; Business Development | Start onboarding | One cycle; correct statuses; exactly nine Tasks with approved code/owner/mandatory/due-date values | Account/Task query and Flow result |
| T02 | Missing/duplicate Client Code or missing Notification Email | Start | Blocked with actionable message; no partial update or Tasks | Before/after query |
| T03 | No Closed Won Opportunity | Start | Blocked; no side effects | Opportunity and Account/Task query |
| T04 | Existing active cycle | Start again | Blocked; no duplicate cycle/checklist | Task count and cycle value |
| T05 | Ordinary or prior-cycle Task | Complete/reopen | No onboarding progress/status change | Task and Account query |
| T06 | Current mandatory item 03–08 without evidence | Complete | Blocked | Validation/Flow message |
| T07 | Current mandatory Task with valid non-sensitive reference | Complete | Completed By/At stamped once; progress recalculated once | Task history/query |
| T08 | Completed current mandatory Task | Reopen | Progress decreases; Ready returns to In Progress; evidence remains auditable | Before/after query/history |
| T09 | All mandatory Tasks complete | MARK_READY | Ready for Review; no automatic approval | Account query |
| T10 | Open mandatory Task or calculated mismatch | MARK_READY | Blocked | Task count and message |
| T11 | Missing/invalid Contract or executed File evidence | SUBMIT | Blocked; no approval request | Contract/File query and approval list |
| T12 | Fully valid Account | SUBMIT | Maker/time stamped; Pending Approval; protected fields controlled | Account and approval evidence |
| T13 | Submitter is checker | Attempt approval | Self-approval blocked | Approval action/error evidence |
| T14 | Authorised independent Administrator | Return with comments | Returned; approval false; correction unlocked; history retained | Approval history/Account query |
| T15 | Returned Account corrected | Resubmit | All gates rerun; new action is auditable | New approval/history evidence |
| T16 | Authorised independent Administrator | Approve | Approved fields/time; Completed; Client Status Active; gate true | Account and approval history |
| T17 | Incomplete onboarding | Cancel with/without reason | Missing reason blocked; valid reason cancels, gate false, open Tasks handled by approved rule | Account/Task/history query |
| T18 | Business Development/direct edit context | Edit protected statuses/audit fields | Blocked outside approved remediation path | UI/API negative evidence |
| T19 | Existing Active Account without owner decision | Baseline/migration attempt | No approval marker written and no automatic Completed status | Baseline register and query |
| T20 | External user | Attempt field/Task/approval/commercial access | Onboarding, Task, approval, Opportunity, Contract and File evidence inaccessible | UI/direct URL/API denial |
| T21 | A-IMP-02 regression contexts | Run Client User/Data Subject separation suite | Purpose/consent automation and PII controls unchanged | A-IMP-02 regression report |
| T22 | Duplicate and concurrent start/Task events | Submit concurrent/repeated events | No duplicate cycle or checklist item; deterministic progress | Transaction/task counts and fault evidence |
| T23 | Controlled fault injection | Trigger start/sync/submit fault path | Durable sanitised evidence; no secret/PII; no silent partial state | Case/log/notification and before/after query |
| T24 | Read-only metadata operator | Fresh retrieve and diff | Only approved Manifest changes; no Production/UAT actions | Hash, diff and component inventory |

Release acceptance requires every applicable test to pass with reviewed evidence. T20 and T21 are mandatory no-regression gates; T22 is a design/implementation blocker until an enforceable idempotency method is approved.

## Step 8 gate notes

- T19 validates Step 7 rule: no automatic `Onboarding_Approved__c` or Completed status for existing Accounts.
- T02/T18/T24 align to RUNTIME GATED Manifest rows A03-001, A03-002 and control enablement waves.
- T01–T17 and T22–T23 remain blocked while A03-013, A03-014, A03-016 and A03-P01–P07 are HOLD.
