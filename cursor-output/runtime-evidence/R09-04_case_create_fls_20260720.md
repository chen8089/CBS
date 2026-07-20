# R09-04 Case Create Permission and FLS Evidence

## Execution identity

- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- Executed: `2026-07-20T10:34:03.2192902Z`
- Operation: read-only Profile screenshot review and SObject Describe
- Test Case created: no
- DML executed: no

## Object permission

- Case createable: **true**
- Case updateable: **true**

## Required createable fields

All M014 fields exist and are createable for the executing user:

1. `OwnerId`
2. `Status`
3. `Priority`
4. `Type`
5. `Exception_Type__c`
6. `AccountId`
7. `ContactId`
8. `Subject`
9. `Description`

`Exception_Type__c` is required on create. The M014 design supplies it.

## Required picklist values

- `Status = New`: available
- `Priority = High`: available
- `Type = Problem`: available
- `Exception_Type__c = Other`: available

## Screenshot assessment

The supplied Profile screenshot shows enabled Case object permissions, but the
Profile name and permission-column headings are not fully visible. The two
Case Field History screenshots concern history tracking and do not establish
FLS. The executing-user SObject Describe result provides the complete effective
create/FLS verification.

## Result

**PASS**

The executing user can create the sanitised M014 fault Case and write every
required field. This check does not create a Case or validate Flow runtime
execution.
