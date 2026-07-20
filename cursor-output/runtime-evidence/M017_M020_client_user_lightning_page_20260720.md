# M017-M020 Client User Lightning Page ChenTest evidence

- Environment: ChenTest
- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- Executing user ID: `005d50000060YnpAAE`
- Final deployment UTC: `2026-07-20T13:25:51Z` to
  `2026-07-20T13:26:40Z`
- Result: `PASS / DEPLOYED`

## Implemented scope

- M017: cleaned `Contact-CBS Contact - Client User Layout`.
- M019: created `CBS_Client_User_Record_Page` using Salesforce standard
  Lightning components only.
- M020: activated that FlexiPage only for:
  - `Admin` + `Contact.Client_User` + `Large`
  - `Admin` + `Contact.Client_User` + `Small`
- No Community, Experience Cloud or Business Development override was added.

The page follows the supplied Client Users reference pattern:

- full-width highlights panel with controlled Edit action;
- Details and Related tabs;
- two-column Dynamic Forms detail area;
- right sidebar with related-list quick links, Activity and Files.

The page and layout contain no Data Subject identity, MyInfo, consent, report,
departure or matching fields/components and no Login As, portal
enable/disable, Delete, Clone, Change Owner, Change Record Type or Share
action.

## Requiredness dependency

Salesforce initially reinserted four object-level required fields into the
Client User layout. The approved M001-M004/M009A-M009C atomic design was
therefore completed:

- `Full_Name__c`, `ID_Type__c`, `ID_Number__c` and
  `Employment_Status__c` are no longer globally required and no longer feed
  tracked.
- Three active stage-scoped validation rules preserve required identity
  controls for Data Subject, Singpass and Non-Singpass processing.
- Final metadata retrieval confirmed all four fields have
  `required=false`, all three rules have `active=true`, and the Client User
  layout no longer contains those fields.

## Validation and deployment

- Initial FlexiPage check-only: `0AfBK00000BUDuL0AX` — failed because a new
  page cannot use parent-only `REPLACE` region mode; corrected before deploy.
- M017-M020 check-only: `0AfBK00000BUCdK0AX` — passed.
- Initial M017-M020 deploy: `0AfBK00000BUDvx0AH` — passed.
- M001-M004/M009 atomic check-only: `0AfBK00000BUDzB0AX` — passed.
- M001-M004/M009 atomic deploy: `0AfBK00000BUABi0AP` — passed.
- Final package check-only with blocking tests: `0AfBK00000BUEGv0AP` —
  passed.
- Final deployment with blocking tests: `0AfBK00000BUEK90AP` — passed.
- Components in final deployment: 16 of 16.
- Component errors: 0.
- Rollback on error: enabled.

## Regression

The first run after activating stage-scoped validation exposed incomplete test
fixtures and duplicate request setup. Test fixtures were corrected to satisfy
the approved identity rules and reuse Flow-created active requests.

- Final deployment test methods: 57
- Passed: 57
- Failed: 0
- Skipped: 0
- Result: 100% pass

## As-built verification

- Retrieve job: `09SBK000009smKG2AY`
- Local and retrieved Layout, FlexiPage and CustomApplication files matched.
- Layout SHA-256:
  `624E97FCBE9CB2AA76E2ECB11031330871A37B171E040B06EECD2769B679F67D`
- FlexiPage SHA-256:
  `FD0ED508B04B6F0C4BE03CBF202DDFEF3831E835C852B916AC0BC075C4F55737`
- Application SHA-256:
  `8011A6B19FCA8E5FFC67BE5864F1FF1AAC5554C7F4907BB9D9DF65F292F1269B`

## Visual QA

Result: `PASS`

The operator-provided ChenTest screenshot for Client User `OBC Bank HR`
confirmed:

- the Credit Bureau app renders the dedicated Client User record page;
- the header exposes the controlled Edit action;
- Details and Related tabs are present;
- User Information, Account Information, Client Access and System Information
  sections render in the expected two-column structure;
- Related List Quick Links and the standard Activity panel render in the right
  sidebar;
- Portal Role, Can Approve and Is Active render in the Client Access section;
- no identity/MyInfo, consent, report, departure or matching component is
  visible;
- no Login As, portal enable/disable, Delete, Clone, Change Owner, Change
  Record Type or Share action is visible.

This closes the authenticated Admin-context visual-QA item.

## Final disposition

The Salesforce-standard Client User Lightning Record Page and its Admin
Small/Large activation are deployed and active in ChenTest. Production and
Community activation remain outside this task.
