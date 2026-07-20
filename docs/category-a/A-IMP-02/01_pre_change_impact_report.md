# A-IMP-02 Gate 1 Pre-Change Impact Report

Status: analysis only
Date: 2026-07-20
Branch: `feature/A-IMP-02-contact-separation`
Salesforce source API version: `67.0`

No Salesforce metadata or data was changed during this Gate 1 analysis.

## 1. Controlled sources

Applied precedence:

1. Confirmed A-IMP-02 pre-Phase 2 decisions D01-D08
2. Category A Solution Design v1.4
3. A-IMP-01 v1.1 Corrected
4. A-IMP-02 Cursor Execution Prompt v1.0
5. A-IMP-02 Revised Impact Report v1.1
6. A-IMP-02 Revised Exact Metadata Manifest v1.1
7. Retrieved Salesforce metadata as current-state evidence only

## 2. Baseline verification

- Baseline archive: `Credit Bureau Sandbox 20260715.zip`
- Size: 16,216,067 bytes
- Expected and actual SHA-256:
  `a3c337d997a556dca2cd53492a5621dce09a39b4f9454ac0d24e7d88a6a93a80`
- Manifest: `CBS_Category_A_A-IMP-02_Exact_Metadata_Manifest_v1.1_Revised.csv`
- Manifest size: 21,776 bytes
- Expected and actual Manifest SHA-256:
  `3ef139987a3887ef960874126ed419314b95f651e271b7449a42eb29ef3be77e`
- All six files in `controlled-documents` match their corresponding
  `SHA256SUMS.txt` entries after normalising only the original package directory
  prefix.
- The Manifest has 37 controlled rows.
- Git baseline tag: `baseline-A-IMP-02` at `b664a1f`.
- Analysis starting HEAD: `8391a967683f5e07b3a4f4b01fe1db927fbff054`.

## 3. Repository drift

The current HEAD differs from `baseline-A-IMP-02` by 295 files, with 1,140
insertions and 560 deletions. The same HEAD was observed on `main`,
`origin/main`, and `origin/feature/A-IMP-02-contact-separation`.

Material drift:

- Baseline Contact history is disabled and has zero tracked Contact fields.
- Current HEAD enables Contact history and tracks 17 processing/consent fields.
- The approved governance fields remain untracked.
- Required A-IMP-02 components such as M007-M011, M013A-M013C, M019 and
  M022-M023 remain absent.

Therefore HEAD cannot be treated as either the approved baseline or a compliant
A-IMP-02 implementation. No metadata build may start until this drift is
reconciled.

## 4. Controlled-document consistency

Resolved by approved precedence:

- The original Execution Prompt says Department and Portal Role are required
  for Client User. Confirmed decision D01 and Manifest M007 supersede this:
  Account, First Name, Last Name and Email are required; Department and Portal
  Role are optional at Contact level.
- The original prompt describes combined validation-rule concepts. The revised
  37-row Manifest controls the exact split into M007, M008A-M008C,
  M009A-M009C, M010 and M011.
- External profile/layout correction and full Experience Cloud redesign remain
  deferred under D08, M021 and M026-M028.

Unresolved conflicts:

1. M018 says six Data Subject-family layouts. Five purpose-specific physical
   layouts were identified. The controlled documents do not map the sixth API
   name unambiguously; `Contact-Contact Layout` must not be assumed without
   approval.
2. M030 names a logical regression suite but does not provide exact Apex test
   class API names.
3. Approved R06 groups by `Current_Status__c`. This does not detect two active
   requests with the same Data Subject/Account/purpose when their active
   statuses differ, for example one Pending and one Sent. M013B-M013D must stop
   until the query/evidence rule is clarified.
4. Current HEAD history metadata conflicts with both the approved baseline and
   M024-M025 target.

## 5. Manifest API, path and dependency validation

### M001-M011

- M001-M006: API names and baseline paths confirmed.
- M001-M004 must be deployed atomically with M009A-M009C.
- M005-M006 require R03 and an owner-approved legacy Client Admin disposition.
- M007-M011 and M008A-M008C/M009A-M009C have available API names and no
  collisions; their Validation Rule files do not yet exist.
- M010 depends on M015-M016 and R04. The current upload controller still writes
  `Portal_Role__c`.

Expected Validation Rule path pattern:

`force-app/main/default/objects/Contact/validationRules/<API>.validationRule-meta.xml`

### M012-M020

- M012 exists at
  `force-app/main/default/flows/contactApproveCreateConsentRequest.flow-meta.xml`.
  It currently runs for every new Contact with Email.
- M013A and M013B field API names are available and files are absent.
- M013C Flow API name is available and the file is absent.
- M013D and M014 are logical modifications to M012, not independent Flow files.
- M015-M016 class paths are confirmed; both still populate/tolerate
  `Portal_Role__c`.
- M017 path is confirmed and retains prohibited fields/actions.
- M018 remains blocked on the unresolved sixth-layout API name.
- M019 API name is available and the FlexiPage is absent.
- M020 application path is confirmed and has no Client User override.

### M021-M030

- M021 current external profile-to-layout mapping is confirmed; retain only.
- M022-M023 API names are available and components are absent.
- M024-M025 are correct at baseline tag but conflict with current HEAD.
- M026-M028 current permission, route and sharing state is confirmed; analyse
  only.
- M029 is runtime analysis and has no metadata file.
- M030 remains blocked because exact test class API names are not controlled.

## 6. Authorised R01-R09 read-only checks

Each runtime result must record query time, org identifier, executing user and
row count. Review copies must mask PII.

### R01 - Contact counts by record type

```sql
SELECT RecordType.DeveloperName, COUNT(Id) total
FROM Contact
GROUP BY RecordType.DeveloperName
```

### R02 - Client Users containing prohibited data

```sql
SELECT Id, AccountId, Email, Birthdate, Date_of_Birth__c, DOB__c,
       NRIC_FIN_Number__c, Passport_Number__c, ID_Type__c, ID_Number__c,
       MyInfo_Retrieval_Status__c, Consent_Type__c, Employment_Status__c,
       Report_Request_Status__c, Departure_Reason__c
FROM Contact
WHERE RecordType.DeveloperName = 'Client_User'
AND (Birthdate != NULL OR Date_of_Birth__c != NULL OR DOB__c != NULL
 OR NRIC_FIN_Number__c != NULL OR Passport_Number__c != NULL
 OR ID_Type__c != NULL OR ID_Number__c != NULL
 OR MyInfo_Retrieval_Status__c != NULL OR Consent_Type__c != NULL
 OR Employment_Status__c != NULL OR Report_Request_Status__c != NULL
 OR Departure_Reason__c != NULL)
```

### R03 - Legacy Client Admin role usage

```sql
SELECT Id, AccountId, Email, Portal_Role__c, Is_Active_Client_User__c
FROM Contact
WHERE RecordType.DeveloperName = 'Client_User'
AND Portal_Role__c = 'Client Admin'
```

### R04 - Data Subject-family access fields

```sql
SELECT Id, RecordType.DeveloperName, AccountId, Email, Portal_Role__c,
       Can_Approve__c, Is_Active_Client_User__c
FROM Contact
WHERE RecordType.DeveloperName IN ('Data_Subject','Singpass','Non_Singpass')
AND (Portal_Role__c != NULL OR Can_Approve__c = TRUE
 OR Is_Active_Client_User__c = TRUE)
```

### R05 - Duplicate Client Users by Account and Email

```sql
SELECT AccountId, Email, COUNT(Id) duplicateCount
FROM Contact
WHERE RecordType.DeveloperName = 'Client_User' AND Email != NULL
GROUP BY AccountId, Email
HAVING COUNT(Id) > 1
```

### R06 - Approved active-request duplicate query

```sql
SELECT Data_Subject__c, Data_Subject__r.AccountId,
       Data_Subject__r.Consent_Type__c, Current_Status__c,
       COUNT(Id) itemCount
FROM Consent_Request_Item__c
WHERE Current_Status__c IN ('Pending','Sent','Viewed')
GROUP BY Data_Subject__c, Data_Subject__r.AccountId,
         Data_Subject__r.Consent_Type__c, Current_Status__c
HAVING COUNT(Id) > 1
```

This query is reproduced exactly from the revised report. Its cross-status
coverage gap is a stop condition, not silently corrected here.

### R07 - Linked Experience Cloud users

```sql
SELECT Id, ContactId, Username, IsActive, Profile.Name, UserType
FROM User
WHERE ContactId != NULL
```

### R08 - Effective legacy permission assignments

```sql
SELECT AssigneeId, Assignee.Username, PermissionSet.Name
FROM PermissionSetAssignment
WHERE PermissionSet.Name IN
      ('Set_Custom_Object_To_Partner',
       'partner_community_User_Permissions_set')
```

### R09 - Setup capacity and ownership

Manual read-only evidence:

- Contact field-history tracked-field capacity
- Shield retention policy
- CBS Processing Queue active membership
- Deployment user Case create permission
- Relevant licence availability

## 7. Proposed physical-file scope

Confirmed existing modifications:

- Four Contact field files for M001-M004
- `Portal_Role__c.field-meta.xml`
- `Contact/recordTypes/Client_User.recordType-meta.xml`
- `contactApproveCreateConsentRequest.flow-meta.xml`
- `BatchExcelUploadController.cls`
- `BatchExcelUploadControllerTest.cls`
- Client User layout
- Five confirmed Data Subject-family layouts
- `Credit_Bureau.app-meta.xml`
- `Contact.object-meta.xml`
- Account, Email, Department, Portal Role, Can Approve and Active Client User
  field files

Confirmed new files/components:

- Nine Contact Validation Rule files
- `Consent_Purpose__c.field-meta.xml`
- `Active_Request_Key__c.field-meta.xml`
- `Consent_Request_Item_Maintain_Active_Key.flow-meta.xml`
- `CBS_Client_User_Record_Page.flexipage-meta.xml`
- Contact matching-rule entry/component
- Client User Duplicate Rule

Unresolved and excluded:

- M018 sixth layout
- M030 test class names
- Any A-IMP-08 permission component
- Any A-IMP-09 Experience Cloud redesign

## 8. Risks and stop conditions

- No Phase 2 metadata modification without the exact statement
  `APPROVE A-IMP-02 MANIFEST`.
- Reconcile current HEAD against the approved baseline before build.
- Stop M018 until its sixth physical API name is approved.
- Stop M013B-M013D until R06 cross-status uniqueness evidence is resolved.
- Stop M030 until exact test API names are approved.
- Do not activate M008A-M008C, M010, M013B-M013D, M022-M025 without the
  corresponding runtime gate and owner-approved disposition.
- Stop if CBS Processing Queue has no active member or the deployment context
  cannot create the fault Case.
- Stop on any Category B-I or Experience Cloud current-state regression.
- No record clearing, conversion, merge, delete or automatic remediation.
- No Sandbox or Production deployment is authorised by this report.

## 9. Gate conclusion

Static analysis is complete. Runtime evidence is unavailable in this
metadata-only environment. The unresolved M018, M030 and R06 issues prevent a
complete conditional build plan for those rows.

AWAITING A-IMP-02 MANIFEST APPROVAL
