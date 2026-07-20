# RC07 Corrected R06 Verification

## Approval

On 2026-07-20 the user approved correcting R06 so that all active statuses are
grouped together rather than grouping separately by `Current_Status__c`.

## Execution identity

- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- Executed: `2026-07-20T10:47:59.4488356Z`
- Operation: read-only aggregate SOQL
- DML executed: no

## Approved query

```sql
SELECT Data_Subject__c,
       Data_Subject__r.AccountId,
       Data_Subject__r.Consent_Type__c,
       COUNT(Id) itemCount
FROM Consent_Request_Item__c
WHERE Current_Status__c IN ('Pending', 'Sent', 'Viewed')
GROUP BY Data_Subject__c,
         Data_Subject__r.AccountId,
         Data_Subject__r.Consent_Type__c
HAVING COUNT(Id) > 1
```

## Result

- Cross-status duplicate groups: 0
- Result: **PASS**

No duplicate group exists across the approved active-status set under the
current controlled purpose key. RC07 is resolved.

This result supplies the corrected runtime evidence gate. It does not by
itself authorise deployment, backfill or activation of M013B-M013D.
