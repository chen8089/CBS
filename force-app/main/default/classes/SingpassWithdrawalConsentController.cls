/**
 * Controller for Singpass Employee / Pre-Hire Withdrawal of Consent & Authorisation page.
 * Guest-accessible via Salesforce Sites / Experience Cloud.
 *
 * without sharing: Guest users must read/update Contact, Consent__c and Consent_Request_Item__c
 * records referenced by validated token links without relying on org-wide sharing defaults.
 */
public without sharing class SingpassWithdrawalConsentController {
    private static final String ACTION_WITHDRAW = 'withdraw';
    private static final String AUTH_TYPE_SINGPASS = 'Singpass';

    private static final String CONTACT_STATUS_AUTHORIZED = 'Authorized';
    private static final String CONTACT_STATUS_VALID = 'Valid';
    private static final String CONTACT_STATUS_DECLINED = 'Declined';
    private static final String CONTACT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String CONTACT_STATUS_EXPIRED = 'Expired';
    private static final String CONTACT_STATUS_REVOKED = 'Revoked';

    private static final String CONSENT_STATUS_ACTIVE = 'Active';
    private static final String CONSENT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String REQUEST_STATUS_WITHDRAWN = 'Withdrawn';

    private static final String LIFECYCLE_STAGE_CONSENT_WITHDRAWN = 'Consent Withdrawn';

    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_NO_ACTIVE_CONSENT = '/apex/NoActiveConsentPage';
    private static final String PAGE_WITHDRAWAL_NOTES = '/apex/WithdrawalImportantNotesPage';
    private static final String PAGE_WITHDRAW_SUCCESS = '/apex/CBSWithdrawSuccessPage';

    public String contactId { get; private set; }
    public String consentId { get; private set; }
    public Boolean hasConfirmedWithdrawal { get; set; }
    public Boolean showPage { get; private set; }
    public Boolean submitInProgress { get; private set; }

    public String principalName { get; private set; }
    public String emailAddress { get; private set; }
    public String idType { get; private set; }
    public String idNumber { get; private set; }
    public String dateOfBirthDisplay { get; private set; }
    public String nationality { get; private set; }
    public String passType { get; private set; }
    public String passportNumber { get; private set; }
    public String gender { get; private set; }
    public String maritalStatus { get; private set; }
    public String registeredAddress { get; private set; }
    public String employerBankName { get; private set; }
    public String employmentStatus { get; private set; }
    public String currentConsentStatus { get; private set; }
    public String consentSubmittedDate { get; private set; }
    public String consentExpiryDate { get; private set; }

    private String requestItemId;
    private String token;
    private String entryAction;
    private String entryType;

    private Contact contactRecord;
    private Consent__c consentRecord;
    private Consent_Request_Item__c requestItemRecord;
    private Boolean contextLoaded = false;

    public SingpassWithdrawalConsentController() {
        parseUrlParameters();
        showPage = false;
        hasConfirmedWithdrawal = false;
        submitInProgress = false;
    }

    public PageReference initPage() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            populateDisplayValues();
            showPage = true;
            contextLoaded = true;
            return null;
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK, true);
        }
    }

    public String getPageMainTitle() {
        return 'Individual\'s Withdrawal of Explicit Authorisation and Consent for Disclosure of Personal Credit Information to '
            + getBankNameForDisplay();
    }

    public String getPageSubtitle() {
        return 'Withdrawal of Consent and Authorisation';
    }

    public String getGreeting() {
        return 'Dear ' + getDataSubjectFullName() + ',';
    }

    public String getDataSubjectFullName() {
        ensureContextLoaded();
        return firstNonBlank(
            principalName,
            getStringFieldValue(contactRecord, new List<String>{ 'Principal_Name__c', 'Full_Name__c', 'Full_Legal_Name__c', 'Name' }),
            'Data Subject'
        );
    }

    public String getSingpassVerificationText() {
        return 'You have completed the required Singpass verification.';
    }

    public String getReviewPrompt() {
        return 'Please review the information below before submitting your withdrawal request.';
    }

    public String getPurposeText() {
        ensureContextLoaded();
        return resolveIsPreHire()
            ? 'pre-employment screening'
            : 'employment-related credit assessment';
    }

    public String getSectionOneTitle() {
        return '1. Submitted Consent';
    }

    public String getSectionTwoTitle() {
        return '2. Withdrawal Declaration';
    }

    public String getDeclarationIntro() {
        return 'By selecting the checkbox and submitting this form, I confirm that:';
    }

    public List<String> getWithdrawalDeclarationClauses() {
        String bankName = getBankNameForDisplay();
        String purpose = getPurposeText();
        return new List<String>{
            'I wish to withdraw the consent and authorisation previously given to Credit Bureau (Singapore) Pte Ltd ("CBS") '
                + 'to disclose my consumer credit report(s) and/or credit information to '
                + bankName
                + ' for '
                + purpose
                + ' purposes.',
            bankName + ' will be notified that I have withdrawn my consent.',
            'After my withdrawal is submitted, '
                + bankName
                + ' will not be able to submit any new credit report request(s) to CBS after my withdrawal has taken effect.'
        };
    }

    public Boolean getIsPreHire() {
        ensureContextLoaded();
        return resolveIsPreHire();
    }

    public PageReference submitWithdrawal() {
        if (submitInProgress == true) {
            return null;
        }

        try {
            submitInProgress = true;

            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            if (hasConfirmedWithdrawal != true) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Please confirm your withdrawal by selecting the checkbox before submitting.'
                ));
                showPage = true;
                return null;
            }

            if (!isSingpassVerificationComplete()) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Singpass authentication is required before your withdrawal can be submitted.'
                ));
                showPage = true;
                return null;
            }

            if (!validateSingpassIdentityMatch()) {
                logIdentityMatchException('Singpass / MyInfo identity did not match the consent record.');
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'We could not verify that the Singpass identity matches this consent request. Withdrawal cannot be submitted.'
                ));
                showPage = true;
                return null;
            }

            if (!hasWithdrawableActiveConsent()) {
                return redirectToNoActiveConsentPage();
            }

            Savepoint savepointBeforeSubmit = Database.setSavepoint();
            try {
                processWithdrawal();
                PageReference successPage = buildRedirect(PAGE_WITHDRAW_SUCCESS, true);
                successPage.getParameters().put('ContactId', contactId);
                successPage.getParameters().put('consentId', consentId);
                if (!String.isBlank(requestItemId)) {
                    successPage.getParameters().put('requestItemId', requestItemId);
                }
                successPage.getParameters().put('action', ACTION_WITHDRAW);
                return successPage;
            } catch (DmlException e) {
                Database.rollback(savepointBeforeSubmit);
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Unable to submit your withdrawal at this time. Please try again later.'
                ));
                showPage = true;
                return null;
            } catch (Exception e) {
                Database.rollback(savepointBeforeSubmit);
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'A system error occurred while submitting your withdrawal. Please try again later.'
                ));
                showPage = true;
                return null;
            }
        } finally {
            submitInProgress = false;
        }
    }

    public PageReference cancel() {
        PageReference notesPage = buildRedirect(PAGE_WITHDRAWAL_NOTES, true);
        notesPage.getParameters().put('action', ACTION_WITHDRAW);
        return notesPage;
    }

    /**
     * Reserved hook for Singpass / MyInfo verification status.
     * Supports returnFromAuth, explicit verification flags, and QR-based withdrawal authentication.
     */
    public Boolean isSingpassVerificationComplete() {
        if (requestItemRecord == null) {
            Id subjectId = parseId(contactId);
            if (subjectId != null) {
                requestItemRecord = resolveRequestItem(subjectId);
            }
        }

        return requestItemRecord != null && requestItemRecord.Withdrawal_QR_Viewed_At__c != null;
    }

    /**
     * Reserved hook for Singpass / MyInfo NRIC-FIN and DOB matching against Contact / Consent.
     */
    public Boolean validateSingpassIdentityMatch() {
        if (contactRecord == null) {
            return false;
        }
        String singpassIdNumber = resolveSingpassIdNumber();
        List<String> referenceIds = new List<String>();

        String contactIdNumber = getStringFieldValue(contactRecord, new List<String>{ 'ID_Number__c', 'NRIC__c', 'FIN__c' });
        if (!String.isBlank(contactIdNumber)) {
            referenceIds.add(contactIdNumber);
        }

        if (consentRecord != null && !String.isBlank(consentRecord.MyInfo_ID_Number__c)) {
            referenceIds.add(consentRecord.MyInfo_ID_Number__c);
        }

        MyInfoMatchService.MatchResult result = MyInfoMatchService.evaluateIdentityMatch(
            singpassIdNumber,
            resolveSingpassDateOfBirth(),
            referenceIds,
            resolveReferenceDateOfBirth()
        );
        return result != null && result.matched == true;
    }

    private void processWithdrawal() {
        Datetime withdrawnAt = System.now();
        Consent__c activeConsent = consentRecord;

        if (activeConsent == null) {
            throw new SingpassWithdrawalConsentException('Active consent record was not found.');
        }

        Consent__c consentUpdate = new Consent__c(Id = activeConsent.Id);
        consentUpdate.Consent_Status__c = choosePicklistValue(
            Consent__c.Consent_Status__c.getDescribe(),
            new List<String>{ CONSENT_STATUS_WITHDRAWN, 'Withdrawn' }
        );
        consentUpdate.Revoked_At__c = withdrawnAt;
        consentUpdate.Action_Type__c = choosePicklistValue(
            Consent__c.Action_Type__c.getDescribe(),
            new List<String>{ 'Consent Withdrawn', 'Withdraw' }
        );
        consentUpdate.Withdrawn_By_Client__c = true;
        setOptionalFieldSafe(consentUpdate, 'Withdrawal_Method__c', 'Singpass');
        setOptionalFieldSafe(consentUpdate, 'Authentication_Type__c', AUTH_TYPE_SINGPASS);
        setOptionalFieldSafe(consentUpdate, 'Consent_Withdrawn_Date__c', withdrawnAt);
        setOptionalFieldSafe(consentUpdate, 'Withdrawal_Channel__c', 'Data Subject Singpass');
        setOptionalFieldSafe(consentUpdate, 'Withdrawal_By__c', UserInfo.getUserId());
        update consentUpdate;

        // Keep state transitions owned by the centralized service to avoid
        // duplicate Contact/CRI status writers across controllers and services.
        ConsentSubmissionService.submitWithdrawal(
            parseId(contactId),
            requestItemRecord == null ? null : requestItemRecord.Id,
            activeConsent,
            withdrawnAt
        );
        CbsConsentWithdrawalNotificationService.notifyWithdrawal(
            parseId(contactId),
            activeConsent.Id,
            requestItemRecord == null ? null : requestItemRecord.Id,
            withdrawnAt
        );
    }

    private PageReference validateEntryAndResolveRedirect() {
        resetContext();

        Id subjectId = resolveContactId();
        if (subjectId == null) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }
        contactId = String.valueOf(subjectId);

        contactRecord = queryContact(subjectId);
        if (contactRecord == null) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        requestItemRecord = resolveRequestItem(subjectId);
        if (!String.isBlank(token) && !isTokenValidForRequestItem(requestItemRecord, token)) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        if (requestItemRecord != null && isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED, false);
        }

        consentRecord = resolveActiveConsent(subjectId);
        if (consentRecord != null) {
            consentId = consentRecord.Id;
        }

        PageReference terminalRedirect = resolveTerminalStatusRedirect(subjectId);
        if (terminalRedirect != null) {
            return terminalRedirect;
        }

        if (!hasWithdrawableActiveConsent()) {
            return redirectToNoActiveConsentPage();
        }

        if (!isSingpassVerificationComplete()) {
            PageReference authPage = buildRedirect('/apex/ndi_auth', false);
            authPage.getParameters().put('returnUrl', '/apex/SingpassWithdrawalConsentPage');
            authPage.getParameters().put('action', ACTION_WITHDRAW);
            return authPage;
        }

        if (!validateSingpassIdentityMatch()) {
            logIdentityMatchException('Singpass / MyInfo identity did not match on page entry.');
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        contextLoaded = true;
        return null;
    }

    private PageReference resolveTerminalStatusRedirect(Id subjectId) {
        String contactStatus = normalizeStatus(getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' }));

        if (contactStatus == CONTACT_STATUS_WITHDRAWN
            || contactStatus == CONTACT_STATUS_DECLINED
            || contactStatus == CONTACT_STATUS_REVOKED) {
            return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
        }

        if (contactStatus == CONTACT_STATUS_EXPIRED) {
            return buildRedirect(PAGE_LINK_EXPIRED, false);
        }

        if (consentRecord != null) {
            String consentStatus = normalizeStatus(consentRecord.Consent_Status__c);
            if (consentStatus == 'WITHDRAWN' || consentStatus == 'DECLINED' || consentStatus == 'REVOKED') {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
            }
            if (consentStatus == 'EXPIRED' || consentStatus == 'CONSUMED') {
                return buildRedirect(PAGE_LINK_EXPIRED, false);
            }
        }

        if (requestItemRecord != null) {
            String requestStatus = normalizeStatus(requestItemRecord.Current_Status__c);
            if (requestStatus == 'WITHDRAWN' || requestStatus == 'DECLINED') {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
            }
            if (requestStatus == 'EXPIRED' || requestStatus == 'CONSUMED') {
                return buildRedirect(PAGE_LINK_EXPIRED, false);
            }
        }

        return null;
    }

    private Boolean hasWithdrawableActiveConsent() {
        String contactStatus = getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' });
        if (!isActiveContactConsentStatus(contactStatus)) {
            return false;
        }

        if (consentRecord != null && isActiveConsentRecordStatus(consentRecord.Consent_Status__c)) {
            return consentRecord.Data_Subject__c == parseId(contactId);
        }

        return hasActiveConsentRecord(parseId(contactId));
    }

    private void populateDisplayValues() {
        employerBankName = resolveBankName();
        principalName = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'Principal_Name__c', 'Full_Name__c', 'Full_Legal_Name__c', 'Name' }),
            consentRecord != null ? blankIfNull(consentRecord.MyInfo_Name__c) : '',
            ''
        );
        emailAddress = blankIfNull(contactRecord.Email);
        idType = getStringFieldValue(contactRecord, new List<String>{ 'ID_Type__c' });
        idNumber = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'ID_Number__c', 'NRIC__c', 'FIN__c' }),
            consentRecord != null ? blankIfNull(consentRecord.MyInfo_ID_Number__c) : '',
            ''
        );
        nationality = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'Nationality__c' }),
            consentRecord != null ? blankIfNull(consentRecord.MyInfo_Nationality__c) : '',
            ''
        );
        passType = getStringFieldValue(contactRecord, new List<String>{ 'Pass_Type__c' });
        passportNumber = getStringFieldValue(contactRecord, new List<String>{ 'Passport_Number__c' });
        gender = getStringFieldValue(contactRecord, new List<String>{ 'Gender__c' });
        maritalStatus = getStringFieldValue(contactRecord, new List<String>{ 'Marital_Status__c' });
        registeredAddress = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'Registered_Address__c' }),
            consentRecord != null ? blankIfNull(consentRecord.MyInfo_Residential_Address__c) : '',
            ''
        );
        dateOfBirthDisplay = formatDateOfBirth(resolveReferenceDateOfBirth());
        employmentStatus = resolveEmploymentStatusLabel();
        currentConsentStatus = firstNonBlank(
            consentRecord != null ? blankIfNull(consentRecord.Consent_Status__c) : '',
            getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' }),
            ''
        );
        consentSubmittedDate = formatSubmittedAt(consentRecord);
        consentExpiryDate = resolveConsentExpiryDate();
    }

    private String resolveBankName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        return 'your employer or the relevant bank';
    }

    private String getBankNameForDisplay() {
        ensureContextLoaded();
        return String.isBlank(employerBankName) ? resolveBankName() : employerBankName;
    }

    private Boolean resolveIsPreHire() {
        String rawStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        if (!String.isBlank(rawStatus)) {
            String normalized = rawStatus.trim().toLowerCase();
            if (normalized.contains('pre') || (normalized.contains('hire') && normalized.contains('new'))) {
                return true;
            }
        }

        String fromUrl = ApexPages.currentPage().getParameters().get('type');
        return equalsIgnoreCase(fromUrl, 'prehire') || equalsIgnoreCase(fromUrl, 'pre-hire');
    }

    private String resolveEmploymentStatusLabel() {
        return resolveIsPreHire() ? 'Pre-Hire' : 'Existing Employee';
    }

    private String resolveConsentExpiryDate() {
        if (consentRecord != null && consentRecord.Consent_Expiry_Date__c != null) {
            return formatDate(consentRecord.Consent_Expiry_Date__c);
        }

        Date contactExpiry = getDateFieldValue(contactRecord, new List<String>{ 'Current_Consent_Expiry_Date__c' });
        return contactExpiry == null ? '' : formatDate(contactExpiry);
    }

    private String formatSubmittedAt(Consent__c consent) {
        if (consent == null || consent.Submitted_At__c == null) {
            Datetime contactSubmitted = getDatetimeFieldValue(
                contactRecord,
                new List<String>{ 'Latest_Submission_Datetime__c' }
            );
            return contactSubmitted == null ? '' : contactSubmitted.format('d MMMM yyyy, h:mm a');
        }
        return consent.Submitted_At__c.format('d MMMM yyyy, h:mm a');
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
            SELECT Id, Data_Subject__c, Consent_Status__c, Consent_Expiry_Date__c, Submitted_At__c,
                MyInfo_Name__c, MyInfo_Nationality__c, MyInfo_ID_Number__c,
                MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c
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
                SELECT Id, Data_Subject__c, Consent_Status__c, Consent_Expiry_Date__c, Submitted_At__c,
                    MyInfo_Name__c, MyInfo_Nationality__c, MyInfo_ID_Number__c,
                    MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c
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
        return item == null || item.Data_Subject__c == null ? null : item.Data_Subject__c;
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
                SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c, Withdrawal_QR_Viewed_At__c
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
        List<String> fields = new List<String>{
            'Id', 'Data_Subject__c', 'Current_Status__c', 'Consent_Link_Expires_At__c', 'Withdrawal_QR_Viewed_At__c'
        };
        List<String> optional = new List<String>{
            'Token__c', 'Secure_Token__c', 'Access_Token__c',
            'Link_Expires_At__c', 'Expires_At__c', 'Expiry_Date_Time__c',
            'Token_Expires_At__c', 'Link_Expiry_DateTime__c'
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
            'Id', 'Name', 'Email', 'AccountId', 'Account.Name',
            'Current_Consent_Status__c', 'Current_Consent_Expiry_Date__c', 'Latest_Submission_Datetime__c'
        };
        List<String> optional = new List<String>{
            'Full_Name__c', 'Principal_Name__c', 'Full_Legal_Name__c',
            'Employment_Status__c', 'Authentication_Type__c', 'Consent_Type__c',
            'Date_of_Birth__c', 'DOB__c', 'Nationality__c', 'ID_Type__c',
            'ID_Number__c', 'NRIC__c', 'FIN__c', 'Gender__c', 'Marital_Status__c',
            'Pass_Type__c', 'Registered_Address__c', 'Passport_Number__c',
            'Data_Subject_Lifecycle_Stage__c', 'Blocked_For_Report_Request__c'
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

    private PageReference redirectToNoActiveConsentPage() {
        PageReference nextPage = buildRedirect(PAGE_NO_ACTIVE_CONSENT, true);
        nextPage.getParameters().remove('id');
        nextPage.getParameters().remove('consentId');
        nextPage.getParameters().put('action', ACTION_WITHDRAW);
        return nextPage;
    }

    private void logIdentityMatchException(String message) {
        try {
            Case exceptionCase = new Case();
            exceptionCase.ContactId = parseId(contactId);
            exceptionCase.Subject = 'Singpass withdrawal identity verification failed';
            exceptionCase.Origin = 'Web';
            exceptionCase.Description = message;
            exceptionCase.Status = choosePicklistValue(Case.Status.getDescribe(), new List<String>{ 'New', 'Working' });
            setOptionalFieldSafe(exceptionCase, 'Consent_Request_Item__c', requestItemRecord == null ? null : requestItemRecord.Id);
            insert exceptionCase;
        } catch (Exception e) {
            // Do not expose internal exception logging failures to the user.
        }
    }

    private String resolveSingpassIdNumber() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        String fromParams = firstNonBlank(
            firstNonBlank(params.get('nric'), params.get('NRIC'), params.get('idNumber')),
            params.get('uinfin'),
            params.get('MyInfo_ID_Number')
        );
        return firstNonBlank(
            fromParams,
            getStringFieldValue(contactRecord, new List<String>{ 'ID_Number__c', 'NRIC__c', 'FIN__c' }),
            consentRecord != null ? blankIfNull(consentRecord.MyInfo_ID_Number__c) : null
        );
    }

    private Date resolveSingpassDateOfBirth() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        Date fromParam = parseDateParam(firstNonBlank(params.get('dob'), params.get('dateOfBirth'), params.get('MyInfo_Date_of_Birth')));
        return fromParam == null ? resolveReferenceDateOfBirth() : fromParam;
    }

    private Date resolveReferenceDateOfBirth() {
        if (consentRecord != null && consentRecord.MyInfo_Date_of_Birth__c != null) {
            return consentRecord.MyInfo_Date_of_Birth__c;
        }
        return getDateFieldValue(contactRecord, new List<String>{ 'Date_of_Birth__c', 'DOB__c' });
    }

    private Date parseDateParam(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            return Date.valueOf(rawValue);
        } catch (Exception e) {
            return null;
        }
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
            'Consent_Link_Expires_At__c', 'Link_Expires_At__c', 'Expires_At__c',
            'Expiry_Date_Time__c', 'Token_Expires_At__c', 'Link_Expiry_DateTime__c'
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
        entryAction = blankIfNull(params.get('action'));
        entryType = blankIfNull(params.get('type'));
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

        List<String> passthroughParams = new List<String>{
            'recordId', 'action', 'type', 'authType', 'authenticationType', 'subjectType',
            'returnFromAuth', 'singpassVerified', 'authComplete', 'nric', 'NRIC', 'idNumber', 'dob'
        };
        for (String key : passthroughParams) {
            String value = ApexPages.currentPage().getParameters().get(key);
            if (!String.isBlank(value)) {
                targetPage.getParameters().put(key, value);
            }
        }
    }

    private PageReference buildRedirect(String pagePath, Boolean setRedirect) {
        PageReference pageRef = new PageReference(pagePath);
        copyContextParams(pageRef);
        if (setRedirect == true) {
            pageRef.setRedirect(true);
        }
        return pageRef;
    }

    private void ensureContextLoaded() {
        if (contextLoaded) {
            return;
        }

        Id subjectId = parseId(contactId);
        if (subjectId == null) {
            return;
        }

        if (contactRecord == null) {
            contactRecord = queryContact(subjectId);
        }
        if (consentRecord == null) {
            consentRecord = resolveActiveConsent(subjectId);
            if (consentRecord != null) {
                consentId = consentRecord.Id;
            }
        }
        if (requestItemRecord == null) {
            requestItemRecord = resolveRequestItem(subjectId);
        }
        if (contactRecord != null) {
            populateDisplayValues();
        }
        contextLoaded = true;
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

    private static String formatDateOfBirth(Date dateOfBirth) {
        return dateOfBirth == null ? '' : formatDate(dateOfBirth);
    }

    private static String formatDate(Date dateValue) {
        if (dateValue == null) {
            return '';
        }
        return Datetime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy');
    }

    private void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || value == null || !hasField(record, fieldApiName)) {
            return;
        }
        try {
            Schema.DescribeFieldResult describe = record.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
            if (!describe.isUpdateable() && !describe.isCreateable()) {
                return;
            }
            if ((describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist)
                && !isPicklistValueAllowed(describe, String.valueOf(value))) {
                return;
            }
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Ignore optional field update failures.
        }
    }

    private Boolean isPicklistValueAllowed(Schema.DescribeFieldResult describe, String value) {
        if (describe == null || String.isBlank(value)) {
            return false;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    private String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
        if (describe == null || preferredValues == null) {
            return null;
        }
        for (String preferred : preferredValues) {
            if (String.isBlank(preferred)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferred) || entry.getLabel().equalsIgnoreCase(preferred)) {
                    return entry.getValue();
                }
            }
        }
        return null;
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

    private static Datetime getDatetimeFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (hasField(record, fieldApi)) {
                Object rawValue = record.get(fieldApi);
                if (rawValue instanceof Datetime) {
                    return (Datetime) rawValue;
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

    public class SingpassWithdrawalConsentException extends Exception {}
}