public without sharing class CBS_NonSingpassIdentityInfoController {
    private static final Integer MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;
    private static final Set<String> ALLOWED_EXTENSIONS = new Set<String>{ 'jpg', 'jpeg', 'png', 'pdf' };
    private static final Set<String> TERMINAL_REQUEST_STATUSES = new Set<String>{ 'Submitted', 'Withdrawn', 'Declined', 'Expired' };

    public String requestItemId { get; set; }
    public String token { get; set; }
    public String action { get; set; }
    public String subjectType { get; set; }
    public String entryType { get; set; }
    public String entryAuthType { get; set; }

    public String principalName { get; set; }
    public String passType { get; set; }
    public String passportNumber { get; set; }
    public Date dateOfBirth { get; set; }
    public String nationality { get; set; }
    public String gender { get; set; }
    public String maritalStatus { get; set; }
    public String registeredAddress { get; set; }
    public Boolean declarationInfoAccurate { get; set; }
    public Boolean declarationDocumentConsent { get; set; }

    public Blob passportBody { get; set; }
    public String passportFileName { get; set; }
    public Blob selfieBody { get; set; }
    public String selfieFileName { get; set; }
    @TestVisible
    public String lastErrorDetails { get; private set; }

    private Consent_Request_Item__c requestItemRecord;
    private Contact dataSubjectContact;
    private Boolean isLinkValid;
    private String invalidReason;

    public CBS_NonSingpassIdentityInfoController() {
        requestItemId = ApexPages.currentPage().getParameters().get('requestItemId');
        token = ApexPages.currentPage().getParameters().get('token');
        action = ApexPages.currentPage().getParameters().get('action');
        subjectType = normalizeSubjectType(ApexPages.currentPage().getParameters().get('subjectType'));
        entryType = normalizeSubjectType(ApexPages.currentPage().getParameters().get('type'));
        entryAuthType = normalizeAuthType(ApexPages.currentPage().getParameters().get('authType'));

        declarationInfoAccurate = false;
        declarationDocumentConsent = false;
        loadRequestContext();
    }

    public Boolean getCanRenderForm() {
        return isLinkValid == true;
    }

    public String getPageTitle() {
        return 'Identity Information Page';
    }

    public String getPageDescription() {
        return 'Please provide your identity information below. This information will be used by Credit Bureau Singapore ("CBS") for manual identity verification before your consent can be processed.';
    }

    public String getEmployerOrBankName() {
        String nameFromRequest = getStringFieldValue(requestItemRecord, new List<String>{ 'Client_Name__c', 'Employer_Name__c', 'Bank_Name__c', 'Uploaded_Employer_Name__c' });
        return String.isBlank(nameFromRequest) ? UserInfo.getOrganizationName() : nameFromRequest;
    }

    public String getRequestFullName() {
        if (requestItemRecord != null && !String.isBlank(requestItemRecord.Uploaded_Full_Name__c)) {
            return requestItemRecord.Uploaded_Full_Name__c;
        }
        return dataSubjectContact == null ? '' : blankIfNull(dataSubjectContact.Full_Name__c);
    }

    public String getRequestEmail() {
        String emailFromRequest = getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_Email__c' });
        if (!String.isBlank(emailFromRequest)) {
            return emailFromRequest;
        }
        return dataSubjectContact == null ? '' : blankIfNull(dataSubjectContact.Email);
    }

    public String getRequestIdType() {
        String idTypeFromRequest = getStringFieldValue(requestItemRecord, new List<String>{ 'Uploaded_ID_Type__c' });
        if (!String.isBlank(idTypeFromRequest)) {
            return idTypeFromRequest;
        }
        return dataSubjectContact == null ? '' : blankIfNull(dataSubjectContact.ID_Type__c);
    }

    public String getMaskedIdNumber() {
        String rawId = requestItemRecord == null ? null : requestItemRecord.Uploaded_ID_Number__c;
        if (String.isBlank(rawId) && dataSubjectContact != null) {
            rawId = dataSubjectContact.ID_Number__c;
        }
        return maskIdValue(rawId);
    }

    public String getEmploymentTypeLabel() {
        String fromRequest = getStringFieldValue(requestItemRecord, new List<String>{ 'Subject_Type__c', 'Employment_Type__c' });
        String normalized = normalizeSubjectType(String.isBlank(fromRequest) ? subjectType : fromRequest);
        if (normalized == 'employee') {
            return 'Employee';
        }
        if (normalized == 'prehire') {
            return 'New Hire';
        }
        return '';
    }

    public PageReference continueToConsent() {
        if (!validateLinkBeforeSubmit()) {
            return null;
        }

        if (!validateSubmissionInput()) {
            return null;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Contact contactUpdate = buildContactUpdate();
            Case verificationCase = upsertVerificationCase();
            List<ContentDocumentLink> links = saveSupportingDocuments(verificationCase.Id);
            Consent_Request_Item__c requestUpdate = buildRequestItemUpdate();

            List<SObject> updates = new List<SObject>{ contactUpdate, requestUpdate };
            update updates;
            if (!links.isEmpty()) {
                insert links;
            }

            return buildNextAuthorizationPage();
        } catch (DmlException e) {
            System.debug('DmlException: ' + e.getMessage());
            System.debug('DmlException: ' + e.getStackTraceString());
            System.debug('DmlException: ' + e.getLineNumber());
            Database.rollback(sp);
            lastErrorDetails = e.getMessage();
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'We could not save your identity information. Please try again later.'));
            return null;
        } catch (Exception e) {
            System.debug('DmlException: ' + e.getMessage());
            System.debug('DmlException: ' + e.getStackTraceString());
            System.debug('DmlException: ' + e.getLineNumber());
            Database.rollback(sp);
            lastErrorDetails = e.getMessage();
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'A system error occurred. Please try again later.'));
            return null;
        }
    }

    public PageReference goBack() {
        PageReference pageRef = Page.QRSiteNonSingpassEmployeeImportantNotes;
        copyContextParams(pageRef);
        pageRef.setRedirect(true);
        return pageRef;
    }

    public PageReference cancelFlow() {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Your input was not submitted.'));
        return goBack();
    }

    private void loadRequestContext() {
        requestItemRecord = resolveRequestItem();
        if (requestItemRecord == null) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        dataSubjectContact = loadDataSubjectContact(requestItemRecord.Data_Subject__c);
        if (dataSubjectContact == null) {
            markInvalidLink('The link is invalid or has expired. Please use the latest email link.');
            return;
        }

        String normalizedSubjectType = normalizeSubjectType(subjectType);
        if (String.isBlank(normalizedSubjectType)) {
            normalizedSubjectType = normalizeSubjectType(dataSubjectContact.Employment_Status__c);
            subjectType = normalizedSubjectType;
        }

        if (String.isBlank(normalizedSubjectType)) {
            markInvalidLink('This page is only available for Non-Singpass Employee or New Hire.');
            return;
        }

        if (!isNonSingpassSubjectType(normalizedSubjectType)) {
            markInvalidLink('This page is only available for Non-Singpass Employee or New Hire.');
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

        String currentStatus = requestItemRecord.Current_Status__c;
        if (TERMINAL_REQUEST_STATUSES.contains(currentStatus)) {
            markInvalidLink('This request can no longer be processed because it is already ' + currentStatus.toLowerCase() + '.');
            return;
        }

        String contactConsentStatus = blankIfNull(dataSubjectContact.Current_Consent_Status__c);
        if (contactConsentStatus == 'Authorized') {
            markInvalidLink('You have already completed consent for this request.');
            return;
        }
        if (contactConsentStatus == 'Withdrawn') {
            markInvalidLink('This request can no longer be processed because consent has already been withdrawn.');
            return;
        }
        if (contactConsentStatus == 'Declined') {
            markInvalidLink('This request can no longer be processed because consent has already been declined.');
            return;
        }

        if (isIdentityAlreadySubmitted()) {
            markInvalidLink('Identity information has already been submitted and is pending verification.');
            return;
        }

        prefillIdentityFields();
        isLinkValid = true;
    }

    private Boolean validateLinkBeforeSubmit() {
        if (isLinkValid != true) {
            if (!String.isBlank(invalidReason)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, invalidReason));
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'The link is invalid or has expired.'));
            }
            return false;
        }

        return true;
    }

    private Boolean validateSubmissionInput() {
        Boolean isValid = true;
        if (String.isBlank(principalName)) {
            isValid = addRequiredError('Principal Name / Full Legal Name is required.', isValid);
        }
        if (String.isBlank(passType)) {
            isValid = addRequiredError('Pass Type is required.', isValid);
        }
        if (String.isBlank(passportNumber)) {
            isValid = addRequiredError('Passport Number is required.', isValid);
        }
        if (dateOfBirth == null) {
            isValid = addRequiredError('Date of Birth is required.', isValid);
        }
        if (String.isBlank(nationality)) {
            isValid = addRequiredError('Nationality is required.', isValid);
        }
        if (String.isBlank(gender)) {
            isValid = addRequiredError('Gender is required.', isValid);
        }
        if (String.isBlank(registeredAddress)) {
            isValid = addRequiredError('Registered Address is required.', isValid);
        }
        if (passportBody == null || String.isBlank(passportFileName)) {
            isValid = addRequiredError('Passport Document is required.', isValid);
        } else {
            isValid = validateFileConstraints(passportBody, passportFileName, 'Passport Document', isValid);
        }
        if (selfieBody == null || String.isBlank(selfieFileName)) {
            isValid = addRequiredError('Face ID / Selfie is required.', isValid);
        } else {
            isValid = validateFileConstraints(selfieBody, selfieFileName, 'Face ID / Selfie', isValid);
        }
        if (declarationInfoAccurate != true) {
            isValid = addRequiredError('Please confirm that the provided information is accurate.', isValid);
        }
        if (declarationDocumentConsent != true) {
            isValid = addRequiredError('Please provide consent for document use in identity verification.', isValid);
        }

        return isValid;
    }

    private Boolean validateFileConstraints(Blob fileBody, String fileName, String label, Boolean isValid) {
        String extension = getFileExtension(fileName);
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, label + ' supports JPG, JPEG, PNG or PDF only.'));
            return false;
        }

        Integer fileSize = fileBody == null ? 0 : fileBody.size();
        if (fileSize <= 0 || fileSize > MAX_FILE_SIZE_BYTES) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, label + ' must be greater than 0 and up to 5MB.'));
            return false;
        }

        return isValid;
    }

    private Contact buildContactUpdate() {
        Contact updateContact = new Contact(Id = dataSubjectContact.Id);
        updateContact.Principal_Name__c = sanitizeSubmittedText(principalName);
        updateContact.Pass_Type__c = resolveContactFieldValue('Pass_Type__c', passType);
        updateContact.Passport_Number__c = sanitizeSubmittedText(passportNumber);
        updateContact.Date_of_Birth__c = dateOfBirth;
        updateContact.Nationality__c = resolveContactFieldValue('Nationality__c', nationality);
        updateContact.Gender__c = resolveContactFieldValue('Gender__c', gender);
        updateContact.Marital_Status__c = resolveContactFieldValue('Marital_Status__c', maritalStatus);
        updateContact.Registered_Address__c = sanitizeSubmittedText(registeredAddress);

        setOptionalFieldSafe(updateContact, 'Identity_Info_Submitted_At__c', System.now());
        setOptionalFieldSafe(updateContact, 'Identity_Verification_Status__c', 'Pending');
        return updateContact;
    }

    private Consent_Request_Item__c buildRequestItemUpdate() {
        Consent_Request_Item__c updateRequest = new Consent_Request_Item__c(Id = requestItemRecord.Id);
        setOptionalFieldSafe(updateRequest, 'Identity_Info_Submitted_At__c', System.now());
        setOptionalFieldSafe(updateRequest, 'Identity_Verification_Status__c', 'Pending');

        String nextRequestStatus = choosePendingVerificationStatusValue();
        if (!String.isBlank(nextRequestStatus)) {
            updateRequest.Current_Status__c = nextRequestStatus;
        }
        return updateRequest;
    }

    private List<ContentDocumentLink> saveSupportingDocuments(Id verificationCaseId) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();

        Id passportDocumentId = insertContentVersion('Passport', passportFileName, passportBody, verificationCaseId);
        Id selfieDocumentId = insertContentVersion('FaceID', selfieFileName, selfieBody, verificationCaseId);

        List<Id> parentIds = new List<Id>{ verificationCaseId, dataSubjectContact.Id, requestItemRecord.Id };
        for (Id parentId : parentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = passportDocumentId,
                LinkedEntityId = parentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
            links.add(new ContentDocumentLink(
                ContentDocumentId = selfieDocumentId,
                LinkedEntityId = parentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        return links;
    }

    private Id insertContentVersion(String documentType, String fileName, Blob body, Id verificationCaseId) {
        ContentVersion versionRecord = new ContentVersion();
        versionRecord.Title = documentType + ' - ' + dataSubjectContact.Full_Name__c;
        versionRecord.PathOnClient = fileName;
        versionRecord.VersionData = body;
        versionRecord.Description = 'Manual Identity Verification - ' + documentType + ' - Request Item ' + requestItemRecord.Id;
        insert versionRecord;

        ContentVersion insertedVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
            LIMIT 1
        ];
        return insertedVersion.ContentDocumentId;
    }

    private Case upsertVerificationCase() {
        List<Case> existingCases = [
            SELECT Id, Status, Subject
            FROM Case
            WHERE ContactId = :dataSubjectContact.Id
            AND Subject LIKE :('Manual identity verification required -%')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Case verificationCase = existingCases.isEmpty() ? new Case() : existingCases[0];
        verificationCase.ContactId = dataSubjectContact.Id;
        verificationCase.Subject = 'Manual identity verification required - ' + blankIfNull(dataSubjectContact.Full_Name__c);
        verificationCase.Status = getPreferredCaseStatus();
        verificationCase.Origin = 'Web';
        verificationCase.Description = 'Generated from Non-Singpass Identity Information page submission.';

        setCasePicklistValue(verificationCase, 'Type', new List<String>{ 'Manual Identity Verification', 'Verification', 'Exception' });
        setCasePicklistValue(verificationCase, 'Case_Type__c', new List<String>{ 'Manual Identity Verification', 'Verification', 'Exception' });
        setCasePicklistValue(verificationCase, 'Exception_Type__c', new List<String>{ 'Manual Identity Verification', 'Verification', 'Exception' });
        setOptionalFieldSafe(verificationCase, 'Identity_Verification_Status__c', 'Pending');
        setOptionalFieldSafe(verificationCase, 'Data_Subject__c', dataSubjectContact.Id);
        setOptionalFieldSafe(verificationCase, 'Consent_Request_Item__c', requestItemRecord.Id);

        if (verificationCase.Id == null) {
            insert verificationCase;
        } else {
            update verificationCase;
        }
        return verificationCase;
    }

    private PageReference buildNextAuthorizationPage() {
        String normalizedType = normalizeSubjectType(subjectType);
        String route;
        if (normalizedType == 'employee') {
            route = '/apex/QRSiteNonSingpassConsentForm?stage=pg3';
        } else {
            route = '/apex/QRSiteNonSingpassPrehireConsentForm?stage=pg4';
        }

        route += '&requestItemId=' + EncodingUtil.urlEncode(requestItemRecord.Id, 'UTF-8');
        route += '&ContactId=' + EncodingUtil.urlEncode(String.valueOf(dataSubjectContact.Id), 'UTF-8');
        route += '&subjectType=' + EncodingUtil.urlEncode(normalizedType, 'UTF-8');
        route += '&action=consent';

        PageReference nextPage = new PageReference(route);
        nextPage.setRedirect(true);
        return nextPage;
    }

    private void prefillIdentityFields() {
        principalName = dataSubjectContact.Principal_Name__c;
        passType = dataSubjectContact.Pass_Type__c;
        passportNumber = dataSubjectContact.Passport_Number__c;
        dateOfBirth = dataSubjectContact.Date_of_Birth__c != null ? dataSubjectContact.Date_of_Birth__c : dataSubjectContact.DOB__c;
        nationality = dataSubjectContact.Nationality__c;
        gender = dataSubjectContact.Gender__c;
        maritalStatus = dataSubjectContact.Marital_Status__c;
        registeredAddress = dataSubjectContact.Registered_Address__c;
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
            List<Consent_Request_Item__c> items = [
                SELECT Id, Data_Subject__c, Current_Status__c, Uploaded_Full_Name__c, Uploaded_ID_Number__c
                FROM Consent_Request_Item__c
                WHERE Id = :safeId
                LIMIT 1
            ];
            return items.isEmpty() ? null : items[0];
        } catch (Exception e) {
            return null;
        }
    }

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        Schema.DescribeSObjectResult describeResult = Consent_Request_Item__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
        List<String> tokenCandidates = new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' };
        String tokenField;
        for (String candidate : tokenCandidates) {
            if (fieldMap.containsKey(candidate)) {
                tokenField = candidate;
                break;
            }
        }

        if (String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT Id, Data_Subject__c, Current_Status__c, Uploaded_Full_Name__c, Uploaded_ID_Number__c ' +
            'FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';
        List<SObject> genericResult = Database.query(soql);
        return genericResult.isEmpty() ? null : (Consent_Request_Item__c) genericResult[0];
    }

    private Contact loadDataSubjectContact(Id contactId) {
        if (contactId == null) {
            return null;
        }
        List<Contact> contacts = [
            SELECT Id, Full_Name__c, Email, ID_Type__c, ID_Number__c, Employment_Status__c,
                Principal_Name__c, Pass_Type__c, Passport_Number__c, DOB__c, Date_of_Birth__c,
                Nationality__c, Gender__c, Marital_Status__c, Registered_Address__c, Current_Consent_Status__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        return contacts.isEmpty() ? null : contacts[0];
    }

    private Boolean isExpiredByConfiguredField(SObject requestItem) {
        if (requestItem == null) {
            return true;
        }
        List<String> expiryFieldCandidates = new List<String>{ 'Link_Expires_At__c', 'Expires_At__c', 'Expiry_Date_Time__c', 'Token_Expires_At__c' };
        for (String fieldApi : expiryFieldCandidates) {
            if (hasField(requestItem, fieldApi)) {
                Object rawValue = requestItem.get(fieldApi);
                if (rawValue instanceof Datetime) {
                    return ((Datetime) rawValue) < System.now();
                }
                if (rawValue instanceof Date) {
                    return ((Date) rawValue) < Date.today();
                }
            }
        }
        return false;
    }

    private Boolean isIdentityAlreadySubmitted() {
        List<String> statusFields = new List<String>{ 'Identity_Verification_Status__c', 'Manual_Verification_Status__c' };
        for (String fieldApi : statusFields) {
            String requestValue = getStringFieldValue(requestItemRecord, new List<String>{ fieldApi });
            String contactValue = getStringFieldValue(dataSubjectContact, new List<String>{ fieldApi });
            if (requestValue == 'Pending' || requestValue == 'Passed' || requestValue == 'Clarification Required') {
                return true;
            }
            if (contactValue == 'Pending' || contactValue == 'Passed' || contactValue == 'Clarification Required') {
                return true;
            }
        }

        List<String> submittedAtFields = new List<String>{ 'Identity_Info_Submitted_At__c' };
        for (String fieldApi : submittedAtFields) {
            if (hasField(requestItemRecord, fieldApi) && requestItemRecord.get(fieldApi) != null) {
                return true;
            }
        }
        return false;
    }

    private String choosePendingVerificationStatusValue() {
        Schema.DescribeFieldResult fieldDesc = Consent_Request_Item__c.Current_Status__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldDesc.getPicklistValues();
        List<String> preferred = new List<String>{ 'Pending Verification', 'Pending', 'Sent' };
        for (String candidate : preferred) {
            for (Schema.PicklistEntry entry : entries) {
                if (entry.getValue() == candidate) {
                    return candidate;
                }
            }
        }
        return null;
    }

    private String getPreferredCaseStatus() {
        Schema.DescribeFieldResult statusDesc = Case.Status.getDescribe();
        List<Schema.PicklistEntry> entries = statusDesc.getPicklistValues();
        List<String> preferredValues = new List<String>{ 'New', 'Pending Verification', 'Working' };
        for (String preferred : preferredValues) {
            for (Schema.PicklistEntry entry : entries) {
                if (entry.getValue() == preferred) {
                    return preferred;
                }
            }
        }
        return entries.isEmpty() ? 'New' : entries[0].getValue();
    }

    private void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
        if (record == null || !hasField(record, fieldApiName) || value == null) {
            return;
        }

        try {
            Schema.DescribeFieldResult describe = record.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
            if (describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist) {
                if (!isPicklistValueAllowed(describe, String.valueOf(value))) {
                    return;
                }
            }
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Ignore optional-field failures to keep submission resilient across org metadata variations.
        }
    }

    private Boolean isPicklistValueAllowed(Schema.DescribeFieldResult describe, String value) {
        if (String.isBlank(value)) {
            return false;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    private void setCasePicklistValue(Case caseRecord, String fieldApiName, List<String> preferredValues) {
        if (caseRecord == null || !hasField(caseRecord, fieldApiName)) {
            return;
        }

        try {
            Schema.DescribeFieldResult describe = caseRecord.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
            String selectedValue;
            for (String preferred : preferredValues) {
                if (isPicklistValueAllowed(describe, preferred)) {
                    selectedValue = preferred;
                    break;
                }
            }

            if (String.isBlank(selectedValue) && !describe.getPicklistValues().isEmpty()) {
                selectedValue = describe.getPicklistValues()[0].getValue();
            }

            if (!String.isBlank(selectedValue)) {
                caseRecord.put(fieldApiName, selectedValue);
            }
        } catch (Exception e) {
            // Ignore optional customization failure.
        }
    }

    private Boolean hasField(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) {
            return false;
        }
        return record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private String getStringFieldValue(SObject record, List<String> fieldApiNames) {
        if (record == null || fieldApiNames == null) {
            return null;
        }
        for (String apiName : fieldApiNames) {
            if (hasField(record, apiName)) {
                try {
                    Object value = record.get(apiName);
                    if (value != null) {
                        return String.valueOf(value);
                    }
                } catch (SObjectException e) {
                    // Field exists in schema but was not selected in this query; try next candidate field.
                }
            }
        }
        return null;
    }

    private Boolean addRequiredError(String message, Boolean currentValidity) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, message));
        return false;
    }

    private String getFileExtension(String fileName) {
        if (String.isBlank(fileName) || !fileName.contains('.')) {
            return '';
        }
        return fileName.substringAfterLast('.').toLowerCase();
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
        String normalizedSubmitted = sanitizeSubmittedText(submittedValue);
        if (String.isBlank(normalizedSubmitted)) {
            return null;
        }

        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            String normalizedValue = sanitizeSubmittedText(entry.getValue());
            String normalizedLabel = sanitizeSubmittedText(entry.getLabel());
            if (normalizedSubmitted.equalsIgnoreCase(normalizedValue) || normalizedSubmitted.equalsIgnoreCase(normalizedLabel)) {
                return entry.getValue();
            }
        }

        return null;
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

    private String maskIdValue(String idNumber) {
        if (String.isBlank(idNumber)) {
            return '';
        }
        if (idNumber.length() <= 4) {
            return '****';
        }
        String lastFour = idNumber.right(4);
        return '****' + lastFour;
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
        if (!String.isBlank(entryType)) {
            targetPage.getParameters().put('type', entryType);
        }
        if (!String.isBlank(entryAuthType)) {
            targetPage.getParameters().put('authType', entryAuthType);
        }
        if (requestItemRecord != null && requestItemRecord.Data_Subject__c != null) {
            targetPage.getParameters().put('ContactId', String.valueOf(requestItemRecord.Data_Subject__c));
        }
    }

    private void markInvalidLink(String reason) {
        isLinkValid = false;
        invalidReason = reason;
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, reason));
    }

    private String normalizeSubjectType(String rawType) {
        if (String.isBlank(rawType)) {
            return null;
        }
        String normalized = rawType.trim().toLowerCase();
        if (normalized == 'employee' || normalized == 'existing hire' || normalized == 'existing_hire') {
            return 'employee';
        }
        if (normalized == 'prehire' || normalized == 'pre-hire' || normalized == 'new hire' || normalized == 'new_hire') {
            return 'prehire';
        }
        return normalized;
    }

    private String normalizeAuthType(String rawType) {
        if (String.isBlank(rawType)) {
            return null;
        }
        String normalized = rawType.trim().toLowerCase();
        if (normalized.contains('singpass') && !normalized.contains('non')) {
            return 'singpass';
        }
        if (normalized.contains('non') && normalized.contains('singpass')) {
            return 'nonsingpass';
        }
        if (normalized.contains('manual')) {
            return 'nonsingpass';
        }
        return normalized;
    }

    private Boolean isNonSingpassSubjectType(String normalizedType) {
        return normalizedType == 'employee' || normalizedType == 'prehire';
    }

    private String blankIfNull(String value) {
        return value == null ? '' : value;
    }
}