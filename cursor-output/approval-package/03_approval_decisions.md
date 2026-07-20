# A-IMP-02 Approval Decision Log

## RC01 - Metadata Git baseline

- Decision date: 2026-07-20
- Decision source: written project-owner instruction in Cursor conversation
- Decision: approve commit `8391a96` as the new Salesforce metadata Git
  baseline for A-IMP-02 comparison.
- Result: RC01 resolved.

Implementation effect:

- Subsequent A-IMP-02 metadata diffs must use `8391a96` as the comparison
  starting point.
- The earlier `baseline-A-IMP-02` tag and original ZIP remain immutable
  historical evidence.
- This approval does not declare every runtime value correct.
- This approval does not resolve RC02-RC15.
- This approval does not authorise metadata implementation, deployment,
  activation or Salesforce data changes.

## RC02 - Data remediation

- Decision date: 2026-07-20
- Decision source: written instruction in Cursor conversation
- Authority confirmation: the user confirmed that the approval formally
  represents both the business owner and privacy owner.
- Runtime evidence: `R04-RERUN-02` returned zero rows.
- Decision: approve the completed RC02 remediation.
- Result: RC02 resolved.

The RC02 decision itself did not approve the four R08 assignments; those
assignments were addressed by the separate RC04 decision below.

## RC04 - Client User permission-set retention

- Decision date: 2026-07-20
- Decision source: written instruction in Cursor conversation
- Authority confirmation: the user confirmed that the decision formally
  represents both the security owner and data owner.
- Runtime evidence: `R08-RERUN-02` found four assignments across two active
  external Client Users.
- Decision: retain `Set_Custom_Object_To_Partner` and
  `partner_community_User_Permissions_set` for both users.
- Business rationale: these permission sets provide required Community access
  and object-view permissions for Client Users.
- Result: RC04 resolved by approved retention.

The approval covers the four current assignments only. It does not approve
additional users, broader permissions or A-IMP-08/A-IMP-09 implementation.

## R09-02 - Shield Field Audit Trail applicability

- Decision date: 2026-07-20
- Decision source: written administrator confirmation in Cursor conversation
- Decision: Field Audit Trail is not licensed or not enabled and A-IMP-02 does
  not rely on extended retention.
- Result: R09-02 closed as not applicable.

Standard Contact field-history capacity and retention assumptions apply. No
extended retention or Shield capacity is claimed.

## RC07 - Corrected R06 cross-status rule

- Decision date: 2026-07-20
- Decision source: written approval in Cursor conversation
- Decision: group `Pending`, `Sent` and `Viewed` records together without
  grouping by `Current_Status__c`.
- Execution result: zero cross-status duplicate groups.
- Result: RC07 resolved.

This approval corrects the read-only evidence rule. It does not authorise DML,
backfill, deployment or activation of M013B-M013D.

## RC08 - M018 shared layout strategy

- Decision date: 2026-07-20
- Decision source: written selection in Cursor conversation
- Evidence: `Contact-Contact Layout` is the sixth M018 layout and is shared by
  Data Subject-family, Client User and Master Record Types.
- Decision: amend the Manifest to add controlled Page Layout Assignment
  changes so different Record Types use dedicated layouts.
- Rejected alternatives: modify the shared layout with cross-record-type impact
  or accept continued Data Subject-family exposure.

The strategy is approved, but implementation remains stopped until the exact
Profile/Record Type assignment matrix and M021/A-IMP-09 boundaries are added
to and approved in the Manifest.

### Internal matrix approval

- Effective Permission Set review result: pass
- Approved internal Profile files: 12
- Approved assignment changes: 46
- Approval date: 2026-07-20

The approval excludes Experience Cloud Profile assignment changes. The
Customer Community Plus Client User/Data Subject shared Community layout
is retained unchanged under the previously confirmed boundary. Community
layout redesign remains deferred to A-IMP-09; A-IMP-02 performs no-regression
verification only.

## M030 exact test suite approval

- Approval date: 2026-07-20
- `AImp02ContactSeparationTest`: approved for creation
- `BatchExcelUploadControllerTest`: approved for modification
- `ReportRequestItemTriggerHandlerTest`: retain and run
- `ConsentStateTransitionServiceTest`: retain and run
- `ConsentRequestResolverServiceTest`: retain and run
- `ExperienceClientDataIsolationTest`: retain and run
- `UatClientUserIsolationE2ETest`: Sandbox UAT only

`UatClientUserIsolationE2ETest` uses `SeeAllData=true`, may skip when suitable
users are unavailable and is not deployment-blocking evidence by itself.

This resolves RC09. The classes were implemented and executed in ChenTest;
final post-deployment run `707BK00001B1HY3` passed all 59 methods.

## RC10 implementation and Category E/G/H applicability

- Approval date: 2026-07-20
- Target: `cbsneworg@creditbureau.com.sg.chentest`
- Org ID: `00DBK00000C9kEP2AZ`
- Approved implementation: M012-M016, M013A-D dependencies and M030.
- Category E: approved NOT APPLICABLE.
- Category G: approved NOT APPLICABLE.
- Category H: approved NOT APPLICABLE.

The user confirmed that the E/G/H decisions represent the corresponding
business-owner authorities. Unknown individual names are not inferred.

The scoped check-only and ChenTest deployment succeeded. This approval did not
authorise Salesforce data remediation, Production deployment, or waiver of
the B/C/D/F/I owner sign-offs.

Before the final approval below, RC10 and RC11 had these open items:

- four historical Client User-linked CRIs required approved disposition;
- manual B-08, D-01 and F-02 evidence was pending;
- B/C/D/F/I owner sign-offs were pending;
- Experience page review and owner sign-off were pending.

## A-IMP-02 Phase 2 final implementation approval

- Approval date: 2026-07-20
- Decision source: explicit written confirmation in Cursor
- Authority: user representing B/C/D/F/I owners, Experience/Community owner
  and project owner
- Decision: approve all remaining outstanding items and formally accept the
  associated risks.

Approved exceptions:

1. retain the four historical Client User-linked Consent Request Items without
   data remediation;
2. waive B-08, D-01 and F-02 manual UAT evidence;
3. waive Experience page screenshot evidence;
4. approve B/C/D/F/I and Experience/Community owner sign-offs.

Result:

- RC10: `RESOLVED_APPROVED_EXCEPTION`
- RC11: `RESOLVED_APPROVED_EXCEPTION`
- A-IMP-02 Phase 2 ChenTest implementation: **APPROVED**

No Salesforce data change was executed. This decision does not independently
authorise Production deployment.
