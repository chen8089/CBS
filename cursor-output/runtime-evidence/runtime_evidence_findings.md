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

- Rows: 0 under the controlled query.
- The controlled query groups by active status and can miss duplicates spanning
  different active statuses. M013B-M013D remain blocked.

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

Not complete. Required operator evidence:

- Contact history capacity and tracked fields
- Shield retention policy
- CBS Processing Queue active membership
- Case create permission and required FLS
- licence and feature availability

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
