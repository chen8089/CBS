# A-IMP-02 Document Consistency and Conflict Report

## Applied precedence

1. Confirmed pre-Phase 2 decisions D01-D08
2. Category A Solution Design v1.4
3. A-IMP-01 v1.1 Corrected
4. A-IMP-02 Cursor Execution Prompt v1.0
5. A-IMP-02 Revised Impact Report v1.1
6. A-IMP-02 Revised Exact Metadata Manifest v1.1
7. Current metadata as evidence, not target authority

## Resolved controlled-document differences

### Client User required fields

The original Cursor Execution Prompt includes Department and Portal Role in the
Client User core. Confirmed decision D01 and Manifest M007 supersede it:

- required: Account, First Name, Last Name and Email;
- optional at Contact level: Department and Portal Role;
- Portal Role becomes mandatory only in the later approved access-request or
  provisioning process.

### Validation Rule decomposition

The original prompt describes broader combined rules. The revised Manifest
controls the exact API names and split:

- M007;
- M008A-M008C;
- M009A-M009C;
- M010;
- M011.

No alternative combined rule may be created.

### External profile and Experience Cloud

The original prompt contemplated correcting the external layout assignment.
Confirmed D08 and M021/M026-M028 require retain-and-regression only. Full
permission, sharing and route redesign remains A-IMP-08/A-IMP-09.

## Resolved decisions and remaining stop conditions

### C01 - Metadata Git baseline (resolved)

On 2026-07-20 the project owner approved commit `8391a96` as the new metadata
Git baseline. Subsequent A-IMP-02 diffs must use that commit as their starting
point.

Disposition: RC01 resolved. The original ZIP/tag remain historical evidence.
Approval of the baseline does not approve the baseline content as the A-IMP-02
target.

### C02 - M024/M025 partial and incorrect history state

Current HEAD has Contact history enabled, but:

- approved governance fields are not tracked;
- 17 consent/processing fields are tracked;
- Record Type tracking is disabled.

This is neither the approved baseline nor the approved target.

Disposition: stop M024-M025.

### C03 - M018 shared-layout scope

Page Layout Assignment evidence supplied on 2026-07-20 confirms
`Contact-Contact Layout` as the sixth physical M018 component because it is
assigned to Data Subject, Non-Singpass and Singpass Record Types for multiple
Profiles.

The same layout is also assigned to Client User and Master. Removing fields
from it would therefore affect those views.

Disposition: API ambiguity resolved. The internal 12-Profile/46-assignment
matrix and rollback are approved after effective Permission Set review. The
shared Contact layout is retained. Both Community layouts and Customer
Community Plus assignments are retained unchanged under the confirmed
Experience boundary; redesign is deferred to A-IMP-09.

### C04 - M030 test API ambiguity

M030 identifies a logical regression suite but no exact Apex class API names.

Disposition: no new test class may be named or created without approval.
Existing tests may be scanned but not expanded under an invented API.

### C05 - R06 cross-status coverage gap

The approved R06 query groups by `Current_Status__c`. It can miss duplicate
active requests when the records have different active statuses, such as one
Pending and one Sent.

Disposition: reproduce the controlled query unchanged, but stop M013B-M013D
until the approved evidence rule covers cross-status uniqueness.

### C06 - Manifest-external high-risk dependencies

The scan found high-risk dependencies not controlled as change rows:

- `ConsentRequestItemTriggerHandler.cls`
- `consentRequestItemTrigger.trigger`
- `ConsentGuestAuthService.cls`
- `QRSiteContactConsentEmail.cls`
- `ConsentRequestResolverService.cls`
- `ConsentInsertUpdateConsentRequestItem.flow-meta.xml`
- `UpdateConsentRequestInsertCase.flow-meta.xml`
- `BatchExcelUploadValidationService.cls`
- `Contact_Record_Page1.flexipage-meta.xml`
- PartnerCommunity2 Contact detail view and recent-activity component

These components may be regression dependencies, but cannot be modified.
Any required modification must enter a separately approved Manifest revision.

### C07 - Current external exposure

Static metadata confirms:

- Client User maps to a SingPass Community User layout;
- `Set_Custom_Object_To_Partner` exposes all four Contact record types;
- legacy partner permissions provide broad Contact FLS;
- generic Contact list/detail/related-list routes exist;
- Contact sharing remains ControlledByParent with Account Edit sharing.

Disposition: R07/R08 and current-state Experience Cloud regression are
mandatory. No A-IMP-08/A-IMP-09 correction is authorised here.

## Conclusion

The controlled target is sufficiently clear for most Manifest rows, but current
metadata is materially drifted and C02-C06 prevent a safe build. Step 4 may
produce analysis artifacts only. No Salesforce metadata component may be
implemented, activated or deployed.
