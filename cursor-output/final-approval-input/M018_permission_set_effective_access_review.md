# M018 Permission Set Effective Access Review

## Scope

Reviewed the 12 Profiles and 46 proposed Page Layout Assignment changes in:

- `M018_current_layout_assignment.csv`
- `M018_proposed_layout_assignment.csv`
- `M018_manifest_amendment_draft.csv`

No Salesforce metadata or assignments were changed.

## Permission Set metadata

- Permission Sets reviewed: 19
- Permission Sets with Contact object permission: 3
- Permission Sets with Contact Record Type visibility: 2
- Permission Sets defining layout assignments: 0

Contact Record Type visibility is present in:

1. `Set_Custom_Object_To_Partner`
   - Client User
   - Data Subject
   - Non-Singpass
   - Singpass
2. `partner_community_User_Permissions_set`
   - Non-Singpass
   - Singpass

`sfdcInternalInt__sfdc_activityplatform` grants Contact Read but does not grant
Contact Record Type visibility.

## Sandbox effective-assignment review

- Org ID: `00DBK00000C9kEP2AZ`
- Executed: `2026-07-20T11:15:41.1375832Z`
- Relevant active assignment groups across the 12 Profiles: **0**

None of the active users under the 12 proposed Profiles is assigned:

- `Set_Custom_Object_To_Partner`
- `partner_community_User_Permissions_set`
- `sfdcInternalInt__sfdc_activityplatform`

Active users under `System Administrator`, `Analytics Cloud Integration User`
and `End User` hold only their Profile-owned permission set or custom
Permission Sets that do not add Contact Record Type visibility.

The two approved external Client Users retain the partner Permission Sets under
RC04, but their `Customer Community Plus User` Profile is excluded from the 12
proposed changes under M021/A-IMP-09.

## SetupEntityAccess observation

The runtime `SetupEntityAccess` query returned zero Record Type access rows.
This result is not used alone as proof because Permission Set metadata directly
contains the controlled Record Type visibility definitions. The conclusion is
based on both metadata capability and actual active-user assignments.

## Result

**PASS**

No active Permission Set assignment creates an additional Contact Record Type
access path within the 12 proposed Profiles. Permission Sets do not override
Profile layout assignments.

## Approval

On 2026-07-20 the user approved the exact 12-Profile, 46-assignment proposal
after this effective-access review.

The approval does not include Experience Cloud Profile assignment changes,
additional Profiles, Field-Level Security changes, deployment or activation.

## Community layout boundary disposition

`Customer Community Plus User` remains assigned
`Contact-CBS Contact - SingPass- Community User` for Client User, Data Subject
and Singpass. This layout is itself one of the M018 field-removal candidates.
Retaining the assignment does not prevent a layout edit from affecting Client
User.

Under the confirmed Experience Cloud boundary, both Community layouts and all
Customer Community Plus assignments remain unchanged in A-IMP-02. Current-state
exposure is subject to no-regression verification, while redesign remains
deferred to A-IMP-09.

The approved M018 build scope is therefore limited to three internal dedicated
layouts and the 12 internal Profile files.
