public without sharing class ConsentStatusModelService {
    public static final String STATUS_PENDING = 'PENDING';
    public static final String STATUS_ACTIVE = 'ACTIVE';
    public static final String STATUS_DECLINED = 'DECLINED';
    public static final String STATUS_WITHDRAWN = 'WITHDRAWN';
    public static final String STATUS_EXPIRED = 'EXPIRED';
    public static final String STATUS_CONSUMED = 'CONSUMED';
    public static final String STATUS_EXCEPTION = 'EXCEPTION';
    public static final String STATUS_UNKNOWN = 'UNKNOWN';

    public static String normalizeConsentStatus(String rawStatus) {
        String token = toToken(rawStatus);
        if (token == null) {
            return STATUS_UNKNOWN;
        }
        if (token == 'active' || token == 'consentvalid' || token == 'valid') {
            return STATUS_ACTIVE;
        }
        if (token == 'pending' || token == 'pendingreview' || token == 'noaction') {
            return STATUS_PENDING;
        }
        if (token == 'declined') {
            return STATUS_DECLINED;
        }
        if (token == 'withdrawn' || token == 'revoked') {
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

    public static String normalizeContactConsentStatus(String rawStatus) {
        String token = toToken(rawStatus);
        if (token == null) {
            return STATUS_UNKNOWN;
        }
        if (token == 'authorized' || token == 'active' || token == 'consentvalid' || token == 'valid') {
            return STATUS_ACTIVE;
        }
        if (token == 'pending' || token == 'noaction') {
            return STATUS_PENDING;
        }
        if (token == 'declined') {
            return STATUS_DECLINED;
        }
        if (token == 'withdrawn' || token == 'revoked') {
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

    public static String normalizeLifecycleStage(String rawStage) {
        String token = toToken(rawStage);
        if (token == null) {
            return STATUS_UNKNOWN;
        }
        if (token == 'activeconsent') {
            return STATUS_ACTIVE;
        }
        if (token == 'consentdeclined') {
            return STATUS_DECLINED;
        }
        if (token == 'consentwithdrawn') {
            return STATUS_WITHDRAWN;
        }
        if (token == 'consentexpired') {
            return STATUS_EXPIRED;
        }
        if (token == 'consumed') {
            return STATUS_CONSUMED;
        }
        if (token == 'processing' || token == 'exception') {
            return STATUS_EXCEPTION;
        }
        if (token == 'awaitingdatasubjectaction' || token == 'consentrequest' || token == 'upload') {
            return STATUS_PENDING;
        }
        if (token == 'departure' || token == 'departed' || token == 'inactive') {
            return STATUS_WITHDRAWN;
        }
        return STATUS_UNKNOWN;
    }

    public static String normalizeReportEligibility(String rawEligibility) {
        String token = toToken(rawEligibility);
        if (token == null) {
            return STATUS_UNKNOWN;
        }
        if (token == 'consentconsumed') {
            return STATUS_CONSUMED;
        }
        if (token == 'consentexpired') {
            return STATUS_EXPIRED;
        }
        if (token == 'consentwithdrawn' || token == 'blocked' || token == 'noteligible') {
            return STATUS_WITHDRAWN;
        }
        return STATUS_UNKNOWN;
    }

    public static Boolean isBlockedForReport(String canonicalStatus) {
        return canonicalStatus == STATUS_DECLINED
            || canonicalStatus == STATUS_WITHDRAWN
            || canonicalStatus == STATUS_EXPIRED
            || canonicalStatus == STATUS_CONSUMED
            || canonicalStatus == STATUS_EXCEPTION
            || canonicalStatus == STATUS_PENDING;
    }

    public static void applyContactState(Contact contactUpdate, String canonicalStatus) {
        if (contactUpdate == null || String.isBlank(canonicalStatus)) {
            return;
        }

        setContactCurrentConsentStatus(contactUpdate, canonicalStatus, null);
        setContactLifecycleStage(contactUpdate, canonicalStatus, null);
    }

    public static void applyPendingVerificationState(Contact contactUpdate) {
        if (contactUpdate == null) {
            return;
        }
        setContactCurrentConsentStatus(
            contactUpdate,
            STATUS_PENDING,
            new List<String>{ 'Processing', 'Pending CBS Verification', 'Pending Verification', 'Verification Pending', 'Pending', 'No Action' }
        );
        setContactLifecycleStage(
            contactUpdate,
            STATUS_PENDING,
            new List<String>{ 'Processing', 'Pending Verification', 'Verification Pending', 'Awaiting Data Subject Action', 'Consent Request', 'Upload' }
        );
    }

    private static void setContactCurrentConsentStatus(
        Contact contactUpdate,
        String canonicalStatus,
        List<String> overridePreferredValues
    ) {
        List<String> overrideValues = overridePreferredValues == null
            ? new List<String>()
            : new List<String>(overridePreferredValues);
        if (!overrideValues.isEmpty()) {
            String resolvedOverride = choosePicklistValue(Contact.Current_Consent_Status__c.getDescribe(), overrideValues);
            if (resolvedOverride != null) {
                contactUpdate.Current_Consent_Status__c = resolvedOverride;
                return;
            }
        }

        List<String> preferredValues = new List<String>();
        if (canonicalStatus == STATUS_ACTIVE) {
            preferredValues.addAll(new List<String>{ 'Authorized', 'Valid', 'Active', 'Consent Valid' });
        } else if (canonicalStatus == STATUS_PENDING) {
            preferredValues.addAll(new List<String>{ 'Pending', 'No Action' });
        } else if (canonicalStatus == STATUS_DECLINED) {
            preferredValues.add('Declined');
        } else if (canonicalStatus == STATUS_WITHDRAWN) {
            preferredValues.addAll(new List<String>{ 'Withdrawn', 'Revoked', 'Departure' });
        } else if (canonicalStatus == STATUS_EXPIRED) {
            preferredValues.add('Expired');
        } else if (canonicalStatus == STATUS_CONSUMED) {
            preferredValues.addAll(new List<String>{ 'Consumed', 'Expired' });
        } else if (canonicalStatus == STATUS_EXCEPTION) {
            preferredValues.add('Exception');
        }

        String resolved = choosePicklistValue(Contact.Current_Consent_Status__c.getDescribe(), preferredValues);
        if (resolved != null) {
            contactUpdate.Current_Consent_Status__c = resolved;
        }
    }

    private static void setContactLifecycleStage(
        Contact contactUpdate,
        String canonicalStatus,
        List<String> overridePreferredValues
    ) {
        List<String> overrideValues = overridePreferredValues == null
            ? new List<String>()
            : new List<String>(overridePreferredValues);
        if (!overrideValues.isEmpty()) {
            String resolvedOverride = choosePicklistValue(Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(), overrideValues);
            if (resolvedOverride != null) {
                contactUpdate.Data_Subject_Lifecycle_Stage__c = resolvedOverride;
                return;
            }
        }

        List<String> preferredValues = new List<String>();
        if (canonicalStatus == STATUS_ACTIVE) {
            preferredValues.add('Active Consent');
        } else if (canonicalStatus == STATUS_PENDING) {
            preferredValues.addAll(new List<String>{ 'Awaiting Data Subject Action', 'Consent Request', 'Upload' });
        } else if (canonicalStatus == STATUS_DECLINED) {
            preferredValues.add('Consent Declined');
        } else if (canonicalStatus == STATUS_WITHDRAWN) {
            preferredValues.addAll(new List<String>{ 'Consent Withdrawn', 'Departure' });
        } else if (canonicalStatus == STATUS_EXPIRED) {
            preferredValues.add('Consent Expired');
        } else if (canonicalStatus == STATUS_CONSUMED) {
            preferredValues.addAll(new List<String>{ 'Consumed', 'Consent Expired' });
        } else if (canonicalStatus == STATUS_EXCEPTION) {
            preferredValues.add('Processing');
        }

        String resolved = choosePicklistValue(Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(), preferredValues);
        if (resolved != null) {
            contactUpdate.Data_Subject_Lifecycle_Stage__c = resolved;
        }
    }

    private static String choosePicklistValue(Schema.DescribeFieldResult describeField, List<String> preferredValues) {
        if (describeField == null || preferredValues == null || preferredValues.isEmpty()) {
            return null;
        }

        for (String preferredValue : preferredValues) {
            if (String.isBlank(preferredValue)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describeField.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferredValue) || entry.getLabel().equalsIgnoreCase(preferredValue)) {
                    return entry.getValue();
                }
            }
        }
        return null;
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