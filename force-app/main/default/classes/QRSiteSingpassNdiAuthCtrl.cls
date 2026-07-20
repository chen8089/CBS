/**
 * Singpass / MyInfo authentication bridge.
 *
 * Flow:
 * 1) Important Notes page redirects here.
 * 2) This controller requests an authorization URL from MyInfo API.
 * 3) User authenticates on Singpass/MyInfo.
 * 4) MyInfo redirects back here with refId (provided in redirect_to).
 * 5) This controller retrieves profile by refId and forwards to Consent page.
 */
public without sharing class QRSiteSingpassNdiAuthCtrl {
    private static final String PAGE_EMPLOYEE_CONSENT_FORM = '/apex/QRSiteSingpassEmployeeConsentForm';
    private static final String PAGE_PREHIRE_CONSENT_FORM = '/apex/QRSiteSingpassPrehireConsentForm';
    private static final String PAGE_WITHDRAW_CONSENT = '/apex/QRSiteWithdrawConsent';
    private static final String PAGE_WITHDRAWAL_CONSENT = '/apex/SingpassWithdrawalConsentPage';
    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PARAM_REF_ID = 'refId';
    private static final String PARAM_RETURN_URL = 'returnUrl';
    private static final String TYPE_PREHIRE = 'prehire';
    private static final String MYINFO_NAMED_CREDENTIAL = 'callout:CBS_MyInfo_API';
    private static final Set<String> ALLOWED_RETURN_URLS = new Set<String>{
        PAGE_EMPLOYEE_CONSENT_FORM,
        PAGE_PREHIRE_CONSENT_FORM,
        PAGE_WITHDRAW_CONSENT,
        PAGE_WITHDRAWAL_CONSENT
    };

    public PageReference initPage() {
        try {
            Map<String, String> params = ApexPages.currentPage().getParameters();
            String contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
            String token = params.get('token');
            if (String.isBlank(token)) {
                token = resolveTokenForRequestItem(contactId, params);
            }
            if (String.isBlank(contactId) || String.isBlank(token)) {
                return buildRedirect(PAGE_INVALID_LINK);
            }

            String refId = blankToNull(params.get(PARAM_REF_ID));
            if (String.isBlank(refId)) {
                // First visit: request authorization URL and send user to Singpass/MyInfo.
                String generatedRefId = generateRefId(contactId, params.get('requestItemId'));
                String redirectTo = buildCallbackUrl(params, generatedRefId);
                String authorizationUrl = requestAuthorizationUrl(generatedRefId, redirectTo);
                if (String.isBlank(authorizationUrl)) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'MyInfo authorization-url response did not contain authorization_url. refId=' + generatedRefId
                    );
                    return buildRedirect(PAGE_INVALID_LINK);
                }
                PageReference launchPage = new PageReference(authorizationUrl);
                launchPage.setRedirect(true);
                return launchPage;
            }

            // Callback visit: read profile and pass mapped values to consent page.
            Map<String, Object> profilePayload = fetchProfile(refId);
            try {
                recordSuccessfulWithdrawalAuthentication(params);
            } catch (Exception authRecordException) {
                System.debug(LoggingLevel.ERROR, 'Failed to record withdrawal Singpass authentication: ' + authRecordException.getMessage());
            }
            PageReference consentPage = buildConsentPage(params, contactId, token);
            applyMockProfileParams(consentPage, profilePayload);
            consentPage.setRedirect(true);
            return consentPage;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'QRSiteSingpassNdiAuthCtrl initPage failed: ' + e.getMessage());
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    private static PageReference buildConsentPage(Map<String, String> params, String contactId, String token) {
        PageReference consentPage = new PageReference(resolveTargetPagePath(params));
        copyParamIfPresent(consentPage, 'contactId', contactId);
        copyParamIfPresent(consentPage, 'requestItemId', firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId')));
        copyParamIfPresent(consentPage, 'token', token);
        copyParamIfPresent(consentPage, 'action', firstNonBlank(params.get('action'), 'authorize'));
        copyParamIfPresent(consentPage, 'type', firstNonBlank(params.get('type'), 'employee'));
        copyParamIfPresent(consentPage, 'authType', firstNonBlank(params.get('authType'), 'singpass'));
        consentPage.getParameters().put('returnFromAuth', 'true');
        return consentPage;
    }

    private static void recordSuccessfulWithdrawalAuthentication(Map<String, String> params) {
        if (params == null || !isWithdrawalCallback(params)) {
            return;
        }

        Id contactId = parseId(firstNonBlank(params.get('contactId'), params.get('ContactId')));
        Id requestItemId = parseId(firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId')));
        String token = params.get('token');
        if (contactId == null || requestItemId == null || String.isBlank(token)) {
            return;
        }

        List<Consent_Request_Item__c> requestItems = [
            SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c, Secure_Token__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItemId
            LIMIT 1
        ];
        if (requestItems.isEmpty()) {
            return;
        }

        Consent_Request_Item__c requestItem = requestItems[0];
        if (requestItem.Data_Subject__c != contactId
            || requestItem.Secure_Token__c != token
            || (requestItem.Consent_Link_Expires_At__c != null && System.now() > requestItem.Consent_Link_Expires_At__c)) {
            return;
        }
        Database.update(
            new Consent_Request_Item__c(
                Id = requestItem.Id,
                Withdrawal_QR_Viewed_At__c = System.now()
            ),
            false
        );
    }

    private static String resolveTokenForRequestItem(String contactIdRaw, Map<String, String> params) {
        Id contactId = parseId(contactIdRaw);
        Id requestItemId = parseId(firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId')));
        if (contactId == null || requestItemId == null) {
            return null;
        }

        List<Consent_Request_Item__c> rows = [
            SELECT Id, Data_Subject__c, Secure_Token__c, Consent_Link_Expires_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItemId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }

        Consent_Request_Item__c requestItem = rows[0];
        if (requestItem.Data_Subject__c != contactId) {
            return null;
        }
        if (requestItem.Consent_Link_Expires_At__c != null && System.now() > requestItem.Consent_Link_Expires_At__c) {
            return null;
        }
        return requestItem.Secure_Token__c;
    }

    private static Boolean isWithdrawalCallback(Map<String, String> params) {
        String action = blankToNull(params.get('action'));
        String returnUrl = getSafeReturnUrl(params.get(PARAM_RETURN_URL));
        return equalsIgnoreCase(action, 'withdraw') || PAGE_WITHDRAWAL_CONSENT.equalsIgnoreCase(returnUrl);
    }

    private static String requestAuthorizationUrl(String refId, String redirectTo) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(buildMyInfoEndpoint('/api/v1/myinfo/authorization-url'));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'ref_id' => refId,
            'redirect_to' => redirectTo
        }));

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            logCalloutException('authorization-url', e);
            throw e;
        }
        if (res == null) {
            System.debug(LoggingLevel.ERROR, 'MyInfo authorization-url returned null response.');
            throw new CalloutException('MyInfo authorization-url call failed.');
        }

        Integer statusCode = res.getStatusCode();
        String responseBody = summarizeForLog(res.getBody());
        if (statusCode == 401 || statusCode == 403) {
            System.debug(
                LoggingLevel.ERROR,
                'MyInfo authorization-url authentication failed. status=' + statusCode + ', body=' + responseBody
            );
            throw new CalloutException('MyInfo authorization-url call failed.');
        }
        if (statusCode < 200 || statusCode >= 300) {
            System.debug(
                LoggingLevel.ERROR,
                'MyInfo authorization-url unexpected status. status=' + statusCode + ', body=' + responseBody
            );
            throw new CalloutException('MyInfo authorization-url call failed.');
        }

        Map<String, Object> payload = parseJsonObject(res.getBody());
        String authorizationUrl = firstNonBlank(
            getAsString(payload, 'authorization_url'),
            getAsString(payload, 'authorizationUrl'),
            getAsString(payload, 'url')
        );
        if (String.isBlank(authorizationUrl)) {
            System.debug(
                LoggingLevel.ERROR,
                'MyInfo authorization-url succeeded but response URL is empty. status=' + statusCode + ', body=' + responseBody
            );
        }
        return authorizationUrl;
    }

    private static Map<String, Object> fetchProfile(String refId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(buildMyInfoEndpoint('/api/v1/myinfo/profile/' + EncodingUtil.urlEncode(refId, 'UTF-8')));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            logCalloutException('profile', e);
            throw e;
        }
        if (res == null) {
            System.debug(LoggingLevel.ERROR, 'MyInfo profile returned null response. refId=' + refId);
            return new Map<String, Object>();
        }
        Integer statusCode = res.getStatusCode();
        String responseBody = summarizeForLog(res.getBody());
        if (statusCode == 401 || statusCode == 403) {
            System.debug(
                LoggingLevel.ERROR,
                'MyInfo profile authentication failed. refId=' + refId + ', status=' + statusCode + ', body=' + responseBody
            );
        }
        if (res.getStatusCode() == 404) {
            // No profile captured yet; continue to consent form without prefill.
            return new Map<String, Object>();
        }
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            System.debug(
                LoggingLevel.ERROR,
                'MyInfo profile unexpected status. refId=' + refId + ', status=' + statusCode + ', body=' + responseBody
            );
            throw new CalloutException('MyInfo profile call failed.');
        }
        return parseJsonObject(res.getBody());
    }

    private static void logCalloutException(String endpointName, Exception e) {
        String message = e == null ? '' : blankIfNull(e.getMessage());
        String normalized = String.isBlank(message) ? '' : message.toLowerCase();
        if (normalized.contains('read timed out') || normalized.contains('connect timed out') || normalized.contains('timeout')) {
            System.debug(
                LoggingLevel.ERROR,
                'MyInfo ' + endpointName + ' callout timeout. message=' + message
            );
            return;
        }
        System.debug(
            LoggingLevel.ERROR,
            'MyInfo ' + endpointName + ' callout exception. message=' + message
        );
    }

    private static String summarizeForLog(String rawBody) {
        if (String.isBlank(rawBody)) {
            return '(empty)';
        }
        String compact = rawBody.replace('\n', ' ').replace('\r', ' ').trim();
        Integer maxLength = 500;
        if (compact.length() > maxLength) {
            return compact.substring(0, maxLength) + '...';
        }
        return compact;
    }

    private static void applyMockProfileParams(PageReference consentPage, Map<String, Object> profilePayload) {
        if (consentPage == null || profilePayload == null || profilePayload.isEmpty()) {
            return;
        }

        Map<String, Object> data = resolvePersonInfoNode(profilePayload);

        putMock(consentPage, 'mockSub', getByPaths(data, new List<String>{ 'sub', 'uinfin.value', 'uinfin' }));
        putMock(consentPage, 'mockName', getByPaths(data, new List<String>{ 'name.value', 'name', 'fullName' }));
        putMock(consentPage, 'mockGivenName', getByPaths(data, new List<String>{ 'given_name', 'givenName', 'name.given' }));
        putMock(consentPage, 'mockFamilyName', getByPaths(data, new List<String>{ 'family_name', 'familyName', 'name.family' }));
        putMock(consentPage, 'mockEmail', getByPaths(data, new List<String>{ 'email.value', 'email' }));
        putMock(consentPage, 'mockUinfin', getByPaths(data, new List<String>{ 'uinfin.value', 'uinfin' }));
        putMock(consentPage, 'mockMobileNo', getByPaths(data, new List<String>{ 'mobileno.nbr.value', 'mobileno.value', 'mobile', 'mobileNo' }));
        putMock(consentPage, 'mockDateOfBirth', getByPaths(data, new List<String>{ 'dob.value', 'dob', 'dateOfBirth' }));
        putMock(consentPage, 'mockNationality', getByPaths(data, new List<String>{ 'nationality.desc', 'nationality.value', 'nationality' }));
        putMock(consentPage, 'mockIdType', getByPaths(data, new List<String>{ 'identityType', 'idType' }));
        putMock(consentPage, 'mockGender', getByPaths(data, new List<String>{ 'sex.desc', 'sex.value', 'gender' }));
        putMock(consentPage, 'mockMaritalStatus', getByPaths(data, new List<String>{ 'marital.desc', 'marital.value', 'maritalStatus' }));
        putMock(consentPage, 'mockPassType', getByPaths(data, new List<String>{ 'passtype.desc', 'passtype.value', 'passType' }));
        putMock(consentPage, 'mockPassportNumber', getByPaths(data, new List<String>{ 'passportnumber.value', 'passportNo', 'passportNumber' }));

        String address = buildAddressText(data);
        if (!String.isBlank(address)) {
            consentPage.getParameters().put('mockRegisteredAddress', address);
        }
    }

    private static String buildAddressText(Map<String, Object> data) {
        String block = getByPaths(data, new List<String>{ 'regadd.block' });
        String street = getByPaths(data, new List<String>{ 'regadd.street' });
        String floor = getByPaths(data, new List<String>{ 'regadd.floor' });
        String unit = getByPaths(data, new List<String>{ 'regadd.unit' });
        String country = getByPaths(data, new List<String>{ 'regadd.country.desc' });
        String postal = getByPaths(data, new List<String>{ 'regadd.postal' });

        List<String> parts = new List<String>();
        if (!String.isBlank(block)) parts.add(block);
        if (!String.isBlank(street)) parts.add(street);
        if (!String.isBlank(floor) || !String.isBlank(unit)) {
            String floorUnit = '';
            if (!String.isBlank(floor)) {
                floorUnit += floor;
            }
            if (!String.isBlank(unit)) {
                floorUnit += (String.isBlank(floorUnit) ? '' : '-') + unit;
            }
            if (!String.isBlank(floorUnit) && !floorUnit.startsWith('#')) {
                floorUnit = '#' + floorUnit;
            }
            if (!String.isBlank(floorUnit)) {
                parts.add(floorUnit);
            }
        }
        if (!String.isBlank(country)) parts.add(country);
        if (!String.isBlank(postal)) parts.add(postal);

        if (!parts.isEmpty()) {
            return String.join(parts, ' ').replaceAll('\\s+', ' ').trim();
        }
        return getByPaths(data, new List<String>{ 'registeredAddress', 'address' });
    }

    private static String buildMyInfoEndpoint(String path) {
        if (String.isBlank(path)) {
            throw new CalloutException('MyInfo endpoint path is required.');
        }
        String normalized = path.startsWith('/') ? path : ('/' + path);
        return MYINFO_NAMED_CREDENTIAL + normalized;
    }

    private static String buildCallbackUrl(Map<String, String> params, String refId) {
        String guestBase = ConsentGuestAuthService.getGuestSiteBaseUrl();

        String callbackBase = guestBase + '/ndi_auth';
        List<String> queryPairs = new List<String>();
        addQueryPair(queryPairs, 'contactId', firstNonBlank(params.get('contactId'), params.get('ContactId')));
        addQueryPair(queryPairs, 'requestItemId', firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId')));
        addQueryPair(queryPairs, 'token', params.get('token'));
        addQueryPair(queryPairs, 'action', firstNonBlank(params.get('action'), 'authorize'));
        addQueryPair(queryPairs, 'type', firstNonBlank(params.get('type'), 'employee'));
        addQueryPair(queryPairs, 'authType', firstNonBlank(params.get('authType'), 'singpass'));
        addQueryPair(queryPairs, PARAM_RETURN_URL, getSafeReturnUrl(params.get(PARAM_RETURN_URL)));
        addQueryPair(queryPairs, PARAM_REF_ID, refId);
        return callbackBase + '?' + String.join(queryPairs, '&');
    }

    private static String resolveTargetPagePath(Map<String, String> params) {
        String safeReturnUrl = getSafeReturnUrl(params == null ? null : params.get(PARAM_RETURN_URL));
        if (!String.isBlank(safeReturnUrl)) {
            return safeReturnUrl;
        }

        String entryType = blankToNull(params == null ? null : params.get('type'));
        if (!String.isBlank(entryType) && entryType.toLowerCase() == TYPE_PREHIRE) {
            return PAGE_PREHIRE_CONSENT_FORM;
        }

        return PAGE_EMPLOYEE_CONSENT_FORM;
    }

    private static String getSafeReturnUrl(String rawReturnUrl) {
        String cleanedReturnUrl = blankToNull(rawReturnUrl);
        if (String.isBlank(cleanedReturnUrl)) {
            return null;
        }
        if (!cleanedReturnUrl.startsWith('/apex/')) {
            return null;
        }
        for (String allowedUrl : ALLOWED_RETURN_URLS) {
            if (allowedUrl.equalsIgnoreCase(cleanedReturnUrl)) {
                return allowedUrl;
            }
        }
        return null;
    }

    private static String generateRefId(String contactId, String requestItemId) {
        String seed = String.valueOf(System.now().getTime()) + ':' + blankIfNull(contactId) + ':' + blankIfNull(requestItemId);
        String hash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(seed)));
        return 'cbs-' + hash.substring(0, 24);
    }

    private static void addQueryPair(List<String> queryPairs, String key, String value) {
        if (String.isBlank(key) || String.isBlank(value)) {
            return;
        }
        queryPairs.add(
            EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(value, 'UTF-8')
        );
    }

    private static String getByPaths(Map<String, Object> root, List<String> dotPaths) {
        return getByPaths(root, dotPaths, false);
    }

    private static String getByPaths(Map<String, Object> root, List<String> dotPaths, Boolean concatMode) {
        if (root == null || dotPaths == null) {
            return null;
        }
        List<String> values = new List<String>();
        for (String dotPath : dotPaths) {
            String value = getByPath(root, dotPath);
            if (String.isBlank(value)) {
                continue;
            }
            if (concatMode == true) {
                values.add(value);
            } else {
                return value;
            }
        }
        return concatMode == true && !values.isEmpty() ? String.join(values, ' ').replaceAll('\\s+', ' ').trim() : null;
    }

    private static String getByPath(Map<String, Object> root, String dotPath) {
        if (root == null || String.isBlank(dotPath)) {
            return null;
        }
        Object current = root;
        for (String segment : dotPath.split('\\.')) {
            if (!(current instanceof Map<String, Object>)) {
                return null;
            }
            Map<String, Object> mapValue = (Map<String, Object>) current;
            if (!mapValue.containsKey(segment)) {
                return null;
            }
            current = mapValue.get(segment);
        }
        return extractStringValue(current);
    }

    private static Map<String, Object> resolvePersonInfoNode(Map<String, Object> payload) {
        if (payload == null) {
            return new Map<String, Object>();
        }

        Map<String, Object> current = payload;
        if (current.containsKey('data') && current.get('data') instanceof Map<String, Object>) {
            current = (Map<String, Object>) current.get('data');
        }
        if (current.containsKey('myinfo_profile') && current.get('myinfo_profile') instanceof Map<String, Object>) {
            current = (Map<String, Object>) current.get('myinfo_profile');
        }
        if (current.containsKey('person_info') && current.get('person_info') instanceof Map<String, Object>) {
            current = (Map<String, Object>) current.get('person_info');
        }
        return current;
    }

    private static String extractStringValue(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        if (!(rawValue instanceof Map<String, Object>)) {
            String plain = String.valueOf(rawValue).trim();
            return String.isBlank(plain) ? null : plain;
        }

        Map<String, Object> nested = (Map<String, Object>) rawValue;
        for (String key : new List<String>{ 'value', 'desc', 'code' }) {
            if (!nested.containsKey(key)) {
                continue;
            }
            String picked = extractStringValue(nested.get(key));
            if (!String.isBlank(picked)) {
                return picked;
            }
        }
        return null;
    }

    private static Map<String, Object> parseJsonObject(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new Map<String, Object>();
        }
        Object parsed = JSON.deserializeUntyped(rawJson);
        return (parsed instanceof Map<String, Object>) ? (Map<String, Object>) parsed : new Map<String, Object>();
    }

    private static String getAsString(Map<String, Object> mapValue, String key) {
        if (mapValue == null || String.isBlank(key) || !mapValue.containsKey(key)) {
            return null;
        }
        Object raw = mapValue.get(key);
        return raw == null ? null : String.valueOf(raw);
    }

    private static void putMock(PageReference targetPage, String key, String value) {
        if (targetPage == null || String.isBlank(key) || String.isBlank(value)) {
            return;
        }
        targetPage.getParameters().put(key, value);
    }

    private static PageReference buildRedirect(String pagePath) {
        PageReference pageRef = new PageReference(pagePath);
        pageRef.setRedirect(true);
        return pageRef;
    }

    private static void copyParamIfPresent(PageReference targetPage, String key, String value) {
        if (targetPage == null || String.isBlank(key) || String.isBlank(value)) {
            return;
        }
        targetPage.getParameters().put(key, value);
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        return !String.isBlank(firstValue) ? firstValue : secondValue;
    }

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        return thirdValue;
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private static Id parseId(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            return (Id) rawValue;
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.toLowerCase() == right.toLowerCase();
    }
}