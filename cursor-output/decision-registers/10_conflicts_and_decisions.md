# A-IMP-03 Conflicts and Decisions

## Open decisions

### D01 — A-IMP-02 baseline

- Evidence: `origin/feature/A-IMP-02-contact-separation` was fetched from `https://github.com/chen8089/CBS.git`. Tip `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916` contains ChenTest deployment retrievals; the approval package states `A-IMP-02 PHASE 2 CHENTEST IMPLEMENTATION APPROVED` and identifies approved baseline `8391a967683f5e07b3a4f4b01fe1db927fbff054`. Production/UAT remain unauthorised.
- Decision used for Phase 1: use the clean remote A-IMP-03 child branch exactly at the current A-IMP-02 tip; retain the 20260715 scan only as historical comparison evidence.
- Required before Phase 2: fetch and reconfirm the final approved A-IMP-02 tip/as-built; rebase only if the parent advanced; rerun diff, collision scan and regression.
- Status: RESOLVED for Step 3/current snapshot; mandatory Phase 2 refresh gate retained.

### D02 — Client Code enforcement

- Conflict: field is neither required nor unique; layout-only requiredness does not cover API/automation.
- Options: field uniqueness after remediation; matching/duplicate rule; validation plus controlled normalisation.
- Evidence: R01/R02 found 49 missing values and no normalised duplicate group among the three populated Client Codes.
- Risk: enabling any control before approved remediation can block existing records/integrations.
- Recommendation: approve the 49-row remediation/disposition first; no automatic numbering/merge/update.
- Step 7/8 update: business owner approved planning dispositions for all 52 Accounts; Wave 2 remediation remains a separate gate.
- Status: **POLICY APPROVED / RUNTIME REMEDIATION NOT AUTHORISED**.

### D03 — Client status migration

- Conflict: current values are Active/Inactive; target omits Inactive and `Active__c` is a competing indicator.
- Evidence: 52 Accounts comprise 3 Active, 1 Inactive and 48 blank statuses.
- Recommendation: business-owned mapping by Account; retain Inactive until all records/dependencies are resolved.
- Step 7/8 update: batch hold rule approved for 48 Accounts; individual Active/Inactive paths approved for the remaining four Accounts.
- Status: **POLICY APPROVED / MAPPING NOT IMPLEMENTED**.

### D04 — Existing Account baseline

- Conflict: metadata cannot prove historical onboarding evidence.
- Options per Account: rebuild and approve; authorised grandfather exception; new onboarding cycle; hold; exclude as non-CBS.
- Evidence: 52 masked decision rows populated and approved by **陈财 / CBS系统负责人** on 2026-07-21.
- Recommendation: require CBS business/data-owner decision; never auto-mark Approved/Completed.
- Status: **RESOLVED FOR PHASE 1 / IMPLEMENTATION NOT AUTHORISED**.

### D05 — Incomplete supplied Manifest template

- Conflict: the 16 supplied rows omit two approved Account reason fields, seven Task fields, return/cancel Flow, completion notification, validation/history and minimum access exposure.
- Recommendation: approve explicit amendment rows A03-P01–A03-P08 before build. Do not build omitted components based only on narrative.
- Step 9 update: amendment rows are included in the approved 26-row Manifest scope but remain **HOLD** for build.
- Status: **MANIFEST APPROVED IN SCOPE / BUILD HOLD FOR P-ROWS**.

### D06 — Checklist identity and concurrency

- Conflict: current-cycle checklist uniqueness must survive retries/concurrency, but no unique key field, custom metadata or Apex is approved.
- Options: prove an enforceable declarative design; approve a narrowly scoped unique key field; redesign transaction boundaries.
- Recommendation: architecture review and concurrency proof before approving A03-005/A03-013/A03-014.
- Status: HOLD.

### D07 — Approval engine

- Conflict: no approval assets are retrieved and Flow Approval Process availability/metadata shape/routing is unconfirmed.
- Evidence: R09/R10 returned 8 Flow definitions, 5 roles, 12 CBS permission assignments, 1 queue, 2 active administrator candidates and no custom notification type.
- Options: approved Flow Approval Process; separately approved Classic fallback only if feature gap is proven.
- Recommendation: obtain Setup/architecture confirmation and named routing approval; do not silently choose Classic.
- Status: HOLD.

### D08 — Opportunity, Contract and File prerequisites

- Conflict: static metadata proves objects/fields, not qualifying records or executed File evidence.
- Evidence: R04–R06 found zero Opportunities, Contracts and Contract File links in ChenTest.
- Recommendation: provide approved test fixtures in a later authorised test phase; keep A-IMP-04/A-IMP-05 lifecycle changes out of scope.
- Status: RUNTIME EXECUTED / NO POSITIVE PREREQUISITE EVIDENCE.

### D09 — Durable fault evidence

- Conflict: no shared durable framework was identified statically; A-IMP-02 proposes a sanitised Case interim mechanism.
- Recommendation: reconcile with post-A-IMP-02 as-built and approve reuse/interface. Do not introduce an unlisted object/Apex/logger.
- Status: HOLD.

### D10 — Permissions and pages

- Conflict: technical testing needs minimum internal exposure, while final roles/app/pages belong to A-IMP-08/A-IMP-11.
- Recommendation: specify exact minimum test access in an approved amendment or defer all exposure to those workstreams; never expose onboarding/commercial evidence externally.
- Status: DEFERRED/HOLD.

### D11 — History capacity

- Conflict: Account history is disabled; approved selected evidence competes with A-IMP-10 audit scope and platform limits.
- Evidence: R10 found zero Account fields with history tracking enabled.
- Recommendation: approve exact non-sensitive tracked fields and A-IMP-10 ownership before enabling.
- Status: HOLD.

### D12 — Live-org drift

- Conflict: ZIP has no Account/Task onboarding automation or approval, but connected-org-only components may exist.
- Evidence: R11/R12 classified all 61 paths: 26 expected retrieve noise, 5 expected A-IMP-02 baseline-ahead, 1 Sandbox-ahead FlowDefinition, 28 true owner conflicts and 1 binary Site.com review.
- Recommendation: retain the exact disposition register. Obtain A-IMP-02 approval for FlowDefinition version 6 and Contact layout; Security/Access decisions for all 26 profiles; Operations/Security queue disposition; and a semantic Site.com comparison. Do not bulk-copy live metadata.
- Decision update: adopt Sandbox FlowDefinition version 6 and Contact layout state through A-IMP-02; retain ChenTest queue membership; exclude Site.com from A-IMP-03; preserve readable/editable FLS for the four identity fields across all 26 Profiles. Step 6 rerun PASS with unexplained drift 0.
- Status: **RESOLVED FOR PHASE 1 EVIDENCE**; cross-workstream source implementation remains separately controlled before Phase 2.

### D13 — Existing profile access

- Conflict: the retrieved profile named `Read Only` has editable FLS for `Account.Client_Code__c` and `Account.Client_Status__c`; onboarding fields have no approved FLS model.
- Recommendation: include effective-access review in R09 and transfer the exact permission correction to A-IMP-08 or an expressly approved Manifest amendment. Do not grant external access.
- Status: HOLD/DEFERRED.

### D14 — Local/remote A-IMP-03 branch ancestry

- Historical conflict: the first local analysis branch was independently initialised from the controlled ZIP at `0c1bd879…` and had no common ancestor with GitHub.
- Resolution: the remote A-IMP-03 branch was created from A-IMP-02 tip `ed2f984c…`, then cloned cleanly to `C:\WorkSpace\CBS-A-IMP-03-Remote`. HEAD and both remote branch tips match; `force-app` is clean. The old workspace is audit-only.
- Status: RESOLVED for Step 2; Phase 2 rebase gate retained before first build commit.

### D15 — Exact Manifest approval

- Evidence: 26-row Manifest finalized Step 8; disposition summary and build gate matrix complete.
- Decision: **陈财 / CBS系统负责人** provided written Manifest approval on 2026-07-21.
- Effect: Gate 2 Controlled Build open; READY rows authorised for Wave 1 inert build only.
- Boundaries: HOLD/RUNTIME GATED rows, deployment, activation, DML and Production/UAT remain separately gated.
- Status: **APPROVED**.

## Closed package-control decisions

- Word lock file: ignored by delivery-owner instruction at 12:38 UTC+8.
- Guide-embedded attachment hashes: ignored by delivery-owner instruction at 12:47 UTC+8.
- Sole checksum authority: package `SHA256SUMS.txt`.

No conflict above authorises a metadata source change, DML, deployment, activation, Production operation or UAT.
