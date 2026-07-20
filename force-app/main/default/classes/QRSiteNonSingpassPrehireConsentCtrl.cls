/**
 * Controller for Non-Singpass Pre-hire Authorisation & Consent form.
 * Reuses the same secure-link validation style as other QR site controllers.
 */
public without sharing class QRSiteNonSingpassPrehireConsentCtrl {
    private static final String ACTION_AUTHORIZE = 'authorize';
    private static final String ACTION_CONSENT = 'consent';
    private static final String ACTION_NONPASS_SUBMIT = 'nonpasssubmit';
    private static final String TYPE_PREHIRE = 'prehire';
    private static final String AUTH_TYPE_SINGPASS = 'singpass';
    private static final String AUTH_TYPE_NONSINGPASS = 'nonsingpass';

    private static final String CONTACT_STATUS_VALID = 'Valid';
    private static final String CONTACT_STATUS_AUTHORIZED = 'Authorized';
    private static final String CONTACT_STATUS_DECLINED = 'Declined';
    private static final String CONTACT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String CONTACT_STATUS_EXPIRED = 'Expired';
    private static final String CONTACT_STATUS_CONSUMED = 'Consumed';

    private static final String REQUEST_STATUS_SUBMITTED = 'Submitted';
    private static final String REQUEST_STATUS_DECLINED = 'Declined';
    private static final String REQUEST_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String REQUEST_STATUS_EXPIRED = 'Expired';
    private static final String REQUEST_STATUS_CONSUMED = 'Consumed';

    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_ACTIVE_CONSENT = '/apex/ActiveConsentNotificationPage';
    private static final String PAGE_DECLINE_CONFIRMATION = '/apex/CBSDeclineConsentConfirmation';
    private static final String PAGE_CONSENT_SUCCESS = '/apex/ConsentSuccessPage';

    private static final String CBS_EMAIL_PLACEHOLDER = '[CBS VERIFICATION EMAIL ADDRESS]';

    public String contactId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public String entryAction { get; private set; }
    public String entryType { get; private set; }
    public String entryAuthType { get; private set; }
    public String entrySubjectType { get; private set; }

    public Boolean hasAcceptedConsent { get; set; }
    public Boolean showPage { get; private set; }

    public String principalName { get; private set; }
    public String dateOfBirthDisplay { get; private set; }
    public String emailAddress { get; private set; }
    public String nationality { get; private set; }
    public String idType { get; private set; }
    public String gender { get; private set; }
    public String idNumber { get; private set; }
    public String maritalStatus { get; private set; }
    public String passType { get; private set; }
    public String registeredAddress { get; private set; }
    public String passportNumber { get; private set; }

    private Contact contactRecord;
    private Consent_Request_Item__c requestItemRecord;
    private Boolean contextLoaded = false;

    public QRSiteNonSingpassPrehireConsentCtrl() {
        parseUrlParameters();
        showPage = false;
        hasAcceptedConsent = false;
    }

    public PageReference initPage() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }
            initializeDisplayValues();
            showPage = true;
            return null;
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK, true);
        }
    }

    public Boolean getShowConsentForm() {
        return showPage == true;
    }

    public String getBankName() {
        ensureContextLoaded();
        if (contactRecord == null || contactRecord.Account == null) {
            return 'your employer';
        }
        return String.isBlank(contactRecord.Account.Name) ? 'your employer' : contactRecord.Account.Name;
    }

    public String getCandidateFullName() {
        ensureContextLoaded();
        return firstNonBlank(
            principalName,
            getStringFieldValue(contactRecord, new List<String>{ 'Principal_Name__c', 'Full_Name__c', 'Name' }),
            'Candidate'
        );
    }

    public String getPersonalInfoIntro() {
        return 'The following information has been provided for this consent request:';
    }

    public String getConsentCheckboxIntro() {
        return 'By selecting the checkbox and submitting this form, I confirm that:';
    }

    public String getConsentCheckboxText() {
        return 'I explicitly authorise and consent to Credit Bureau (Singapore) Pte Ltd ("CBS") collecting, receiving, using, releasing and disclosing my personal credit information to '
            + getBankName()
            + ' for pre-employment screening / background check purposes.';
    }

    public String getCbsVerificationEmailAddress() {
        ensureContextLoaded();
        String fromUrl = ApexPages.currentPage().getParameters().get('cbsVerificationEmail');
        if (!String.isBlank(fromUrl)) {
            return fromUrl;
        }

        String fromRequest = getStringFieldValue(
            requestItemRecord,
            new List<String>{ 'CBS_Verification_Email__c', 'Verification_Email__c' }
        );
        if (!String.isBlank(fromRequest)) {
            return fromRequest;
        }

        if (contactRecord != null && contactRecord.Account != null) {
            String fromAccount = getStringFieldValue(
                contactRecord.Account,
                new List<String>{ 'CBS_Verification_Email__c', 'Verification_Email__c' }
            );
            if (!String.isBlank(fromAccount)) {
                return fromAccount;
            }
        }

        // TODO: replace fallback with Custom Label/Custom Metadata source for CBS verification email.
        return CBS_EMAIL_PLACEHOLDER;
    }

    public List<String> getUnderstandingClauses() {
        String bankName = getBankName();
        return new List<String>{
            'CBS may process my personal credit information for the purpose stated above.',
            'CBS may disclose my personal credit information to ' + bankName + ' for pre-employment screening / background check purposes.',
            bankName + ' may submit a credit report request to CBS under this consent only while this consent remains valid and after CBS has completed and approved the required identity verification.',
            'My consent will remain valid for 1 month from the date of submission or until one successful credit report retrieval has been completed, whichever is earlier, unless withdrawn earlier.',
            'I may withdraw my consent at any time by using the withdrawal link provided in the email from ' + bankName + ' Human Resources and completing the required identity verification steps.',
            'If I withdraw my consent, ' + bankName + ' will not be able to submit any new credit report request to CBS under this consent.',
            'Withdrawal of consent will not affect any credit report request that was already submitted, processed or completed before the date and time of withdrawal.',
            bankName + ' will be notified of my consent status.'
        };
    }

    public String getDeclarationLine1() {
        return 'I confirm that I have read and understood the above consent and authorisation statement.';
    }

    public String getDeclarationLine2() {
        return 'I confirm that the information submitted is true, complete and accurate to the best of my knowledge.';
    }

    public String getDeclarationLine3() {
        return 'I confirm that I am voluntarily providing my consent for the stated purpose.';
    }

    public PageReference submitConsent() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            if (hasAcceptedConsent != true) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Please confirm the consent statement before submitting.'
                ));
                showPage = true;
                return null;
            }
            if (!validatePersonalInformation()) {
                showPage = true;
                return null;
            }

            Savepoint savepointBeforeSubmit = Database.setSavepoint();
            try {
                Datetime submittedAt = System.now();
                Date expiryDate = Date.today().addMonths(1);

                Consent__c newConsent = buildConsentRecord(submittedAt, expiryDate);
                if (newConsent == null) {
                    Database.rollback(savepointBeforeSubmit);
                    showPage = true;
                    return null;
                }
                insert newConsent;

                update buildContactUpdate(submittedAt, expiryDate);
                update buildRequestItemUpdate(submittedAt);

                PageReference successPage = buildRedirect(PAGE_CONSENT_SUCCESS, true);
                successPage.getParameters().put('consentId', newConsent.Id);
                return successPage;
            } catch (DmlException e) {
                Database.rollback(savepointBeforeSubmit);
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'We could not submit your consent. Please try again later.'
                ));
                showPage = true;
                return null;
            } catch (Exception e) {
                Database.rollback(savepointBeforeSubmit);
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'A system error occurred. Please try again later.'
                ));
                showPage = true;
                return null;
            }
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK, true);
        }
    }

    public PageReference declineConsent() {
        try {
            PageReference redirect = validateEntryAndResolveRedirect();
            if (redirect != null) {
                redirect.setRedirect(true);
                return redirect;
            }

            PageReference declinePage = buildRedirect(PAGE_DECLINE_CONFIRMATION, true);
            return declinePage;
        } catch (Exception e) {
            return buildRedirect(PAGE_INVALID_LINK, true);
        }
    }

    private Consent__c buildConsentRecord(Datetime submittedAt, Date expiryDate) {
        String consentStatus = choosePicklistValue(
            Consent__c.Consent_Status__c.getDescribe(),
            new List<String>{ 'Pending CBS Verification', 'Processing', 'Pending Verification', 'Verification Pending', 'Pending' }
        );
        if (String.isBlank(consentStatus)) {
            consentStatus = chooseNonActiveFallbackStatus(Consent__c.Consent_Status__c.getDescribe());
        }
        String actionType = choosePicklistValue(
            Consent__c.Action_Type__c.getDescribe(),
            new List<String>{ 'Consent Given', 'Authorize', 'Consent' }
        );
        if (String.isBlank(consentStatus) || String.isBlank(actionType)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Consent status configuration is missing. Please contact CBS support.'
            ));
            return null;
        }

        Consent__c newConsent = new Consent__c();
        newConsent.Data_Subject__c = contactRecord.Id;
        newConsent.Consent_Status__c = consentStatus;
        newConsent.Submitted_At__c = submittedAt;
        newConsent.Action_Type__c = actionType;
        newConsent.MyInfo_Name__c = principalName;
        newConsent.MyInfo_Nationality__c = nationality;
        newConsent.MyInfo_ID_Number__c = idNumber;
        newConsent.MyInfo_Date_of_Birth__c = resolveDateOfBirth();
        newConsent.MyInfo_Residential_Address__c = registeredAddress;
        newConsent.Consent_Expiry_Date__c = expiryDate;

        setOptionalFieldSafe(newConsent, 'Consent_Request_Item__c', requestItemRecord == null ? null : requestItemRecord.Id);
        setOptionalFieldSafe(newConsent, 'Authentication_Type__c', choosePicklistValueForField(Consent__c.SObjectType, 'Authentication_Type__c', new List<String>{ 'Non-Singpass', 'Non Singpass' }));
        setOptionalFieldSafe(newConsent, 'Verification_Status__c', choosePicklistValueForField(Consent__c.SObjectType, 'Verification_Status__c', new List<String>{ 'Pending CBS Verification', 'Pending Verification', 'Verification Pending', 'Pending' }));
        setOptionalFieldSafe(newConsent, 'Latest_Submission_Date_Time__c', submittedAt);
        setOptionalFieldSafe(newConsent, 'Consent_Type__c', choosePicklistValueForField(Consent__c.SObjectType, 'Consent_Type__c', new List<String>{ 'Pre-hire', 'Prehire', 'Per-Report Consent' }));
        setOptionalFieldSafe(newConsent, 'Employment_Status__c', choosePicklistValueForField(Consent__c.SObjectType, 'Employment_Status__c', new List<String>{ 'Pre-hire', 'Prehire', 'New Hire' }));
        setOptionalFieldSafe(newConsent, 'MyInfo_Pass_Type__c', passType);
        setOptionalFieldSafe(newConsent, 'MyInfo_Passport_Number__c', passportNumber);
        setOptionalFieldSafe(newConsent, 'MyInfo_Gender__c', gender);
        setOptionalFieldSafe(newConsent, 'MyInfo_Marital_Status__c', maritalStatus);
        return newConsent;
    }

    private Contact buildContactUpdate(Datetime submittedAt, Date expiryDate) {
        Contact updateContact = new Contact(Id = contactRecord.Id);
        String contactStatus = choosePicklistValue(
            Contact.Current_Consent_Status__c.getDescribe(),
            new List<String>{ 'Processing', 'Pending CBS Verification', 'Pending Verification', 'Pending' }
        );
        if (!String.isBlank(contactStatus)) {
            updateContact.Current_Consent_Status__c = contactStatus;
        }
        setOptionalFieldSafe(updateContact, 'Current_Consent_Expiry_Date__c', expiryDate);
        setOptionalFieldSafe(updateContact, 'Latest_Submission_Datetime__c', submittedAt);
        setOptionalFieldSafe(updateContact, 'Submitted_Date__c', submittedAt);
        setOptionalFieldSafe(updateContact, 'Consent_Type__c', choosePicklistValueForField(Contact.SObjectType, 'Consent_Type__c', new List<String>{ 'Pre-hire', 'Prehire', 'Per-Report Consent' }));
        setOptionalFieldSafe(updateContact, 'Employment_Status__c', choosePicklistValueForField(Contact.SObjectType, 'Employment_Status__c', new List<String>{ 'Pre-hire', 'Prehire', 'New Hire' }));
        setOptionalFieldSafe(updateContact, 'Authentication_Type__c', choosePicklistValueForField(Contact.SObjectType, 'Authentication_Type__c', new List<String>{ 'Non-Singpass', 'Non Singpass' }));
        setOptionalFieldSafe(updateContact, 'Data_Subject_Lifecycle_Stage__c', choosePicklistValueForField(Contact.SObjectType, 'Data_Subject_Lifecycle_Stage__c', new List<String>{ 'Processing', 'Pending Verification', 'Verification Pending' }));
        setOptionalFieldSafe(updateContact, 'Latest_Status_Datetime__c', submittedAt);
        return updateContact;
    }

    private Consent_Request_Item__c buildRequestItemUpdate(Datetime submittedAt) {
        Consent_Request_Item__c updateRequest = new Consent_Request_Item__c(Id = requestItemRecord.Id);
        String pendingStatus = choosePicklistValue(
            Consent_Request_Item__c.Current_Status__c.getDescribe(),
            new List<String>{ 'Pending CBS Verification', 'Pending Verification', 'Verification Pending', 'Processing', 'Pending' }
        );
        if (!String.isBlank(pendingStatus)) {
            updateRequest.Current_Status__c = pendingStatus;
        }
        setOptionalFieldSafe(updateRequest, 'Verification_Status__c', choosePicklistValueForField(Consent_Request_Item__c.SObjectType, 'Verification_Status__c', new List<String>{ 'Pending CBS Verification', 'Pending Verification', 'Verification Pending', 'Pending' }));
        setOptionalFieldSafe(updateRequest, 'Latest_Submission_Date_Time__c', submittedAt);
        updateRequest.Withdrawal_QR_Viewed_At__c = null;
        return updateRequest;
    }

    private Boolean validatePersonalInformation() {
        Boolean isValid = true;
        if (String.isBlank(principalName)) {
            isValid = addRequiredError('Full Name / Principal Name is required.', isValid);
        }
        if (String.isBlank(idType)) {
            isValid = addRequiredError('ID Type is required.', isValid);
        }
        if (String.isBlank(idNumber)) {
            isValid = addRequiredError('ID Number is required.', isValid);
        }
        if (resolveDateOfBirth() == null) {
            isValid = addRequiredError('Date of Birth is required.', isValid);
        }
        if (String.isBlank(emailAddress)) {
            isValid = addRequiredError('Email Address is required.', isValid);
        }
        return isValid;
    }

    private void initializeDisplayValues() {
        principalName = getStringFieldValue(contactRecord, new List<String>{ 'Principal_Name__c', 'Full_Name__c', 'Name' });
        emailAddress = getStringFieldValue(contactRecord, new List<String>{ 'Email' });
        nationality = getStringFieldValue(contactRecord, new List<String>{ 'Nationality__c' });
        idType = firstNonBlank(
            getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_ID_Type__c' }),
            getStringFieldValue(contactRecord, new List<String>{ 'ID_Type__c' })
        );
        gender = getStringFieldValue(contactRecord, new List<String>{ 'Gender__c' });
        idNumber = firstNonBlank(
            getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_ID_Number__c' }),
            getStringFieldValue(contactRecord, new List<String>{ 'ID_Number__c', 'NRIC__c', 'FIN__c' })
        );
        maritalStatus = getStringFieldValue(contactRecord, new List<String>{ 'Marital_Status__c' });
        passType = getStringFieldValue(contactRecord, new List<String>{ 'Pass_Type__c' });
        registeredAddress = getStringFieldValue(contactRecord, new List<String>{ 'Registered_Address__c' });
        passportNumber = getStringFieldValue(contactRecord, new List<String>{ 'Passport_Number__c' });
        dateOfBirthDisplay = formatDateOfBirth(resolveDateOfBirth());
    }

    private PageReference validateEntryAndResolveRedirect() {
        resetContext();

        if (String.isBlank(contactId) || (String.isBlank(token) && String.isBlank(requestItemId))) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        Id parsedContactId = parseId(contactId);
        if (parsedContactId == null) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        contactRecord = queryContact(parsedContactId);
        if (contactRecord == null) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        requestItemRecord = resolveRequestItem(parsedContactId);
        if (requestItemRecord == null) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        if (!isTokenValidForRequestItem(requestItemRecord, token)) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        if (isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED, false);
        }

        if (!isNonSingpassPrehireScenario()) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        PageReference statusRedirect = resolveConsentStatusRedirect(parsedContactId);
        if (statusRedirect != null) {
            return statusRedirect;
        }

        contextLoaded = true;
        return null;
    }

    private PageReference resolveConsentStatusRedirect(Id subjectId) {
        String contactStatus = blankIfNull(contactRecord.Current_Consent_Status__c);
        if (isActiveConsentStatus(contactStatus) || hasActiveConsentRecord(subjectId)) {
            return buildRedirect(PAGE_ACTIVE_CONSENT, false);
        }
        if (contactStatus == CONTACT_STATUS_DECLINED || contactStatus == CONTACT_STATUS_WITHDRAWN) {
            return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
        }
        if (contactStatus == CONTACT_STATUS_EXPIRED || contactStatus == CONTACT_STATUS_CONSUMED) {
            return buildRedirect(
                contactStatus == CONTACT_STATUS_CONSUMED ? PAGE_CONSENT_ALREADY_ACTIONED : PAGE_LINK_EXPIRED,
                false
            );
        }

        if (requestItemRecord != null) {
            String requestStatus = blankIfNull(requestItemRecord.Current_Status__c);
            if (requestStatus == REQUEST_STATUS_SUBMITTED || requestStatus == REQUEST_STATUS_CONSUMED) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
            }
            if (requestStatus == REQUEST_STATUS_DECLINED || requestStatus == REQUEST_STATUS_WITHDRAWN) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
            }
            if (requestStatus == REQUEST_STATUS_EXPIRED) {
                return buildRedirect(PAGE_LINK_EXPIRED, false);
            }
        }

        return null;
    }

    private Boolean isNonSingpassPrehireScenario() {
        String normalizedAction = normalizeToken(entryAction);
        if (!String.isBlank(normalizedAction)
            && normalizedAction != ACTION_AUTHORIZE
            && normalizedAction != ACTION_CONSENT
            && normalizedAction != ACTION_NONPASS_SUBMIT) {
            return false;
        }

        String normalizedType = normalizeToken(entryType);
        if (!String.isBlank(normalizedType) && normalizedType != TYPE_PREHIRE) {
            return false;
        }

        String normalizedSubjectType = normalizeToken(entrySubjectType);
        if (!String.isBlank(normalizedSubjectType) && normalizedSubjectType != TYPE_PREHIRE) {
            return false;
        }

        String authType = normalizeAuthType(firstNonBlank(
            entryAuthType,
            getStringFieldValue(contactRecord, new List<String>{ 'Authentication_Type__c' })
        ));
        if (!String.isBlank(authType) && authType == AUTH_TYPE_SINGPASS) {
            return false;
        }

        String employmentStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        if (!String.isBlank(employmentStatus) && !isPreHireEmploymentStatus(employmentStatus)) {
            return false;
        }

        return true;
    }

    private static String normalizeAuthType(String value) {
        String normalized = normalizeToken(value);
        if (String.isBlank(normalized)) {
            return '';
        }
        if (normalized.contains('singpass') && !normalized.contains('non')) {
            return AUTH_TYPE_SINGPASS;
        }
        if (normalized.contains('non') && normalized.contains('singpass')) {
            return AUTH_TYPE_NONSINGPASS;
        }
        if (normalized.contains('manual')) {
            return AUTH_TYPE_NONSINGPASS;
        }
        return normalized;
    }

    private static Boolean isPreHireEmploymentStatus(String employmentStatus) {
        String normalized = normalizeToken(employmentStatus);
        return normalized == 'pre-hire'
            || normalized == 'pre hire'
            || normalized == 'prehire'
            || normalized == 'new hire'
            || normalized == 'newhire';
    }

    private Boolean isTokenValidForRequestItem(Consent_Request_Item__c requestItem, String tokenValue) {
        if (requestItem == null) {
            return false;
        }
        if (requestItem.Data_Subject__c != null && parseId(contactId) != requestItem.Data_Subject__c) {
            return false;
        }
        if (String.isBlank(tokenValue)) {
            return true;
        }

        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(fieldMap, new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
        if (String.isBlank(tokenField)) {
            return true;
        }

        Object storedToken = requestItem.get(tokenField);
        if (storedToken == null || String.isBlank(String.valueOf(storedToken))) {
            return true;
        }
        return String.valueOf(storedToken) == tokenValue;
    }

    private Consent_Request_Item__c resolveRequestItem(Id subjectId) {
        String requestItemParam = firstNonBlank(
            requestItemId,
            ApexPages.currentPage().getParameters().get('consentRequestItemId')
        );

        if (!String.isBlank(requestItemParam)) {
            Consent_Request_Item__c byId = queryRequestItemById(requestItemParam);
            if (byId != null) {
                requestItemId = byId.Id;
                return byId;
            }
        }

        if (!String.isBlank(token)) {
            Consent_Request_Item__c byToken = queryRequestItemByToken(token);
            if (byToken != null) {
                requestItemId = byToken.Id;
                return byToken;
            }
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
            'Status__c',
            'Uploaded_ID_Type__c',
            'Uploaded_ID_Number__c',
            'CBS_Verification_Email__c',
            'Verification_Email__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        return fields;
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Name', 'Email', 'AccountId', 'Account.Name', 'Current_Consent_Status__c' };
        List<String> optional = new List<String>{
            'Principal_Name__c',
            'Full_Name__c',
            'Date_of_Birth__c',
            'DOB__c',
            'Nationality__c',
            'ID_Type__c',
            'ID_Number__c',
            'NRIC__c',
            'FIN__c',
            'Gender__c',
            'Marital_Status__c',
            'Pass_Type__c',
            'Registered_Address__c',
            'Passport_Number__c',
            'Current_Consent_Expiry_Date__c',
            'Latest_Submission_Datetime__c',
            'Employment_Status__c',
            'Authentication_Type__c',
            'Consent_Type__c'
        };
        for (String candidate : optional) {
            if (contactFields.containsKey(candidate)) {
                fields.add(candidate);
            }
        }

        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (accountFields.containsKey('CBS_Verification_Email__c')) {
            fields.add('Account.CBS_Verification_Email__c');
        }
        if (accountFields.containsKey('Verification_Email__c')) {
            fields.add('Account.Verification_Email__c');
        }

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

    private Date resolveDateOfBirth() {
        if (contactRecord == null) {
            return null;
        }
        Object dateOfBirthValue = getObjectFieldValue(contactRecord, 'Date_of_Birth__c');
        if (dateOfBirthValue instanceof Date) {
            return (Date) dateOfBirthValue;
        }
        Object dobValue = getObjectFieldValue(contactRecord, 'DOB__c');
        if (dobValue instanceof Date) {
            return (Date) dobValue;
        }
        return null;
    }

    private String formatDateOfBirth(Date dateOfBirth) {
        if (dateOfBirth == null) {
            return '';
        }
        return formatDate(dateOfBirth);
    }

    private String formatDate(Date dateValue) {
        if (dateValue == null) {
            return '';
        }
        Datetime dateTimeValue = Datetime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
        return dateTimeValue.format('d MMMM yyyy');
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        token = params.get('token');
        entryAction = blankIfNull(params.get('action'));
        entryType = blankIfNull(params.get('type'));
        entryAuthType = blankIfNull(params.get('authType'));
        entrySubjectType = blankIfNull(params.get('subjectType'));
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
        if (!String.isBlank(entryAction)) {
            targetPage.getParameters().put('action', entryAction);
        } else {
            targetPage.getParameters().put('action', ACTION_CONSENT);
        }
        if (!String.isBlank(entryType)) {
            targetPage.getParameters().put('type', entryType);
        } else {
            targetPage.getParameters().put('type', TYPE_PREHIRE);
        }
        if (!String.isBlank(entryAuthType)) {
            targetPage.getParameters().put('authType', entryAuthType);
        } else {
            targetPage.getParameters().put('authType', AUTH_TYPE_NONSINGPASS);
        }
        if (!String.isBlank(entrySubjectType)) {
            targetPage.getParameters().put('subjectType', entrySubjectType);
        } else {
            targetPage.getParameters().put('subjectType', TYPE_PREHIRE);
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
        if (!contextLoaded) {
            validateEntryAndResolveRedirect();
            if (contactRecord != null) {
                initializeDisplayValues();
            }
            contextLoaded = true;
        }
    }

    private void resetContext() {
        contactRecord = null;
        requestItemRecord = null;
        contextLoaded = false;
    }

    private Boolean addRequiredError(String message, Boolean currentValidity) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, message));
        return false;
    }

    private static void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
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
            // Ignore optional field update failures.
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

    private static String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
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

    private static String choosePicklistValueForField(
        Schema.SObjectType objectType,
        String fieldApiName,
        List<String> preferredValues
    ) {
        if (objectType == null || String.isBlank(fieldApiName)) {
            return null;
        }
        Map<String, Schema.SObjectField> fields = objectType.getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) {
            return null;
        }
        return choosePicklistValue(fields.get(fieldApiName).getDescribe(), preferredValues);
    }

    private static String chooseNonActiveFallbackStatus(Schema.DescribeFieldResult describe) {
        if (describe == null) {
            return null;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            String value = blankIfNull(entry.getValue());
            if (value != 'Active' && value != 'Valid') {
                return value;
            }
        }
        if (!describe.getPicklistValues().isEmpty()) {
            return describe.getPicklistValues()[0].getValue();
        }
        return null;
    }

    private static Boolean isActiveConsentStatus(String statusValue) {
        return statusValue == CONTACT_STATUS_AUTHORIZED || statusValue == CONTACT_STATUS_VALID;
    }

    private static Object getObjectFieldValue(SObject record, String fieldApi) {
        if (record == null || String.isBlank(fieldApi) || !hasField(record, fieldApi)) {
            return null;
        }
        return record.get(fieldApi);
    }

    private static String getStringFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null || fieldCandidates == null) {
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

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        return String.isBlank(thirdValue) ? '' : thirdValue;
    }

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private static String normalizeToken(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }
}