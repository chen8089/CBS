# A-IMP-02 R01-R09 Read-Only Checks

Status: pre-build validation only
Target org placeholder: `TARGET_ORG`

## Execution controls

- Run only against the authorised connected Sandbox.
- Do not run DML, Anonymous Apex, data loader updates or remediation.
- Record query time, org ID, executing user and row count for every result.
- Mask PII in review copies.
- Keep full-value evidence only in the controlled remediation location.
- R01-R08 are SOQL. R09 is a read-only Setup inspection.

## R01 - Contact counts by record type

```sql
SELECT RecordType.DeveloperName, COUNT(Id) total
FROM Contact
GROUP BY RecordType.DeveloperName
```

Evidence:

- counts for Client_User, Data_Subject, Singpass and Non_Singpass;
- any unexpected Contact record type;
- total reconciled to the exported row count.

## R02 - Client Users containing prohibited data

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

Evidence:

- masked record-level extract;
- prohibited-field categories, not unmasked values;
- business owner and approved disposition;
- no automatic clearing or record-type conversion.

## R03 - Legacy Client Admin role usage

```sql
SELECT Id, AccountId, Email, Portal_Role__c, Is_Active_Client_User__c
FROM Contact
WHERE RecordType.DeveloperName = 'Client_User'
AND Portal_Role__c = 'Client Admin'
```

Evidence:

- row count and masked extract;
- linked User status;
- owner-approved legacy disposition before M006.

## R04 - Data Subject-family access fields

```sql
SELECT Id, RecordType.DeveloperName, AccountId, Email, Portal_Role__c,
       Can_Approve__c, Is_Active_Client_User__c
FROM Contact
WHERE RecordType.DeveloperName IN ('Data_Subject','Singpass','Non_Singpass')
AND (Portal_Role__c != NULL OR Can_Approve__c = TRUE
 OR Is_Active_Client_User__c = TRUE)
```

Evidence:

- masked record-level extract;
- source process/owner;
- M015 upload regression evidence;
- approved disposition before M010 activation.

## R05 - Duplicate Client Users by Account and Email

```sql
SELECT AccountId, Email, COUNT(Id) duplicateCount
FROM Contact
WHERE RecordType.DeveloperName = 'Client_User' AND Email != NULL
GROUP BY AccountId, Email
HAVING COUNT(Id) > 1
```

Evidence:

- duplicate groups and linked Users;
- normalisation assumptions;
- manual disposition;
- no automatic merge, delete or deactivation.

## R06 - Active consent-request duplicates

Controlled v1.1 query:

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

Evidence:

- active duplicate group;
- status history and retained active record;
- owner-approved terminalisation decision;
- purpose-backfill quality review.

Stop condition: grouping by `Current_Status__c` can miss an active duplicate
whose records have different active statuses. Do not change the controlled
query or proceed with M013B-M013D until the evidence rule is approved.

## R07 - Linked Experience Cloud users

```sql
SELECT Id, ContactId, Username, IsActive, Profile.Name, UserType
FROM User
WHERE ContactId != NULL
```

Evidence:

- linked Contact record type and Account;
- current active/inactive state;
- profile and user type;
- current-state Experience Cloud no-regression result.

## R08 - Effective legacy permission assignments

```sql
SELECT AssigneeId, Assignee.Username, PermissionSet.Name
FROM PermissionSetAssignment
WHERE PermissionSet.Name IN
      ('Set_Custom_Object_To_Partner',
       'partner_community_User_Permissions_set')
```

Evidence:

- complete assignee export;
- associated Profile, Permission Set Group and Network membership evidence;
- Contact CRUD/FLS/record-type exposure;
- no A-IMP-08 or A-IMP-09 change.

## R09 - Setup capacity and ownership

Perform read-only Setup checks:

1. Contact field-history tracked-field count and remaining capacity.
2. Current tracked Contact fields.
3. Shield Field Audit Trail retention policy.
4. CBS Processing Queue active membership.
5. Deployment user Case create permission and required Case FLS.
6. Relevant licence availability.

Evidence:

- timestamped Setup screenshots or exports;
- org ID and executing user;
- selected target fields;
- confirmation that DOB, ID, passport and MyInfo are not tracked.

## Result gate

No runtime-gated component may be activated or deployed until all applicable
evidence and owner-approved dispositions are complete.
