public with sharing class ConsentProjectionSyncService {
    public static final String STATUS_PENDING = 'PENDING';
    public static final String STATUS_ACTIVE = 'ACTIVE';
    public static final String STATUS_DECLINED = 'DECLINED';
    public static final String STATUS_WITHDRAWN = 'WITHDRAWN';
    public static final String STATUS_EXPIRED = 'EXPIRED';
    public static final String STATUS_CONSUMED = 'CONSUMED';
    public static final String STATUS_EXCEPTION = 'EXCEPTION';
    public static final String STATUS_UNKNOWN = 'UNKNOWN';

    public static final Map<String, List<String>> CONTACT_STATUS_PREF = new Map<String, List<String>>{
        STATUS_ACTIVE => new List<String>{ 'Authorized', 'Valid', 'Active', 'Consent Valid' },
        STATUS_PENDING => new List<String>{ 'Pending', 'No Action' },
        STATUS_DECLINED => new List<String>{ 'Declined' },
        STATUS_WITHDRAWN => new List<String>{ 'Withdrawn', 'Revoked', 'Departure' },
        STATUS_EXPIRED => new List<String>{ 'Expired' },
        STATUS_CONSUMED => new List<String>{ 'Consumed', 'Expired' },
        STATUS_EXCEPTION => new List<String>{ 'Exception' }
    };

    public static final Map<String, List<String>> CONTACT_LIFECYCLE_PREF = new Map<String, List<String>>{
        STATUS_ACTIVE => new List<String>{ 'Active Consent' },
        STATUS_PENDING => new List<String>{ 'Awaiting Data Subject Action', 'Consent Request', 'Upload', 'Processing', 'Pending Verification' },
        STATUS_DECLINED => new List<String>{ 'Consent Declined' },
        STATUS_WITHDRAWN => new List<String>{ 'Consent Withdrawn', 'Departure' },
        STATUS_EXPIRED => new List<String>{ 'Consent Expired' },
        STATUS_CONSUMED => new List<String>{ 'Consumed', 'Consent Expired' },
        STATUS_EXCEPTION => new List<String>{ 'Processing' }
    };

    public static final Map<String, List<String>> CONTACT_REPORT_ELIGIBILITY_PREF = new Map<String, List<String>>{
        STATUS_WITHDRAWN => new List<String>{ 'Consent Withdrawn', 'Blocked', 'Not Eligible' },
        STATUS_EXPIRED => new List<String>{ 'Consent Expired' },
        STATUS_CONSUMED => new List<String>{ 'Consent Consumed' },
        STATUS_DECLINED => new List<String>{ 'Consent Withdrawn', 'Not Eligible' }
    };

    /**
     * Normalizes raw status values from Consent/CRI/Contact into canonical tokens.
     */
    public static String normalize(String rawStatus) {
        String token = toToken(rawStatus);
        if (token == null) {
            return STATUS_UNKNOWN;
        }

        if (token == 'active'
            || token == 'valid'
            || token == 'consentvalid'
            || token == 'authorized'
            || token == 'submitted') {
            return STATUS_ACTIVE;
        }

        if (token == 'pending'
            || token == 'pendingreview'
            || token == 'noaction'
            || token == 'sent'
            || token == 'viewed'
            || token == 'processing'
            || token == 'pendingverification'
            || token == 'verificationpending'
            || token == 'pendingcbsverification'
            || token == 'awaitingdatasubjectaction'
            || token == 'consentrequest'
            || token == 'upload') {
            return STATUS_PENDING;
        }

        if (token == 'declined') {
            return STATUS_DECLINED;
        }

        if (token == 'withdrawn'
            || token == 'revoked'
            || token == 'departure'
            || token == 'departed'
            || token == 'inactive') {
            return STATUS_WITHDRAWN;
        }

        if (token == 'expired') {
            return STATUS_EXPIRED;
        }

        if (token == 'consumed') {
            return STATUS_CONSUMED;
        }

        if (token == 'exception') {
            return STATUS_EXCEPTION;
        }

        return STATUS_UNKNOWN;
    }

    /**
     * Chooses the first available picklist value from preferred values.
     * Returns null when no preferred value exists in the target picklist.
     */
    public static String choosePicklistValue(
        Schema.DescribeFieldResult describeField,
        List<String> preferredValues
    ) {
        if (describeField == null || preferredValues == null || preferredValues.isEmpty()) {
            return null;
        }

        for (String preferredValue : preferredValues) {
            if (String.isBlank(preferredValue)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describeField.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferredValue)
                    || entry.getLabel().equalsIgnoreCase(preferredValue)) {
                    return entry.getValue();
                }
            }
        }
        return null;
    }

    /**
     * Syncs Contact projection fields from a consent-like status.
     */
    public static void syncContactFromConsent(
        Id dataSubjectId,
        String consentStatusRaw,
        Date consentExpiryDate,
        Datetime statusAt
    ) {
        if (dataSubjectId == null) {
            return;
        }

        String canonical = normalize(consentStatusRaw);
        if (canonical == STATUS_UNKNOWN) {
            return;
        }

        Contact contactUpdate = new Contact(Id = dataSubjectId);
        Boolean hasUpdates = false;

        hasUpdates = applyPicklistField(
            contactUpdate,
            'Current_Consent_Status__c',
            CONTACT_STATUS_PREF.get(canonical)
        ) || hasUpdates;

        hasUpdates = applyPicklistField(
            contactUpdate,
            'Data_Subject_Lifecycle_Stage__c',
            CONTACT_LIFECYCLE_PREF.get(canonical)
        ) || hasUpdates;

        if (CONTACT_REPORT_ELIGIBILITY_PREF.containsKey(canonical)) {
            hasUpdates = applyPicklistField(
                contactUpdate,
                'Report_Eligibility_Status__c',
                CONTACT_REPORT_ELIGIBILITY_PREF.get(canonical)
            ) || hasUpdates;
        }

        if (consentExpiryDate != null) {
            hasUpdates = setFieldIfAvailable(contactUpdate, 'Current_Consent_Expiry_Date__c', consentExpiryDate) || hasUpdates;
            hasUpdates = setFieldIfAvailable(contactUpdate, 'Consent_Expiry_Date__c', consentExpiryDate) || hasUpdates;
        }

        if (statusAt != null) {
            hasUpdates = setFieldIfAvailable(contactUpdate, 'Latest_Status_Datetime__c', statusAt) || hasUpdates;
            hasUpdates = setFieldIfAvailable(contactUpdate, 'Latest_Status_Date__c', statusAt.date()) || hasUpdates;
        }

        if (hasUpdates) {
            update contactUpdate;
        }
    }

    private static Boolean applyPicklistField(SObject record, String fieldApi, List<String> preferredValues) {
        Schema.DescribeFieldResult describeField = getDescribe(record, fieldApi);
        if (describeField == null) {
            return false;
        }
        String resolved = choosePicklistValue(describeField, preferredValues);
        if (String.isBlank(resolved)) {
            return false;
        }
        try {
            record.put(fieldApi, resolved);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static Schema.DescribeFieldResult getDescribe(SObject record, String fieldApi) {
        if (record == null || String.isBlank(fieldApi)) {
            return null;
        }
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApi)) {
            return null;
        }
        return fields.get(fieldApi).getDescribe();
    }

    private static Boolean setFieldIfAvailable(SObject record, String fieldApi, Object value) {
        if (record == null || String.isBlank(fieldApi) || value == null) {
            return false;
        }
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApi)) {
            return false;
        }
        try {
            record.put(fieldApi, value);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static String toToken(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String lowered = rawValue.trim().toLowerCase();
        lowered = lowered.replace(' ', '');
        lowered = lowered.replace('_', '');
        lowered = lowered.replace('-', '');
        lowered = lowered.replace('/', '');
        return lowered;
    }
}