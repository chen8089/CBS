public without sharing class QRSiteNonSingpassConsentController {
    private static final Set<String> TERMINAL_REQUEST_STATUSES = new Set<String>{ 'Submitted', 'Withdrawn', 'Declined', 'Expired' };
    private static final Set<String> TERMINAL_CONTACT_STATUSES = new Set<String>{ 'Authorized', 'Withdrawn', 'Declined' };
    private static final Set<String> BLOCKING_CONSENT_STATUSES = new Set<String>{ 'Active', 'Valid', 'Pending Verification', 'Verification Pending', 'Pending' };
    private static final List<String> BANK_NAME_FIELD_CANDIDATES = new List<String>{ 'Client_Name__c', 'Employer_Name__c', 'Bank_Name__c', 'Uploaded_Employer_Name__c' };
    private static final Boolean ENFORCE_DOCUMENT_UPLOAD_VALIDATION = true;
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';

    public String contactId { get; set; }
    public String requestItemId { get; set; }
    public String token { get; set; }
    public String action { get; set; }
    public String subjectType { get; set; }
    public Boolean isFinished { get; set; }
    public Boolean hasAcceptedConsent { get; set; }
    public String inputPrincipalName { get; set; }
    public String inputPassType { get; set; }
    public String inputPassportNumber { get; set; }
    public String inputNationality { get; set; }
    public String inputGender { get; set; }
    public String inputMaritalStatus { get; set; }
    public String inputRegisteredAddress { get; set; }
    public String inputEmailAddress { get; set; }
    public String inputIdType { get; set; }
    public String inputIdNumber { get; set; }
    public String inputDobDay { get; set; }
    public String inputDobMonth { get; set; }
    public String inputDobYear { get; set; }
    public Boolean passportUploaded { get; set; }
    public Boolean faceIdUploaded { get; set; }

    private Consent_Request_Item__c requestItemRecord;
    private Contact contactRecord;
    private Consent__c latestConsentRecord;
    private Boolean isLinkValid;
    private String invalidReason;
    private PageReference initialRedirect;

    public QRSiteNonSingpassConsentController() {
        requestItemId = ApexPages.currentPage().getParameters().get('requestItemId');
        token = ApexPages.currentPage().getParameters().get('token');
        action = ApexPages.currentPage().getParameters().get('action');
        subjectType = ApexPages.currentPage().getParameters().get('subjectType');
        contactId = ApexPages.currentPage().getParameters().get('ContactId');
        isFinished = false;
        hasAcceptedConsent = false;
        passportUploaded = false;
        faceIdUploaded = false;
        loadRequestContext();
    }

    public PageReference initPage() {
        if (initialRedirect != null) {
            initialRedirect.setRedirect(true);
            return initialRedirect;
        }
        return null;
    }

    public String getBankName() {
        String fromUrl =
            firstNonBlank(
                ApexPages.currentPage().getParameters().get('bankName'),
                ApexPages.currentPage().getParameters().get('employerName'),
                ApexPages.currentPage().getParameters().get('clientName')
            );
        if (!String.isBlank(fromUrl)) {
            return fromUrl;
        }

        String fromContactAccount = getContactAccountName();
        if (!String.isBlank(fromContactAccount)) {
            return fromContactAccount;
        }

        String fromRequest = getStringFieldValue(requestItemRecord, BANK_NAME_FIELD_CANDIDATES);
        return String.isBlank(fromRequest) ? 'NAME OF BANK' : fromRequest;
    }

    public String getCurrentDateString() {
        return Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy, EEEE');
    }

    public Boolean getShowConsentForm() {
        return isFinished != true && ApexPages.currentPage().getParameters().get('completed') != 'true' && isLinkValid == true;
    }

    public Boolean getShowCompletionMessage() {
        return isFinished == true || ApexPages.currentPage().getParameters().get('completed') == 'true';
    }

    public String getCompletionMessageLine1() {
        return 'Authorization and consent submitted successfully.';
    }

    public List<String> getCompletionMessageLines() {
        return new List<String>{
            'Your consent has been received by CBS and is now pending manual identity verification.',
            'Consent will only become valid after CBS verifies your Passport and Face ID documents.',
            'You may now close this page.'
        };
    }

    public String getPassportUploadStatus() {
        return passportUploaded == true ? 'Uploaded' : 'Not Uploaded';
    }

    public String getFaceIdUploadStatus() {
        return faceIdUploaded == true ? 'Uploaded' : 'Not Uploaded';
    }

    public Boolean getCanRenderForm() {
        return isLinkValid == true;
    }

    public Boolean getShowDeclineLink() {
        return getCanRenderForm();
    }

    public PageReference submitConsent() {
        PageReference terminalRedirect = resolveTerminalStatusRedirect(true);
        if (terminalRedirect != null) {
            terminalRedirect.setRedirect(true);
            return terminalRedirect;
        }

        if (!validateLinkBeforeSubmit()) {
            return null;
        }
        if (hasAcceptedConsent != true) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please confirm your authorization and consent before submitting.'));
            return null;
        }
        if (!validateIdentityInfo()) {
            return null;
        }
        if (ENFORCE_DOCUMENT_UPLOAD_VALIDATION && !validateDocumentStatus()) {
            return null;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Datetime submittedAt = System.now();
            Id consentId = ConsentSubmissionService.submitNonSingpassAuthorization(
                requestItemRecord,
                inputPrincipalName,
                inputNationality,
                inputPassportNumber,
                parseInputDateOfBirth(),
                inputRegisteredAddress,
                resolveContactFieldValue('Pass_Type__c', inputPassType),
                inputPassportNumber,
                resolveContactFieldValue('Gender__c', inputGender),
                resolveContactFieldValue('Marital_Status__c', inputMaritalStatus),
                submittedAt
            );
            if (consentId == null) {
                Database.rollback(sp);
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Consent status configuration is missing. Please contact CBS support.'));
                return null;
            }
            try {
                upsertManualVerificationCase();
            } catch (Exception verificationCaseException) {
                // Keep consent submission successful even if downstream manual-verification case automation differs by org.
                // TODO: align verification case required-field mapping for the target org if this warning appears.
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Consent submitted. Manual verification case creation requires additional configuration.'));
            }

            isFinished = true;
            PageReference successPage = Page.QRSiteConsentForm;
            successPage.getParameters().put('completed', 'true');
            successPage.getParameters().put('completedMode', 'submitted');
            copyContextParams(successPage);
            successPage.setRedirect(true);
            return successPage;
        } catch (DmlException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'We could not submit your consent. Please try again later.'));
            return null;
        } catch (Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'A system error occurred. Please try again later.'));
            return null;
        }
    }

    public PageReference goBack() {
        PageReference backPage = Page.CBS_NonSingpassIdentityInfoPage;
        copyContextParams(backPage);
        backPage.setRedirect(true);
        return backPage;
    }

    public PageReference goToDeclinePage() {
        PageReference declinePage = Page.QRSiteDeclinationComplete;
        copyContextParams(declinePage);
        declinePage.setRedirect(true);
        return declinePage;
    }

    private void loadRequestContext() {
        requestItemRecord = resolveRequestItem();
        if (requestItemRecord == null) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        String tokenValue = token;
        if (String.isBlank(tokenValue)) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        Id expectedContactId = parseIdValue(ApexPages.currentPage().getParameters().get('ContactId'));
        if (!ConsentGuestAuthService.isTokenValidForRequestItem(requestItemRecord, tokenValue, expectedContactId)) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        contactId = String.valueOf(requestItemRecord.Data_Subject__c);
        contactRecord = loadDataSubjectContact(requestItemRecord.Data_Subject__c);
        if (contactRecord == null) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        String requestedContact = ApexPages.currentPage().getParameters().get('ContactId');
        if (!String.isBlank(requestedContact) && requestedContact != contactId) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        if (!String.isBlank(action) && action.toLowerCase() != 'consent') {
            markInvalidLink('The link action is invalid for this page.');
            return;
        }

        if (isExpiredByConfiguredField(requestItemRecord)) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        if (resolveTerminalStatusRedirect(false) != null) {
            return;
        }

        initializeFormValues();
        refreshDocumentStatus();
        isLinkValid = true;
    }

    private PageReference resolveTerminalStatusRedirect(Boolean refreshState) {
        if (refreshState == true && requestItemRecord != null) {
            Consent_Request_Item__c latestRequestItem = queryRequestItemById(requestItemRecord.Id);
            if (latestRequestItem != null) {
                requestItemRecord = latestRequestItem;
            }
        }
        if (refreshState == true && contactRecord != null) {
            Contact latestContact = loadDataSubjectContact(contactRecord.Id);
            if (latestContact != null) {
                contactRecord = latestContact;
            }
        }
        if (contactRecord != null) {
            latestConsentRecord = getLatestConsent(contactRecord.Id);
        }

        if (requestItemRecord != null) {
            String requestStatus = blankIfNull(requestItemRecord.Current_Status__c);
            if (TERMINAL_REQUEST_STATUSES.contains(requestStatus)) {
                initialRedirect = buildAlreadyActionedRedirect(requestStatus);
                markInvalidLink('This request can no longer be processed because it is already ' + requestStatus.toLowerCase() + '.');
                return initialRedirect;
            }
        }

        String currentConsentStatus = contactRecord == null ? '' : blankIfNull(contactRecord.Current_Consent_Status__c);
        if (TERMINAL_CONTACT_STATUSES.contains(currentConsentStatus)) {
            initialRedirect = buildAlreadyActionedRedirect(currentConsentStatus);
            markInvalidLink('This request can no longer be processed because consent is already ' + currentConsentStatus.toLowerCase() + '.');
            return initialRedirect;
        }

        if (latestConsentRecord != null && BLOCKING_CONSENT_STATUSES.contains(blankIfNull(latestConsentRecord.Consent_Status__c))) {
            initialRedirect = buildAlreadyActionedRedirect(latestConsentRecord.Consent_Status__c);
            markInvalidLink('A consent record already exists for this request. If required, please use the existing withdrawal flow.');
            return initialRedirect;
        }
        return null;
    }

    private PageReference buildAlreadyActionedRedirect(String statusValue) {
        PageReference pageRef = new PageReference(PAGE_CONSENT_ALREADY_ACTIONED);
        copyContextParams(pageRef);
        if (!String.isBlank(statusValue)) {
            pageRef.getParameters().put('status', statusValue);
        }
        if (String.isBlank(pageRef.getParameters().get('action'))) {
            pageRef.getParameters().put('action', 'consent');
        }
        return pageRef;
    }

    private void initializeFormValues() {
        inputPrincipalName = firstNonBlank(contactRecord.Principal_Name__c, contactRecord.Full_Name__c, getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_Full_Name__c' }));
        inputPassType = blankIfNull(contactRecord.Pass_Type__c);
        inputPassportNumber = blankIfNull(contactRecord.Passport_Number__c);
        inputNationality = blankIfNull(contactRecord.Nationality__c);
        inputGender = blankIfNull(contactRecord.Gender__c);
        inputMaritalStatus = blankIfNull(contactRecord.Marital_Status__c);
        inputRegisteredAddress = blankIfNull(contactRecord.Registered_Address__c);
        inputEmailAddress = firstNonBlank(getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_Email__c' }), contactRecord.Email);
        inputIdType = firstNonBlank(getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_ID_Type__c' }), contactRecord.ID_Type__c);
        inputIdNumber = firstNonBlank(getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_ID_Number__c' }), contactRecord.ID_Number__c, contactRecord.Passport_Number__c);

        Date dateOfBirth = contactRecord.Date_of_Birth__c != null ? contactRecord.Date_of_Birth__c : contactRecord.DOB__c;
        if (dateOfBirth == null && hasField(requestItemRecord, 'Uploaded_Date_of_Birth__c')) {
            Object uploadedDob = requestItemRecord.get('Uploaded_Date_of_Birth__c');
            if (uploadedDob instanceof Date) {
                dateOfBirth = (Date) uploadedDob;
            }
        }
        setInputDateOfBirth(dateOfBirth);
    }

    private Boolean validateLinkBeforeSubmit() {
        if (isLinkValid != true) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, String.isBlank(invalidReason) ? 'The link is invalid or has expired.' : invalidReason));
            return false;
        }
        return true;
    }

    private Boolean validateIdentityInfo() {
        Boolean isValid = true;
        if (String.isBlank(inputPrincipalName)) {
            isValid = addRequiredError('Principal Name / Full Legal Name is required.', isValid);
        }
        if (String.isBlank(inputPassType)) {
            isValid = addRequiredError('Pass Type is required.', isValid);
        }
        if (String.isBlank(inputPassportNumber)) {
            isValid = addRequiredError('Passport Number is required.', isValid);
        }
        if (String.isBlank(inputDobDay) || String.isBlank(inputDobMonth) || String.isBlank(inputDobYear)) {
            isValid = addRequiredError('Date of Birth is required.', isValid);
        }
        if (String.isBlank(inputNationality)) {
            isValid = addRequiredError('Nationality is required.', isValid);
        }
        if (String.isBlank(inputGender)) {
            isValid = addRequiredError('Gender is required.', isValid);
        }
        if (String.isBlank(inputRegisteredAddress)) {
            isValid = addRequiredError('Registered Address is required.', isValid);
        }
        if (String.isBlank(inputEmailAddress)) {
            isValid = addRequiredError('Email Address is required.', isValid);
        }
        if (String.isBlank(inputIdType)) {
            isValid = addRequiredError('ID Type is required.', isValid);
        }
        if (String.isBlank(inputIdNumber)) {
            isValid = addRequiredError('ID Number is required.', isValid);
        }
        return isValid;
    }

    private Boolean validateDocumentStatus() {
        refreshDocumentStatus();
        Boolean isValid = true;
        if (passportUploaded != true) {
            isValid = addRequiredError('Passport document is required before consent submission.', isValid);
        }
        if (faceIdUploaded != true) {
            isValid = addRequiredError('Face ID document is required before consent submission.', isValid);
        }
        return isValid;
    }

    private void refreshDocumentStatus() {
        passportUploaded = false;
        faceIdUploaded = false;
        if (requestItemRecord == null || contactRecord == null) {
            return;
        }

        Set<Id> parentIds = new Set<Id>{ requestItemRecord.Id, contactRecord.Id };
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.LatestPublishedVersion.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :parentIds
        ];

        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink linkRecord : links) {
            if (linkRecord.ContentDocumentId != null) {
                contentDocumentIds.add(linkRecord.ContentDocumentId);
            }
            String titleValue = linkRecord.ContentDocument != null && linkRecord.ContentDocument.LatestPublishedVersion != null
                ? blankIfNull(linkRecord.ContentDocument.LatestPublishedVersion.Title).toLowerCase()
                : '';
            applyDocumentTitleStatus(titleValue);
        }

        if ((passportUploaded != true || faceIdUploaded != true) && !contentDocumentIds.isEmpty()) {
            List<ContentVersion> latestVersions = [
                SELECT Title
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId IN :contentDocumentIds
            ];
            for (ContentVersion versionRecord : latestVersions) {
                applyDocumentTitleStatus(blankIfNull(versionRecord.Title).toLowerCase());
                if (passportUploaded == true && faceIdUploaded == true) {
                    break;
                }
            }
        }
    }

    private void applyDocumentTitleStatus(String titleValue) {
        if (String.isBlank(titleValue)) {
            return;
        }
        if (titleValue.contains('passport')) {
            passportUploaded = true;
        }
        if (titleValue.contains('faceid') || titleValue.contains('face id') || titleValue.contains('selfie')) {
            faceIdUploaded = true;
        }
    }

    private void upsertManualVerificationCase() {
        Case verificationCase = findExistingManualVerificationCase();
        if (verificationCase == null) {
            verificationCase = new Case();
        }
        verificationCase.ContactId = contactRecord.Id;
        verificationCase.Subject = 'Manual identity verification required - ' + blankIfNull(contactRecord.Full_Name__c);
        verificationCase.Origin = 'Web';
        verificationCase.Description = 'Generated from Non-Singpass Authorization & Consent submission.';
        verificationCase.Status = choosePicklistValue(Case.Status.getDescribe(), new List<String>{ 'New', 'Pending Verification', 'Working' });
        setOptionalFieldSafe(verificationCase, 'Identity_Verification_Status__c', 'Pending');
        setOptionalFieldSafe(verificationCase, 'Data_Subject__c', contactRecord.Id);
        setOptionalFieldSafe(verificationCase, 'Consent_Request_Item__c', requestItemRecord.Id);
        // TODO: populate project-specific Verification/Exception object fields if Case is not the primary process object in target org.

        if (verificationCase.Id == null) {
            insert verificationCase;
        } else {
            update verificationCase;
        }
    }

    private Case findExistingManualVerificationCase() {
        if (contactRecord == null || contactRecord.Id == null) {
            return null;
        }
        Map<String, Schema.SObjectField> caseFields = Case.SObjectType.getDescribe().fields.getMap();
        Boolean hasRequestItemLookup = caseFields.containsKey('Consent_Request_Item__c');
        Id targetRequestItemId = requestItemRecord == null ? null : requestItemRecord.Id;

        String subjectPrefix = 'Manual identity verification required -%';
        String soql = 'SELECT Id, Status, Subject';
        if (hasRequestItemLookup) {
            soql += ', Consent_Request_Item__c';
        }
        soql += ' FROM Case WHERE ContactId = :contactIdValue';
        soql += ' AND IsClosed = false';
        soql += ' AND Subject LIKE :subjectPrefix';
        soql += ' ORDER BY CreatedDate DESC';
        soql += ' LIMIT 20';

        Id contactIdValue = contactRecord.Id;
        List<SObject> candidateRows = Database.query(soql);
        if (candidateRows.isEmpty()) {
            return null;
        }
        if (!hasRequestItemLookup || targetRequestItemId == null) {
            return (Case) candidateRows[0];
        }
        for (SObject row : candidateRows) {
            Object rowRequestItemId = row.get('Consent_Request_Item__c');
            if (rowRequestItemId != null && (Id) rowRequestItemId == targetRequestItemId) {
                return (Case) row;
            }
        }
        return null;
    }

    private Consent_Request_Item__c resolveRequestItem() {
        if (!String.isBlank(requestItemId)) {
            return queryRequestItemById(requestItemId);
        }
        if (!String.isBlank(token)) {
            return queryRequestItemByToken(token);
        }
        return null;
    }

    private Consent_Request_Item__c queryRequestItemById(String rawId) {
        try {
            Id safeId = (Id) rawId;
            List<SObject> rows = Database.query('SELECT ' + String.join(getRequestItemSelectFields(), ',') + ' FROM Consent_Request_Item__c WHERE Id = :safeId LIMIT 1');
            return rows.isEmpty() ? null : (Consent_Request_Item__c) rows[0];
        } catch (Exception e) {
            return null;
        }
    }

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        String tokenField = findFirstExistingField(Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap(), new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
        if (String.isBlank(tokenField)) {
            return null;
        }
        String soql = 'SELECT ' + String.join(getRequestItemSelectFields(), ',') + ' FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : (Consent_Request_Item__c) rows[0];
    }

    private List<String> getRequestItemSelectFields() {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        List<String> baseFields = new List<String>{
            'Id',
            'Data_Subject__c',
            'Current_Status__c',
            'Uploaded_Full_Name__c',
            'Uploaded_ID_Number__c',
            'Uploaded_Date_of_Birth__c',
            'Withdrawal_QR_Viewed_At__c'
        };
        List<String> optionalFields = new List<String>{
            'Uploaded_Email__c',
            'Uploaded_ID_Type__c',
            'Client_Name__c',
            'Employer_Name__c',
            'Bank_Name__c',
            'Uploaded_Employer_Name__c',
            'Link_Expires_At__c',
            'Expires_At__c',
            'Expiry_Date_Time__c',
            'Token_Expires_At__c',
            'Identity_Verification_Status__c',
            'Manual_Verification_Status__c',
            'Identity_Info_Submitted_At__c'
        };

        for (String apiName : optionalFields) {
            if (fieldMap.containsKey(apiName)) {
                baseFields.add(apiName);
            }
        }
        return baseFields;
    }

    private Contact loadDataSubjectContact(Id subjectContactId) {
        if (subjectContactId == null) {
            return null;
        }
        List<Contact> contacts = [
            SELECT Id, Full_Name__c, Email, ID_Type__c, ID_Number__c, Principal_Name__c, Pass_Type__c,
                Passport_Number__c, DOB__c, Date_of_Birth__c, Nationality__c, Gender__c,
                Marital_Status__c, Registered_Address__c, Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c,
                AccountId, Account.Name
            FROM Contact
            WHERE Id = :subjectContactId
            LIMIT 1
        ];
        return contacts.isEmpty() ? null : contacts[0];
    }

    private String getContactAccountName() {
        if (contactRecord == null || contactRecord.Account == null) {
            return null;
        }
        return contactRecord.Account.Name;
    }

    private Consent__c getLatestConsent(Id subjectId) {
        if (subjectId == null) {
            return null;
        }
        List<Consent__c> rows = [
            SELECT Id, Consent_Status__c
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private Boolean isExpiredByConfiguredField(SObject requestItem) {
        if (requestItem == null) {
            return true;
        }
        List<String> expiryFieldCandidates = new List<String>{ 'Link_Expires_At__c', 'Expires_At__c', 'Expiry_Date_Time__c', 'Token_Expires_At__c' };
        for (String fieldApi : expiryFieldCandidates) {
            if (hasField(requestItem, fieldApi)) {
                Object rawValue = requestItem.get(fieldApi);
                if (rawValue instanceof Datetime && ((Datetime) rawValue) < System.now()) {
                    return true;
                }
                if (rawValue instanceof Date && ((Date) rawValue) < Date.today()) {
                    return true;
                }
            }
        }
        return false;
    }

    private void setInputDateOfBirth(Date dateOfBirth) {
        if (dateOfBirth == null) {
            return;
        }
        inputDobDay = leftPad(String.valueOf(dateOfBirth.day()), 2);
        inputDobMonth = getMonthName(dateOfBirth.month());
        inputDobYear = String.valueOf(dateOfBirth.year());
    }

    private Date parseInputDateOfBirth() {
        if (String.isBlank(inputDobDay) || String.isBlank(inputDobMonth) || String.isBlank(inputDobYear)) {
            return null;
        }
        Integer day = Integer.valueOf(inputDobDay);
        Integer month = getMonthNumber(inputDobMonth);
        Integer year = Integer.valueOf(inputDobYear);
        return Date.newInstance(year, month, day);
    }

    private Integer getMonthNumber(String monthValue) {
        List<String> monthNames = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        for (Integer index = 0; index < monthNames.size(); index++) {
            if (monthNames[index].equalsIgnoreCase(blankIfNull(monthValue).trim())) {
                return index + 1;
            }
        }
        return Integer.valueOf(monthValue);
    }

    private String getMonthName(Integer monthNumber) {
        List<String> monthNames = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        return monthNames[monthNumber - 1];
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }
        if (!String.isBlank(action)) {
            targetPage.getParameters().put('action', action);
        }
        if (!String.isBlank(subjectType)) {
            targetPage.getParameters().put('subjectType', subjectType);
        }
        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('ContactId', contactId);
        }
    }

    private String resolveContactFieldValue(String fieldApiName, String submittedValue) {
        String cleanedValue = sanitizeSubmittedText(submittedValue);
        if (String.isBlank(cleanedValue)) {
            return null;
        }
        Schema.DescribeFieldResult describe = Contact.SObjectType.getDescribe().fields.getMap().get(fieldApiName).getDescribe();
        if (describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist) {
            String matchedPicklistValue = choosePicklistValue(describe, new List<String>{ cleanedValue });
            if (!String.isBlank(matchedPicklistValue)) {
                return matchedPicklistValue;
            }
            return describe.isRestrictedPicklist() ? null : cleanedValue;
        }
        return cleanedValue;
    }

    private void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || value == null || !hasField(record, fieldApiName)) {
            return;
        }
        try {
            Schema.DescribeFieldResult describe = record.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
            if ((describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist) && !isPicklistValueAllowed(describe, String.valueOf(value))) {
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

    private String chooseNonActiveFallbackStatus(Schema.DescribeFieldResult describe) {
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

    private String getStringFieldValue(SObject record, List<String> fieldApiNames) {
        if (record == null || fieldApiNames == null) {
            return null;
        }
        for (String apiName : fieldApiNames) {
            if (!hasField(record, apiName)) {
                continue;
            }
            try {
                Object raw = record.get(apiName);
                if (raw != null) {
                    return String.valueOf(raw);
                }
            } catch (Exception e) {
                // Ignore inaccessible optional fields.
            }
        }
        return null;
    }

    private Boolean hasField(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) {
            return false;
        }
        return record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private String findFirstExistingField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        if (fieldMap == null || candidates == null) {
            return null;
        }
        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private Id parseIdValue(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            return (Id) rawValue;
        } catch (Exception e) {
            return null;
        }
    }

    private Boolean addRequiredError(String message, Boolean currentValidity) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, message));
        return false;
    }

    private String sanitizeSubmittedText(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String cleaned = value.replaceAll('[\\u200B\\u200C\\u200D\\uFEFF\\u2060]', '').replaceAll('\\s+', ' ').trim();
        return String.isBlank(cleaned) ? null : cleaned;
    }

    private String firstNonBlank(String value1, String value2, String value3) {
        if (!String.isBlank(value1)) {
            return value1;
        }
        if (!String.isBlank(value2)) {
            return value2;
        }
        return String.isBlank(value3) ? '' : value3;
    }

    private String firstNonBlank(String value1, String value2) {
        return firstNonBlank(value1, value2, null);
    }

    private String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private void markInvalidLink(String reason) {
        isLinkValid = false;
        invalidReason = reason;
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, reason));
    }

    private String leftPad(String value, Integer targetLength) {
        String result = value;
        while (result.length() < targetLength) {
            result = '0' + result;
        }
        return result;
    }
}