# A-IMP-02 R01-R09 Operator Execution Plan

Status: pending execution by an authorised Sandbox operator

## Confirmed target

- Alias: `ChenTest CBS`
- Org ID: `00DBK00000C9kEP2AZ`
- Authenticated username:
  `cbsneworg@creditbureau.com.sg.chentest`
- Environment: Sandbox
- API version: `67.0`

The operator must confirm these values again at execution time. Stop if the Org
ID or executing user differs.

## Controls

- Only the SELECT statements below are authorised.
- Cursor has not executed these queries.
- Record execution time, Org ID, executing user and returned row count.
- Full-value exports must remain in the separately controlled remediation
  working location.
- Only masked review copies may be placed in this directory.
- Do not run metadata deployment, activation, Flow execution or Anonymous Apex.

## Required output filenames

- `R01_Contact_Counts_MASKED.csv`
- `R02_Client_User_Prohibited_Data_MASKED.csv`
- `R03_Legacy_Client_Admin_MASKED.csv`
- `R04_Data_Subject_Access_Fields_MASKED.csv`
- `R05_Duplicate_Client_Users_MASKED.csv`
- `R06_Active_Request_Duplicates_MASKED.csv`
- `R07_Linked_External_Users_MASKED.csv`
- `R08_Legacy_Assignments_MASKED.csv`
- `R09_Setup_Evidence/` screenshots or read-only exports

## R01

```sql
SELECT RecordType.DeveloperName, COUNT(Id) total
FROM Contact
GROUP BY RecordType.DeveloperName
```

## R02

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

Mask Email and replace DOB/identity values with presence indicators in the
review copy.

## R03

```sql
SELECT Id, AccountId, Email, Portal_Role__c, Is_Active_Client_User__c
FROM Contact
WHERE RecordType.DeveloperName = 'Client_User'
AND Portal_Role__c = 'Client Admin'
```

Mask Email in the review copy.

## R04

```sql
SELECT Id, RecordType.DeveloperName, AccountId, Email, Portal_Role__c,
       Can_Approve__c, Is_Active_Client_User__c
FROM Contact
WHERE RecordType.DeveloperName IN ('Data_Subject','Singpass','Non_Singpass')
AND (Portal_Role__c != NULL OR Can_Approve__c = TRUE
 OR Is_Active_Client_User__c = TRUE)
```

Mask Email in the review copy.

## R05

```sql
SELECT AccountId, Email, COUNT(Id) duplicateCount
FROM Contact
WHERE RecordType.DeveloperName = 'Client_User' AND Email != NULL
GROUP BY AccountId, Email
HAVING COUNT(Id) > 1
```

Replace Email with a stable masked or hashed value in the review copy.

## R06

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

This reproduces the controlled query exactly. Its cross-status coverage gap
remains an implementation stop condition.

## R07

```sql
SELECT Id, ContactId, Username, IsActive, Profile.Name, UserType
FROM User
WHERE ContactId != NULL
```

Mask Username in the review copy.

## R08

```sql
SELECT AssigneeId, Assignee.Username, PermissionSet.Name
FROM PermissionSetAssignment
WHERE PermissionSet.Name IN
      ('Set_Custom_Object_To_Partner',
       'partner_community_User_Permissions_set')
```

Mask Username in the review copy.

## R09

Capture timestamped screenshots or read-only exports for:

1. Contact field-history capacity and current tracked fields.
2. Shield retention policy.
3. CBS Processing Queue active membership.
4. Executing/deployment user Case create permission and required Case FLS.
5. Relevant licence and feature availability.

Use `R09_setup_checklist.csv` to register every artifact.

## Completion gate

Populate `runtime_evidence_summary.csv` only after each output has been reviewed
for masking and the row count reconciled.
