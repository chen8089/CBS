public without sharing class ConsentExpiryScheduler implements Schedulable {
    private static final Set<String> ACTIVE_CONSENT_STATUSES = new Set<String>{ 'Active', 'Consent Valid' };
    private static final String CONSENT_STATUS_EXPIRED = 'Expired';
    private static final String LIFECYCLE_STAGE_EXPIRED = 'Consent Expired';
    private static final String REPORT_ELIGIBILITY_EXPIRED = 'Consent Expired';

    public void execute(SchedulableContext context) {
        runExpiredConsentSweep();
    }

    @TestVisible
    static Integer runExpiredConsentSweep() {
        List<Consent__c> consentRows = [
            SELECT Id, Data_Subject__c, Consent_Status__c
            FROM Consent__c
            WHERE Consent_Expiry_Date__c != NULL
                AND Consent_Expiry_Date__c < :Date.today()
                AND Consent_Status__c IN :ACTIVE_CONSENT_STATUSES
        ];
        if (consentRows.isEmpty()) {
            return 0;
        }

        Set<Id> subjectIds = new Set<Id>();
        List<Consent__c> consentsToUpdate = new List<Consent__c>();
        for (Consent__c consentRow : consentRows) {
            if (consentRow.Data_Subject__c != null) {
                subjectIds.add(consentRow.Data_Subject__c);
            }
            consentsToUpdate.add(new Consent__c(
                Id = consentRow.Id,
                Consent_Status__c = CONSENT_STATUS_EXPIRED
            ));
        }
        update consentsToUpdate;

        if (!subjectIds.isEmpty()) {
            updateContactsForExpiredConsent(subjectIds);
            expireOpenConsentRequestItems(subjectIds);
        }
        return consentsToUpdate.size();
    }

    private static void updateContactsForExpiredConsent(Set<Id> subjectIds) {
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Id subjectId : subjectIds) {
            Contact contactUpdate = new Contact(Id = subjectId);
            setFieldIfAvailable(contactUpdate, 'Data_Subject_Lifecycle_Stage__c', LIFECYCLE_STAGE_EXPIRED);
            setFieldIfAvailable(contactUpdate, 'Report_Eligibility_Status__c', REPORT_ELIGIBILITY_EXPIRED);
            contactsToUpdate.add(contactUpdate);
        }
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    private static void expireOpenConsentRequestItems(Set<Id> subjectIds) {
        String expiredStatus = choosePicklistValue(
            Consent_Request_Item__c.Current_Status__c.getDescribe(),
            new List<String>{ 'Expired' }
        );
        if (String.isBlank(expiredStatus)) {
            return;
        }

        List<Consent_Request_Item__c> requestItems = [
            SELECT Id, Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c IN :subjectIds
            ORDER BY CreatedDate DESC
        ];

        List<Consent_Request_Item__c> requestItemsToUpdate = new List<Consent_Request_Item__c>();
        for (Consent_Request_Item__c requestItem : requestItems) {
            if (requestItem.Current_Status__c == null || requestItem.Current_Status__c == 'Pending' || requestItem.Current_Status__c == 'Sent' || requestItem.Current_Status__c == 'Viewed') {
                requestItemsToUpdate.add(new Consent_Request_Item__c(
                    Id = requestItem.Id,
                    Current_Status__c = expiredStatus
                ));
            }
        }
        if (!requestItemsToUpdate.isEmpty()) {
            update requestItemsToUpdate;
        }
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }

    private static String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
        if (describe == null || preferredValues == null) {
            return null;
        }
        for (String preferred : preferredValues) {
            if (String.isBlank(preferred)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferred) || entry.getLabel().equalsIgnoreCase(preferred)) {
                    return entry.getValue();
                }
            }
        }
        return null;
    }
}