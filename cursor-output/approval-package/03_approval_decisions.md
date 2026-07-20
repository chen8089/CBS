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
