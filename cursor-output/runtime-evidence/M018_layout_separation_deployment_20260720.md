# M018 ChenTest layout separation deployment evidence

- Environment: ChenTest
- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- Executing user ID: `005d50000060YnpAAE`
- Deployment UTC: `2026-07-20T12:53:34Z` to `2026-07-20T12:53:38Z`
- Result: `PASS / DEPLOYED`

## Controlled scope

- Modified three internal Data Subject-family layouts to remove
  `Portal_Role__c`:
  - `Contact-CBS Contact - Data Subject Layout`
  - `Contact-CBS Contact - Non-SingPass`
  - `Contact-CBS Contact - SingPass`
- Applied the approved 46 assignment changes to 12 internal Profiles.
- Retained `Contact-Contact Layout` unchanged.
- Did not modify Community layouts or Experience Cloud Profiles; those remain
  deferred to A-IMP-09.

## Validation and deployment

- Initial full-Profile check-only exposed unrelated baseline invalid-tab
  warnings. No M018 layout or assignment defect was reported.
- A sparse Profile source containing only approved `layoutAssignments` was used
  to avoid changing unrelated Profile settings.
- Successful check-only deployment ID: `0AfBK00000BUDKr0AP`
- Successful deployment ID: `0AfBK00000BUDMT0A5`
- Components deployed: 15 of 15
- Component errors: 0
- Rollback on error: enabled

## Post-deployment verification

The Tooling API `ProfileLayout` verification returned exactly five Contact
layout mappings for each of the 12 approved Profiles:

- Master: `Contact Layout`
- Client User: `CBS Contact - Client User Layout`
- Data Subject: `CBS Contact - Data Subject Layout`
- Non-Singpass: `CBS Contact - Non-SingPass`
- Singpass: `CBS Contact - SingPass`

Total verified mappings: 60 (12 Profiles x 5 mappings).

The three deployed layouts were retrieved under retrieve job
`09SBK000009snL92AI`. Each retrieved file matched the approved local source:

- Data Subject Layout:
  `93E8AD978A0EF8C0A80E9937DFBAF62B24EE18CAD6496D9E361C146708D057CE`
- Non-SingPass:
  `F972A7ACA449608ADC0441D693013AC346AA4CCE377AD85DCF49B1A3E60A9E49`
- SingPass:
  `836F15608FC43F2B714CD665D619C122C3788693D7E4CC19CEC0693C36D5D22F`

No `Portal_Role__c`, `Can_Approve__c`, or
`Is_Active_Client_User__c` field reference was present in the retrieved
Data Subject-family layouts.

## Regression

- Test run ID: `707BK00001B1AaN`
- Test classes: six approved deployment-blocking classes
- Tests run: 59
- Passed: 59
- Failed: 0
- Skipped: 0
- Pass rate: 100%

## Final disposition

M018 internal Client User/Data Subject page layout separation is implemented
and verified in ChenTest. Community page layout redesign remains unchanged and
deferred to A-IMP-09.
