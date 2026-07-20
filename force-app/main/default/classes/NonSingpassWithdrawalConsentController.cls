/**
 * Controller for Non-Singpass Employee / Pre-Hire Withdrawal of Consent & Authorisation page.
 * Guest-accessible via Salesforce Sites / Experience Cloud.
 */
public without sharing class NonSingpassWithdrawalConsentController {
    private static final String ACTION_WITHDRAW = 'withdraw';
    private static final String AUTH_TYPE_NON_SINGPASS = 'Non-Singpass';

    private static final String CONTACT_STATUS_AUTHORIZED = 'Authorized';
    private static final String CONTACT_STATUS_VALID = 'Valid';
    private static final String CONTACT_STATUS_DECLINED = 'Declined';
    private static final String CONTACT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String CONTACT_STATUS_EXPIRED = 'Expired';
    private static final String CONTACT_STATUS_REVOKED = 'Revoked';

    private static final String CONSENT_STATUS_ACTIVE = 'Active';
    private static final String CONSENT_STATUS_VALID = 'Valid';
    private static final String CONSENT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String REQUEST_STATUS_WITHDRAWN = 'Withdrawn';

    private static final String LIFECYCLE_STAGE_CONSENT_WITHDRAWN = 'Consent Withdrawn';
    private static final String DEFAULT_VERIFICATION_EMAIL_PLACEHOLDER = '[CBS VERIFICATION EMAIL ADDRESS]';

    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_NO_ACTIVE_CONSENT = '/apex/NoActiveConsentPage';
    private static final String PAGE_WITHDRAW_SUCCESS = '/apex/CBSWithdrawSuccessPage';
    private static final Integer MAX_NAME_LENGTH = 80;
    private static final Integer MAX_TEXT_LENGTH = 80;
    private static final Integer MAX_ID_OR_PASSPORT_LENGTH = 50;
    private static final Integer MAX_ADDRESS_LENGTH = 255;
    private static final String SAFE_TEXT_REGEX = '^[A-Za-z0-9 ()\\-\\/,\\.]+$';
    private static final String ID_NUMBER_REGEX = '^[A-Za-z0-9\\-\\/]+$';

    public String contactId { get; private set; }
    public String consentId { get; private set; }
    public Boolean hasConfirmedWithdrawal { get; set; }
    public Boolean showPage { get; private set; }
    public Boolean submitInProgress { get; private set; }

    public String principalName { get; set; }
    public String emailAddress { get; private set; }
    public String idType { get; set; }
    public String idNumber { get; set; }
    public String dateOfBirthInput { get; set; }
    public String nationality { get; set; }
    public String passType { get; set; }
    public String passportNumber { get; set; }
    public String gender { get; set; }
    public String maritalStatus { get; set; }
    public String registeredAddress { get; set; }
    public String employerBankName { get; private set; }
    public String employmentStatus { get; private set; }
    public String currentConsentStatus { get; private set; }
    public String consentSubmittedDate { get; private set; }
    public String consentExpiryDate { get; private set; }
    public String consentReferenceId { get; private set; }
    public String consentTypeDisplay { get; private set; }

    private String requestItemId;
    private String token;

    private Contact contactRecord;
    private Consent__c consentRecord;
    private Consent_Request_Item__c requestItemRecord;
    private Boolean contextLoaded = false;
    private String cachedVerificationEmail;

    public NonSingpassWithdrawalConsentController() {
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

            if (contextLoaded != true || contactRecord == null || consentRecord == null) {
                showPage = false;
                return null;
            }

            populateDisplayValues();
            showPage = true;
            contextLoaded = true;
            return null;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'The withdrawal link is invalid or cannot be used. Please use the latest withdrawal link from CBS.'
            ));
            showPage = false;
            return null;
        }
    }

    public String getPageMainTitle() {
        return 'Individual\'s Withdrawal of Explicit Authorisation and Consent for Disclosure of Personal Credit Information to '
            + getBankNameForDisplay();
    }

    public String getPageSubtitle() {
        return 'Withdrawal of Consent and Authorisation';
    }

    public String getIntroLine() {
        return 'You are about to withdraw the consent previously given to Credit Bureau (Singapore) Pte Ltd ("CBS") to collect, receive, use, release and disclose your personal credit information to '
            + getBankNameForDisplay()
            + ' for '
            + getPurposeDescription()
            + ' purposes.';
    }

    public String getPurposeDescription() {
        return getIsPreHire()
            ? 'pre-employment screening / background check'
            : 'employment-related credit assessment / background screening';
    }

    public String getConsentValidityDescription() {
        return getIsPreHire()
            ? '1 month from the date of submission or until one successful credit report retrieval has been completed, whichever is earlier'
            : '5 years from the date of submission, unless withdrawn earlier';
    }

    public String getEmploymentStatusLabel() {
        return getIsPreHire() ? 'Pre-Hire' : 'Employee';
    }

    public String getWithdrawalCheckboxText() {
        return 'I WITHDRAW MY CONSENT AND AUTHORISATION previously given to Credit Bureau (Singapore) Pte Ltd ("CBS") to collect, receive, use, release and disclose my personal credit information to '
            + getBankNameForDisplay()
            + ' for the purpose of employment screening and/or background check.';
    }

    public String getSupportingVerificationText() {
        return 'You may be required to provide supporting identity verification documents so that CBS can verify your identity and process your withdrawal request.';
    }

    public String getVerificationEmailLabelText() {
        return 'Please email the supporting documents directly to CBS at:';
    }

    public String getVerificationEmailAddress() {
        if (cachedVerificationEmail != null) {
            return cachedVerificationEmail;
        }
        cachedVerificationEmail = resolveVerificationEmailFromConfig();
        return cachedVerificationEmail;
    }

    public List<String> getSupportingDocumentIncludes() {
        return new List<String>{
            'Full Name',
            'Email Address',
            'Bank Name',
            'Reference ID'
        };
    }

    public List<String> getSupportingDocumentTypes() {
        return new List<String>{
            'Valid passport',
            'Face identity verification image'
        };
    }

    public List<String> getWithdrawalConsequenceClauses() {
        String bankName = getBankNameForDisplay();
        return new List<String>{
            'CBS will update my consent status as withdrawn upon successful submission of this electronic form.',
            bankName + ' will be notified that I have withdrawn my consent.',
            'After my withdrawal has been processed, ' + bankName + ' will not be able to submit any new request to CBS for my credit report under this consent.',
            'This withdrawal does not affect any credit report request that was already submitted, processed, or completed before the date and time of this withdrawal.',
            'I may be required to provide fresh consent if ' + bankName + ' needs to request my credit report again in future.'
        };
    }

    public Boolean getIsIdTypeReadOnly() {
        ensureContextLoaded();
        return !String.isBlank(getStringFieldValue(contactRecord, new List<String>{ 'ID_Type__c' }));
    }

    public Boolean getIsIdNumberReadOnly() {
        ensureContextLoaded();
        return !String.isBlank(firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'ID_Number__c', 'NRIC__c', 'FIN__c' }),
            consentRecord != null ? blankIfNull(consentRecord.MyInfo_ID_Number__c) : ''
        ));
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
            if (contextLoaded != true || contactRecord == null || consentRecord == null) {
                showPage = false;
                return null;
            }

            if (!validateSubmissionInput()) {
                showPage = true;
                return null;
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

    private Boolean validateSubmissionInput() {
        Boolean isValid = true;
        sanitizeInputsForSubmission();

        if (hasConfirmedWithdrawal != true) {
            isValid = addErrorAndReturnFalse(
                'Please confirm your withdrawal by selecting the declaration checkbox before submitting.',
                isValid
            );
        }

        if (!hasWithdrawableActiveConsent()) {
            isValid = addErrorAndReturnFalse(
                'This consent is no longer active and cannot be withdrawn through this link.',
                isValid
            );
        }

        if (String.isBlank(principalName)) {
            isValid = addErrorAndReturnFalse('Principal Name / Full Legal Name is required.', isValid);
        }
        if (String.isBlank(idType)) {
            isValid = addErrorAndReturnFalse('ID Type is required.', isValid);
        }
        if (String.isBlank(idNumber)) {
            isValid = addErrorAndReturnFalse('ID Number is required.', isValid);
        }
        if (String.isBlank(passportNumber)) {
            isValid = addErrorAndReturnFalse('Passport Number is required.', isValid);
        }
        if (!String.isBlank(idType) && !Pattern.matches(SAFE_TEXT_REGEX, idType)) {
            isValid = addErrorAndReturnFalse('ID Type contains invalid characters.', isValid);
        }
        if (!String.isBlank(idNumber) && !Pattern.matches(ID_NUMBER_REGEX, idNumber)) {
            isValid = addErrorAndReturnFalse('ID Number supports only letters, numbers, "-" and "/".', isValid);
        }
        if (!String.isBlank(passportNumber) && !Pattern.matches(ID_NUMBER_REGEX, passportNumber)) {
            isValid = addErrorAndReturnFalse('Passport Number supports only letters, numbers, "-" and "/".', isValid);
        }
        if (String.isBlank(dateOfBirthInput)) {
            isValid = addErrorAndReturnFalse('Date of Birth is required.', isValid);
        } else {
            Date parsedDob = parseDateInput(dateOfBirthInput);
            if (parsedDob == null) {
                isValid = addErrorAndReturnFalse('Date of Birth must be in YYYY-MM-DD format.', isValid);
            } else if (parsedDob > Date.today()) {
                isValid = addErrorAndReturnFalse('Date of Birth cannot be a future date.', isValid);
            }
        }
        return isValid;
    }

    private void sanitizeInputsForSubmission() {
        principalName = sanitizeSubmittedText(principalName, MAX_NAME_LENGTH);
        idType = sanitizeSubmittedText(idType, MAX_TEXT_LENGTH);
        idNumber = sanitizeSubmittedText(idNumber, MAX_ID_OR_PASSPORT_LENGTH);
        passportNumber = sanitizeSubmittedText(passportNumber, MAX_ID_OR_PASSPORT_LENGTH);
        dateOfBirthInput = sanitizeSubmittedText(dateOfBirthInput, 10);
        nationality = sanitizeSubmittedText(nationality, MAX_TEXT_LENGTH);
        passType = sanitizeSubmittedText(passType, MAX_TEXT_LENGTH);
        gender = sanitizeSubmittedText(gender, 40);
        maritalStatus = sanitizeSubmittedText(maritalStatus, 40);
        registeredAddress = sanitizeSubmittedText(registeredAddress, MAX_ADDRESS_LENGTH);
    }

    private void processWithdrawal() {
        Datetime withdrawnAt = System.now();
        Consent__c activeConsent = consentRecord;
        if (activeConsent == null) {
            throw new NonSingpassWithdrawalConsentException('Active consent record was not found.');
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
        setOptionalFieldSafe(consentUpdate, 'Withdrawal_Method__c', 'Non-Singpass / Manual Verification');
        setOptionalFieldSafe(consentUpdate, 'Authentication_Type__c', AUTH_TYPE_NON_SINGPASS);
        setOptionalFieldSafe(consentUpdate, 'Latest_Submission_Date_Time__c', withdrawnAt);
        setOptionalFieldSafe(consentUpdate, 'Latest_Status_Datetime__c', withdrawnAt);
        setOptionalFieldSafe(consentUpdate, 'Consent_Withdrawn_Date__c', withdrawnAt);
        setOptionalFieldSafe(consentUpdate, 'Withdrawal_Channel__c', 'Client on behalf');
        setOptionalFieldSafe(consentUpdate, 'Withdrawal_By__c', UserInfo.getUserId());
        update consentUpdate;

        updateLatestRequestItemStatus(parseId(contactId), REQUEST_STATUS_WITHDRAWN);
        updateContactIdentityInfo(parseId(contactId), withdrawnAt);
        updateContactForWithdrawal(parseId(contactId), withdrawnAt);
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
            return blockWithError('Invalid withdrawal link: missing or inconsistent Contact/Consent/Request reference.');
        }
        contactId = String.valueOf(subjectId);

        contactRecord = queryContact(subjectId);
        if (contactRecord == null) {
            return blockWithError('Invalid withdrawal link: data subject record was not found.');
        }

        requestItemRecord = resolveRequestItem(subjectId);
        if (!String.isBlank(token) && !isTokenValidForRequestItem(requestItemRecord, token)) {
            return blockWithError('Invalid withdrawal link: token does not match this request.');
        }

        if (requestItemRecord != null && isRequestItemLinkExpired(requestItemRecord)) {
            return blockWithError('This withdrawal link has expired. Please use the latest link from CBS.');
        }

        consentRecord = resolveActiveConsent(subjectId);
        if (consentRecord != null) {
            consentId = consentRecord.Id;
        }

        PageReference terminalRedirect = resolveTerminalStatusRedirect();
        if (terminalRedirect != null) {
            return terminalRedirect;
        }

        if (!hasWithdrawableActiveConsent()) {
            return redirectToNoActiveConsentPage();
        }

        contextLoaded = true;
        return null;
    }

    private PageReference blockWithError(String message) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, message));
        showPage = false;
        return null;
    }

    private PageReference resolveTerminalStatusRedirect() {
        String contactStatus = normalizeStatus(getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' }));
        String lifecycleStage = normalizeStatus(getStringFieldValue(contactRecord, new List<String>{ 'Data_Subject_Lifecycle_Stage__c' }));
        if (lifecycleStage == normalizeStatus(LIFECYCLE_STAGE_CONSENT_WITHDRAWN)
            && contactStatus == CONTACT_STATUS_WITHDRAWN.toUpperCase()) {
            return redirectToNoActiveConsentPage();
        }

        if (contactStatus == CONTACT_STATUS_WITHDRAWN.toUpperCase()
            || contactStatus == CONTACT_STATUS_DECLINED.toUpperCase()
            || contactStatus == CONTACT_STATUS_REVOKED.toUpperCase()
            || contactStatus == CONTACT_STATUS_EXPIRED.toUpperCase()) {
            return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
        }

        if (consentRecord != null) {
            String consentStatus = normalizeStatus(consentRecord.Consent_Status__c);
            if (consentStatus == 'WITHDRAWN'
                || consentStatus == 'DECLINED'
                || consentStatus == 'REVOKED'
                || consentStatus == 'EXPIRED'
                || consentStatus == 'CONSUMED') {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
            }
        }

        if (requestItemRecord != null) {
            String requestStatus = normalizeStatus(requestItemRecord.Current_Status__c);
            if (requestStatus == 'WITHDRAWN'
                || requestStatus == 'DECLINED'
                || requestStatus == 'EXPIRED'
                || requestStatus == 'CONSUMED') {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
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
        idType = firstNonBlank(getStringFieldValue(contactRecord, new List<String>{ 'ID_Type__c' }), '');
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
        dateOfBirthInput = formatDateForInput(resolveReferenceDateOfBirth());
        employmentStatus = resolveEmploymentStatusLabel();
        currentConsentStatus = firstNonBlank(
            consentRecord != null ? blankIfNull(consentRecord.Consent_Status__c) : '',
            getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' }),
            ''
        );
        consentSubmittedDate = formatSubmittedAt(consentRecord);
        consentExpiryDate = resolveConsentExpiryDate();
        consentReferenceId = resolveReferenceIdDisplay();
        consentTypeDisplay = resolveConsentTypeDisplay();
    }

    private String resolveConsentTypeDisplay() {
        String fromConsent = getStringFieldValue(consentRecord, new List<String>{ 'Consent_Type__c', 'Consent_Duration_Type__c' });
        if (!String.isBlank(fromConsent)) {
            return fromConsent;
        }
        String fromContact = getStringFieldValue(contactRecord, new List<String>{ 'Consent_Type__c' });
        if (!String.isBlank(fromContact)) {
            return fromContact;
        }
        return getEmploymentStatusLabel();
    }

    private String resolveReferenceIdDisplay() {
        if (requestItemRecord != null && requestItemRecord.Id != null) {
            return String.valueOf(requestItemRecord.Id);
        }
        if (!String.isBlank(requestItemId)) {
            return requestItemId;
        }
        if (consentRecord != null && consentRecord.Id != null) {
            return String.valueOf(consentRecord.Id);
        }
        return '';
    }

    private String resolveBankName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        if (requestItemRecord != null) {
            String fromRequest = getStringFieldValue(
                requestItemRecord,
                new List<String>{ 'Client_Name__c', 'Employer_Name__c', 'Bank_Name__c', 'Uploaded_Employer_Name__c' }
            );
            if (!String.isBlank(fromRequest)) {
                return fromRequest;
            }
        }
        return '[NAME OF BANK]';
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
        return resolveIsPreHire() ? 'Pre-Hire' : 'Employee';
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
            Datetime contactSubmitted = getDatetimeFieldValue(contactRecord, new List<String>{ 'Latest_Submission_Datetime__c' });
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
                AND Consent_Status__c IN :new List<String>{ CONSENT_STATUS_ACTIVE, CONSENT_STATUS_VALID }
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
                AND Consent_Status__c IN :new List<String>{ CONSENT_STATUS_ACTIVE, CONSENT_STATUS_VALID }
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
        List<String> fields = new List<String>{
            'Id', 'Data_Subject__c', 'Current_Status__c', 'Consent_Link_Expires_At__c'
        };
        List<String> optional = new List<String>{
            'Token__c', 'Secure_Token__c', 'Access_Token__c',
            'Link_Expires_At__c', 'Expires_At__c', 'Expiry_Date_Time__c',
            'Token_Expires_At__c', 'Link_Expiry_DateTime__c',
            'Client_Name__c', 'Employer_Name__c', 'Bank_Name__c', 'Uploaded_Employer_Name__c'
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

    private void updateContactIdentityInfo(Id subjectId, Datetime withdrawnAt) {
        if (subjectId == null) {
            return;
        }

        Contact contactUpdate = new Contact(Id = subjectId);
        contactUpdate.Principal_Name__c = principalName;
        contactUpdate.ID_Type__c = resolvePicklistOrRawValue(Contact.ID_Type__c.getDescribe(), idType);
        contactUpdate.ID_Number__c = idNumber;
        if (!String.isBlank(passType)) {
            contactUpdate.Pass_Type__c = resolvePicklistOrRawValue(Contact.Pass_Type__c.getDescribe(), passType);
        }
        contactUpdate.Passport_Number__c = passportNumber;
        if (!String.isBlank(nationality)) {
            contactUpdate.Nationality__c = resolvePicklistOrRawValue(Contact.Nationality__c.getDescribe(), nationality);
        }
        if (!String.isBlank(gender)) {
            contactUpdate.Gender__c = resolvePicklistOrRawValue(Contact.Gender__c.getDescribe(), gender);
        }
        if (!String.isBlank(maritalStatus)) {
            contactUpdate.Marital_Status__c = resolvePicklistOrRawValue(Contact.Marital_Status__c.getDescribe(), maritalStatus);
        }
        if (!String.isBlank(registeredAddress)) {
            contactUpdate.Registered_Address__c = registeredAddress;
        }
        Date parsedDob = parseDateInput(dateOfBirthInput);
        if (parsedDob != null) {
            setOptionalFieldSafe(contactUpdate, 'Date_of_Birth__c', parsedDob);
            setOptionalFieldSafe(contactUpdate, 'DOB__c', parsedDob);
        }
        setOptionalFieldSafe(contactUpdate, 'Latest_Submission_Datetime__c', withdrawnAt);
        update contactUpdate;
    }

    private void updateContactForWithdrawal(Id subjectId, Datetime withdrawnAt) {
        if (subjectId == null) {
            return;
        }

        String withdrawnStatusValue = resolvePicklistOrRawValue(
            Contact.Current_Consent_Status__c.getDescribe(),
            CONTACT_STATUS_WITHDRAWN
        );
        String withdrawnLifecycleValue = resolvePicklistOrRawValue(
            Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(),
            LIFECYCLE_STAGE_CONSENT_WITHDRAWN
        );
        Contact contactUpdate = new Contact(
            Id = subjectId,
            Current_Consent_Status__c = withdrawnStatusValue,
            Data_Subject_Lifecycle_Stage__c = withdrawnLifecycleValue
        );
        setOptionalFieldSafe(contactUpdate, 'Blocked_For_Report_Request__c', true);
        setOptionalFieldSafe(contactUpdate, 'Authentication_Type__c', AUTH_TYPE_NON_SINGPASS);
        setOptionalFieldSafe(contactUpdate, 'Latest_Submission_Datetime__c', withdrawnAt);

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> withdrawalDatetimeFields = new List<String>{
            'Withdrawal_Date__c', 'Withdrawal_Datetime__c', 'Consent_Revocation_Date__c', 'Revoked_At__c',
            'Latest_Status_Datetime__c', 'Last_Activity_Date__c'
        };
        for (String fieldApi : withdrawalDatetimeFields) {
            if (!contactFields.containsKey(fieldApi)) {
                continue;
            }
            Schema.DisplayType fieldType = contactFields.get(fieldApi).getDescribe().getType();
            if (fieldType == Schema.DisplayType.Date) {
                contactUpdate.put(fieldApi, withdrawnAt.date());
            } else if (fieldType == Schema.DisplayType.DateTime) {
                contactUpdate.put(fieldApi, withdrawnAt);
            }
        }
        update contactUpdate;
    }

    private void updateLatestRequestItemStatus(Id subjectId, String status) {
        Id targetRequestItemId = null;
        if (requestItemRecord != null && requestItemRecord.Id != null) {
            targetRequestItemId = requestItemRecord.Id;
        } else if (!String.isBlank(requestItemId)) {
            targetRequestItemId = parseId(requestItemId);
        }

        if (targetRequestItemId == null && subjectId != null) {
            List<Consent_Request_Item__c> requestItems = [
                SELECT Id
                FROM Consent_Request_Item__c
                WHERE Data_Subject__c = :subjectId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!requestItems.isEmpty()) {
                targetRequestItemId = requestItems[0].Id;
            }
        }

        if (targetRequestItemId == null) {
            return;
        }

        String statusValue = choosePicklistValue(
            Consent_Request_Item__c.Current_Status__c.getDescribe(),
            new List<String>{ status, 'Withdrawn' }
        );
        if (String.isBlank(statusValue)) {
            return;
        }

        Consent_Request_Item__c reqUpdate = new Consent_Request_Item__c(Id = targetRequestItemId, Current_Status__c = statusValue);
        setOptionalFieldSafe(reqUpdate, 'Latest_Submission_Date_Time__c', System.now());
        update reqUpdate;
    }

    private PageReference redirectToNoActiveConsentPage() {
        PageReference nextPage = buildRedirect(PAGE_NO_ACTIVE_CONSENT, true);
        nextPage.getParameters().remove('id');
        nextPage.getParameters().remove('consentId');
        nextPage.getParameters().put('action', ACTION_WITHDRAW);
        return nextPage;
    }

    private Date resolveReferenceDateOfBirth() {
        if (consentRecord != null && consentRecord.MyInfo_Date_of_Birth__c != null) {
            return consentRecord.MyInfo_Date_of_Birth__c;
        }
        return getDateFieldValue(contactRecord, new List<String>{ 'Date_of_Birth__c', 'DOB__c' });
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
            'recordId', 'action', 'type', 'authType', 'authenticationType', 'subjectType'
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

    private String resolveVerificationEmailFromConfig() {
        String fromUrl = firstNonBlank(
            ApexPages.currentPage().getParameters().get('verificationEmail'),
            ApexPages.currentPage().getParameters().get('cbsVerificationEmail')
        );
        if (!String.isBlank(fromUrl)) {
            return fromUrl;
        }

        List<String> metadataTypeCandidates = new List<String>{
            'CBS_Config__mdt', 'CBS_Site_Config__mdt', 'Consent_Config__mdt'
        };
        List<String> fieldCandidates = new List<String>{
            'CBS_Verification_Email__c', 'Verification_Email__c', 'Manual_Verification_Email__c'
        };

        for (String typeName : metadataTypeCandidates) {
            String fromMetadata = queryDynamicConfigValue(typeName, fieldCandidates);
            if (!String.isBlank(fromMetadata)) {
                return fromMetadata;
            }
        }

        return DEFAULT_VERIFICATION_EMAIL_PLACEHOLDER;
    }

    private String queryDynamicConfigValue(String typeName, List<String> fieldCandidates) {
        Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe();
        if (!globalDescribeMap.containsKey(typeName)) {
            return null;
        }
        Schema.DescribeSObjectResult describe = globalDescribeMap.get(typeName).getDescribe();
        Map<String, Schema.SObjectField> fields = describe.fields.getMap();
        for (String fieldApi : fieldCandidates) {
            if (!fields.containsKey(fieldApi)) {
                continue;
            }
            try {
                String soql = 'SELECT ' + fieldApi + ' FROM ' + typeName + ' LIMIT 1';
                List<SObject> rows = Database.query(soql);
                if (!rows.isEmpty()) {
                    Object raw = rows[0].get(fieldApi);
                    if (raw != null && !String.isBlank(String.valueOf(raw))) {
                        return String.valueOf(raw);
                    }
                }
            } catch (Exception e) {
                // Ignore missing access / packaging differences and continue fallback.
            }
        }
        return null;
    }

    private static Boolean isActiveContactConsentStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }
        String normalized = statusValue.trim().toLowerCase();
        return normalized == CONTACT_STATUS_AUTHORIZED.toLowerCase() || normalized == CONTACT_STATUS_VALID.toLowerCase();
    }

    private static Boolean isActiveConsentRecordStatus(String statusValue) {
        String normalized = normalizeStatus(statusValue);
        return normalized == CONSENT_STATUS_ACTIVE.toUpperCase() || normalized == CONSENT_STATUS_VALID.toUpperCase();
    }

    private static String normalizeStatus(String statusValue) {
        return String.isBlank(statusValue) ? '' : statusValue.trim().toUpperCase();
    }

    private static String formatDate(Date dateValue) {
        if (dateValue == null) {
            return '';
        }
        return Datetime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy');
    }

    private static String formatDateForInput(Date dateValue) {
        return dateValue == null ? '' : String.valueOf(dateValue);
    }

    private Date parseDateInput(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            return Date.valueOf(rawValue.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private Boolean addErrorAndReturnFalse(String message, Boolean currentValidity) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, message));
        return false;
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

    private String resolvePicklistOrRawValue(Schema.DescribeFieldResult describe, String preferredValue) {
        if (String.isBlank(preferredValue) || describe == null) {
            return preferredValue;
        }
        if (describe.getType() != Schema.DisplayType.Picklist
            && describe.getType() != Schema.DisplayType.MultiPicklist) {
            return preferredValue;
        }
        String resolvedValue = choosePicklistValue(describe, new List<String>{ preferredValue });
        return String.isBlank(resolvedValue) ? preferredValue : resolvedValue;
    }

    private String sanitizeSubmittedText(String rawValue, Integer maxLength) {
        if (String.isBlank(rawValue)) {
            return '';
        }
        String normalized = rawValue.trim().replaceAll('\\s+', ' ');
        if (maxLength != null && maxLength > 0 && normalized.length() > maxLength) {
            normalized = normalized.substring(0, maxLength);
        }
        return normalized;
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

    public class NonSingpassWithdrawalConsentException extends Exception {}
}