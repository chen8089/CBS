public with sharing class NonSingpassVerificationOrchestrator {
    private static final List<String> PENDING_VERIFICATION_VALUES = new List<String>{
        'Pending Verification',
        'Verification Pending',
        'Identity Verification Pending',
        'Pending'
    };
    private static final List<String> REQUEST_PENDING_VALUES = new List<String>{
        'Pending Verification',
        'Verification Pending',
        'Pending',
        'Sent'
    };

    public static void applyPendingVerificationStatus(Contact contactRecord) {
        if (contactRecord == null) {
            return;
        }
        String pendingStatus = choosePicklistValue(
            Contact.Current_Consent_Status__c.getDescribe(),
            PENDING_VERIFICATION_VALUES
        );
        if (!String.isBlank(pendingStatus)) {
            contactRecord.Current_Consent_Status__c = pendingStatus;
        }
        setOptionalFieldSafe(contactRecord, 'Identity_Verification_Status__c', 'Pending');
    }

    public static void applyPendingVerificationStatus(Consent__c consentRecord) {
        if (consentRecord == null) {
            return;
        }
        String pendingStatus = choosePicklistValue(
            Consent__c.Consent_Status__c.getDescribe(),
            PENDING_VERIFICATION_VALUES
        );
        if (String.isBlank(pendingStatus)) {
            pendingStatus = chooseNonActiveFallbackStatus(Consent__c.Consent_Status__c.getDescribe());
        }
        if (!String.isBlank(pendingStatus)) {
            consentRecord.Consent_Status__c = pendingStatus;
        }
        setOptionalFieldSafe(consentRecord, 'Verification_Status__c', 'Pending');
        setOptionalFieldSafe(consentRecord, 'Identity_Verification_Status__c', 'Pending');
    }

    public static void applyPendingVerificationStatus(Consent_Request_Item__c requestItemRecord) {
        if (requestItemRecord == null) {
            return;
        }
        String pendingStatus = choosePicklistValue(
            Consent_Request_Item__c.Current_Status__c.getDescribe(),
            REQUEST_PENDING_VALUES
        );
        if (!String.isBlank(pendingStatus)) {
            requestItemRecord.Current_Status__c = pendingStatus;
        }
        setOptionalFieldSafe(requestItemRecord, 'Identity_Verification_Status__c', 'Pending');
    }

    public static String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
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

    public static String chooseNonActiveFallbackStatus(Schema.DescribeFieldResult describe) {
        if (describe == null) {
            return null;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            String value = entry == null ? '' : String.valueOf(entry.getValue());
            if (value != 'Active' && value != 'Valid') {
                return value;
            }
        }
        if (!describe.getPicklistValues().isEmpty()) {
            return describe.getPicklistValues()[0].getValue();
        }
        return null;
    }

    private static void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || value == null || !hasField(record, fieldApiName)) {
            return;
        }
        try {
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Keep orchestration tolerant across org schema variations.
        }
    }

    private static Boolean hasField(SObject record, String fieldApi) {
        return record != null
            && record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApi);
    }
}