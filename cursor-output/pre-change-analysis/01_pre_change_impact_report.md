# A-IMP-03 Phase 1 Pre-change Impact Report

## 1. Control status

- Execution date: 2026-07-21 (UTC+8)
- Executor: `hp` (OS account; business identity not independently verified)
- Scope: Phase 1 analysis only
- Technical baseline: `Credit Bureau Sandbox 20260715.zip`
- Baseline ZIP SHA-256: `a3c337d997a556dca2cd53492a5621dce09a39b4f9454ac0d24e7d88a6a93a80` — verified by `SHA256SUMS.txt`
- Source API: `67.0`
- Project structure: `sfdx-project.json` and `force-app/main/default` found
- Branch: `feature/A-IMP-03-account-onboarding`
- Original static-analysis baseline commit: `0c1bd8793ad8caa8871d1deb46f4b87142fac3db` (archived isolated workspace)
- Current clean child-branch commit: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- Baseline type: A-IMP-03 child branch exactly at current A-IMP-02 remote tip
- Metadata source changes during Phase 1: none

The Word temporary lock file and the guide's embedded attachment hashes were excluded by the delivery owner's written instructions at 12:38 and 12:47 UTC+8. `SHA256SUMS.txt` is the sole attachment-integrity authority.

Post-A-IMP-02 targeted revalidation on the clean child branch found zero `force-app` delta from A-IMP-02, no collision for the canonical A-IMP-03 field/Flow/approval names, and the same current-state gaps for `Client_Code__c`, `Client_Status__c` and Task Type. A full R11/R12 live-org retrieve comparison remains runtime-gated.

## 2. Seven primary controlled inputs and precedence

1. A-IMP-03 confirmed project decisions in `CBS_Category_A_A-IMP-03_客户账户生命周期与客户入驻_Cursor受控执行提示词_CN_v1.0.docx`.
2. `CBS_Category_A_Solution_Design_v1.4_Visual_Approved_and_Implementation_Ready.docx`.
3. `CBS_Category_A_A-IMP-01_Implementation_Mapping_and_Deployment_Plan_v1.1_Corrected.docx`.
4. A-IMP-03 Cursor controlled prompt v1.0 (workflow execution rules).
5. `CBS_Category_A_A-IMP-02_Phase_1_Pre_Change_Impact_Report_v1.1_Revised_for_Final_Phase_2_Approval.docx`.
6. `CBS_Category_A_A-IMP-02_Exact_Metadata_Manifest_v1.1_Revised.csv` together with the A-IMP-02 Cursor prompt v1.0 as dependency control.
7. `Credit Bureau Sandbox 20260715.zip` and read-only runtime evidence as current-state technical evidence only.

Where current metadata differs from approved target design, metadata proves current state but does not override controlled decisions.

## 3. A-IMP-02 dependency

The packaged A-IMP-02 v1.1 report states **“Decision complete - final approval and runtime evidence gate pending”** (2026-07-19). Newer remote evidence was fetched on 2026-07-21 13:15 (UTC+8):

- Repository: `https://github.com/chen8089/CBS.git`
- Branch: `origin/feature/A-IMP-02-contact-separation`
- Remote tip: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- Approved comparison baseline / merge base with remote main: `8391a967683f5e07b3a4f4b01fe1db927fbff054`
- Approval package status: `A-IMP-02 PHASE 2 CHENTEST IMPLEMENTATION APPROVED`
- Runtime/as-built evidence: ChenTest deployment and post-deployment retrieves recorded
- Remaining authority boundary: no Production deployment or UAT authorised

Therefore:

- Phase 1 static analysis may use the 20260715 baseline.
- A-IMP-03 Phase 2 must not start from this commit.
- Before Phase 2, confirm the final approved A-IMP-02 tip/as-built commit (currently remote tip `ed2f984c…`), rebase in a clean worktree, rerun the complete diff and Exact Manifest validation, and execute A-IMP-02 regression.

Overlap components:

- `Contact` purpose fields, record types, validation rules and layouts.
- Active Flow `contactApproveCreateConsentRequest`.
- `BatchExcelUploadController` and test.
- `Credit_Bureau` application and Client User page assignments.
- Contact history, profiles, permission sets, Experience Cloud routes and sharing.
- Durable fault evidence and administrator/queue dependencies.

A-IMP-03 must not modify these A-IMP-02 components in Phase 1 or silently absorb their scope.

## 4. Static metadata findings

### Account

- `Client_Code__c`: FOUND; Text(255), `required=false`, `unique=false`; CBS layout marks it required.
- `Client_Status__c`: FOUND; values Active and Inactive only.
- `Notification_Email__c`, `Email_Domain__c`, `SLA_Days__c`, `Approval_Required__c`: FOUND.
- `Active__c` is a competing lifecycle indicator and requires business disposition.
- Account history is disabled.
- No Account record type, onboarding validation, trigger, approval definition, or onboarding Flow was found.

### Task

- Standard Task is present with Type values Call, Meeting, Other and Status values Open, Completed.
- No controlled onboarding fields, validation, trigger, or Task onboarding Flow was found.
- No `Client Onboarding` Type value was found.

### Commercial prerequisites and Files

- Opportunity and Contract metadata exist.
- Opportunity `Closed Won` and Contract statuses are statically visible, but record-level readiness is not provable.
- Contract Files and signed-document evidence require runtime `ContentDocumentLink` checks.
- A-IMP-03 may read these dependencies but must not change Opportunity or Contract lifecycle metadata.

### Automation, approval, pages and access

- Eight retrieved Flows are consent/contact/case lifecycle automation (six active, two draft); none is Account/Task onboarding.
- Active `contactApproveCreateConsentRequest` now contains the A-IMP-02 Data Subject-family decision guard and exits Client Users without consent automation. It is a mandatory no-regression dependency, not an unresolved baseline P1 defect.
- No approval-process metadata was retrieved.
- `Account_Record_Page_Three_Column` and Account layouts are generic and contain no onboarding controls.
- No onboarding field permissions exist because the fields do not yet exist.
- The profile named `Read Only` currently has editable FLS for `Account.Client_Code__c` and `Account.Client_Status__c`; this is a material least-privilege conflict for future lifecycle controls.
- `Approval_Required__c` is exposed but no consuming automation was found; it must not be repurposed as the onboarding approval gate.
- No onboarding Apex/LWC was found or is authorised.

## 5. Dependency graph

`A-IMP-02 approved as-built` → `A-IMP-03 rebase/diff/regression`

`R01/R02/R03 business data` → `Client Code enforcement` + `Client status migration` + `existing Account decisions`

`A-IMP-04 Closed Won evidence` + `A-IMP-05 Contract/File evidence` → `Start/Submit eligibility`

`R07 Task inventory` + `approved idempotency design` → `checklist creation/synchronisation`

`R09 approver inventory` + `R10 approval-feature confirmation` → `maker-checker approval`

`approved Exact Manifest` → `isolated build` → `approved data remediation` → `validation/uniqueness/Flow activation`

## 6. Runtime evidence status

R01–R12 were executed read-only against ChenTest Sandbox Org `00DBK00000C9kEP2AZ` as `cbsneworg@creditbureau.com.sg.chentest` on 2026-07-21. No DML, deployment or activation occurred. Raw record exports are held outside Git in `C:\WorkSpace\CBS-A-IMP-03-runtime-private`; masked review copies, hashes, row counts and findings are registered in `cursor-output/runtime-evidence`.

Key results: 52 Accounts; 49 missing Client Codes; 47 missing notification emails; status distribution 3 Active, 1 Inactive and 48 blank; zero normalised duplicate groups among populated Client Codes; zero Opportunities, Contracts, Contract File links and onboarding/client-like Tasks; 2 active external linked Users; 5 roles; 12 CBS permission assignments; 1 queue; 8 Flow definitions; no Account history-tracked fields. Task `Type` is not available in this Org.

R11/R12 were rerun after confirming A-IMP-03 is up to date with A-IMP-02 and synchronising the approved comparison baseline for 2 A-IMP-02 and 26 A-IMP-08 paths. All 10 checks passed. The only raw change was the explicitly excluded `PartnerCommunity2.site`; unexplained drift is 0. **Step 6 status: PASS.**

## 7. Existing Account baseline

The masked baseline decision register contains one row for each of 52 Accounts. **Step 7 business policy approval was recorded on 2026-07-21** by **陈财 / CBS系统负责人** via Cursor business-owner confirmation. No Salesforce DML, deployment or activation was authorised.

| Approved disposition | Count | Implementation |
|---|---:|---|
| Batch hold rule (exclusion candidate, not approved exclusion) | 48 | Policy approved — not implemented |
| Deactivate access and exclude | 1 | Policy approved — not implemented |
| Grandfather exception (not onboarding-complete) | 1 | Policy approved — not implemented |
| New onboarding cycle | 1 | Policy approved — not implemented |
| Remediate Client Code then new onboarding cycle | 1 | Policy approved — not implemented |

Approval record: `decision-registers/18_account_baseline_business_owner_approval_2026-07-21.md`.

## 8. Risks and active stop conditions

1. A-IMP-02 ChenTest Phase 2 approval and remote deployment/retrieve evidence are available; the clean A-IMP-03 child branch currently matches its tip. The parent must still be refreshed immediately before Phase 2.
2. Runtime evidence found 49 missing Client Codes and no normalised duplicate group among the three populated values; status mapping remains a business decision for 48 blank, 3 Active and 1 Inactive Accounts.
3. Existing Account baseline policy decisions are approved by 陈财 / CBS系统负责人 for Phase 2 planning; Salesforce implementation remains separately gated.
4. Eight Flow definitions, 5 roles, 12 CBS permission assignments and 1 queue were inventoried, but no custom notification type was returned and approval feature/routing remains unapproved.
5. ChenTest contains zero Opportunity, Contract and Contract File evidence records; prerequisite behavior cannot be positively proven from current data.
6. Concurrent checklist idempotency is not proven without an approved unique-key mechanism or other enforceable design.
7. The supplied 16-row Manifest template omits controlled Task fields, reason fields, return/cancel and completion automation, validation/history and minimal access exposure. These are listed only as proposed Manifest amendments and remain HOLD.
8. A-IMP-02 and Category B–F runtime regression has not yet been executed for A-IMP-03, despite the clean static baseline.
9. Step 6 drift is closed for evidence purposes; cross-workstream source implementation remains separately controlled before Phase 2.

## 9. Phase 1 conclusion

Static analysis, R01–R12 read-only execution, Step 6 drift closure, Step 7 Account baseline policy approval, Step 8 Manifest finalization and **Step 9 Exact Manifest written approval** are complete.

**Exact Manifest approved on 2026-07-21 by 陈财 / CBS系统负责人.** Phase 1 analysis is closed. Gate 2 Controlled Build is open for the approved 26-row scope. This does **not** authorise Sandbox deployment, Flow/approval activation, data remediation DML, Production or UAT.

### Exact Manifest disposition (26 rows — approved scope)

| Disposition | Count | Post-approval build authority |
|---|---:|---|
| READY | 2 | Wave 1 inert field build authorised |
| RUNTIME GATED | 10 | Approved in scope; build blocked until gates close |
| HOLD | 11 | Approved in scope; no build until amendment/decision |
| DEFERRED | 1 | Deferred to A-IMP-08/A-IMP-11 |
| ANALYSIS ONLY | 2 | Boundary only |

Approval record: `decision-registers/20_manifest_written_approval_2026-07-21.md`.

### Remaining gates after Manifest approval

1. Rebase onto final approved A-IMP-02 as-built immediately before first Phase 2 commit.
2. HOLD rows: idempotency/progress, approval engine, proposed amendments.
3. RUNTIME GATED rows: Client Code/status remediation, approval routing, prerequisite fixtures.
4. Separate Wave 2 data-remediation approval for approved Account dispositions.
5. Separate deployment and activation approvals.
6. Mandatory A-IMP-02 regression (T21) before release acceptance.

## 10. Step 8 deliverables

- Exact Metadata Manifest: `manifest/02_exact_metadata_manifest.csv`
- Candidate change list: `manifest/06_candidate_file_change_list.csv`
- Disposition summary: `manifest/19_manifest_disposition_summary.csv`
- Build gate matrix: `manifest/07_manifest_build_gate_matrix.md`
- Step 8 summary: `manifest/19_step8_manifest_finalization_summary.md`
- Test plan draft: `test-plan/07_test_plan.md`
- Deployment draft: `deployment-draft/08_deployment_runbook_draft.md`
- Rollback draft: `rollback-draft/09_rollback_runbook_draft.md`
- Conflicts register: `decision-registers/10_conflicts_and_decisions.md`
- Approval package index: `decision-registers/19_phase1_approval_package_index.md`
- Manifest written approval: `decision-registers/20_manifest_written_approval_2026-07-21.md`

**Phase 1 status: COMPLETE. Exact Manifest approved 2026-07-21.**
