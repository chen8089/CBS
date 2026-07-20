public without sharing class SiteTokenService {
    public class TokenValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public String tokenHash;

        public TokenValidationResult(Boolean isValid, String reasonCode, String tokenHash) {
            this.isValid = isValid;
            this.reasonCode = reasonCode;
            this.tokenHash = tokenHash;
        }
    }

    public static String hashToken(String plainToken) {
        if (String.isBlank(plainToken)) {
            return null;
        }
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(plainToken.trim()));
        return EncodingUtil.convertToHex(digest);
    }

    public static TokenValidationResult validateToken(
        String plainToken,
        Datetime expiryAt,
        String currentStatus
    ) {
        String hashedValue = hashToken(plainToken);
        if (String.isBlank(hashedValue)) {
            return new TokenValidationResult(false, 'TOKEN_REQUIRED', null);
        }
        if (expiryAt != null && expiryAt < System.now()) {
            return new TokenValidationResult(false, 'TOKEN_EXPIRED', hashedValue);
        }
        Set<String> invalidStatuses = new Set<String>{ 'Declined', 'Withdrawn', 'Expired', 'Already Actioned' };
        if (invalidStatuses.contains(currentStatus)) {
            return new TokenValidationResult(false, 'TOKEN_ALREADY_ACTIONED', hashedValue);
        }
        return new TokenValidationResult(true, 'TOKEN_VALID', hashedValue);
    }

    public static Id createAccessLog(
        Id consentRequestId,
        Id dataSubjectId,
        String tokenHash,
        String ipAddress,
        String userAgent,
        String accessResult,
        String failureReason,
        String actionType,
        Boolean alertTriggered
    ) {
        Site_Access_Log__c log = new Site_Access_Log__c(
            Consent_Request__c = consentRequestId,
            Data_Subject__c = dataSubjectId,
            Token_Hash__c = tokenHash,
            Accessed_At__c = System.now(),
            IP_Address__c = ipAddress,
            User_Agent__c = userAgent,
            Access_Result__c = accessResult,
            Failure_Reason__c = failureReason,
            Action_Type__c = actionType,
            Alert_Triggered__c = alertTriggered
        );
        insert log;
        return log.Id;
    }
}