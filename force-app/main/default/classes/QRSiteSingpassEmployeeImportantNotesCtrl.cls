/**
 * Important Notes page for Singpass Employee / 5-year Term-based Consent flow.
 * Does NOT record consent; only informs the data subject before Singpass authentication.
 */
public with sharing class QRSiteSingpassEmployeeImportantNotesCtrl {
    private static final String ACTION_AUTHORIZE = 'authorize';
    private static final String TYPE_EMPLOYEE = 'employee';
    private static final String AUTH_TYPE_SINGPASS = 'singpass';

    private static final String AUTHENTICATION_TYPE_SINGPASS = 'Singpass';
    private static final String EMPLOYMENT_STATUS_EXISTING_HIRE = 'Existing Hire';
    private static final String CONSENT_TYPE_TERM_BASED = 'Term-Based Consent';

    private static final String STATUS_AUTHORIZED = 'Authorized';
    private static final String STATUS_VALID = 'Valid';
    private static final String STATUS_DECLINED = 'Declined';
    private static final String STATUS_WITHDRAWN = 'Withdrawn';
    private static final String STATUS_EXPIRED = 'Expired';

    private static final Set<String> TERMINAL_REQUEST_STATUSES = new Set<String>{
        'Submitted', 'Declined', 'Withdrawn', 'Expired'
    };

    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/QRSiteConsentAlreadyActioned';
    private static final String PAGE_ACTIVE_CONSENT = '/apex/QRSiteActiveConsentNotification';
    private static final String PAGE_DECLINE_CONFIRMATION = '/apex/QRSiteDeclineConfirmation';
    // TODO: Replace with actual Singpass launch page when available in org.
    private static final String PAGE_SINGPASS_AUTH = '/apex/ndi_auth';

    public String contactId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public String actionParam { get; private set; }
    public String typeParam { get; private set; }
    public String authTypeParam { get; private set; }

    public Boolean canRenderPage { get; private set; }

    private Contact contactRecord;
    private Consent_Request_Item__c requestItemRecord;
    private String bankName;
    private String hrSupportEmail;

    public QRSiteSingpassEmployeeImportantNotesCtrl() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('ContactId'), params.get('contactId'));
        requestItemId = firstNonBlank(
            params.get('requestItemId'),
            params.get('consentRequestItemId')
        );
        token = params.get('token');
        actionParam = blankToNull(params.get('action'));
        typeParam = blankToNull(params.get('type'));
        authTypeParam = blankToNull(params.get('authType'));
        canRenderPage = false;
    }

    public PageReference initializePage() {
        try {
            PageReference redirect = validateAndResolveRedirect();
            if (redirect != null) {
                return redirect;
            }
            loadDisplayContext();
            canRenderPage = true;
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'initializePage failed: ' + e.getMessage());
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    public PageReference continueWithSingpass() {
        try {
            PageReference redirect = validateAndResolveRedirect();
            if (redirect != null) {
                return redirect;
            }

            PageReference nextPage = buildRedirect(PAGE_SINGPASS_AUTH);
            copyContextParams(nextPage);
            nextPage.getParameters().put('action', ACTION_AUTHORIZE);
            nextPage.getParameters().put('type', TYPE_EMPLOYEE);
            nextPage.getParameters().put('authType', AUTH_TYPE_SINGPASS);
            return nextPage;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'continueWithSingpass failed: ' + e.getMessage());
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    public PageReference declineConsent() {
        try {
            PageReference redirect = validateAndResolveRedirect();
            if (redirect != null) {
                return redirect;
            }

            PageReference nextPage = buildRedirect(PAGE_DECLINE_CONFIRMATION);
            copyContextParams(nextPage);
            return nextPage;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'declineConsent failed: ' + e.getMessage());
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    public String getPageTitle() {
        return 'Important Notes Before You Proceed';
    }

    public String getPageSubtitle() {
        return 'Singpass Employee - 5-year Term-based Consent';
    }

    public String getIntroText() {
        return 'You have accessed this page because ' + escapeForDisplay(getBankName())
            + ' Human Resources has requested you to indicate whether you consent to Credit Bureau (Singapore) Pte Ltd ("CBS") '
            + 'collecting, receiving, using, releasing and disclosing your personal credit information to '
            + escapeForDisplay(getBankName())
            + ' for employment-related credit assessment / background screening purposes.';
    }

    public String getSection1Point1() {
        return escapeForDisplay(getBankName())
            + ' is requesting your consent so that CBS may process an authorised credit report request '
            + 'for employment-related credit assessment / background screening purposes.';
    }

    public String getSection1Point2() {
        return 'This page does not mean that you have already given consent. Your consent will only be recorded '
            + 'after you have reviewed the consent form and submitted it.';
    }

    public String getSection3Point1() {
        return 'By submitting the consent form, you will be explicitly authorising and consenting to CBS collecting, '
            + 'receiving, using, releasing and disclosing your personal credit information to '
            + escapeForDisplay(getBankName()) + '.';
    }

    public String getSection4Point3() {
        return escapeForDisplay(getBankName()) + ' will be notified.';
    }

    public String getSection4Point4() {
        return escapeForDisplay(getBankName())
            + ' will not be able to submit a new credit report request to CBS under this consent request '
            + 'unless valid consent is provided in future.';
    }

    public String getSection5Point1() {
        return 'If you provide consent, you may withdraw your consent later by using the withdrawal link provided '
            + 'in the email from ' + escapeForDisplay(getBankName()) + ' Human Resources.';
    }

    public String getSection5Point3() {
        return 'Withdrawing your consent will prevent ' + escapeForDisplay(getBankName())
            + ' from submitting any new credit report request to CBS under this consent.';
    }

    public String getSection6Point2() {
        String hrEmail = getHrSupportEmail();
        if (String.isBlank(hrEmail)) {
            // TODO: Confirm Account HR support email field API name if different from HR_Support_Email__c.
            return 'If you have any questions, please contact '
                + escapeForDisplay(getBankName())
                + ' Human Resources before continuing.';
        }
        return 'If you have any questions, please contact '
            + escapeForDisplay(getBankName())
            + ' Human Resources at '
            + escapeForDisplay(hrEmail)
            + ' before continuing.';
    }

    private PageReference validateAndResolveRedirect() {
        if (String.isBlank(contactId) || String.isBlank(token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        Id subjectId = parseId(contactId);
        if (subjectId == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        contactRecord = queryContact(subjectId);
        if (contactRecord == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        requestItemRecord = resolveRequestItem(subjectId);
        if (requestItemRecord == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (!isTokenValidForRequestItem(requestItemRecord, token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (requestItemRecord.Data_Subject__c != subjectId) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        if (!isSingpassEmployeeTermScenario()) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (!String.isBlank(actionParam) && actionParam.toLowerCase() != ACTION_AUTHORIZE) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        return resolveConsentStatusRedirect();
    }

    private PageReference resolveConsentStatusRedirect() {
        String contactStatus = normalizeStatus(getStringField(contactRecord, 'Current_Consent_Status__c'));

        if (isActiveConsentStatus(contactStatus)) {
            PageReference activePage = buildRedirect(PAGE_ACTIVE_CONSENT);
            copyContextParams(activePage);
            return activePage;
        }

        if (contactStatus == normalizeStatus(STATUS_DECLINED) || contactStatus == normalizeStatus(STATUS_WITHDRAWN)) {
            PageReference actionedPage = buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            copyContextParams(actionedPage);
            return actionedPage;
        }

        if (contactStatus == normalizeStatus(STATUS_EXPIRED)) {
            PageReference expiredPage = buildRedirect(PAGE_LINK_EXPIRED);
            copyContextParams(expiredPage);
            return expiredPage;
        }

        String requestStatus = normalizeStatus(requestItemRecord.Current_Status__c);
        if (containsNormalizedStatus(TERMINAL_REQUEST_STATUSES, requestStatus)) {
            if (requestStatus == 'expired') {
                PageReference expiredPage = buildRedirect(PAGE_LINK_EXPIRED);
                copyContextParams(expiredPage);
                return expiredPage;
            }
            PageReference actionedPage = buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            copyContextParams(actionedPage);
            return actionedPage;
        }

        return null;
    }

    private Boolean isSingpassEmployeeTermScenario() {
        String authTypeFromContact = normalizeStatus(getStringField(contactRecord, 'Authentication_Type__c'));
        String employmentStatus = normalizeStatus(getStringField(contactRecord, 'Employment_Status__c'));
        String consentType = normalizeStatus(getStringField(contactRecord, 'Consent_Type__c'));

        String authTypeFromUrl = normalizeStatus(authTypeParam);
        String typeFromUrl = normalizeStatus(typeParam);

        Boolean authTypeOk =
            authTypeFromUrl == AUTH_TYPE_SINGPASS
            || authTypeFromContact == normalizeStatus(AUTHENTICATION_TYPE_SINGPASS);

        Boolean employeeOk =
            typeFromUrl == TYPE_EMPLOYEE
            || employmentStatus == normalizeStatus(EMPLOYMENT_STATUS_EXISTING_HIRE);

        Boolean termBasedOk =
            consentType == normalizeStatus(CONSENT_TYPE_TERM_BASED)
            || consentType.contains('term');

        // TODO: Add RecordType / Subject_Type__c checks on Consent_Request_Item__c if your org uses them.
        return authTypeOk && employeeOk && termBasedOk;
    }

    private void loadDisplayContext() {
        bankName = getAccountName(contactRecord);
        if (String.isBlank(bankName)) {
            bankName = 'your employer';
        }
        hrSupportEmail = getAccountHrSupportEmail(contactRecord);
    }

    private String getBankName() {
        return String.isBlank(bankName) ? 'your employer' : bankName;
    }

    private String getHrSupportEmail() {
        return hrSupportEmail;
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> selectFields = new List<String>{
            'Id', 'Name', 'Email', 'AccountId', 'Account.Name'
        };
        addFieldIfExists(contactFields, selectFields, 'Employment_Status__c');
        addFieldIfExists(contactFields, selectFields, 'Authentication_Type__c');
        addFieldIfExists(contactFields, selectFields, 'Consent_Type__c');
        addFieldIfExists(contactFields, selectFields, 'Current_Consent_Status__c');
        addFieldIfExists(contactFields, selectFields, 'Current_Consent_Expiry_Date__c');
        // TODO: Replace HR_Support_Email__c if your Account uses a different API name.
        addFieldIfExists(contactFields, selectFields, 'Account.HR_Support_Email__c');

        String soql = 'SELECT ' + String.join(selectFields, ',')
            + ' FROM Contact WHERE Id = :subjectId LIMIT 1';

        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Consent_Request_Item__c resolveRequestItem(Id subjectId) {
        if (!String.isBlank(requestItemId)) {
            Consent_Request_Item__c byId = queryRequestItemById(parseId(requestItemId));
            if (byId != null) {
                return byId;
            }
        }

        Consent_Request_Item__c byToken = queryRequestItemByToken(token);
        if (byToken != null) {
            requestItemId = byToken.Id;
            return byToken;
        }

        List<Consent_Request_Item__c> latestItems = [
            SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :subjectId
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 1
        ];
        if (!latestItems.isEmpty()) {
            requestItemId = latestItems[0].Id;
        }
        return latestItems.isEmpty() ? null : latestItems[0];
    }

    private Consent_Request_Item__c queryRequestItemById(Id itemId) {
        if (itemId == null) {
            return null;
        }

        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        List<String> selectFields = new List<String>{
            'Id', 'Data_Subject__c', 'Current_Status__c', 'Consent_Link_Expires_At__c'
        };
        String tokenField = findFirstExistingField(
            fieldMap,
            new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' }
        );
        if (!String.isBlank(tokenField)) {
            selectFields.add(tokenField);
        }

        String soql = 'SELECT ' + String.join(selectFields, ',')
            + ' FROM Consent_Request_Item__c WHERE Id = :itemId LIMIT 1';

        List<Consent_Request_Item__c> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(
            fieldMap,
            new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' }
        );
        if (String.isBlank(tokenField)) {
            // TODO: Add Token__c (or equivalent) to Consent_Request_Item__c if not yet deployed.
            return null;
        }

        List<String> selectFields = new List<String>{
            'Id', 'Data_Subject__c', 'Current_Status__c', 'Consent_Link_Expires_At__c', tokenField
        };

        String soql = 'SELECT ' + String.join(selectFields, ',')
            + ' FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';

        List<Consent_Request_Item__c> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Boolean isTokenValidForRequestItem(Consent_Request_Item__c item, String tokenValue) {
        if (item == null || String.isBlank(tokenValue)) {
            return false;
        }

        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(
            fieldMap,
            new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' }
        );
        if (String.isBlank(tokenField)) {
            // TODO: Remove this fallback once Token__c is deployed in all orgs.
            return true;
        }

        Consent_Request_Item__c refreshed = queryRequestItemById(item.Id);
        if (refreshed != null && hasField(refreshed, tokenField) && refreshed.get(tokenField) != null) {
            return String.valueOf(refreshed.get(tokenField)) == tokenValue;
        }

        Consent_Request_Item__c byToken = queryRequestItemByToken(tokenValue);
        return byToken != null && byToken.Id == item.Id;
    }

    private Boolean isRequestItemLinkExpired(Consent_Request_Item__c item) {
        if (item == null) {
            return true;
        }

        List<String> expiryFieldCandidates = new List<String>{
            'Consent_Link_Expires_At__c',
            'Link_Expires_At__c',
            'Expires_At__c',
            'Expiry_Date_Time__c',
            'Token_Expires_At__c',
            'Link_Expiry_DateTime__c'
        };

        for (String fieldApi : expiryFieldCandidates) {
            if (!hasField(item, fieldApi)) {
                continue;
            }
            Object rawValue = item.get(fieldApi);
            if (rawValue instanceof Datetime && ((Datetime) rawValue) < System.now()) {
                return true;
            }
            if (rawValue instanceof Date && ((Date) rawValue) < Date.today()) {
                return true;
            }
        }
        return false;
    }

    private Boolean isActiveConsentStatus(String normalizedStatus) {
        return normalizedStatus == normalizeStatus(STATUS_AUTHORIZED)
            || normalizedStatus == normalizeStatus(STATUS_VALID);
    }

    private String getAccountName(Contact con) {
        if (con == null) {
            return null;
        }
        SObject account = con.getSObject('Account');
        if (account != null && account.get('Name') != null) {
            return String.valueOf(account.get('Name'));
        }
        return null;
    }

    private String getAccountHrSupportEmail(Contact con) {
        if (con == null) {
            return null;
        }
        SObject account = con.getSObject('Account');
        if (account != null && hasField(account, 'HR_Support_Email__c')) {
            return blankToNull(String.valueOf(account.get('HR_Support_Email__c')));
        }
        return null;
    }

    private PageReference buildRedirect(String urlPath) {
        PageReference pageRef = new PageReference(urlPath);
        pageRef.setRedirect(true);
        return pageRef;
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }
        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('ContactId', contactId);
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }
        if (!String.isBlank(actionParam)) {
            targetPage.getParameters().put('action', actionParam);
        }
        if (!String.isBlank(typeParam)) {
            targetPage.getParameters().put('type', typeParam);
        }
        if (!String.isBlank(authTypeParam)) {
            targetPage.getParameters().put('authType', authTypeParam);
        }
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

    private static String firstNonBlank(String firstValue, String secondValue) {
        return !String.isBlank(firstValue) ? firstValue : secondValue;
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static String normalizeStatus(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static Boolean containsNormalizedStatus(Set<String> statuses, String normalizedStatus) {
        for (String status : statuses) {
            if (normalizeStatus(status) == normalizedStatus) {
                return true;
            }
        }
        return false;
    }

    private static String getStringField(SObject record, String fieldApi) {
        if (record == null || String.isBlank(fieldApi) || !hasField(record, fieldApi)) {
            return null;
        }
        Object raw = record.get(fieldApi);
        return raw == null ? null : String.valueOf(raw);
    }

    private static Boolean hasField(SObject record, String fieldApi) {
        return record != null
            && !String.isBlank(fieldApi)
            && record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApi);
    }

    private static void addFieldIfExists(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> selectFields,
        String fieldApi
    ) {
        if (fieldMap.containsKey(fieldApi) && !selectFields.contains(fieldApi)) {
            selectFields.add(fieldApi);
        }
    }

    private static String findFirstExistingField(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> candidates
    ) {
        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private static String escapeForDisplay(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.replace('<', '').replace('>', '');
    }
}