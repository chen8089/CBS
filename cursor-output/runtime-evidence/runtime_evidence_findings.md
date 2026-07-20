# A-IMP-02 Runtime Evidence Findings

Status: STOP - owner and security review required

## Execution identity

- Org alias: `ChenTest CBS`
- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- Sandbox confirmed: yes
- API version: `67.0`
- Queries executed: R01-R08 SELECT only
- DML executed: none
- Full PII retained by Cursor: none

Record IDs, Account IDs, Email and Username values in review outputs are
represented by stable SHA-256-derived tokens.

## Results

### R01 - Contact counts

- Data_Subject: 1
- Singpass: 119
- Non_Singpass: 2
- Client_User: 0
- Total Contacts represented: 122

### R02 - Client User prohibited data

- Rows: 0
- Interpretation: the target Org currently has no Client_User Contact returned
  by R01, so this does not prove that remediation logic is safe for future
  Client Users.

### R03 - Legacy Client Admin

- Rows: 0

### R04 - Data Subject-family access fields

- Rows: 117 of 122 Data Subject-family Contacts
- Singpass: 115
- Non_Singpass: 1
- Data_Subject: 1
- Portal Role HR: 5
- Portal Role Approver: 81
- Portal Role Subject: 31
- Active Client User = true: 2
- Can Approve = true: 0

`Subject` is not an active Portal Role value in the repository field metadata
reviewed during pre-build validation. This is unexplained runtime drift and a
stop condition.

No values may be cleared or changed without a masked record-level review,
business owner decision, privacy approval and separately authorised execution.

### R05 - Duplicate Client Users

- Rows: 0
- Interpretation is constrained by R01 returning zero Client_User Contacts.

### R06 - Active request duplicates

- Original query: 0 groups, but it grouped separately by active status.
- Corrected rule approved on 2026-07-20.
- Corrected cross-status query: 0 duplicate groups across `Pending`, `Sent`
  and `Viewed`.
- RC07 is resolved. Deployment, backfill and activation gates remain separate.

### R07 - Linked external users

- Rows: 2
- Active users: 2
- Profile: Customer Community Plus User
- Both linked Contacts are included in the R04 access-field result.

### R08 - Legacy assignments

- Rows: 4
- Both linked external users have:
  - `Set_Custom_Object_To_Partner`
  - `partner_community_User_Permissions_set`

This confirms the static effective-access concern and requires security review.
No A-IMP-08/A-IMP-09 permission change is authorised here.

### R09 - Setup checks

Partially complete.

- R09-01 Contact history capacity: collected; 17 of 20 standard fields tracked,
  with a target of 6 of 20 after controlled M025 replacement.
- R09-02 Shield retention policy: administrator confirms Field Audit Trail is
  not licensed or enabled and A-IMP-02 does not rely on extended retention;
  standard history assumptions apply.
- R09-03 CBS Processing Queue active membership: passes; Queue exists, supports
  Case and has one active direct user member.
- R09-04 Case create permission and required FLS: passes; Case is createable,
  all nine M014 fields are createable and target picklist values are available.
- R09-05 licence and feature availability: passes; relevant licences are active
  and the required features are available for the current scope.

R09 evidence collection is complete pending review. RC06 is resolved.

## Stop conditions triggered

1. Runtime Portal Role value `Subject` is not reconciled with the approved
   baseline metadata.
2. 117 Data Subject-family Contacts carry client-access role data.
3. Two active external users are linked to affected Contacts.
4. Both users hold both broad legacy permission sets.
5. R09 evidence is incomplete.
6. R06 cross-status uniqueness coverage remains unresolved.

## Disposition

- Stop metadata build, deployment and activation.
- Do not perform data remediation.
- Obtain business owner, privacy owner and security reviewer decisions.
- Complete R09 manually.
- Reconcile the target Org with the approved metadata baseline.

## Post-remediation update - 2026-07-20 09:19 UTC

- R04-RERUN-02 returned zero rows.
- R07-RERUN-02 returned two active linked external users and zero R04
  overlaps; RC03 is resolved.
- R08-RERUN-02 still returned four legacy permission-set assignments.
- Business and privacy owner approval of the R04 remediation was formally
  supplied in the Cursor conversation.
- Security and data owner approval was supplied to retain all four R08
  assignments as required Client User Community and object-view permissions.

The original findings above remain historical evidence. RC02 and RC03 are
resolved; RC04 is resolved by approved retention.

## RC05 verification update - 2026-07-20 09:32 UTC

- No Contact has `Portal_Role__c = Subject`.
- Sandbox active values are `HR`, `Approver` and `Client Admin`.
- Sandbox values exactly match repository metadata.

RC05 is resolved by runtime and metadata verification.
