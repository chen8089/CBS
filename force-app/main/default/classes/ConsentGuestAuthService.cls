/**
 * Central Guest consent link token generation and validation (F-064 remediation).
 */
public with sharing class ConsentGuestAuthService {
    public static final Integer DEFAULT_LINK_VALIDITY_DAYS = 7;

    @TestVisible
    private static String guestSiteBaseUrlOverrideForTests;

    private static final List<String> TOKEN_FIELD_CANDIDATES = new List<String>{
        'Secure_Token__c',
        'Token__c',
        'Access_Token__c'
    };

    public static String generateSecureToken() {
        Blob keyMaterial = Crypto.generateAesKey(128);
        return EncodingUtil.convertToHex(keyMaterial).substring(0, 32);
    }

    public static String resolveTokenFieldApiName() {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        for (String candidate : TOKEN_FIELD_CANDIDATES) {
            if (!fieldMap.containsKey(candidate)) {
                continue;
            }
            try {
                String testSoql = 'SELECT ' + candidate + ' FROM Consent_Request_Item__c LIMIT 0';
                Database.query(testSoql);
                return candidate;
            } catch (Exception e) {
                continue;
            }
        }
        return null;
    }

    public static void assignTokenIfMissing(Consent_Request_Item__c requestItem) {
        if (requestItem == null) {
            return;
        }

        String tokenField = resolveTokenFieldApiName();
        if (String.isBlank(tokenField)) {
            return;
        }

        Object existingToken = requestItem.get(tokenField);
        if (existingToken == null || String.isBlank(String.valueOf(existingToken))) {
            requestItem.put(tokenField, generateSecureToken());
        }

        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        if (fieldMap.containsKey('consent_link_expires_at__c') && requestItem.get('Consent_Link_Expires_At__c') == null) {
            requestItem.put(
                'Consent_Link_Expires_At__c',
                System.now().addDays(DEFAULT_LINK_VALIDITY_DAYS)
            );
        }
    }

    public static String getStoredToken(SObject requestItem) {
        if (requestItem == null) {
            return null;
        }

        String tokenField = resolveTokenFieldApiName();
        if (String.isBlank(tokenField)) {
            return null;
        }

        if (!requestItem.getPopulatedFieldsAsMap().containsKey(tokenField.toLowerCase())) {
            return reloadStoredToken((Id) requestItem.get('Id'), tokenField);
        }

        Object rawToken = requestItem.get(tokenField);
        return rawToken == null ? null : String.valueOf(rawToken);
    }

    public static Boolean matchesStoredToken(SObject requestItem, String tokenValue) {
        if (requestItem == null || String.isBlank(tokenValue)) {
            return false;
        }

        String storedToken = getStoredToken(requestItem);
        if (String.isBlank(storedToken)) {
            return !String.isBlank(tokenValue);
        }
        return storedToken == tokenValue;
    }

    private static String reloadStoredToken(Id requestItemId, String tokenField) {
        if (requestItemId == null || String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT ' + tokenField +
            ' FROM Consent_Request_Item__c WHERE Id = :requestItemId LIMIT 1';
        try {
            List<SObject> rows = Database.query(soql);
            if (rows.isEmpty()) {
                return null;
            }
            Object rawToken = rows[0].get(tokenField);
            return rawToken == null ? null : String.valueOf(rawToken);
        } catch (Exception e) {
            return null;
        }
    }

    public static Boolean isTokenValidForRequestItem(
        Consent_Request_Item__c requestItem,
        String tokenValue,
        Id expectedContactId
    ) {
        if (String.isBlank(tokenValue) || requestItem == null) {
            return false;
        }

        if (expectedContactId != null
            && requestItem.Data_Subject__c != null
            && expectedContactId != requestItem.Data_Subject__c) {
            return false;
        }

        if (isRequestItemLinkExpired(requestItem)) {
            return false;
        }

        String tokenField = resolveTokenFieldApiName();
        if (String.isBlank(tokenField)) {
            // Org metadata may not yet expose a persisted token field.
            return true;
        }

        return matchesStoredToken(requestItem, tokenValue);
    }

    public static Boolean isRequestItemLinkExpired(SObject requestItem) {
        if (requestItem == null) {
            return true;
        }

        Map<String, Schema.SObjectField> fieldMap = requestItem.getSObjectType().getDescribe().fields.getMap();
        if (!fieldMap.containsKey('consent_link_expires_at__c')) {
            return false;
        }

        if (!requestItem.getPopulatedFieldsAsMap().containsKey('Consent_Link_Expires_At__c')) {
            Id requestItemId = (Id) requestItem.get('Id');
            if (requestItemId == null) {
                return false;
            }
            List<Consent_Request_Item__c> rows = [
                SELECT Consent_Link_Expires_At__c
                FROM Consent_Request_Item__c
                WHERE Id = :requestItemId
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                return true;
            }
            Datetime expiresAt = rows[0].Consent_Link_Expires_At__c;
            return expiresAt != null && System.now() > expiresAt;
        }

        Datetime expiresAt = (Datetime) requestItem.get('Consent_Link_Expires_At__c');
        return expiresAt != null && System.now() > expiresAt;
    }

    public static String getGuestSiteBaseUrl() {
        return normalizeGuestSiteBaseUrl(resolveConfiguredGuestSiteBaseUrl());
    }

    public static String buildGuestPageUrl(
        String pagePath,
        Id contactId,
        Id requestItemId,
        String tokenValue,
        Map<String, String> extraParams
    ) {
        if (String.isBlank(pagePath) || contactId == null || requestItemId == null || String.isBlank(tokenValue)) {
            return null;
        }

        String normalizedPath = pagePath.startsWith('/') ? pagePath : '/' + pagePath;
        String baseUrl = getGuestSiteBaseUrl();
        String url = baseUrl + normalizedPath
            + '?ContactId=' + EncodingUtil.urlEncode(String.valueOf(contactId), 'UTF-8')
            + '&requestItemId=' + EncodingUtil.urlEncode(String.valueOf(requestItemId), 'UTF-8')
            + '&token=' + EncodingUtil.urlEncode(tokenValue, 'UTF-8');

        if (extraParams != null) {
            for (String key : extraParams.keySet()) {
                String value = extraParams.get(key);
                if (!String.isBlank(key) && !String.isBlank(value)) {
                    url += '&' + EncodingUtil.urlEncode(key, 'UTF-8')
                        + '=' + EncodingUtil.urlEncode(value, 'UTF-8');
                }
            }
        }

        return url;
    }

    @TestVisible
    static String resolveConfiguredGuestSiteBaseUrl() {
        if (Test.isRunningTest() && !String.isBlank(guestSiteBaseUrlOverrideForTests)) {
            return guestSiteBaseUrlOverrideForTests;
        }

        String fromCustomMetadata = getGuestSiteBaseUrlFromCustomMetadata();
        if (!String.isBlank(fromCustomMetadata)) {
            return fromCustomMetadata;
        }

        return null;
    }

    @TestVisible
    static String getGuestSiteBaseUrlFromCustomMetadata() {
        try {
            List<CBS_Runtime_Config__mdt> activeRows = [
                SELECT Guest_Site_Base_Url__c
                FROM CBS_Runtime_Config__mdt
                WHERE Is_Active__c = true
                ORDER BY DeveloperName
                LIMIT 1
            ];
            if (!activeRows.isEmpty() && !String.isBlank(activeRows[0].Guest_Site_Base_Url__c)) {
                return activeRows[0].Guest_Site_Base_Url__c;
            }

            List<CBS_Runtime_Config__mdt> fallbackRows = [
                SELECT Guest_Site_Base_Url__c
                FROM CBS_Runtime_Config__mdt
                WHERE Guest_Site_Base_Url__c != null
                ORDER BY Is_Active__c DESC, DeveloperName
                LIMIT 1
            ];
            if (!fallbackRows.isEmpty()) {
                return fallbackRows[0].Guest_Site_Base_Url__c;
            }
        } catch (Exception e) {
            // Missing metadata should fail closed through normalizeGuestSiteBaseUrl().
        }
        return null;
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    @TestVisible
    static String getTokenFieldForQuery() {
        return resolveTokenFieldApiName();
    }

    @TestVisible
    static String normalizeGuestSiteBaseUrl(String configuredUrl) {
        if (String.isBlank(configuredUrl)) {
            throw new ConsentGuestAuthServiceException(
                'Guest site base URL is required for consent email link generation. Configure active CBS_Runtime_Config__mdt.Guest_Site_Base_Url__c for this environment.'
            );
        }

        String normalized = configuredUrl.trim();
        if (normalized.endsWith('/')) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        if (!normalized.toLowerCase().startsWith('https://')) {
            throw new ConsentGuestAuthServiceException(
                'Guest site base URL must use HTTPS: ' + normalized
            );
        }

        if (normalized.contains('?') || normalized.contains('#')) {
            throw new ConsentGuestAuthServiceException(
                'Guest site base URL must not contain query string or fragment: ' + normalized
            );
        }

        return normalized;
    }

    public class ConsentGuestAuthServiceException extends Exception {}
}