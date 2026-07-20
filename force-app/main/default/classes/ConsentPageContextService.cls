public without sharing class ConsentPageContextService {
    private static final String ERROR_INVALID_LINK = 'The link is invalid or has expired.';

    public class SuccessContextState {
        public Boolean initialized = false;
        public Boolean valid = true;
        public String errorMessage;
        public SObject contactRecord;
        public SObject requestItemRecord;
        public Id resolvedContactId;
    }

    public class WithdrawContextState {
        public Boolean initialized = false;
        public Boolean valid = true;
        public String errorMessage;
        public SObject contactRecord;
        public SObject requestItemRecord;
        public Id resolvedContactId;
    }

    public static void ensureSuccessContextLoaded(
        SuccessContextState state,
        Map<String, String> pageParameters,
        String contactIdParam,
        Boolean isFinished
    ) {
        if (state.initialized == true) {
            return;
        }
        state.initialized = true;

        if (pageParameters.get('completed') != 'true' && isFinished != true) {
            return;
        }

        Id resolvedContactId = resolveSuccessContactId(state, pageParameters, contactIdParam);
        if (resolvedContactId == null) {
            invalidateSuccess(state, ERROR_INVALID_LINK);
            return;
        }

        state.resolvedContactId = resolvedContactId;
        state.contactRecord = ConsentRequestResolverService.querySuccessContact(resolvedContactId);
        if (state.contactRecord == null) {
            invalidateSuccess(state, ERROR_INVALID_LINK);
        }
    }

    public static void ensureWithdrawContextLoaded(
        WithdrawContextState state,
        Map<String, String> pageParameters,
        String contactIdParam
    ) {
        if (state.initialized == true) {
            return;
        }
        state.initialized = true;

        Id resolvedContactId = resolveWithdrawContactId(state, pageParameters, contactIdParam);
        if (resolvedContactId == null) {
            invalidateWithdraw(state, ERROR_INVALID_LINK);
            return;
        }

        state.resolvedContactId = resolvedContactId;
        state.contactRecord = ConsentRequestResolverService.querySuccessContact(resolvedContactId);
        if (state.contactRecord == null) {
            invalidateWithdraw(state, ERROR_INVALID_LINK);
        }
    }

    public static void refreshWithdrawContext(WithdrawContextState state) {
        state.initialized = false;
        state.valid = true;
        state.errorMessage = null;
        state.requestItemRecord = null;
        state.contactRecord = null;
        state.resolvedContactId = null;
    }

    public static Id resolveSuccessContactId(
        SuccessContextState state,
        Map<String, String> pageParameters,
        String contactIdParam
    ) {
        if (state.requestItemRecord == null) {
            state.requestItemRecord = resolveSuccessRequestItem(state, pageParameters);
        }
        if (state.requestItemRecord != null) {
            Object subjectFromRequest = state.requestItemRecord.get('Data_Subject__c');
            if (subjectFromRequest instanceof Id) {
                return (Id) subjectFromRequest;
            }
        }

        String consentIdParam = firstNonBlank(
            pageParameters.get('consentId'),
            pageParameters.get('id')
        );
        if (!String.isBlank(consentIdParam)) {
            Id fromConsent = ConsentRequestResolverService.resolveContactIdByConsentId(consentIdParam);
            if (fromConsent != null) {
                return fromConsent;
            }
        }

        Id fromContactParam = parseIdValue(contactIdParam);
        if (fromContactParam != null) {
            return fromContactParam;
        }

        String recordId = pageParameters.get('recordId');
        if (!String.isBlank(recordId)) {
            return ConsentRequestResolverService.resolveRecordIdToContactId(recordId);
        }

        return null;
    }

    public static Id resolveWithdrawContactId(
        WithdrawContextState state,
        Map<String, String> pageParameters,
        String contactIdParam
    ) {
        Id contactIdFromParam = parseIdValue(contactIdParam);
        Id fromRequest = resolveWithdrawContactIdFromRequest(state, pageParameters);
        if (fromRequest != null) {
            if (contactIdFromParam != null && contactIdFromParam != fromRequest) {
                return null;
            }
            return fromRequest;
        }

        String consentIdParam = firstNonBlank(
            pageParameters.get('consentId'),
            pageParameters.get('id')
        );
        Id fromConsent = ConsentRequestResolverService.resolveContactIdByConsentId(consentIdParam);
        if (fromConsent != null) {
            if (contactIdFromParam != null && contactIdFromParam != fromConsent) {
                return null;
            }
            return fromConsent;
        }

        Id fromRecord = ConsentRequestResolverService.resolveRecordIdToContactId(pageParameters.get('recordId'));
        if (fromRecord != null) {
            if (contactIdFromParam != null && contactIdFromParam != fromRecord) {
                return null;
            }
            return fromRecord;
        }

        return contactIdFromParam;
    }

    public static Boolean isRequestItemLinkExpired(SObject requestItem) {
        if (requestItem == null) {
            return true;
        }
        List<String> expiryFieldCandidates = new List<String>{
            'Link_Expires_At__c', 'Expires_At__c', 'Expiry_Date_Time__c', 'Token_Expires_At__c'
        };
        for (String fieldApi : expiryFieldCandidates) {
            if (hasPopulatedField(requestItem, fieldApi)) {
                Object rawValue = requestItem.get(fieldApi);
                if (rawValue instanceof Datetime && ((Datetime) rawValue) < System.now()) {
                    return true;
                }
                if (rawValue instanceof Date && ((Date) rawValue) < Date.today()) {
                    return true;
                }
            }
        }
        return false;
    }

    private static SObject resolveSuccessRequestItem(
        SuccessContextState state,
        Map<String, String> pageParameters
    ) {
        String tokenValue = pageParameters.get('token');
        String requestIdCandidate = firstNonBlank(
            pageParameters.get('requestItemId'),
            pageParameters.get('requestId')
        );
        if (!String.isBlank(requestIdCandidate)) {
            SObject byId = ConsentRequestResolverService.querySuccessRequestItemById(requestIdCandidate);
            if (byId != null) {
                if (isRequestItemLinkExpired(byId) || !doesTokenMatchRequestItem(byId, tokenValue)) {
                    invalidateSuccess(state, ERROR_INVALID_LINK);
                    return null;
                }
                return byId;
            }
        }

        if (!String.isBlank(tokenValue)) {
            SObject byToken = ConsentRequestResolverService.querySuccessRequestItemByToken(tokenValue);
            if (byToken == null) {
                invalidateSuccess(state, ERROR_INVALID_LINK);
                return null;
            }
            if (isRequestItemLinkExpired(byToken)) {
                invalidateSuccess(state, ERROR_INVALID_LINK);
                return null;
            }
            return byToken;
        }
        return null;
    }

    private static Id resolveWithdrawContactIdFromRequest(
        WithdrawContextState state,
        Map<String, String> pageParameters
    ) {
        if (state.requestItemRecord == null) {
            String requestIdCandidate = firstNonBlank(
                pageParameters.get('requestItemId'),
                pageParameters.get('requestId')
            );
            if (!String.isBlank(requestIdCandidate)) {
                state.requestItemRecord = ConsentRequestResolverService.querySuccessRequestItemById(requestIdCandidate);
            } else {
                String tokenValue = pageParameters.get('token');
                if (!String.isBlank(tokenValue)) {
                    state.requestItemRecord = ConsentRequestResolverService.querySuccessRequestItemByToken(tokenValue);
                }
            }
        }

        if (state.requestItemRecord == null || isRequestItemLinkExpired(state.requestItemRecord)) {
            return null;
        }

        Object subjectValue = state.requestItemRecord.get('Data_Subject__c');
        return subjectValue instanceof Id ? (Id) subjectValue : null;
    }

    private static Boolean doesTokenMatchRequestItem(SObject requestItemRaw, String tokenValue) {
        return ConsentGuestAuthService.matchesStoredToken(requestItemRaw, tokenValue);
    }

    private static void invalidateSuccess(SuccessContextState state, String errorMessage) {
        state.valid = false;
        state.errorMessage = errorMessage;
    }

    private static void invalidateWithdraw(WithdrawContextState state, String errorMessage) {
        state.valid = false;
        state.errorMessage = errorMessage;
    }

    private static Boolean hasPopulatedField(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) {
            return false;
        }
        if (!record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            return false;
        }
        try {
            return record.getPopulatedFieldsAsMap().containsKey(fieldApiName);
        } catch (Exception e) {
            return false;
        }
    }

    private static String firstNonBlank(String value1, String value2) {
        if (!String.isBlank(value1)) {
            return value1;
        }
        return String.isBlank(value2) ? null : value2;
    }

    private static Id parseIdValue(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            return (Id) rawValue;
        } catch (Exception e) {
            return null;
        }
    }
}