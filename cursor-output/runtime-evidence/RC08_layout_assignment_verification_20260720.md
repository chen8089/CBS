# RC08 Contact Layout Assignment Verification

## Evidence

The operator supplied:

1. the complete Contact Page Layout list; and
2. the Contact Page Layout Assignment matrix covering all five Record Type
   columns.

The Sandbox contains seven Contact layouts:

1. `CBS Contact - Client User Layout`
2. `CBS Contact - Data Subject Layout`
3. `CBS Contact - Non-SingPass`
4. `CBS Contact - Non-SingPass - Community User`
5. `CBS Contact - SingPass`
6. `CBS Contact - SingPass- Community User`
7. `Contact Layout`

## Sixth M018 API identification

The assignment matrix shows `Contact Layout` assigned to `Data Subject`,
`Non-Singpass` and `Singpass` Record Types for multiple internal Profiles.

The sixth physical M018 layout is therefore:

- Metadata full name: `Contact-Contact Layout`
- Repository path:
  `force-app/main/default/layouts/Contact-Contact Layout.layout-meta.xml`

The prior API-name ambiguity is resolved.

## Shared-layout conflict

`Contact Layout` is also assigned to `Client User` and `Master` for many of the
same Profiles. Page Layout field removal is not conditional by Record Type.
Removing `Portal_Role__c`, `Can_Approve__c` and
`Is_Active_Client_User__c` from this shared layout would therefore also remove
them from Client User views that use the same layout.

## Disposition

On 2026-07-20 the user approved the controlled strategy to amend the Manifest
and add Page Layout Assignment changes so Data Subject-family and Client User
Record Types use dedicated layouts.

The following alternatives were not selected:

- modifying the shared layout and accepting Client User/Master impact; and
- excluding the shared layout while accepting continued exposure.

## Remaining gate

**STOP - MANIFEST AMENDMENT REQUIRED**

The revised Manifest must identify every affected Profile and Record Type
assignment, the target dedicated layout, M021/A-IMP-09 boundaries, regression
scope and rollback mapping. Those exact assignment changes require approval
before implementation.

No Layout or Profile assignment was changed during this verification.

## Internal matrix approval and remaining boundary

The 12 internal Profile files and 46 assignment changes were subsequently
approved after effective Permission Set review.

`Customer Community Plus User` still uses
`Contact-CBS Contact - SingPass- Community User` for Client User, Data Subject
and Singpass. Modifying that Community layout would affect Client User, so the
internal approval does not authorise that change.

The confirmed Experience Cloud boundary resolves this by retaining both
Community layouts unchanged in A-IMP-02 and deferring redesign to A-IMP-09.
Only current-state no-regression is permitted for those layouts.
