@isTest
private class QRSiteNonSingpassConsentControllerTest {
    @isTest
    static void formLoadsContactFieldValues() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);

        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();

        System.assertEquals('Test Principal', controller.inputPrincipalName);
        System.assertEquals(getPicklistValue('Contact', 'Pass_Type__c', 0), controller.inputPassType);
        System.assertEquals('P1234567', controller.inputPassportNumber);
        System.assertEquals('Malaysian', controller.inputNationality);
        System.assertEquals('Female', controller.inputGender);
        System.assertEquals(getPicklistValue('Contact', 'Marital_Status__c', 0), controller.inputMaritalStatus);
        System.assertEquals('1 Test Street', controller.inputRegisteredAddress);
        System.assertEquals('15', controller.inputDobDay);
        System.assertEquals('March', controller.inputDobMonth);
        System.assertEquals('1992', controller.inputDobYear);
    }

    @isTest
    static void submitConsentRequiresConsentCheckbox() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);

        Test.startTest();
        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :contact.Id]);
    }

    @isTest
    static void submitConsentRequiresDocuments() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);

        Test.startTest();
        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        controller.hasAcceptedConsent = true;
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertEquals(null, result);
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(messages.size() > 0);
        System.assertEquals(false, controller.passportUploaded);
        System.assertEquals(false, controller.faceIdUploaded);
        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :contact.Id]);
    }

    @isTest
    static void submitConsentCreatesPendingVerificationConsent() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        attachIdentityDocuments(contact, requestItem);
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);

        Test.startTest();
        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        controller.hasAcceptedConsent = true;
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Consent submission should redirect to completion page.');
        System.assert(result.getUrl().contains('completed=true'), 'Completion page redirect expected.');
        System.assert(result.getUrl().contains('completedMode=submitted'));
        System.assertEquals(true, controller.isFinished);

        Consent__c createdConsent = [
            SELECT MyInfo_Name__c, MyInfo_Nationality__c, MyInfo_ID_Number__c,
                MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c, Consent_Status__c, Submitted_At__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertNotEquals(null, createdConsent.Submitted_At__c);
        System.assertNotEquals('Active', createdConsent.Consent_Status__c);
        System.assertEquals('Test Principal', createdConsent.MyInfo_Name__c);
        System.assertEquals('Malaysian', createdConsent.MyInfo_Nationality__c);
        System.assertEquals('P1234567', createdConsent.MyInfo_ID_Number__c);
        System.assertEquals(Date.newInstance(1992, 3, 15), createdConsent.MyInfo_Date_of_Birth__c);
        System.assertEquals('1 Test Street', createdConsent.MyInfo_Residential_Address__c);

        Contact updatedContact = [
            SELECT Principal_Name__c, Pass_Type__c, Passport_Number__c, DOB__c,
                Nationality__c, Gender__c, Marital_Status__c, Registered_Address__c,
                Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Test Principal', updatedContact.Principal_Name__c);
        System.assertEquals(getPicklistValue('Contact', 'Pass_Type__c', 0), updatedContact.Pass_Type__c);
        System.assertEquals('P1234567', updatedContact.Passport_Number__c);
        System.assertEquals(Date.newInstance(1992, 3, 15), updatedContact.DOB__c);
        System.assertEquals('Malaysian', updatedContact.Nationality__c);
        System.assertEquals('Female', updatedContact.Gender__c);
        System.assertEquals(getPicklistValue('Contact', 'Marital_Status__c', 0), updatedContact.Marital_Status__c);
        System.assertEquals('1 Test Street', updatedContact.Registered_Address__c);
        String normalizedContactStatus = updatedContact.Current_Consent_Status__c == null
            ? ''
            : updatedContact.Current_Consent_Status__c.toLowerCase();
        System.assert(
            normalizedContactStatus.contains('pending') || normalizedContactStatus.contains('verification'),
            'Expected pending-verification status but got: ' + updatedContact.Current_Consent_Status__c
        );
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Latest_Submission_Datetime__c')) {
            Contact latestSubmissionCheck = (Contact) Database.query(
                'SELECT Id, Latest_Submission_Datetime__c FROM Contact WHERE Id = \'' + String.escapeSingleQuotes(contact.Id) + '\' LIMIT 1'
            );
            System.assertNotEquals(null, latestSubmissionCheck.get('Latest_Submission_Datetime__c'));
        }

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertNotEquals('Submitted', updatedRequestItem.Current_Status__c);
    }

    @isTest
    static void completionMessageShownForCompletedParameter() {
        Contact contact = createContact();
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('completed', 'true');

        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();

        System.assertEquals(false, controller.getShowConsentForm());
        System.assertEquals(true, controller.getShowCompletionMessage());
    }

    @isTest
    static void controllerHandlesMissingRequestContext() {
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);

        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        System.assertEquals(false, controller.getCanRenderForm());
        System.assertEquals('NAME OF BANK', controller.getBankName());
        System.assertEquals('Not Uploaded', controller.getPassportUploadStatus());
        System.assertEquals('Not Uploaded', controller.getFaceIdUploadStatus());
        System.assertEquals(null, controller.submitConsent());
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void getBankNameUsesUrlAndNavigationKeepsContext() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');
        ApexPages.currentPage().getParameters().put('bankName', 'TEST BANK');

        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        System.assertEquals('TEST BANK', controller.getBankName());
        System.assertEquals(true, controller.getShowDeclineLink());

        PageReference backRef = controller.goBack();
        System.assertNotEquals(null, backRef);
        System.assert(backRef.getUrl().contains('requestItemId=' + requestItem.Id));
        System.assert(backRef.getUrl().contains('subjectType=employee'));

        PageReference declineRef = controller.goToDeclinePage();
        System.assertNotEquals(null, declineRef);
        System.assert(declineRef.getUrl().contains('ContactId=' + contact.Id));
        System.assert(declineRef.getUrl().contains('requestItemId=' + requestItem.Id));
        System.assert(declineRef.getUrl().contains('token=' + ConsentGuestAuthService.getStoredToken(requestItem)));
    }

    @isTest
    static void getBankNameUsesContactAccountNameWhenUrlAbsent() {
        Contact contact = createContact();
        Account employerAccount = new Account(Name = 'CBS Employer Account');
        insert employerAccount;
        contact.AccountId = employerAccount.Id;
        update contact;

        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);

        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        System.assertEquals('CBS Employer Account', controller.getBankName());
    }

    @isTest
    static void controllerRejectsMismatchedContactAndInvalidAction() {
        Contact contact = createContact();
        Contact anotherContact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('ContactId', anotherContact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');

        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        System.assertEquals(false, controller.getCanRenderForm());
        controller.hasAcceptedConsent = true;
        System.assertEquals(null, controller.submitConsent());
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void controllerBlocksTerminalRequestAndExistingConsent() {
        Contact contact = createContact();
        Consent_Request_Item__c submittedRequest = createRequestItem(contact);
        submittedRequest.Current_Status__c = 'Submitted';
        update submittedRequest;

        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(submittedRequest, contact.Id);
        QRSiteNonSingpassConsentController blockedByStatus = new QRSiteNonSingpassConsentController();
        PageReference statusRedirect = blockedByStatus.initPage();
        System.assertNotEquals(null, statusRedirect);
        System.assert(statusRedirect.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
        System.assertEquals(false, blockedByStatus.getCanRenderForm());

        Contact activeConsentContact = createContact();
        Consent_Request_Item__c activeConsentRequest = createRequestItem(activeConsentContact);
        insert new Consent__c(
            Data_Subject__c = activeConsentContact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given',
            MyInfo_Name__c = activeConsentContact.Principal_Name__c
        );

        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(activeConsentRequest, activeConsentContact.Id);
        QRSiteNonSingpassConsentController blockedByActiveConsent = new QRSiteNonSingpassConsentController();
        PageReference activeRedirect = blockedByActiveConsent.initPage();
        System.assertNotEquals(null, activeRedirect);
        System.assert(activeRedirect.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
        System.assertEquals(false, blockedByActiveConsent.getCanRenderForm());
    }

    @isTest
    static void submitConsentRedirectsAlreadyActionedWhenRequestBecomesTerminal() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        attachIdentityDocuments(contact, requestItem);

        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);
        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        controller.hasAcceptedConsent = true;

        requestItem.Current_Status__c = 'Submitted';
        update requestItem;

        PageReference result = controller.submitConsent();
        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void controllerRejectsTamperedToken() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        String validToken = ConsentGuestAuthService.getStoredToken(requestItem);
        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('token', validToken + 'tampered');

        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        System.assertEquals(false, controller.getCanRenderForm());
        System.assertEquals(null, controller.submitConsent());
    }

    @isTest
    static void submitConsentReusesExistingOpenManualVerificationCase() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        attachIdentityDocuments(contact, requestItem);

        Case existingCase = new Case(
            ContactId = contact.Id,
            Subject = 'Manual identity verification required - Existing',
            Origin = 'Web',
            Status = 'New',
            Exception_Type__c = 'File Validation'
        );
        if (Case.SObjectType.getDescribe().fields.getMap().containsKey('Consent_Request_Item__c')) {
            existingCase.put('Consent_Request_Item__c', requestItem.Id);
        }
        insert existingCase;

        Test.setCurrentPage(Page.QRSiteNonSingpassConsentForm);
        setSecureLinkParams(requestItem, contact.Id);

        Test.startTest();
        QRSiteNonSingpassConsentController controller = new QRSiteNonSingpassConsentController();
        controller.hasAcceptedConsent = true;
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertNotEquals(null, result);
        List<Case> manualCases = [
            SELECT Id, Subject
            FROM Case
            WHERE ContactId = :contact.Id
            AND IsClosed = false
            AND Subject LIKE 'Manual identity verification required -%'
        ];
        System.assertEquals(1, manualCases.size(), 'Expected controller to reuse existing open manual verification case.');
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'NonSingpass Test',
            Email = 'nonsingpass.test+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1992, 3, 15),
            DOB__c = Date.newInstance(1992, 3, 15),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'NonSingpass Test',
            ID_Number__c = 'P' + uniqueSuffix.right(7),
            ID_Type__c = 'Passport',
            Portal_Role__c = 'Approver',
            Principal_Name__c = 'Test Principal',
            Pass_Type__c = getPicklistValue('Contact', 'Pass_Type__c', 0),
            Passport_Number__c = 'P1234567',
            Nationality__c = 'Malaysian',
            Gender__c = 'Female',
            Marital_Status__c = getPicklistValue('Contact', 'Marital_Status__c', 0),
            Registered_Address__c = '1 Test Street'
        );
        insert contact;
        return contact;
    }

    private static String getPicklistValue(String objectApiName, String fieldApiName, Integer index) {
        Schema.DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe()
            .get(objectApiName)
            .getDescribe()
            .fields.getMap()
            .get(fieldApiName)
            .getDescribe();
        List<Schema.PicklistEntry> entries = fieldDescribe.getPicklistValues();
        Integer safeIndex = Math.mod(index, entries.size());
        return entries[safeIndex].getValue();
    }

    private static Consent_Request_Item__c createRequestItem(Contact contact) {
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent',
            Uploaded_Full_Name__c = contact.Full_Name__c,
            Uploaded_ID_Number__c = contact.ID_Number__c,
            Uploaded_Date_of_Birth__c = contact.Date_of_Birth__c,
            Uploaded_Email__c = contact.Email,
            Uploaded_ID_Type__c = contact.ID_Type__c
        );
        insert requestItem;
        return requestItem;
    }

    private static void setSecureLinkParams(Consent_Request_Item__c requestItem, Id contactId) {
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', ConsentGuestAuthService.getStoredToken(requestItem));
        if (contactId != null) {
            ApexPages.currentPage().getParameters().put('ContactId', contactId);
        }
    }

    private static void attachIdentityDocuments(Contact contact, Consent_Request_Item__c requestItem) {
        Id passportDocumentId = createContentDocument('Passport - Test User', 'passport.pdf');
        Id faceIdDocumentId = createContentDocument('FaceID - Test User', 'faceid.jpg');

        List<ContentDocumentLink> links = new List<ContentDocumentLink>{
            new ContentDocumentLink(ContentDocumentId = passportDocumentId, LinkedEntityId = requestItem.Id, ShareType = 'V', Visibility = 'AllUsers'),
            new ContentDocumentLink(ContentDocumentId = faceIdDocumentId, LinkedEntityId = requestItem.Id, ShareType = 'V', Visibility = 'AllUsers'),
            new ContentDocumentLink(ContentDocumentId = passportDocumentId, LinkedEntityId = contact.Id, ShareType = 'V', Visibility = 'AllUsers'),
            new ContentDocumentLink(ContentDocumentId = faceIdDocumentId, LinkedEntityId = contact.Id, ShareType = 'V', Visibility = 'AllUsers')
        };
        insert links;
    }

    private static Id createContentDocument(String title, String pathOnClient) {
        ContentVersion versionRecord = new ContentVersion(
            Title = title,
            PathOnClient = pathOnClient,
            VersionData = Blob.valueOf('test file body')
        );
        insert versionRecord;
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
            LIMIT 1
        ].ContentDocumentId;
    }
}