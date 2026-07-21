# A-IMP-03 R01–R12 Read-only Runtime Query Pack

Operator prerequisites for every item:

- Confirm and record Sandbox Org ID and executing username before running.
- Record UTC timestamp, exact query/check text, row count and protected output path.
- Export only to the controlled runtime-evidence location.
- Mask Account names, usernames, Contact details, Contract numbers and filenames in review copies.
- Do not run DML, write-capable anonymous Apex, data import/update, Flow activation or deployment.

## R01 — Account lifecycle profile

```sql
SELECT Client_Status__c, COUNT(Id)
FROM Account
GROUP BY Client_Status__c
```

```sql
SELECT Type, RecordType.DeveloperName, COUNT(Id)
FROM Account
GROUP BY Type, RecordType.DeveloperName
```

```sql
SELECT Id, Name, Client_Code__c, Client_Status__c, Active__c,
       Notification_Email__c, OwnerId, Type, RecordTypeId
FROM Account
WHERE Client_Code__c = NULL
   OR Notification_Email__c = NULL
   OR OwnerId = NULL
ORDER BY Id
```

## R02 — Duplicate Client Code

```sql
SELECT Client_Code__c, COUNT(Id)
FROM Account
WHERE Client_Code__c != NULL
GROUP BY Client_Code__c
HAVING COUNT(Id) > 1
```

Export masked IDs and Client Codes to the protected operator location, then perform trim/case-normalised comparison offline without modifying Salesforce.

## R03 — Existing Account baseline

```sql
SELECT Id, Client_Code__c, Client_Status__c, Active__c, OwnerId,
       Notification_Email__c,
       (SELECT Id, StageName, CloseDate FROM Opportunities),
       (SELECT Id, Status, StartDate, ContractTerm, EndDate FROM Contracts),
       (SELECT Id, Type, Status, Subject, ActivityDate FROM Tasks)
FROM Account
ORDER BY Id
```

Run R06 and R08 separately for Files and active external Users. Record one baseline-register row per Account.

## R04 — Opportunity prerequisite

```sql
SELECT AccountId, StageName, COUNT(Id)
FROM Opportunity
WHERE AccountId != NULL
GROUP BY AccountId, StageName
ORDER BY AccountId, StageName
```

```sql
SELECT Id, AccountId, StageName, CloseDate, IsWon, IsClosed
FROM Opportunity
WHERE AccountId != NULL
ORDER BY AccountId, CloseDate DESC
```

## R05 — Contract readiness

```sql
SELECT Id, AccountId, ContractNumber, Status, StartDate,
       ContractTerm, EndDate, OwnerId, CompanySignedDate,
       CustomerSignedDate
FROM Contract
ORDER BY AccountId, StartDate DESC
```

## R06 — Contract Files

After obtaining Contract IDs from R05, run in controlled batches:

```sql
SELECT Id, LinkedEntityId, ContentDocumentId, ShareType, Visibility
FROM ContentDocumentLink
WHERE LinkedEntityId IN ('<ContractId1>','<ContractId2>')
```

```sql
SELECT Id, Title, FileType, LatestPublishedVersionId
FROM ContentDocument
WHERE Id IN ('<ContentDocumentId1>','<ContentDocumentId2>')
```

Do not download signed contracts into the repository. Review copies must mask titles.

## R07 — Existing Task usage

```sql
SELECT Type, Status, COUNT(Id)
FROM Task
GROUP BY Type, Status
ORDER BY Type, Status
```

```sql
SELECT Id, WhatId, WhoId, Subject, Type, Status,
       ActivityDate, OwnerId, CreatedDate
FROM Task
WHERE Subject LIKE '%onboard%'
   OR Subject LIKE '%client%'
ORDER BY CreatedDate DESC
```

## R08 — Active external Users

```sql
SELECT Id, Username, IsActive, UserType, Profile.Name,
       ContactId, Contact.AccountId
FROM User
WHERE ContactId != NULL
  AND IsActive = TRUE
ORDER BY Contact.AccountId
```

Mask Username in review copies.

## R09 — Roles, permissions, queues and approver candidates

```sql
SELECT Id, Name, DeveloperName, ParentRoleId
FROM UserRole
ORDER BY Name
```

```sql
SELECT AssigneeId, PermissionSet.Name, PermissionSet.IsOwnedByProfile
FROM PermissionSetAssignment
WHERE PermissionSet.Name LIKE 'CBS%'
ORDER BY AssigneeId, PermissionSet.Name
```

```sql
SELECT Id, Name, Type
FROM Group
WHERE Type = 'Queue'
ORDER BY Name
```

```sql
SELECT QueueId, SobjectType
FROM QueueSobject
ORDER BY QueueId, SobjectType
```

Use Setup read-only review to confirm active authorised administrator candidates and maker-checker separation. Do not assign roles or permissions.

## R10 — Feature and capacity Setup checks

Capture masked Setup screenshots/exports for:

1. Flow Approval Process availability, metadata type and applicable limits.
2. Active Flow versions and interview/transaction limits.
3. Account field-history enabled state and number of tracked fields.
4. Task history capability and any tracked fields.
5. Approval routing, queues and authorised checker membership.
6. Email/custom-notification availability and durable fault mechanism.
7. Required licences/features and any Sandbox-specific limitation.

Do not enable any feature.

## R11 — Automation and configuration drift

Use read-only Setup/Tooling API or a fresh metadata retrieve to inventory:

- active Account/Task Flows and versions;
- Apex triggers/classes/invocable actions touching Account or Task;
- workflow/process remnants;
- quick actions, Lightning pages, app/profile assignments;
- approval assets, queues and notifications absent from the 20260715 ZIP.

Record component name, version/status and source of evidence.

## R12 — Latest-baseline comparison

1. Retrieve metadata into a new read-only directory; never overwrite the controlled baseline.
2. Hash the fresh retrieve.
3. Compare it with `Credit Bureau Sandbox 20260715.zip`.
4. Compare it with the approved A-IMP-02 branch/as-built retrieve.
5. Record added, removed and changed components, with special attention to Contact, Account, Task, Flow, permission, page, application and fault-evidence components.

No connected-org command was executed by Cursor in this Phase 1 run.
