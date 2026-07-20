/**
 * Important Notes page for Singpass Pre-hire / Per-Report Consent flow.
 * Guest-accessible via Salesforce Sites / Experience Cloud.
 * Does not record consent; only displays pre-authorisation information and routes next steps.
 */
public without sharing class QRSiteSingpassPrehireImportantNotesCtrl {
    private static final String ACTION_AUTHORIZE = 'authorize';
    private static final String TYPE_PREHIRE = 'prehire';
    private static final String AUTH_TYPE_SINGPASS = 'singpass';

    private static final String CONTACT_STATUS_AUTHORIZED = 'Authorized';
    private static final String CONTACT_STATUS_VALID = 'Valid';
    private static final String CONTACT_STATUS_DECLINED = 'Declined';
    private static final String CONTACT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String CONTACT_STATUS_EXPIRED = 'Expired';

    private static final String LIFECYCLE_STAGE_ACTIVE_CONSENT = 'Active Consent';

    private static final String REQUEST_STATUS_SUBMITTED = 'Submitted';
    private static final String REQUEST_STATUS_DECLINED = 'Declined';
    private static final String REQUEST_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String REQUEST_STATUS_EXPIRED = 'Expired';

    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_ACTIVE_CONSENT = '/apex/ActiveConsentNotificationPage';
    private static final String PAGE_DECLINE_CONFIRMATION = '/apex/CBSDeclineConsentConfirmation';
    private static final String PAGE_CONSENT_FORM = '/apex/QRSiteSingpassPrehireConsentForm';
    private static final String PAGE_SINGPASS_AUTH = '/apex/ndi_auth';

    public String contactId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public String entryAction { get; private set; }
    public String entryType { get; private set; }
    public String entryAuthType { get; private set; }
    public Boolean showPage { get; private set; }

    private Contact contactRecord;
    private Consent_Request_Item__c requestItemRecord;
    private Boolean contextLoaded = false;
    private Boolean contextValid = false;
    private String hrSupportEmail;

    public QRSiteSingpassPrehireImportantNotesCtrl() {
        parseUrlParameters();
        showPage = false;
    }

    public PageReference initPage() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }
            showPage = true;
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'initPage failed: ' + e.getMessage());
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    public String getImportantNotesTitle() {
        return 'Important Notes Before You Proceed';
    }

    public String getIntroText() {
        return 'You have accessed this page because ' + getBankName()
            + ' Human Resources has requested you to indicate whether you consent to Credit Bureau (Singapore) Pte Ltd ("CBS") '
            + 'collecting, receiving, using, releasing and disclosing your personal credit information to '
            + getBankName()
            + ' for pre-employment screening / background check purposes.';
    }

    public String getReadNotesPrompt() {
        return 'Please read the following notes carefully before you proceed.';
    }

    public List<String> getWhatThisRequestIsForParagraphs() {
        return new List<String>{
            getBankName()
                + ' is requesting your consent so that CBS may process an authorised credit report request as part of '
                + getBankName()
                + '\'s pre-employment screening / background check process.',
            'This page does not mean that you have already given consent. Your consent will only be recorded '
                + 'after you have reviewed the consent form and submitted it.'
        };
    }

    public List<String> getSingpassMyinfoParagraphs() {
        return new List<String>{
            'If you choose to proceed, you will be redirected to Singpass to authenticate your identity.',
            'After successful Singpass authentication, selected personal information from Myinfo may be retrieved and used to populate the consent form. '
                + 'This may include your name, NRIC / FIN, pass type, passport number, date of birth, nationality, gender, marital status and registered address, where applicable.',
            'Please review the information shown on the consent form carefully before submitting.'
        };
    }

    public List<String> getYourConsentParagraphs() {
        return new List<String>{
            'By submitting the consent form, you will be explicitly authorising and consenting to CBS collecting, '
                + 'receiving, using, releasing and disclosing your personal credit information to '
                + getBankName()
                + ' for pre-employment screening / background check purposes.',
            'Your consent will remain valid for 1 month from the date of submission or until one successful '
                + 'credit report retrieval has been completed, whichever is earlier, unless withdrawn earlier.'
        };
    }

    public List<String> getDeclineParagraphs() {
        return new List<String>{
            'You may decline to give consent.',
            'If you decline, CBS will update your consent status as declined and ' + getBankName()
                + ' will be notified. ' + getBankName()
                + ' will not be able to submit a credit report request to CBS under this consent request '
                + 'unless valid consent is provided in future.'
        };
    }

    public List<String> getWithdrawalParagraphs() {
        return new List<String>{
            'If you provide consent, you may withdraw your consent later by using the withdrawal link provided '
                + 'in the email from ' + getBankName() + ' Human Resources.',
            'You may be required to authenticate via Singpass before your withdrawal is submitted.',
            'Withdrawing your consent will prevent ' + getBankName()
                + ' from submitting any new credit report request to CBS under this consent. '
                + 'It will not affect any request that was already submitted, processed or completed before the withdrawal date and time.'
        };
    }

    public List<String> getSecurityParagraphs() {
        return new List<String>{
            'Please do not proceed if you are unsure why you received this request.',
            buildSecurityContactText()
        };
    }

    public String getContinueButtonLabel() {
        return 'Continue with Singpass';
    }

    public String getDeclineButtonLabel() {
        return 'Decline to Give Consent';
    }

    public String getBankName() {
        ensureContextLoaded();
        if (contactRecord == null || contactRecord.Account == null) {
            return 'your employer';
        }
        return String.isBlank(contactRecord.Account.Name) ? 'your employer' : contactRecord.Account.Name;
    }

    public PageReference continueWithSingpass() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect(false, false);
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            PageReference singpassPage = buildRedirect(PAGE_SINGPASS_AUTH);
            copyContextParams(singpassPage);
            singpassPage.getParameters().put('action', ACTION_AUTHORIZE);
            singpassPage.getParameters().put('type', TYPE_PREHIRE);
            singpassPage.getParameters().put('authType', AUTH_TYPE_SINGPASS);
            singpassPage.getParameters().put('returnUrl', PAGE_CONSENT_FORM);
            singpassPage.setRedirect(true);
            return singpassPage;
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    public PageReference declineConsent() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            PageReference declinePage = buildRedirect(PAGE_DECLINE_CONFIRMATION);
            copyContextParams(declinePage);
            declinePage.setRedirect(true);
            return declinePage;
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    private String buildSecurityContactText() {
        String hrEmail = getHrSupportEmail();
        if (String.isBlank(hrEmail)) {
            return 'If you have any questions about this request, please contact '
                + getBankName()
                + ' Human Resources before continuing.';
        }
        return 'If you have any questions about this request, please contact '
            + getBankName()
            + ' Human Resources at '
            + hrEmail
            + ' before continuing.';
    }

    private String getHrSupportEmail() {
        ensureContextLoaded();
        return hrSupportEmail;
    }

    private PageReference validateEntryAndResolveRedirect() {
        return validateEntryAndResolveRedirect(true, true);
    }

    private PageReference validateEntryAndResolveRedirect(Boolean checkActiveConsentOnEntry, Boolean checkContactConsentStatus) {
        resetContext();

        if (String.isBlank(contactId) || String.isBlank(token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        Id parsedContactId = parseId(contactId);
        if (parsedContactId == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        contactRecord = queryContact(parsedContactId);
        if (contactRecord == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        hrSupportEmail = getAccountHrSupportEmail(contactRecord);

        requestItemRecord = resolveRequestItem(parsedContactId);
        if (!isTokenValidForRequestItem(requestItemRecord, token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        if (!isSingpassPrehireScenario()) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        PageReference statusRedirect = resolveConsentStatusRedirect(
            parsedContactId,
            checkActiveConsentOnEntry,
            checkContactConsentStatus
        );
        if (statusRedirect != null) {
            return statusRedirect;
        }

        contextValid = true;
        return null;
    }

    private PageReference resolveConsentStatusRedirect(
        Id subjectId,
        Boolean checkActiveConsent,
        Boolean checkContactConsentStatus
    ) {
        if (checkContactConsentStatus == true) {
            if (checkActiveConsent
                && matchesContactLifecycleAndStatus(
                    contactRecord,
                    LIFECYCLE_STAGE_ACTIVE_CONSENT,
                    CONTACT_STATUS_AUTHORIZED
                )) {
                return buildRedirect(PAGE_ACTIVE_CONSENT);
            }

            String contactStatus = blankIfNull(contactRecord.Current_Consent_Status__c);
            if (contactStatus == CONTACT_STATUS_DECLINED || contactStatus == CONTACT_STATUS_WITHDRAWN) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (contactStatus == CONTACT_STATUS_EXPIRED) {
                return buildRedirect(PAGE_LINK_EXPIRED);
            }
        }

        if (requestItemRecord != null) {
            String requestStatus = blankIfNull(requestItemRecord.Current_Status__c);
            if (requestStatus == REQUEST_STATUS_SUBMITTED) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (requestStatus == REQUEST_STATUS_DECLINED || requestStatus == REQUEST_STATUS_WITHDRAWN) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (requestStatus == REQUEST_STATUS_EXPIRED) {
                return buildRedirect(PAGE_LINK_EXPIRED);
            }
        }

        return null;
    }

    private Boolean isSingpassPrehireScenario() {
        if (!String.isBlank(entryAction) && entryAction.toLowerCase() != ACTION_AUTHORIZE) {
            return false;
        }
        if (!String.isBlank(entryType) && entryType.toLowerCase() != TYPE_PREHIRE) {
            return false;
        }
        if (!String.isBlank(entryAuthType) && entryAuthType.toLowerCase() != AUTH_TYPE_SINGPASS) {
            return false;
        }

        String authType = getStringFieldValue(contactRecord, new List<String>{ 'Authentication_Type__c' });
        if (!String.isBlank(authType) && !equalsIgnoreCase(authType, 'Singpass')) {
            return false;
        }

        String employmentStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        if (!String.isBlank(employmentStatus) && !isPreHireEmploymentStatus(employmentStatus)) {
            return false;
        }

        String consentType = getStringFieldValue(contactRecord, new List<String>{ 'Consent_Type__c' });
        if (!String.isBlank(consentType) && !isPerReportConsentType(consentType)) {
            return false;
        }

        return true;
    }

    private static Boolean isPreHireEmploymentStatus(String employmentStatus) {
        String normalized = employmentStatus == null ? '' : employmentStatus.trim().toLowerCase();
        return normalized == 'pre-hire'
            || normalized == 'pre hire'
            || normalized == 'prehire'
            || normalized == 'new hire'
            || normalized == 'newhire';
    }

    private static Boolean isPerReportConsentType(String consentType) {
        String normalized = consentType == null ? '' : consentType.trim().toLowerCase().replace('-', ' ');
        return normalized.contains('per report') || normalized.contains('perreport');
    }

    private Boolean isTokenValidForRequestItem(Consent_Request_Item__c requestItem, String tokenValue) {
        return ConsentGuestAuthService.isTokenValidForRequestItem(
            requestItem,
            tokenValue,
            parseId(contactId)
        );
    }

    private Consent_Request_Item__c resolveRequestItem(Id subjectId) {
        String requestItemParam = firstNonBlank(
            requestItemId,
            ApexPages.currentPage().getParameters().get('consentRequestItemId')
        );

        if (!String.isBlank(requestItemParam)) {
            Consent_Request_Item__c byId = queryRequestItemById(requestItemParam);
            if (byId != null) {
                return byId;
            }
        }

        Consent_Request_Item__c byToken = queryRequestItemByToken(token);
        if (byToken != null) {
            requestItemId = byToken.Id;
            return byToken;
        }

        List<Consent_Request_Item__c> latestItems = Database.query(
            'SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c' +
            ' FROM Consent_Request_Item__c WHERE Data_Subject__c = :subjectId' +
            ' ORDER BY CreatedDate DESC, Id DESC LIMIT 1'
        );
        if (!latestItems.isEmpty()) {
            requestItemId = latestItems[0].Id;
            return latestItems[0];
        }

        return null;
    }

    private Consent_Request_Item__c queryRequestItemById(String rawId) {
        try {
            Id safeId = (Id) rawId;
            String soql =
                'SELECT ' + String.join(getRequestItemSelectFields(), ',') +
                ' FROM Consent_Request_Item__c WHERE Id = :safeId LIMIT 1';
            List<Consent_Request_Item__c> items = Database.query(soql);
            return items.isEmpty() ? null : items[0];
        } catch (Exception e) {
            return null;
        }
    }

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(fieldMap, new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
        if (String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT ' + String.join(getRequestItemSelectFields(), ',') +
            ' FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';
        List<Consent_Request_Item__c> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private List<String> getRequestItemSelectFields() {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Data_Subject__c', 'Current_Status__c', 'Consent_Link_Expires_At__c' };
        List<String> optional = new List<String>{
            'Token__c',
            'Secure_Token__c',
            'Access_Token__c',
            'Link_Expires_At__c',
            'Expires_At__c',
            'Expiry_Date_Time__c',
            'Token_Expires_At__c',
            'Link_Expiry_DateTime__c',
            'Status__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        return fields;
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id', 'Name', 'Email', 'AccountId', 'Account.Name', 'Current_Consent_Status__c', 'Current_Consent_Expiry_Date__c'
        };
        List<String> optional = new List<String>{
            'Data_Subject_Lifecycle_Stage__c',
            'Employment_Status__c',
            'Authentication_Type__c',
            'Consent_Type__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }

        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (accountFields.containsKey('HR_Support_Email__c')) {
            fields.add('Account.HR_Support_Email__c');
        }

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static String getAccountHrSupportEmail(Contact contactRecord) {
        if (contactRecord == null || contactRecord.Account == null) {
            return null;
        }
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (!accountFields.containsKey('HR_Support_Email__c')) {
            return null;
        }
        Object rawValue = contactRecord.Account.get('HR_Support_Email__c');
        return rawValue == null ? null : String.valueOf(rawValue);
    }

    private Boolean isRequestItemLinkExpired(Consent_Request_Item__c requestItem) {
        if (requestItem == null) {
            return false;
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
            if (!hasField(requestItem, fieldApi)) {
                continue;
            }
            Object rawValue = requestItem.get(fieldApi);
            if (rawValue instanceof Datetime && ((Datetime) rawValue) < System.now()) {
                return true;
            }
            if (rawValue instanceof Date && ((Date) rawValue) < Date.today()) {
                return true;
            }
        }
        return false;
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        token = params.get('token');
        entryAction = blankIfNull(params.get('action'));
        entryType = blankIfNull(params.get('type'));
        entryAuthType = blankIfNull(params.get('authType'));
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }

        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('contactId', contactId);
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }
        if (!String.isBlank(entryAction)) {
            targetPage.getParameters().put('action', entryAction);
        } else {
            targetPage.getParameters().put('action', ACTION_AUTHORIZE);
        }
        targetPage.getParameters().put('type', TYPE_PREHIRE);
        if (!String.isBlank(entryAuthType)) {
            targetPage.getParameters().put('authType', entryAuthType);
        } else {
            targetPage.getParameters().put('authType', AUTH_TYPE_SINGPASS);
        }
    }

    private PageReference buildRedirect(String pagePath) {
        PageReference pageRef = new PageReference(pagePath);
        copyContextParams(pageRef);
        return pageRef;
    }

    private void ensureContextLoaded() {
        if (!contextLoaded) {
            validateEntryAndResolveRedirect();
            contextLoaded = true;
        }
    }

    private void resetContext() {
        contactRecord = null;
        requestItemRecord = null;
        hrSupportEmail = null;
        contextLoaded = false;
        contextValid = false;
    }

    private static Boolean matchesContactLifecycleAndStatus(
        Contact contactRecord,
        String lifecycleStage,
        String consentStatus
    ) {
        if (contactRecord == null || String.isBlank(lifecycleStage) || String.isBlank(consentStatus)) {
            return false;
        }

        String actualLifecycle = blankIfNull(getStringFieldValue(
            contactRecord,
            new List<String>{ 'Data_Subject_Lifecycle_Stage__c' }
        ));
        String actualStatus = blankIfNull(contactRecord.Current_Consent_Status__c);
        return actualLifecycle.equalsIgnoreCase(lifecycleStage) && actualStatus.equalsIgnoreCase(consentStatus);
    }

    private static String getStringFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (hasField(record, fieldApi)) {
                Object rawValue = record.get(fieldApi);
                if (rawValue != null) {
                    return String.valueOf(rawValue);
                }
            }
        }
        return null;
    }

    private static String findFirstExistingField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private static Boolean hasField(SObject record, String fieldApi) {
        return record != null
            && record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApi);
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

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.toLowerCase() == right.toLowerCase();
    }
}