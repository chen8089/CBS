/**
 * Controller for Withdrawal Important Notes page.
 * Display-only: explains withdrawal impact and routes to the next step by authentication type.
 * Does not update Consent status; withdrawal is submitted on the subsequent form page.
 */
public without sharing class WithdrawalImportantNotesController {
    private static final String ACTION_WITHDRAW = 'withdraw';
    private static final String AUTH_TYPE_SINGPASS = 'Singpass';
    private static final String AUTH_TYPE_NON_SINGPASS = 'Non-Singpass';

    private static final String CONTACT_STATUS_AUTHORIZED = 'Authorized';
    private static final String CONTACT_STATUS_VALID = 'Valid';
    private static final String CONTACT_STATUS_DECLINED = 'Declined';
    private static final String CONTACT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String CONTACT_STATUS_EXPIRED = 'Expired';
    private static final String CONTACT_STATUS_REVOKED = 'Revoked';

    private static final String LIFECYCLE_STAGE_CONSENT_WITHDRAWN = 'Consent Withdrawn';

    private static final String CONSENT_STATUS_ACTIVE = 'Active';

    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_NO_ACTIVE_CONSENT = '/apex/NoActiveConsentPage';
    private static final String PAGE_SINGPASS_AUTH = '/apex/ndi_auth';
    private static final String PAGE_SINGPASS_WITHDRAW_CONSENT = '/apex/SingpassWithdrawalConsentPage';
    private static final String PAGE_WITHDRAW_CONSENT = '/apex/QRSiteWithdrawConsent';
    private static final String PAGE_WITHDRAW_QR = '/apex/QRSiteWithdrawQrPage';

    public String contactId { get; private set; }
    public String consentId { get; private set; }
    public String dataSubjectName { get; private set; }
    public String email { get; private set; }
    public String bankName { get; private set; }
    public String employmentStatus { get; private set; }
    public String currentConsentStatus { get; private set; }
    public String consentExpiryDate { get; private set; }
    public String authenticationType { get; private set; }
    public Boolean isSingpass { get; private set; }
    public Boolean isManualVerification { get; private set; }
    public String errorMessage { get; private set; }
    public Boolean hasError { get; private set; }
    public Boolean canProceed { get; private set; }

    public Boolean showPage { get; private set; }
    public Boolean cancelled { get; private set; }

    private String requestItemId;
    private String token;

    private Contact contactRecord;
    private Consent__c consentRecord;
    private Consent_Request_Item__c requestItemRecord;
    private Boolean contextLoaded = false;

    public WithdrawalImportantNotesController() {
        parseUrlParameters();
        showPage = false;
        hasError = false;
        canProceed = false;
        cancelled = false;
        isSingpass = false;
        isManualVerification = false;
    }

    /**
     * Page action – validates entry context and redirects when the withdrawal link is not usable.
     */
    public PageReference init() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            populateDisplayValues();
            canProceed = true;
            showPage = true;
            return null;
        } catch (Exception e) {
            return redirectToInvalidLinkPage();
        }
    }

    public String getPageTitle() {
        return 'Important Notes Before You Withdraw Consent';
    }

    public String getIntroText() {
        return 'You are about to withdraw the consent previously submitted to Credit Bureau (Singapore) Pte Ltd ("CBS") '
            + 'to disclose your consumer credit report(s) and/or credit information to '
            + getBankNameForDisplay()
            + ' for '
            + getPurposeText()
            + ' purposes.';
    }

    public String getEffectOfWithdrawalHeading() {
        return 'Effects of withdrawal';
    }

    public String getEffectOfWithdrawalIntro() {
        return 'If you withdraw your consent:';
    }

    public List<String> getWithdrawalEffectBullets() {
        String employerName = getBankNameForDisplay();
        return new List<String>{
            'For Singpass-verified withdrawals, your consent status will be updated directly.',
            'For withdrawals which require identity verification by CBS (i.e., non-Singpass users), your withdrawal status will be updated by CBS after identity verification is completed. CBS may contact you if further verification is required. Contact CBS at privacy@creditbureau.com.sg to check on your consent withdrawal status. '
                + employerName
                + ' will be notified of your withdrawal.',
            employerName
                + ' will not be able to submit any new credit report request(s) to CBS after your withdrawal has taken effect.'
        };
    }

    public String getProceedNote() {
        return 'To proceed with the withdrawal for Singpass users, you may be required to authenticate via Singpass. '
            + 'For non-Singpass users, you may be required to complete identity verification before the withdrawal is recorded.';
    }

    public String getContinueButtonLabel() {
        return 'Continue to Withdrawal Form';
    }

    public String getCancelMessage() {
        return 'You have cancelled the withdrawal process. No changes have been made to your consent.';
    }

    public PageReference continueToWithdrawal() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect(true);
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            if (isSingpass == true) {
                PageReference singpassPage = buildRedirect(PAGE_SINGPASS_AUTH);
                copyContextParams(singpassPage);
                singpassPage.getParameters().put('action', ACTION_WITHDRAW);
                singpassPage.getParameters().put('returnUrl', PAGE_SINGPASS_WITHDRAW_CONSENT);
                singpassPage.setRedirect(true);
                return singpassPage;
            }

            if (isManualVerification == true) {
                PageReference withdrawPage = buildRedirect(PAGE_WITHDRAW_CONSENT);
                copyContextParams(withdrawPage);
                withdrawPage.getParameters().put('action', ACTION_WITHDRAW);
                withdrawPage.setRedirect(true);
                return withdrawPage;
            }

            // Fallback: existing QR-based Singpass withdrawal entry when auth type is unknown.
            PageReference qrPage = buildRedirect(PAGE_WITHDRAW_QR);
            copyContextParams(qrPage);
            qrPage.getParameters().put('action', ACTION_WITHDRAW);
            qrPage.setRedirect(true);
            return qrPage;
        } catch (Exception e) {
            return redirectToInvalidLinkPage();
        }
    }

    public PageReference cancel() {
        cancelled = true;
        showPage = false;
        canProceed = false;
        return null;
    }

    public PageReference redirectToNoActiveConsentPage() {
        PageReference nextPage = buildRedirect(PAGE_NO_ACTIVE_CONSENT);
        nextPage.getParameters().remove('id');
        nextPage.getParameters().remove('consentId');
        nextPage.getParameters().put('action', ACTION_WITHDRAW);
        nextPage.setRedirect(true);
        return nextPage;
    }

    public PageReference redirectToInvalidLinkPage() {
        PageReference nextPage = buildRedirect(PAGE_INVALID_LINK);
        nextPage.setRedirect(true);
        return nextPage;
    }

    private PageReference validateEntryAndResolveRedirect() {
        return validateEntryAndResolveRedirect(false);
    }

    private PageReference validateEntryAndResolveRedirect(Boolean forContinueAction) {
        resetContext();

        Id subjectId = resolveContactId();
        if (subjectId == null) {
            return redirectToInvalidLinkPage();
        }
        contactId = String.valueOf(subjectId);

        contactRecord = queryContact(subjectId);
        if (contactRecord == null) {
            return redirectToInvalidLinkPage();
        }

        requestItemRecord = resolveRequestItem(subjectId);
        if (!String.isBlank(token) && !isTokenValidForRequestItem(requestItemRecord, token)) {
            return redirectToInvalidLinkPage();
        }

        if (requestItemRecord != null && isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        consentRecord = resolveActiveConsent(subjectId);
        if (consentRecord != null) {
            consentId = consentRecord.Id;
        }

        if (forContinueAction != true
            && matchesContactLifecycleAndStatus(
                contactRecord,
                LIFECYCLE_STAGE_CONSENT_WITHDRAWN,
                CONTACT_STATUS_WITHDRAWN
            )) {
            return redirectToNoActiveConsentPage();
        }

        String contactStatus = normalizeStatus(
            getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' })
        );

        PageReference terminalRedirect = resolveTerminalStatusRedirect(subjectId, forContinueAction == true);
        if (terminalRedirect != null) {
            return terminalRedirect;
        }

        if (!hasWithdrawableActiveConsent(subjectId)) {
            if (forContinueAction == true) {
                resolveAuthenticationType();
                contextLoaded = true;
                return null;
            }
            if (contactStatus == CONTACT_STATUS_DECLINED) {
                resolveAuthenticationType();
                contextLoaded = true;
                return null;
            }
            return redirectToNoActiveConsentPage();
        }

        resolveAuthenticationType();
        contextLoaded = true;
        return null;
    }

    private PageReference resolveTerminalStatusRedirect(Id subjectId) {
        return resolveTerminalStatusRedirect(subjectId, false);
    }

    private PageReference resolveTerminalStatusRedirect(Id subjectId, Boolean skipContactConsentStatus) {
        if (matchesContactLifecycleAndStatus(
            contactRecord,
            LIFECYCLE_STAGE_CONSENT_WITHDRAWN,
            CONTACT_STATUS_WITHDRAWN
        )) {
            return redirectToNoActiveConsentPage();
        }

        if (skipContactConsentStatus != true) {
            String contactStatus = normalizeStatus(
                getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' })
            );

            if (contactStatus == CONTACT_STATUS_WITHDRAWN
                || contactStatus == CONTACT_STATUS_REVOKED) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }

            if (contactStatus == CONTACT_STATUS_EXPIRED) {
                return buildRedirect(PAGE_LINK_EXPIRED);
            }
        }

        if (consentRecord != null) {
            String consentStatus = normalizeStatus(consentRecord.Consent_Status__c);
            if (consentStatus == 'WITHDRAWN' || consentStatus == 'DECLINED' || consentStatus == 'REVOKED') {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (consentStatus == 'EXPIRED') {
                return buildRedirect(PAGE_LINK_EXPIRED);
            }
        }

        if (requestItemRecord != null) {
            String requestStatus = normalizeStatus(requestItemRecord.Current_Status__c);
            if (requestStatus == 'WITHDRAWN' || requestStatus == 'DECLINED') {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (requestStatus == 'EXPIRED' || requestStatus == 'CONSUMED') {
                return buildRedirect(PAGE_LINK_EXPIRED);
            }
        }

        return null;
    }

    private Boolean hasWithdrawableActiveConsent(Id subjectId) {
        String contactStatus = getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' });
        if (isActiveContactConsentStatus(contactStatus)) {
            return consentRecord != null || hasActiveConsentRecord(subjectId);
        }
        return false;
    }

    private void populateDisplayValues() {
        bankName = resolveBankName();
        dataSubjectName = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'Full_Name__c', 'Principal_Name__c', 'Full_Legal_Name__c', 'Name' }),
            ''
        );
        email = blankIfNull(contactRecord.Email);
        employmentStatus = resolveEmploymentStatusLabel();
        currentConsentStatus = firstNonBlank(
            consentRecord != null ? blankIfNull(consentRecord.Consent_Status__c) : '',
            getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' }),
            ''
        );
        consentExpiryDate = resolveConsentExpiryDate();
    }

    private void resolveAuthenticationType() {
        authenticationType = getStringFieldValue(contactRecord, new List<String>{ 'Authentication_Type__c' });
        if (String.isBlank(authenticationType)) {
            authenticationType = firstNonBlank(
                ApexPages.currentPage().getParameters().get('authType'),
                ApexPages.currentPage().getParameters().get('authenticationType'),
                ApexPages.currentPage().getParameters().get('subjectType')
            );
        }

        isSingpass = equalsIgnoreCase(authenticationType, AUTH_TYPE_SINGPASS)
            || (!String.isBlank(authenticationType) && authenticationType.toLowerCase().contains('singpass') && !authenticationType.toLowerCase().contains('non'));
        isManualVerification = equalsIgnoreCase(authenticationType, AUTH_TYPE_NON_SINGPASS)
            || (!String.isBlank(authenticationType) && authenticationType.toLowerCase().contains('non'));
    }

    private String resolvePurposeText() {
        String rawStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        if (!String.isBlank(rawStatus)) {
            String normalized = rawStatus.trim().toLowerCase();
            if (normalized.contains('pre') || (normalized.contains('hire') && normalized.contains('new'))) {
                return 'pre-employment screening';
            }
        }

        String fromUrl = ApexPages.currentPage().getParameters().get('type');
        if (equalsIgnoreCase(fromUrl, 'prehire') || equalsIgnoreCase(fromUrl, 'pre-hire')) {
            return 'pre-employment screening';
        }

        return 'employment-related credit assessment';
    }

    private String getPurposeText() {
        ensureContextLoaded();
        return resolvePurposeText();
    }

    private String resolveBankName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        return 'your employer or the relevant bank';
    }

    private String getBankNameForDisplay() {
        ensureContextLoaded();
        return String.isBlank(bankName) ? resolveBankName() : bankName;
    }

    private String resolveEmploymentStatusLabel() {
        String rawStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        if (String.isBlank(rawStatus)) {
            String fromUrl = ApexPages.currentPage().getParameters().get('type');
            if (equalsIgnoreCase(fromUrl, 'prehire') || equalsIgnoreCase(fromUrl, 'pre-hire')) {
                return 'Pre-Hire';
            }
            if (equalsIgnoreCase(fromUrl, 'employee')) {
                return 'Existing Employee';
            }
            return '';
        }

        String normalized = rawStatus.trim().toLowerCase();
        if (normalized.contains('pre') || normalized.contains('hire') && normalized.contains('new')) {
            return 'Pre-Hire';
        }
        return 'Existing Employee';
    }

    private String resolveConsentExpiryDate() {
        if (consentRecord != null && consentRecord.Consent_Expiry_Date__c != null) {
            return consentRecord.Consent_Expiry_Date__c.format();
        }

        Date contactExpiry = getDateFieldValue(contactRecord, new List<String>{ 'Current_Consent_Expiry_Date__c' });
        return contactExpiry == null ? '' : contactExpiry.format();
    }

    private Consent__c resolveActiveConsent(Id subjectId) {
        String consentIdParam = firstNonBlank(
            consentId,
            ApexPages.currentPage().getParameters().get('consentId'),
            ApexPages.currentPage().getParameters().get('id')
        );

        if (!String.isBlank(consentIdParam)) {
            Consent__c byId = queryConsentById(consentIdParam);
            if (byId != null && byId.Data_Subject__c == subjectId && isActiveConsentRecordStatus(byId.Consent_Status__c)) {
                return byId;
            }
            if (byId != null && byId.Data_Subject__c == subjectId) {
                consentRecord = byId;
            }
        }

        List<Consent__c> activeConsents = [
            SELECT Id, Data_Subject__c, Consent_Status__c, Consent_Expiry_Date__c, Submitted_At__c
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
                AND Consent_Status__c = :CONSENT_STATUS_ACTIVE
            ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];
        return activeConsents.isEmpty() ? null : activeConsents[0];
    }

    private Consent__c queryConsentById(String rawConsentId) {
        try {
            Id safeId = (Id) rawConsentId;
            return [
                SELECT Id, Data_Subject__c, Consent_Status__c, Consent_Expiry_Date__c, Submitted_At__c
                FROM Consent__c
                WHERE Id = :safeId
                LIMIT 1
            ];
        } catch (Exception e) {
            return null;
        }
    }

    private Boolean hasActiveConsentRecord(Id subjectId) {
        List<Consent__c> consents = [
            SELECT Id
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
                AND Consent_Status__c = :CONSENT_STATUS_ACTIVE
            LIMIT 1
        ];
        return !consents.isEmpty();
    }

    private Id resolveContactId() {
        Id contactIdFromParam = parseId(firstNonBlank(contactId, ApexPages.currentPage().getParameters().get('ContactId')));

        Id fromRequest = resolveContactIdFromRequestItem();
        if (fromRequest != null) {
            if (contactIdFromParam != null && contactIdFromParam != fromRequest) {
                return null;
            }
            return fromRequest;
        }

        String consentIdParam = firstNonBlank(
            consentId,
            ApexPages.currentPage().getParameters().get('consentId'),
            ApexPages.currentPage().getParameters().get('id')
        );
        Id fromConsent = resolveContactIdByConsentId(consentIdParam);
        if (fromConsent != null) {
            if (contactIdFromParam != null && contactIdFromParam != fromConsent) {
                return null;
            }
            return fromConsent;
        }

        String recordIdParam = ApexPages.currentPage().getParameters().get('recordId');
        if (!String.isBlank(recordIdParam)) {
            Id fromRecord = resolveRecordIdToContactId(recordIdParam);
            if (fromRecord != null) {
                if (contactIdFromParam != null && contactIdFromParam != fromRecord) {
                    return null;
                }
                return fromRecord;
            }
        }

        return contactIdFromParam;
    }

    private Id resolveContactIdFromRequestItem() {
        Consent_Request_Item__c item = resolveRequestItem(null);
        if (item == null || item.Data_Subject__c == null) {
            return null;
        }
        return item.Data_Subject__c;
    }

    private Id resolveContactIdByConsentId(String rawConsentId) {
        Consent__c consent = queryConsentById(rawConsentId);
        return consent == null ? null : consent.Data_Subject__c;
    }

    private Id resolveRecordIdToContactId(String rawRecordId) {
        Id parsedId = parseId(rawRecordId);
        if (parsedId == null) {
            return null;
        }

        String objectName = parsedId.getSObjectType().getDescribe().getName();
        if (objectName == 'Contact') {
            return parsedId;
        }
        if (objectName == 'Consent__c') {
            return resolveContactIdByConsentId(rawRecordId);
        }
        if (objectName == 'Consent_Request_Item__c') {
            List<Consent_Request_Item__c> items = [
                SELECT Data_Subject__c
                FROM Consent_Request_Item__c
                WHERE Id = :parsedId
                LIMIT 1
            ];
            return items.isEmpty() ? null : items[0].Data_Subject__c;
        }
        return null;
    }

    private Consent_Request_Item__c resolveRequestItem(Id subjectId) {
        if (requestItemRecord != null) {
            return requestItemRecord;
        }

        String requestItemParam = firstNonBlank(
            requestItemId,
            ApexPages.currentPage().getParameters().get('requestItemId'),
            ApexPages.currentPage().getParameters().get('requestId'),
            ApexPages.currentPage().getParameters().get('consentRequestItemId')
        );

        if (!String.isBlank(requestItemParam)) {
            Consent_Request_Item__c byId = queryRequestItemById(requestItemParam);
            if (byId != null) {
                requestItemId = byId.Id;
                requestItemRecord = byId;
                return byId;
            }
        }

        if (!String.isBlank(token)) {
            Consent_Request_Item__c byToken = queryRequestItemByToken(token);
            if (byToken != null) {
                requestItemId = byToken.Id;
                requestItemRecord = byToken;
                return byToken;
            }
        }

        if (subjectId != null) {
            List<Consent_Request_Item__c> latestItems = [
                SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c
                FROM Consent_Request_Item__c
                WHERE Data_Subject__c = :subjectId
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 1
            ];
            if (!latestItems.isEmpty()) {
                requestItemId = latestItems[0].Id;
                requestItemRecord = latestItems[0];
                return latestItems[0];
            }
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
            'Link_Expiry_DateTime__c'
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
            'Full_Name__c',
            'Principal_Name__c',
            'Full_Legal_Name__c',
            'Employment_Status__c',
            'Authentication_Type__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Boolean isTokenValidForRequestItem(Consent_Request_Item__c requestItem, String tokenValue) {
        return ConsentGuestAuthService.isTokenValidForRequestItem(
            requestItem,
            tokenValue,
            parseId(contactId)
        );
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
        consentId = firstNonBlank(params.get('consentId'), params.get('id'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('requestId'), params.get('consentRequestItemId'));
        token = params.get('token');
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }

        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('ContactId', contactId);
        }
        if (!String.isBlank(consentId)) {
            targetPage.getParameters().put('id', consentId);
            targetPage.getParameters().put('consentId', consentId);
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }

        List<String> passthroughParams = new List<String>{ 'recordId', 'action', 'type', 'authType', 'authenticationType', 'subjectType' };
        for (String key : passthroughParams) {
            String value = ApexPages.currentPage().getParameters().get(key);
            if (!String.isBlank(value)) {
                targetPage.getParameters().put(key, value);
            }
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
            if (contactRecord != null) {
                populateDisplayValues();
            }
            contextLoaded = true;
        }
    }

    private void resetContext() {
        contactRecord = null;
        consentRecord = null;
        requestItemRecord = null;
        contextLoaded = false;
    }

    private static Boolean isActiveContactConsentStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }
        String normalized = statusValue.trim().toLowerCase();
        return normalized == CONTACT_STATUS_AUTHORIZED.toLowerCase() || normalized == CONTACT_STATUS_VALID.toLowerCase();
    }

    private static Boolean isActiveConsentRecordStatus(String statusValue) {
        return normalizeStatus(statusValue) == CONSENT_STATUS_ACTIVE.toUpperCase();
    }

    private static String normalizeStatus(String statusValue) {
        return String.isBlank(statusValue) ? '' : statusValue.trim().toUpperCase();
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

    private static Date getDateFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (hasField(record, fieldApi)) {
                Object rawValue = record.get(fieldApi);
                if (rawValue instanceof Date) {
                    return (Date) rawValue;
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

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        return thirdValue;
    }

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue, String fourthValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        if (!String.isBlank(thirdValue)) {
            return thirdValue;
        }
        return fourthValue;
    }

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.toLowerCase() == right.toLowerCase();
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
        String actualStatus = blankIfNull(getStringFieldValue(
            contactRecord,
            new List<String>{ 'Current_Consent_Status__c' }
        ));
        return actualLifecycle.equalsIgnoreCase(lifecycleStage) && actualStatus.equalsIgnoreCase(consentStatus);
    }
}