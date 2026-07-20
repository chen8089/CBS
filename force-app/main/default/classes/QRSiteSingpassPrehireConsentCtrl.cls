/**
 * Controller for Singpass Pre-hire Authorisation & Consent Page (Per Report Consent).
 * Guest-accessible via Salesforce Sites / Experience Cloud.
 */
public without sharing class QRSiteSingpassPrehireConsentCtrl {
    private static final String ACTION_AUTHORIZE = 'authorize';
    private static final String TYPE_PREHIRE = 'prehire';
    private static final String AUTH_TYPE_SINGPASS = 'singpass';
    private static final String CONSENT_TYPE_PER_REPORT = 'Per-Report Consent';
    private static final String EMPLOYMENT_STATUS_PREHIRE = 'Pre-hire';

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

    public String contactId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public String entryAction { get; private set; }
    public String entryType { get; private set; }
    public String entryAuthType { get; private set; }
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

    public QRSiteSingpassPrehireConsentCtrl() {
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

    public String getSingpassAuthNotice() {
        return 'You have authenticated via Singpass. Please review the information below and the consent statement before submitting your response.';
    }

    public String getPersonalInfoIntro() {
        return 'The following information has been retrieved or populated for this consent request:';
    }

    public String getConsentCheckboxIntro() {
        return 'By selecting the checkbox and submitting this form, I confirm that:';
    }

    public String getConsentCheckboxText() {
        return 'I explicitly authorise and consent to Credit Bureau (Singapore) Pte Ltd ("CBS") collecting, receiving, using, releasing and disclosing my personal credit information to '
            + getBankName()
            + ' for pre-employment screening / background check purposes.';
    }

    public List<String> getUnderstandingClauses() {
        String bankName = getBankName();
        return new List<String>{
            'CBS may process my personal credit information for the purpose stated above.',
            'CBS may disclose my personal credit information to ' + bankName + ' for pre-employment screening / background check purposes.',
            bankName + ' may submit a credit report request to CBS under this consent while this consent remains valid.',
            'My consent will remain valid for 1 month from the date of submission or until one successful credit report retrieval has been completed, whichever is earlier, unless withdrawn earlier.',
            'I may withdraw my consent at any time by using the withdrawal link provided in the email from ' + bankName + ' Human Resources and authenticating via Singpass.',
            'If I withdraw my consent, ' + bankName + ' will not be able to submit any new credit report request to CBS under this consent.',
            'Withdrawal of consent will not affect any credit report request that was already submitted, processed or completed before the date and time of withdrawal.',
            bankName + ' will be notified of my consent status.'
        };
    }

    public String getDeclarationLine1() {
        return 'I confirm that I have read and understood the above consent and authorisation statement.';
    }

    public String getDeclarationLine2() {
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
                    'Please confirm your authorization and consent before submitting.'
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

    /**
     * Marks an active Pre-hire Per-Report consent as Consumed after a successful credit report retrieval.
     * Wire this into the credit report fulfilment process when available.
     */
    public static void markPrehireConsentConsumedOnReportRetrieval(Id consentRecordId, Id contactRecordId) {
        if (consentRecordId == null && contactRecordId == null) {
            return;
        }

        Consent__c consentUpdate = consentRecordId == null ? null : new Consent__c(Id = consentRecordId);
        if (consentUpdate != null) {
            String consumedStatus = choosePicklistValue(
                Consent__c.Consent_Status__c.getDescribe(),
                new List<String>{ CONTACT_STATUS_CONSUMED, 'Expired' }
            );
            if (!String.isBlank(consumedStatus)) {
                consentUpdate.Consent_Status__c = consumedStatus;
            }
            setOptionalFieldSafe(consentUpdate, 'Latest_Submission_Date_Time__c', System.now());
        }

        Contact contactUpdate = contactRecordId == null ? null : new Contact(Id = contactRecordId);
        if (contactUpdate != null) {
            String contactStatus = choosePicklistValue(
                Contact.Current_Consent_Status__c.getDescribe(),
                new List<String>{ CONTACT_STATUS_CONSUMED, CONTACT_STATUS_EXPIRED }
            );
            if (!String.isBlank(contactStatus)) {
                contactUpdate.Current_Consent_Status__c = contactStatus;
            }
            setOptionalFieldSafe(contactUpdate, 'Latest_Status_Datetime__c', System.now());
        }

        if (consentUpdate != null) {
            update consentUpdate;
        }
        if (contactUpdate != null) {
            update contactUpdate;
        }
    }

    private Consent__c buildConsentRecord(Datetime submittedAt, Date expiryDate) {
        String consentStatus = choosePicklistValue(
            Consent__c.Consent_Status__c.getDescribe(),
            new List<String>{ 'Active', 'Valid' }
        );
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

        MyInfoMatchService.MyInfoSnapshot snapshot = buildMyInfoSnapshot();
        Consent__c newConsent = new Consent__c();
        newConsent.Data_Subject__c = contactRecord.Id;
        newConsent.Consent_Status__c = consentStatus;
        newConsent.Submitted_At__c = submittedAt;
        newConsent.Action_Type__c = actionType;
        newConsent.MyInfo_Name__c = snapshot.principalName;
        newConsent.MyInfo_Nationality__c = snapshot.nationality;
        newConsent.MyInfo_ID_Number__c = snapshot.idNumber;
        newConsent.MyInfo_Date_of_Birth__c = snapshot.dateOfBirth;
        newConsent.MyInfo_Residential_Address__c = snapshot.registeredAddress;
        newConsent.Consent_Expiry_Date__c = expiryDate;

        setOptionalFieldSafe(newConsent, 'Consent_Request_Item__c', requestItemRecord == null ? null : requestItemRecord.Id);
        setOptionalFieldSafe(newConsent, 'Authentication_Type__c', 'Singpass');
        setOptionalFieldSafe(newConsent, 'Latest_Submission_Date_Time__c', submittedAt);
        setOptionalFieldSafe(newConsent, 'Consent_Type__c', CONSENT_TYPE_PER_REPORT);
        setOptionalFieldSafe(newConsent, 'Employment_Status__c', EMPLOYMENT_STATUS_PREHIRE);
        setOptionalFieldSafe(newConsent, 'MyInfo_Pass_Type__c', snapshot.passType);
        setOptionalFieldSafe(newConsent, 'MyInfo_Passport_Number__c', snapshot.passportNumber);
        setOptionalFieldSafe(newConsent, 'MyInfo_Gender__c', snapshot.gender);
        setOptionalFieldSafe(newConsent, 'MyInfo_Marital_Status__c', snapshot.maritalStatus);
        return newConsent;
    }

    private Contact buildContactUpdate(Datetime submittedAt, Date expiryDate) {
        Contact updateContact = new Contact(Id = contactRecord.Id);
        String contactStatus = choosePicklistValue(
            Contact.Current_Consent_Status__c.getDescribe(),
            new List<String>{ CONTACT_STATUS_AUTHORIZED, CONTACT_STATUS_VALID }
        );
        if (!String.isBlank(contactStatus)) {
            updateContact.Current_Consent_Status__c = contactStatus;
        }
        setOptionalFieldSafe(updateContact, 'Current_Consent_Expiry_Date__c', expiryDate);
        setOptionalFieldSafe(updateContact, 'Latest_Submission_Datetime__c', submittedAt);
        setOptionalFieldSafe(updateContact, 'Submitted_Date__c', submittedAt);
        setOptionalFieldSafe(updateContact, 'Consent_Type__c', CONSENT_TYPE_PER_REPORT);
        setOptionalFieldSafe(updateContact, 'Employment_Status__c', EMPLOYMENT_STATUS_PREHIRE);
        setOptionalFieldSafe(
            updateContact,
            'Data_Subject_Lifecycle_Stage__c',
            choosePicklistValue(
                Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(),
                new List<String>{ 'Active Consent' }
            )
        );
        return updateContact;
    }

    private Consent_Request_Item__c buildRequestItemUpdate(Datetime submittedAt) {
        Consent_Request_Item__c updateRequest = new Consent_Request_Item__c(Id = requestItemRecord.Id);
        String submittedStatus = choosePicklistValue(
            Consent_Request_Item__c.Current_Status__c.getDescribe(),
            new List<String>{ REQUEST_STATUS_SUBMITTED }
        );
        if (!String.isBlank(submittedStatus)) {
            updateRequest.Current_Status__c = submittedStatus;
        }
        setOptionalFieldSafe(updateRequest, 'Latest_Submission_Date_Time__c', submittedAt);
        updateRequest.Withdrawal_QR_Viewed_At__c = null;
        return updateRequest;
    }

    private Boolean validatePersonalInformation() {
        Boolean isValid = true;
        if (String.isBlank(principalName)) {
            isValid = addRequiredError('Full Name / Principal Name is required.', isValid);
        }
        if (String.isBlank(idNumber)) {
            isValid = addRequiredError('NRIC / FIN is required.', isValid);
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
        idType = getStringFieldValue(contactRecord, new List<String>{ 'ID_Type__c' });
        gender = getStringFieldValue(contactRecord, new List<String>{ 'Gender__c' });
        idNumber = getStringFieldValue(contactRecord, new List<String>{ 'ID_Number__c', 'NRIC__c', 'FIN__c' });
        maritalStatus = getStringFieldValue(contactRecord, new List<String>{ 'Marital_Status__c' });
        passType = getStringFieldValue(contactRecord, new List<String>{ 'Pass_Type__c' });
        registeredAddress = getStringFieldValue(contactRecord, new List<String>{ 'Registered_Address__c' });
        passportNumber = getStringFieldValue(contactRecord, new List<String>{ 'Passport_Number__c' });
        dateOfBirthDisplay = formatDateOfBirth(resolveDateOfBirth());
    }

    private MyInfoMatchService.MyInfoSnapshot buildMyInfoSnapshot() {
        MyInfoMatchService.MyInfoSnapshot snapshot = new MyInfoMatchService.MyInfoSnapshot();
        snapshot.principalName = principalName;
        snapshot.emailAddress = emailAddress;
        snapshot.nationality = nationality;
        snapshot.idType = idType;
        snapshot.gender = gender;
        snapshot.idNumber = idNumber;
        snapshot.maritalStatus = maritalStatus;
        snapshot.passType = passType;
        snapshot.registeredAddress = registeredAddress;
        snapshot.passportNumber = passportNumber;
        snapshot.dateOfBirth = resolveDateOfBirth();
        return snapshot;
    }

    private PageReference validateEntryAndResolveRedirect() {
        resetContext();

        if (String.isBlank(contactId) || String.isBlank(token)) {
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
        if (!isTokenValidForRequestItem(requestItemRecord, token)) {
            return buildRedirect(PAGE_INVALID_LINK, false);
        }

        if (isRequestItemLinkExpired(requestItemRecord)) {
            return buildRedirect(PAGE_LINK_EXPIRED, false);
        }

        if (!isSingpassPrehireScenario()) {
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
                requestItemId = byId.Id;
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
        List<String> fields = new List<String>{ 'Id', 'Name', 'Email', 'AccountId', 'Account.Name' };
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
            'Current_Consent_Status__c',
            'Current_Consent_Expiry_Date__c',
            'Latest_Submission_Datetime__c',
            'Employment_Status__c',
            'Authentication_Type__c',
            'Consent_Type__c'
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

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.toLowerCase() == right.toLowerCase();
    }
}