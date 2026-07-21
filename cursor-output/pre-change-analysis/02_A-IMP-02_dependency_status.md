# A-IMP-02 Dependency Status Record

## Verification

- Verification time: 2026-07-21 13:29 (UTC+8)
- Repository: `https://github.com/chen8089/CBS.git`
- Parent branch: `origin/feature/A-IMP-02-contact-separation`
- A-IMP-03 child branch: `origin/feature/A-IMP-03-account-onboarding`
- Local branch: `feature/A-IMP-03-account-onboarding`
- A-IMP-02 tip: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- A-IMP-03 remote tip: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- Local HEAD: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- Merge base: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- Ahead/behind: `0/0`
- `force-app` delta between parent and child: 0 files
- Current `force-app` working-tree changes: 0

Result: **Step 3 dependency branch/version verification passed for the current Phase 1 snapshot.**

## A-IMP-02 status

The remote approval package records:

- `A-IMP-02 PHASE 2 CHENTEST IMPLEMENTATION APPROVED`.
- Approved scoped metadata deployed to ChenTest.
- R01–R08 and R09 evidence recorded.
- Post-deployment/as-built retrieval evidence committed.
- Approved comparison baseline: `8391a967683f5e07b3a4f4b01fe1db927fbff054`.
- Latest dependency branch tip: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`.
- Production deployment and UAT are not authorised.
- M024–M025 history correction and remaining runtime-gated activations retain separate approvals.

Classification: **ChenTest Phase 2 implemented with as-built evidence; not Production-complete.**

## Overlap components

The following A-IMP-02 areas can affect A-IMP-03 and must remain unchanged unless an approved Manifest amendment explicitly authorises them:

1. Contact purpose fields, record types, validation rules and layouts.
2. `contactApproveCreateConsentRequest` and Consent Request creation/reuse/fault paths.
3. `Consent_Request_Item__c` purpose and active-request uniqueness components.
4. `BatchExcelUploadController`, its tests and Data Subject role separation.
5. `CBS_Client_User_Record_Page` and Client User layout assignments.
6. `Credit_Bureau` application overrides/navigation.
7. Contact history configuration and M024–M025 follow-up.
8. Profiles, permission sets and effective Client User access.
9. Experience Cloud routes, sharing and external no-regression boundaries.
10. CBS Processing Queue and sanitised durable fault evidence.

A-IMP-03 Account/Task onboarding components currently have no direct source delta on top of A-IMP-02.

## Required future refresh

Immediately before any A-IMP-03 Phase 2 build:

1. Fetch `origin/feature/A-IMP-02-contact-separation`.
2. Record the then-current approved A-IMP-02 tip and approval/as-built status.
3. If the parent advanced, rebase the clean A-IMP-03 branch onto it.
4. Require merge-base = current approved parent tip.
5. Re-run `force-app` diff, API collision scan and Exact Manifest validation.
6. Re-run A-IMP-02 regression, especially Client User zero-consent creation and Category B–F continuity.
7. Do not start from the archived 20260715-only workspace.

This future refresh requirement does not reopen Step 3 for the current Phase 1 snapshot; it is the mandatory Phase 2 entry gate.
