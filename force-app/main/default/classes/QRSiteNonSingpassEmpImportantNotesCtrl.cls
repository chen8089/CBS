/**
 * Important Notes page for Non-Singpass Employee / 5-year Term-based Consent flow.
 * Guest-accessible via Salesforce Sites / Experience Cloud.
 */
public without sharing class QRSiteNonSingpassEmpImportantNotesCtrl {
    private static final String BANK_NAME_PLACEHOLDER = '[NAME OF BANK]';
    private static final String HR_SUPPORT_EMAIL_PLACEHOLDER = '[BANK HR SUPPORT EMAIL]';

    // Docx 3.1 placeholder -> Contact field mapping (Non-Singpass layout).
    private static final List<String> CONTACT_FIELDS_DATA_SUBJECT_NAME = new List<String>{
        'Full_Name__c', 'Principal_Name__c', 'Name'
    };
    private static final List<String> CONTACT_FIELDS_PRINCIPAL_NAME = new List<String>{
        'Principal_Name__c', 'Full_Name__c', 'Name'
    };
    private static final List<String> CONTACT_FIELDS_YOUR_FULL_NAME = new List<String>{
        'Full_Name__c', 'Principal_Name__c', 'Name'
    };
    private static final List<String> CONTACT_FIELDS_PASS_TYPE = new List<String>{
        'Pass_Type__c', 'ID_Type__c'
    };
    private static final List<String> CONTACT_FIELDS_ID_NUMBER = new List<String>{
        'ID_Number__c', 'NRIC_FIN_Number__c'
    };
    private static final List<String> CONTACT_FIELDS_PASSPORT_NUMBER = new List<String>{
        'Passport_Number__c'
    };
    private static final List<String> CONTACT_FIELDS_NATIONALITY = new List<String>{
        'Nationality__c'
    };
    private static final List<String> CONTACT_FIELDS_GENDER = new List<String>{
        'Gender__c'
    };
    private static final List<String> CONTACT_FIELDS_MARITAL_STATUS = new List<String>{
        'Marital_Status__c'
    };
    private static final List<String> CONTACT_FIELDS_REGISTERED_ADDRESS = new List<String>{
        'Registered_Address__c', 'MailingStreet'
    };
    private static final List<String> CONTACT_FIELDS_REFERENCE_NUMBER = new List<String>{
        'Report_Request_ID__c'
    };

    private static final String ACTION_AUTHORIZE = 'authorize';
    private static final String ACTION_CONSENT = 'consent';
    private static final String TYPE_EMPLOYEE = 'employee';
    private static final String TYPE_PREHIRE = 'prehire';
    private static final String AUTH_TYPE_NONSINGPASS = 'nonsingpass';
    private static final String SUBJECT_TYPE_EMPLOYEE = 'employee';
    private static final String SUBJECT_TYPE_PREHIRE = 'prehire';

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
    private static final String PAGE_IDENTITY_INFO = '/apex/CBS_NonSingpassIdentityInfoPage';
    private static final String PAGE_CONSENT_SUCCESS = '/apex/ConsentSuccessPage';

    public String contactId { get; set; }
    public String requestItemId { get; set; }
    public String token { get; set; }
    public String entryAction { get; set; }
    public String entryType { get; set; }
    public String entryAuthType { get; set; }
    public String entrySubjectType { get; set; }
    public String expectedFlowType { get; set; }
    public Boolean showPage { get; private set; }
    public Boolean hasAcceptedConsent { get; set; }
    public String inputPrincipalName { get; set; }
    public String inputIdType { get; set; }
    public String inputIdNumber { get; set; }
    public String inputPassType { get; set; }
    public String inputPassportNumber { get; set; }
    public Date inputDateOfBirth { get; set; }
    public String inputNationality { get; set; }
    public String inputGender { get; set; }
    public String inputMaritalStatus { get; set; }
    public String inputRegisteredAddress { get; set; }

    private Contact contactRecord;
    private Consent_Request_Item__c requestItemRecord;
    private Boolean contextLoaded = false;
    private String hrSupportEmail;
    private String debugStep;
    private Boolean displayValuesInitialized = false;
    private Boolean formValuesInitialized = false;

    private String displayDataSubjectName;
    private String displayPrincipalName;
    private String displayPassType;
    private String displayIdNumber;
    private String displayPassportNumber;
    private String displayDateOfBirth;
    private String displayNationality;
    private String displayGender;
    private String displayMaritalStatus;
    private String displayRegisteredAddress;
    private String displayYourFullName;
    private String displayReferenceNumber;
    private String resolvedBankName;

    public QRSiteNonSingpassEmpImportantNotesCtrl() {
        parseUrlParameters();
        expectedFlowType = TYPE_EMPLOYEE;
        showPage = false;
        hasAcceptedConsent = false;
    }

    public PageReference initPage() {
        try {
            if (isFormPostBack() && hasRequiredContextParams()) {
                PageReference redirect = validateEntryAndResolveRedirect(false, false);
                if (redirect != null) {
                    redirect.setRedirect(true);
                    return redirect;
                }
                initializeDisplayValues();
                showPage = true;
                return null;
            }

            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }
            initializeDisplayValues();
            initializeFormValues();
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

    public List<String> getIdentityVerificationParagraphs() {
        return new List<String>{
            'If you choose to proceed, you will be asked to provide or confirm selected identity information so that CBS can verify your identity and process the consent request.',
            'The information requested may include your full name, pass type, passport number, date of birth, nationality, gender, marital status and registered address, where applicable.',
            'You may also be required to provide supporting identity verification documents, such as a valid passport and face identity verification image, where requested.',
            'CBS will perform manual identity verification. Consent is only treated as valid after this verification is completed successfully.'
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
            'You may be required to complete identity verification checks before your withdrawal is submitted.',
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

    public String getSubmitButtonLabel() {
        return 'Submit';
    }

    public String getConsentCheckboxIntro() {
        return 'By selecting the checkbox and submitting this form, I authorise and give my consent for:';
    }

    public List<String> getConsentAuthorisationParagraphs() {
        String bank = getBankName();
        return new List<String>{
            'Credit Bureau (Singapore) Pte Ltd ("CBS") to collect, receive and use my personal data to generate and process my consumer credit report(s), and to release and disclose my consumer credit report(s) and/or any credit information, data or extracts derived from my consumer credit report(s) or otherwise held by CBS (including but not limited to current and historical credit information and any personal data contained therein) to '
                + bank
                + ', for the purpose of employment screening and/or background check',
            'I agree to indemnify and hold you, CBS, harmless for and/or in respect of all or any loss or damage arising from the disclosure of my credit information as requested by '
                + bank
                + ' and/or provided by CBS arising from my aforesaid authorization and consent.',
            bank + ' may submit credit report requests to CBS under this consent while this consent remains valid.'
        };
    }

    public String getConsentValidityIntro() {
        return 'By submitting my Consent and Authorisation, I acknowledge and agree that such consent and authorisation shall remain valid and in effect until the earlier of:';
    }

    public List<String> getConsentValidityItems() {
        return new List<String>{
            'the date falling ten (10) business days after such consent and authorisation is revoked by me or by '
                + getBankName()
                + '; or',
            'the expiry of the applicable period, being five (5) years from the date of this consent, unless withdrawn earlier.'
        };
    }

    public List<String> getDisclaimerParagraphs() {
        return new List<String>{
            'I understand that the information contained in my credit report has been provided by various third parties to and/or collated by Credit Bureau (Singapore) Pte Ltd and shall not hold Credit Bureau (Singapore) Pte Ltd for the accuracy of such information and/or the Score derived therefrom.',
            'I understand the above matters and confirm that the information I give is correct and that I accept the terms of the indemnity and disclaimer set out in this consent form.'
        };
    }

    public String getSupportingDocumentsNote() {
        return 'Note: CBS will review the information and documents submitted before your consent status is updated. Thereafter, '
            + getBankName()
            + ' can submit a credit report request under your consent.';
    }

    public String getSubmissionTitle() {
        return 'Submission of Consent and Personal Information';
    }

    public String getDisplayDataSubjectName() {
        initializeDisplayValues();
        return displayDataSubjectName;
    }

    public String getDisplayPrincipalName() {
        initializeDisplayValues();
        return displayPrincipalName;
    }

    public String getDisplayPassType() {
        initializeDisplayValues();
        return displayPassType;
    }

    public String getDisplayIdNumber() {
        initializeDisplayValues();
        return displayIdNumber;
    }

    public String getDisplayPassportNumber() {
        initializeDisplayValues();
        return displayPassportNumber;
    }

    public String getDisplayDateOfBirth() {
        initializeDisplayValues();
        return displayDateOfBirth;
    }

    public String getDisplayNationality() {
        initializeDisplayValues();
        return displayNationality;
    }

    public String getDisplayGender() {
        initializeDisplayValues();
        return displayGender;
    }

    public String getDisplayMaritalStatus() {
        initializeDisplayValues();
        return displayMaritalStatus;
    }

    public String getDisplayRegisteredAddress() {
        initializeDisplayValues();
        return displayRegisteredAddress;
    }

    public String getDisplayReferenceNumber() {
        initializeDisplayValues();
        return displayReferenceNumber;
    }

    public String getDisplayEmailSubjectTitle() {
        initializeDisplayValues();
        return 'Provide Supporting Documents for '
            + displayYourFullName
            + ' for '
            + displayReferenceNumber;
    }

    public String getBankName() {
        initializeDisplayValues();
        return resolvedBankName;
    }

    public PageReference submitConsent() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect(false, false);
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            if (hasAcceptedConsent != true) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Please confirm your authorization and consent before submitting.'
                ));
                showPage = true;
                return null;
            }

            if (!validateEditableInputs()) {
                showPage = true;
                return null;
            }

            Savepoint sp = Database.setSavepoint();
            try {
                updateContactAndRequestItem();
            } catch (Exception saveException) {
                Database.rollback(sp);
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'We could not save your submission. Please check your input and try again.'
                ));
                showPage = true;
                return null;
            }

            PageReference successPage = buildRedirect(PAGE_CONSENT_SUCCESS);
            successPage.getParameters().put('completed', 'true');
            successPage.getParameters().put('completedMode', 'submitted');
            successPage.setRedirect(true);
            return successPage;
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK);
        }
    }

    private String buildSecurityContactText() {
        String hrEmail = String.isBlank(getHrSupportEmail())
            ? HR_SUPPORT_EMAIL_PLACEHOLDER
            : getHrSupportEmail();
        return 'If you have any questions about this request, please contact '
            + getBankName()
            + ' Human Resources at '
            + hrEmail
            + ' before continuing.';
    }

    private void initializeDisplayValues() {
        ensureContextLoaded();
        if (displayValuesInitialized) {
            return;
        }

        displayDataSubjectName = resolveContactPlaceholder(
            CONTACT_FIELDS_DATA_SUBJECT_NAME,
            '[DATA SUBJECT FULL NAME]'
        );
        displayPrincipalName = resolveContactPlaceholder(
            CONTACT_FIELDS_PRINCIPAL_NAME,
            '[PRINCIPAL NAME]'
        );
        displayYourFullName = resolveContactPlaceholder(
            CONTACT_FIELDS_YOUR_FULL_NAME,
            '[YOUR FULL NAME]'
        );
        displayPassType = resolveContactPlaceholder(
            CONTACT_FIELDS_PASS_TYPE,
            '[PASS TYPE]'
        );
        displayIdNumber = resolveContactPlaceholder(
            CONTACT_FIELDS_ID_NUMBER,
            '[ID NUMBER]'
        );
        displayPassportNumber = resolveContactPlaceholder(
            CONTACT_FIELDS_PASSPORT_NUMBER,
            '[PASSPORT NUMBER]'
        );
        displayDateOfBirth = resolveDateOfBirthDisplay();
        displayNationality = resolveContactPlaceholder(
            CONTACT_FIELDS_NATIONALITY,
            '[NATIONALITY]'
        );
        displayGender = resolveContactPlaceholder(
            CONTACT_FIELDS_GENDER,
            '[GENDER]'
        );
        displayMaritalStatus = resolveContactPlaceholder(
            CONTACT_FIELDS_MARITAL_STATUS,
            '[MARITAL STATUS]'
        );
        displayRegisteredAddress = resolveContactPlaceholder(
            CONTACT_FIELDS_REGISTERED_ADDRESS,
            '[REGISTERED ADDRESS]'
        );
        displayReferenceNumber = resolveReferenceNumber();
        resolvedBankName = resolveBankName();
        displayValuesInitialized = true;
    }

    private void initializeFormValues() {
        ensureContextLoaded();
        if (formValuesInitialized || contactRecord == null) {
            return;
        }

        inputPrincipalName = getStringFieldValue(contactRecord, CONTACT_FIELDS_PRINCIPAL_NAME);
        inputIdType = getStringFieldValue(contactRecord, new List<String>{ 'ID_Type__c', 'Pass_Type__c' });
        inputIdNumber = getStringFieldValue(contactRecord, CONTACT_FIELDS_ID_NUMBER);
        inputPassType = getStringFieldValue(contactRecord, CONTACT_FIELDS_PASS_TYPE);
        inputPassportNumber = getStringFieldValue(contactRecord, CONTACT_FIELDS_PASSPORT_NUMBER);
        inputDateOfBirth = resolveDateOfBirth();
        inputNationality = getStringFieldValue(contactRecord, CONTACT_FIELDS_NATIONALITY);
        inputGender = getStringFieldValue(contactRecord, CONTACT_FIELDS_GENDER);
        inputMaritalStatus = getStringFieldValue(contactRecord, CONTACT_FIELDS_MARITAL_STATUS);
        inputRegisteredAddress = getStringFieldValue(contactRecord, CONTACT_FIELDS_REGISTERED_ADDRESS);
        formValuesInitialized = true;
    }

    private Boolean validateEditableInputs() {
        Boolean isValid = true;

        if (String.isBlank(sanitizeSubmittedText(inputPrincipalName))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Full Name is required.'));
            isValid = false;
        }
        if (String.isBlank(sanitizeSubmittedText(inputIdType))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'ID Type is required.'));
            isValid = false;
        }
        if (String.isBlank(sanitizeSubmittedText(inputIdNumber))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'ID Number is required.'));
            isValid = false;
        }
        if (String.isBlank(sanitizeSubmittedText(inputPassType))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Pass Type is required.'));
            isValid = false;
        }
        if (String.isBlank(sanitizeSubmittedText(inputPassportNumber))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Passport Number is required.'));
            isValid = false;
        }
        if (inputDateOfBirth == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Date of Birth is required.'));
            isValid = false;
        }
        if (String.isBlank(sanitizeSubmittedText(inputNationality))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Nationality is required.'));
            isValid = false;
        }
        if (String.isBlank(sanitizeSubmittedText(inputGender))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Gender is required.'));
            isValid = false;
        }
        if (String.isBlank(sanitizeSubmittedText(inputRegisteredAddress))) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Registered Address is required.'));
            isValid = false;
        }

        if (inputDateOfBirth != null && inputDateOfBirth > Date.today()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Date of Birth cannot be in the future.'));
            isValid = false;
        }
        return isValid;
    }

    private void updateContactAndRequestItem() {
        if (contactRecord == null || requestItemRecord == null) {
            throw new AuraHandledException('Missing request context.');
        }

        Contact updateContact = new Contact(Id = contactRecord.Id);
        updateContact.Principal_Name__c = sanitizeSubmittedText(inputPrincipalName);
        updateContact.Full_Name__c = sanitizeSubmittedText(inputPrincipalName);
        updateContact.ID_Type__c = resolveContactFieldValue('ID_Type__c', inputIdType);
        updateContact.ID_Number__c = sanitizeSubmittedText(inputIdNumber);
        setOptionalFieldSafe(updateContact, 'NRIC_FIN_Number__c', sanitizeSubmittedText(inputIdNumber));
        updateContact.Pass_Type__c = resolveContactFieldValue('Pass_Type__c', inputPassType);
        updateContact.Passport_Number__c = sanitizeSubmittedText(inputPassportNumber);
        updateContact.Date_of_Birth__c = inputDateOfBirth;
        setOptionalFieldSafe(updateContact, 'DOB__c', inputDateOfBirth);
        setOptionalFieldSafe(updateContact, 'Birthdate', inputDateOfBirth);
        updateContact.Nationality__c = resolveContactFieldValue('Nationality__c', inputNationality);
        updateContact.Gender__c = resolveContactFieldValue('Gender__c', inputGender);
        updateContact.Marital_Status__c = resolveContactFieldValue('Marital_Status__c', inputMaritalStatus);
        updateContact.Registered_Address__c = sanitizeSubmittedText(inputRegisteredAddress);
        setOptionalFieldSafe(updateContact, 'MailingStreet', sanitizeSubmittedText(inputRegisteredAddress));
        updateContact.Data_Subject_Lifecycle_Stage__c = LIFECYCLE_STAGE_ACTIVE_CONSENT;
        updateContact.Current_Consent_Status__c = CONTACT_STATUS_AUTHORIZED;
        setOptionalFieldSafe(updateContact, 'Latest_Submission_Datetime__c', System.now());

        Consent_Request_Item__c updateRequestItem = new Consent_Request_Item__c(
            Id = requestItemRecord.Id,
            Current_Status__c = REQUEST_STATUS_SUBMITTED
        );
        setOptionalFieldSafe(updateRequestItem, 'Identity_Verification_Status__c', 'Pending');
        setOptionalFieldSafe(updateRequestItem, 'Latest_Submission_Date_Time__c', System.now());

        update new List<SObject>{ updateContact, updateRequestItem };

        contactRecord = queryContact(contactRecord.Id);
        requestItemRecord = queryRequestItemById(requestItemRecord.Id);
        displayValuesInitialized = false;
        formValuesInitialized = false;
        initializeDisplayValues();
        initializeFormValues();
    }

    private String resolveContactPlaceholder(List<String> contactFieldCandidates, String placeholder) {
        String value = getStringFieldValue(contactRecord, contactFieldCandidates);
        if (!String.isBlank(value)) {
            return value;
        }

        value = getStringFieldValue(requestItemRecord, getRequestItemFallbackFields(contactFieldCandidates));
        return String.isBlank(value) ? placeholder : value;
    }

    private List<String> getRequestItemFallbackFields(List<String> contactFieldCandidates) {
        if (contactFieldCandidates == CONTACT_FIELDS_DATA_SUBJECT_NAME
            || contactFieldCandidates == CONTACT_FIELDS_PRINCIPAL_NAME
            || contactFieldCandidates == CONTACT_FIELDS_YOUR_FULL_NAME) {
            return new List<String>{ 'Uploaded_Full_Name__c' };
        }
        if (contactFieldCandidates == CONTACT_FIELDS_PASS_TYPE) {
            return new List<String>{ 'Uploaded_ID_Type__c' };
        }
        if (contactFieldCandidates == CONTACT_FIELDS_ID_NUMBER) {
            return new List<String>{ 'Uploaded_ID_Number__c' };
        }
        if (contactFieldCandidates == CONTACT_FIELDS_REFERENCE_NUMBER) {
            return new List<String>{ 'Name' };
        }
        return new List<String>();
    }

    private String resolveDateOfBirthDisplay() {
        Date dob = resolveDateOfBirth();
        return dob == null
            ? '[DATE OF BIRTH]'
            : Datetime.newInstance(dob, Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy');
    }

    private Date resolveDateOfBirth() {
        if (contactRecord != null) {
            Object rawDob = null;
            if (hasField(contactRecord, 'Date_of_Birth__c')) {
                rawDob = contactRecord.get('Date_of_Birth__c');
            }
            if (rawDob == null && hasField(contactRecord, 'DOB__c')) {
                rawDob = contactRecord.get('DOB__c');
            }
            if (rawDob == null && hasField(contactRecord, 'Birthdate')) {
                rawDob = contactRecord.get('Birthdate');
            }
            if (rawDob instanceof Date) {
                return (Date) rawDob;
            }
        }

        if (requestItemRecord != null && hasField(requestItemRecord, 'Uploaded_Date_of_Birth__c')) {
            Object rawUploadedDob = requestItemRecord.get('Uploaded_Date_of_Birth__c');
            if (rawUploadedDob instanceof Date) {
                return (Date) rawUploadedDob;
            }
        }
        return null;
    }

    private String resolveReferenceNumber() {
        String fromContact = getStringFieldValue(contactRecord, CONTACT_FIELDS_REFERENCE_NUMBER);
        if (!String.isBlank(fromContact)) {
            return fromContact;
        }

        String fromRequestName = getStringFieldValue(requestItemRecord, new List<String>{ 'Name' });
        if (!String.isBlank(fromRequestName)) {
            return fromRequestName;
        }

        if (requestItemRecord != null && requestItemRecord.Id != null) {
            return String.valueOf(requestItemRecord.Id);
        }

        return '[REFERENCE NUMBER]';
    }

    private String resolveBankName() {
        String fromContactAccount = getContactAccountName();
        if (!String.isBlank(fromContactAccount)) {
            return fromContactAccount;
        }

        return BANK_NAME_PLACEHOLDER;
    }

    private String getContactAccountName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }

        if (contactRecord != null && contactRecord.AccountId != null) {
            try {
                List<Account> accounts = Database.query(
                    'SELECT Name FROM Account WHERE Id = :contactRecord.AccountId LIMIT 1',
                    AccessLevel.SYSTEM_MODE
                );
                if (!accounts.isEmpty() && !String.isBlank(accounts[0].Name)) {
                    return accounts[0].Name;
                }
            } catch (Exception e) {
                // Continue to placeholder fallback.
            }
        }
        return null;
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
        debugStep = 'start';

        debugStep = 'check-required-params';
        if (String.isBlank(contactId) || String.isBlank(token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        debugStep = 'parse-contact-id';
        Id parsedContactId = parseId(contactId);
        if (parsedContactId == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        debugStep = 'query-contact';
        try {
            contactRecord = queryContact(parsedContactId);
        } catch (Exception e) {
            contactRecord = null;
        }

        if (contactRecord != null) {
            hrSupportEmail = getAccountHrSupportEmail(contactRecord);
        }

        debugStep = 'resolve-request-item';
        try {
            requestItemRecord = resolveRequestItem(parsedContactId);
        } catch (Exception e) {
            requestItemRecord = null;
        }

        if (contactRecord == null && requestItemRecord != null && requestItemRecord.Data_Subject__c != null) {
            try {
                contactRecord = queryContact(requestItemRecord.Data_Subject__c);
            } catch (Exception e) {
                contactRecord = null;
            }
            if (contactRecord != null) {
                hrSupportEmail = getAccountHrSupportEmail(contactRecord);
            }
        }

        debugStep = 'validate-scenario';
        if (!isNonSingpassEmployeeScenario()) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        debugStep = 'validate-request-item';
        if (requestItemRecord == null || requestItemRecord.Data_Subject__c == null) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (requestItemRecord.Data_Subject__c != parsedContactId) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (!isTokenValidForRequestItem(requestItemRecord, token)) {
            return buildRedirect(PAGE_INVALID_LINK);
        }

        if (isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        debugStep = 'check-status';
        PageReference statusRedirect = resolveConsentStatusRedirect(
            parsedContactId,
            checkActiveConsentOnEntry,
            checkContactConsentStatus
        );
        if (statusRedirect != null) {
            return statusRedirect;
        }

        debugStep = 'ok';
        contextLoaded = true;
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
            if (requestStatus == REQUEST_STATUS_SUBMITTED
                || requestStatus == REQUEST_STATUS_DECLINED
                || requestStatus == REQUEST_STATUS_WITHDRAWN) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (requestStatus == REQUEST_STATUS_EXPIRED) {
                return buildRedirect(PAGE_LINK_EXPIRED);
            }
        }
        return null;
    }

    private Boolean isNonSingpassEmployeeScenario() {
        String normalizedExpectedType = normalizeToken(expectedFlowType);
        if (String.isBlank(normalizedExpectedType)) {
            normalizedExpectedType = TYPE_EMPLOYEE;
        }

        String normalizedEntryAction = normalizeToken(entryAction);
        if (!String.isBlank(normalizedEntryAction)
            && normalizedEntryAction != ACTION_AUTHORIZE
            && normalizedEntryAction != ACTION_CONSENT) {
            return false;
        }

        String normalizedEntryType = normalizeToken(entryType);
        if (!String.isBlank(normalizedEntryType) && normalizedEntryType != normalizedExpectedType) {
            return false;
        }

        String normalizedEntrySubjectType = normalizeToken(entrySubjectType);
        String expectedSubjectType = normalizedExpectedType == TYPE_PREHIRE
            ? SUBJECT_TYPE_PREHIRE
            : SUBJECT_TYPE_EMPLOYEE;
        if (!String.isBlank(normalizedEntrySubjectType) && normalizedEntrySubjectType != expectedSubjectType) {
            return false;
        }

        String normalizedEntryAuthType = normalizeAuthType(entryAuthType);
        if (!String.isBlank(normalizedEntryAuthType) && normalizedEntryAuthType != AUTH_TYPE_NONSINGPASS) {
            return false;
        }

        String authType = normalizeAuthType(getStringFieldValue(contactRecord, new List<String>{ 'Authentication_Type__c' }));
        if (!String.isBlank(authType) && authType != AUTH_TYPE_NONSINGPASS) {
            return false;
        }

        String employmentStatus = normalizeToken(getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' }));
        if (!String.isBlank(employmentStatus)) {
            if (normalizedExpectedType == TYPE_PREHIRE) {
                if (employmentStatus != 'pre-hire'
                    && employmentStatus != 'pre hire'
                    && employmentStatus != 'prehire'
                    && employmentStatus != 'new hire'
                    && employmentStatus != 'newhire') {
                    return false;
                }
            } else if (employmentStatus != 'existing hire' && employmentStatus != 'employee') {
                return false;
            }
        }

        String consentType = normalizeToken(getStringFieldValue(contactRecord, new List<String>{ 'Consent_Type__c' }));
        if (!String.isBlank(consentType)) {
            if (normalizedExpectedType == TYPE_PREHIRE) {
                String normalizedConsentType = consentType.replace('-', ' ');
                if (!normalizedConsentType.contains('per report') && !normalizedConsentType.contains('perreport')) {
                    return false;
                }
            } else if (!consentType.contains('term') && consentType != 'term based consent') {
                return false;
            }
        }

        return true;
    }

    private static String normalizeAuthType(String value) {
        String normalized = normalizeToken(value);
        if (String.isBlank(normalized)) {
            return '';
        }
        if (normalized.contains('singpass') && !normalized.contains('non')) {
            return 'singpass';
        }
        if ((normalized.contains('non') && normalized.contains('singpass')) || normalized.contains('manual')) {
            return AUTH_TYPE_NONSINGPASS;
        }
        return normalized;
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

        List<Consent_Request_Item__c> latestItems;
        try {
            latestItems = Database.query(
                'SELECT ' + String.join(getRequestItemSelectFields(), ',') +
                ' FROM Consent_Request_Item__c WHERE Data_Subject__c = :subjectId' +
                ' ORDER BY CreatedDate DESC, Id DESC LIMIT 1',
                AccessLevel.SYSTEM_MODE
            );
        } catch (Exception e) {
            latestItems = new List<Consent_Request_Item__c>();
        }
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
            List<Consent_Request_Item__c> items = Database.query(soql, AccessLevel.SYSTEM_MODE);
            return items.isEmpty() ? null : items[0];
        } catch (Exception e) {
            return null;
        }
    }

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        String tokenField = ConsentGuestAuthService.resolveTokenFieldApiName();
        if (String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT ' + String.join(getRequestItemSelectFields(), ',') +
            ' FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';
        try {
            List<Consent_Request_Item__c> rows = Database.query(soql, AccessLevel.SYSTEM_MODE);
            return rows.isEmpty() ? null : rows[0];
        } catch (Exception e) {
            return null;
        }
    }

    private List<String> getRequestItemSelectFields() {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Data_Subject__c', 'Current_Status__c', 'Consent_Link_Expires_At__c', 'Name' };
        List<String> optional = new List<String>{
            'Uploaded_Full_Name__c',
            'Uploaded_ID_Type__c',
            'Uploaded_ID_Number__c',
            'Uploaded_Date_of_Birth__c',
            'Consent_Request_Case__c',
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
        String soql =
            'SELECT Id, Name, Email, AccountId, Account.Name,' +
            ' Principal_Name__c, Full_Name__c, Pass_Type__c, ID_Type__c,' +
            ' ID_Number__c, NRIC_FIN_Number__c, Passport_Number__c,' +
            ' Date_of_Birth__c, DOB__c, Birthdate, Nationality__c, Gender__c,' +
            ' Marital_Status__c, Registered_Address__c, MailingStreet,' +
            ' Report_Request_ID__c, Current_Consent_Status__c,' +
            ' Current_Consent_Expiry_Date__c, Data_Subject_Lifecycle_Stage__c,' +
            ' Employment_Status__c, Authentication_Type__c, Consent_Type__c' +
            ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<Contact> rows = Database.query(soql, AccessLevel.SYSTEM_MODE);
        return rows.isEmpty() ? null : rows[0];
    }

    private static String getAccountHrSupportEmail(Contact sourceContact) {
        if (sourceContact == null || sourceContact.Account == null) {
            return null;
        }
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (!accountFields.containsKey('HR_Support_Email__c')) {
            return null;
        }
        Object rawValue = sourceContact.Account.get('HR_Support_Email__c');
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
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'), contactId);
        requestItemId = firstNonBlank(
            params.get('requestItemId'),
            params.get('consentRequestItemId'),
            requestItemId
        );
        token = firstNonBlank(params.get('token'), token);
        entryAction = firstNonBlank(params.get('action'), entryAction);
        entryType = firstNonBlank(params.get('type'), entryType);
        entryAuthType = firstNonBlank(params.get('authType'), entryAuthType);
        entrySubjectType = firstNonBlank(params.get('subjectType'), entrySubjectType);
    }

    private Boolean hasRequiredContextParams() {
        return !String.isBlank(contactId) && !String.isBlank(token);
    }

    private Boolean isFormPostBack() {
        return ApexPages.currentPage().getParameters().containsKey('QRSiteNonSingpassEmployeeImportantNotes:theForm');
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }
        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('contactId', contactId);
            targetPage.getParameters().put('ContactId', contactId);
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
            targetPage.getParameters().put('consentRequestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }
        targetPage.getParameters().put('action', String.isBlank(entryAction) ? ACTION_AUTHORIZE : entryAction);
        targetPage.getParameters().put('type', String.isBlank(entryType) ? TYPE_EMPLOYEE : entryType);
        targetPage.getParameters().put('authType', String.isBlank(entryAuthType) ? AUTH_TYPE_NONSINGPASS : entryAuthType);
        targetPage.getParameters().put('subjectType', String.isBlank(entrySubjectType) ? SUBJECT_TYPE_EMPLOYEE : entrySubjectType);
    }

    private PageReference buildRedirect(String pagePath) {
        PageReference pageRef = new PageReference(pagePath);
        copyContextParams(pageRef);
        if (!String.isBlank(debugStep)) {
            pageRef.getParameters().put('debugStep', debugStep);
        }
        return pageRef;
    }

    private void ensureContextLoaded() {
        if (!contextLoaded) {
            validateEntryAndResolveRedirect(false, false);
        }
    }

    private void resetContext() {
        contactRecord = null;
        requestItemRecord = null;
        hrSupportEmail = null;
        contextLoaded = false;
        displayValuesInitialized = false;
        formValuesInitialized = false;
        displayDataSubjectName = null;
        displayPrincipalName = null;
        displayPassType = null;
        displayIdNumber = null;
        displayPassportNumber = null;
        displayDateOfBirth = null;
        displayNationality = null;
        displayGender = null;
        displayMaritalStatus = null;
        displayRegisteredAddress = null;
        displayReferenceNumber = null;
        displayYourFullName = null;
        resolvedBankName = null;
    }

    private static Boolean matchesContactLifecycleAndStatus(
        Contact sourceContact,
        String lifecycleStage,
        String consentStatus
    ) {
        if (sourceContact == null || String.isBlank(lifecycleStage) || String.isBlank(consentStatus)) {
            return false;
        }

        String actualLifecycle = blankIfNull(getStringFieldValue(
            sourceContact,
            new List<String>{ 'Data_Subject_Lifecycle_Stage__c' }
        ));
        String actualStatus = blankIfNull(sourceContact.Current_Consent_Status__c);
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

    private String resolveContactFieldValue(String fieldApiName, String submittedValue) {
        String cleanedValue = sanitizeSubmittedText(submittedValue);
        if (String.isBlank(cleanedValue)) {
            return null;
        }

        Schema.DescribeFieldResult describe = Contact.SObjectType.getDescribe().fields.getMap().get(fieldApiName).getDescribe();
        if (describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist) {
            String matchedPicklistValue = findMatchingPicklistValue(describe, cleanedValue);
            if (!String.isBlank(matchedPicklistValue)) {
                return matchedPicklistValue;
            }
            return describe.isRestrictedPicklist() ? null : cleanedValue;
        }

        return cleanedValue;
    }

    private String findMatchingPicklistValue(Schema.DescribeFieldResult describe, String submittedValue) {
        if (describe == null || String.isBlank(submittedValue)) {
            return null;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            String entryValue = entry.getValue();
            String entryLabel = entry.getLabel();
            if (!String.isBlank(entryValue) && submittedValue.equalsIgnoreCase(entryValue)) {
                return entryValue;
            }
            if (!String.isBlank(entryLabel) && submittedValue.equalsIgnoreCase(entryLabel)) {
                return entryValue;
            }
        }
        return null;
    }

    private void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || value == null || !hasField(record, fieldApiName)) {
            return;
        }
        try {
            Schema.DescribeFieldResult describe = record.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
            if ((describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist)
                && !isPicklistValueAllowed(describe, String.valueOf(value))) {
                return;
            }
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Ignore optional-field updates to keep flow resilient across org metadata variations.
        }
    }

    private static Boolean isPicklistValueAllowed(Schema.DescribeFieldResult describe, String value) {
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

    private String sanitizeSubmittedText(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String cleaned = value
            .replaceAll('[\\u200B\\u200C\\u200D\\uFEFF\\u2060]', '')
            .replaceAll('\\s+', ' ')
            .trim();
        return String.isBlank(cleaned) ? null : cleaned;
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

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private static String normalizeToken(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }
}