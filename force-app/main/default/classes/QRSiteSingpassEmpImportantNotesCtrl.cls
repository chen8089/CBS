/**
 * Controller for Singpass Employee / 5-year Term-based Consent Important Notes page.
 * Guest-accessible via Salesforce Sites / Experience Cloud.
 * Does not record consent; only displays pre-authorisation information and routes next steps.
 */
public without sharing class QRSiteSingpassEmpImportantNotesCtrl {
    private static final String ACTION_AUTHORIZE = 'authorize';
    private static final String TYPE_EMPLOYEE = 'employee';
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

    // Placeholder Visualforce pages – replace with Page.* references once deployed.
    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_ACTIVE_CONSENT = '/apex/ActiveConsentNotificationPage';
    private static final String PAGE_DECLINE_CONFIRMATION = '/apex/CBSDeclineConsentConfirmation';
    private static final String PAGE_CONSENT_FORM = '/apex/QRSiteSingpassEmployeeConsentForm';
    private static final String PAGE_PREHIRE_CONSENT_FORM = '/apex/QRSiteSingpassPrehireConsentForm';
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

    public QRSiteSingpassEmpImportantNotesCtrl() {
        parseUrlParameters();
        showPage = false;
    }

    /**
     * Page action – validates link on initial load and redirects when invalid or already actioned.
     */
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
            + ' for employment-related credit assessment / background screening purposes.';
    }

    public String getReadNotesPrompt() {
        return 'Please read the following notes carefully before you proceed.';
    }

    public List<String> getWhatThisRequestIsForParagraphs() {
        return new List<String>{
            getBankName()
                + ' is requesting your consent so that CBS may process an authorised credit report request '
                + 'for employment-related credit assessment / background screening purposes.',
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
                + ' for employment-related credit assessment / background screening purposes.',
            'Your consent will remain valid for 5 years from the date of submission, unless withdrawn earlier.'
        };
    }

    public List<String> getDeclineParagraphs() {
        return new List<String>{
            'You may decline to give consent.',
            'If you decline, CBS will update your consent status as declined and ' + getBankName()
                + ' will be notified. ' + getBankName()
                + ' will not be able to submit a new credit report request to CBS under this consent request '
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
            'If you have any questions about this request, please contact '
                + getBankName()
                + ' Human Resources at [BANK HR SUPPORT EMAIL] before continuing.'
        };
    }

    public String getContinueButtonMain() {
        return 'Continue with Singpass';
    }

    public String getContinueButtonSub() {
        return '';
    }

    public String getDeclineButtonMain() {
        return 'Decline to Give Consent';
    }

    public String getDeclineButtonSub() {
        return '';
    }

    public String getBankName() {
        ensureContextLoaded();
        if (contactRecord == null || contactRecord.Account == null) {
            return 'your employer';
        }
        return String.isBlank(contactRecord.Account.Name) ? 'your employer' : contactRecord.Account.Name;
    }

    public String getHrSupportEmail() {
        // TODO: Confirm Account HR support email field API name if different from HR_Support_Email__c.
        return '[BANK HR SUPPORT EMAIL]';
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
            if (String.isBlank(singpassPage.getParameters().get('action'))) {
                singpassPage.getParameters().put('action', ACTION_AUTHORIZE);
            }
            singpassPage.getParameters().put('returnUrl', isPrehireScenario() ? PAGE_PREHIRE_CONSENT_FORM : PAGE_CONSENT_FORM);
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

            // Important Notes page does not update consent status; user confirms on Decline page.
            PageReference declinePage = buildRedirect(PAGE_DECLINE_CONFIRMATION);
            copyContextParams(declinePage);
            declinePage.setRedirect(true);
            return declinePage;
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    private PageReference validateEntryAndResolveRedirect() {
        return validateEntryAndResolveRedirect(true, true);
    }

    private PageReference validateEntryAndResolveRedirect(Boolean checkActiveConsentOnEntry, Boolean checkContactConsentStatus) {
        resetContext();

        if (String.isBlank(token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        Id parsedContactId = parseId(contactId);
        if (parsedContactId == null) {
            parsedContactId = resolveSubjectIdFromRequestItemId(requestItemId);
        }
        if (parsedContactId == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }
        contactId = String.valueOf(parsedContactId);

        contactRecord = queryContact(parsedContactId);
        if (contactRecord == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        requestItemRecord = resolveRequestItem(parsedContactId);
        if (!isTokenValidForRequestItem(requestItemRecord, token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        if (!isSingpassEmployeeScenario()) {
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

    private Id resolveSubjectIdFromRequestItemId(String requestItemIdValue) {
        if (String.isBlank(requestItemIdValue)) {
            return null;
        }
        try {
            Id safeRequestItemId = (Id) requestItemIdValue;
            List<Consent_Request_Item__c> rows = [
                SELECT Data_Subject__c
                FROM Consent_Request_Item__c
                WHERE Id = :safeRequestItemId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].Data_Subject__c;
        } catch (Exception e) {
            return null;
        }
    }

    private PageReference resolveConsentStatusRedirect(Id subjectId) {
        return resolveConsentStatusRedirect(subjectId, true, true);
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

    private Boolean isSingpassEmployeeScenario() {
        if (!String.isBlank(entryAction) && entryAction.toLowerCase() != ACTION_AUTHORIZE) {
            return false;
        }
        if (!String.isBlank(entryType)
            && entryType.toLowerCase() != TYPE_EMPLOYEE
            && entryType.toLowerCase() != TYPE_PREHIRE) {
            return false;
        }
        if (!String.isBlank(entryAuthType) && entryAuthType.toLowerCase() != AUTH_TYPE_SINGPASS) {
            return false;
        }

        // TODO: Confirm picklist values if org metadata differs.
        String authType = getStringFieldValue(contactRecord, new List<String>{ 'Authentication_Type__c' });
        if (!String.isBlank(authType) && !equalsIgnoreCase(authType, 'Singpass')) {
            return false;
        }

        String employmentStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        String consentType = getStringFieldValue(contactRecord, new List<String>{ 'Consent_Type__c' });

        if (isPrehireScenario()) {
            if (!String.isBlank(employmentStatus)
                && !equalsIgnoreCase(employmentStatus, 'Pre-hire')
                && !employmentStatus.toLowerCase().contains('pre')) {
                return false;
            }
            if (!String.isBlank(consentType)
                && !equalsIgnoreCase(consentType, 'Per-Report Consent')
                && !consentType.toLowerCase().contains('per-report')
                && !consentType.toLowerCase().contains('pre-hire')
                && !consentType.toLowerCase().contains('prehire')) {
                return false;
            }
        } else {
            if (!String.isBlank(employmentStatus)
                && !equalsIgnoreCase(employmentStatus, 'Existing Hire')
                && !equalsIgnoreCase(employmentStatus, 'Employee')) {
                return false;
            }
            if (!String.isBlank(consentType)
                && !equalsIgnoreCase(consentType, 'Term-Based Consent')
                && !consentType.toLowerCase().contains('term')) {
                return false;
            }
        }

        return true;
    }

    private Boolean isPrehireScenario() {
        String effectiveType = blankIfNull(entryType);
        if (!String.isBlank(effectiveType)) {
            return effectiveType.toLowerCase() == TYPE_PREHIRE;
        }

        String employmentStatus = blankIfNull(getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' }));
        if (!String.isBlank(employmentStatus) && employmentStatus.toLowerCase().contains('pre')) {
            return true;
        }

        String consentType = blankIfNull(getStringFieldValue(contactRecord, new List<String>{ 'Consent_Type__c' }));
        return consentType.toLowerCase().contains('per-report')
            || consentType.toLowerCase().contains('pre-hire')
            || consentType.toLowerCase().contains('prehire');
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
            // Security hard-stop: when requestItemId is supplied, do not fallback to "latest item".
            // The incoming link must be a strict triple match (contact + request item + token).
            return queryRequestItemById(requestItemParam, subjectId, token);
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
            return latestItems[0];
        }

        return null;
    }

    private Consent_Request_Item__c queryRequestItemById(String rawId, Id subjectId, String tokenValue) {
        try {
            Id safeId = (Id) rawId;
            if (subjectId == null || String.isBlank(tokenValue)) {
                return null;
            }

            String tokenField = ConsentGuestAuthService.resolveTokenFieldApiName();

            String soql =
                'SELECT ' + String.join(getRequestItemSelectFields(), ',') +
                ' FROM Consent_Request_Item__c' +
                ' WHERE Id = :safeId' +
                ' AND Data_Subject__c = :subjectId';
            if (!String.isBlank(tokenField)) {
                soql += ' AND ' + tokenField + ' = :tokenValue';
            }
            soql += ' LIMIT 1';
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

        // TODO: Confirm Account HR support email field API name if different from HR_Support_Email__c.
        // HR support email is displayed as [BANK HR SUPPORT EMAIL] placeholder until field is confirmed.

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Boolean hasActiveConsentRecord(Id subjectId) {
        List<Consent__c> consents = [
            SELECT Id
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
                AND Consent_Status__c = 'Active'
            ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];
        return !consents.isEmpty();
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
        }
        if (!String.isBlank(entryType)) {
            targetPage.getParameters().put('type', entryType);
        }
        if (!String.isBlank(entryAuthType)) {
            targetPage.getParameters().put('authType', entryAuthType);
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
        contextLoaded = false;
        contextValid = false;
    }

    private static Boolean isActiveConsentStatus(String statusValue) {
        return statusValue == CONTACT_STATUS_AUTHORIZED || statusValue == CONTACT_STATUS_VALID;
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