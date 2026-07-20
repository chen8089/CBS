@isTest
private class QRSiteSingpassEmpConsentCtrlTest {
    @isTest
    static void initPageShowsConsentFormForValidLink() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        setStandardParams(data);

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(true, controller.getShowConsentForm());
        System.assertEquals('Singpass Employee Test', controller.principalName);
        System.assertEquals(data.accountRecord.Name, controller.getBankName());
        System.assertEquals(8, controller.getUnderstandingClauses().size());
    }

    @isTest
    static void initPageRedirectsToInvalidLinkWhenTokenMissing() {
        Contact contact = createContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        ApexPages.currentPage().getParameters().put('contactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void submitConsentRequiresCheckbox() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        setStandardParams(data);

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        controller.initPage();
        PageReference result = controller.submitConsent();

        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :data.contactRecord.Id]);
    }

    @isTest
    static void submitConsentShowsValidationErrorsWhenPersonalInfoMissing() {
        TestData data = createValidScenario('Pending');
        update new Contact(
            Id = data.contactRecord.Id,
            Email = null
        );

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        setStandardParams(data);

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        controller.initPage();
        controller.hasAcceptedConsent = true;
        PageReference result = controller.submitConsent();

        System.assertEquals(null, result);
        System.assert(controller.showPage);
        System.assert(ApexPages.getMessages().size() >= 1);
        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :data.contactRecord.Id]);
    }

    @isTest
    static void submitConsentCreatesActiveConsentAndUpdatesContact() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        setStandardParams(data);

        Test.startTest();
        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        controller.initPage();
        controller.hasAcceptedConsent = true;
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/ConsentSuccessPage'));
        System.assertNotEquals(null, result.getParameters().get('consentId'));

        Consent__c createdConsent = [
            SELECT Consent_Status__c, Submitted_At__c, Consent_Expiry_Date__c,
                MyInfo_Name__c, MyInfo_Nationality__c, MyInfo_ID_Number__c,
                MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c
            FROM Consent__c
            WHERE Data_Subject__c = :data.contactRecord.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Active', createdConsent.Consent_Status__c);
        System.assertNotEquals(null, createdConsent.Submitted_At__c);
        System.assertEquals(Date.today().addYears(5), createdConsent.Consent_Expiry_Date__c);
        System.assertEquals('Singpass Employee Test', createdConsent.MyInfo_Name__c);

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Current_Consent_Expiry_Date__c, Latest_Submission_Datetime__c,
                Data_Subject_Lifecycle_Stage__c, Submitted_Date__c
            FROM Contact
            WHERE Id = :data.contactRecord.Id
        ];
        System.assertEquals('Authorized', updatedContact.Current_Consent_Status__c);
        System.assertEquals('Active Consent', updatedContact.Data_Subject_Lifecycle_Stage__c);
        System.assertEquals(Date.today().addYears(5), updatedContact.Current_Consent_Expiry_Date__c);
        System.assertNotEquals(null, updatedContact.Latest_Submission_Datetime__c);
        System.assertNotEquals(null, updatedContact.Submitted_Date__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :data.requestItemRecord.Id
        ];
        System.assertEquals('Submitted', updatedRequestItem.Current_Status__c);
    }

    @isTest
    static void declineConsentRedirectsToDeclineConfirmation() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        setStandardParams(data);

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        controller.initPage();
        PageReference result = controller.declineConsent();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSDeclineConsentConfirmation'));
        System.assertEquals(data.contactRecord.Id, result.getParameters().get('contactId'));
    }

    @isTest
    static void initPageRedirectsToActiveConsentForValidStatus() {
        TestData data = createValidScenario('Authorized');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        setStandardParams(data);

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/ActiveConsentNotificationPage'));
    }

    @isTest
    static void initSuccessPageLoadsSummary() {
        TestData data = createValidScenario('Authorized');
        update new Contact(
            Id = data.contactRecord.Id,
            Latest_Submission_Datetime__c = System.now(),
            Current_Consent_Expiry_Date__c = Date.today().addYears(5)
        );

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentSuccess);
        setStandardParams(data);

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        PageReference result = controller.initSuccessPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Consent Submitted Successfully', controller.getSuccessTitle());
        System.assertEquals(data.accountRecord.Name, controller.employerBankName);
        System.assertNotEquals('', controller.submissionDateTime);
        System.assertNotEquals('', controller.consentExpiryDate);
    }

    @isTest
    static void initSuccessPageRedirectsWhenContactIsInvalid() {
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentSuccess);
        ApexPages.currentPage().getParameters().put('contactId', 'invalid-contact-id');
        ApexPages.currentPage().getParameters().put('token', 'tkn-singpass-001');

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        PageReference result = controller.initSuccessPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageRedirectsWhenRequestLinkIsExpired() {
        TestData data = createValidScenario('Pending');
        update new Consent_Request_Item__c(
            Id = data.requestItemRecord.Id,
            Consent_Link_Expires_At__c = System.now().addDays(-1)
        );

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeConsentForm);
        setStandardParams(data);

        QRSiteSingpassEmpConsentCtrl controller = new QRSiteSingpassEmpConsentCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().contains('/apex/QRSiteInvalidLink'),
            'Expected invalid-link page for expired tokenized URL but got: ' + result.getUrl()
        );
    }

    @isTest
    static void ndiAuthRedirectsToConsentForm() {
        Test.setCurrentPage(Page.ndi_auth);
        ApexPages.currentPage().getParameters().put('contactId', '003000000000001AAA');
        ApexPages.currentPage().getParameters().put('requestItemId', 'a02000000000001AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-emp-001');
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('refId', 'cbs-ref-employee-001');
        Test.setMock(HttpCalloutMock.class, new NdiProfileOnlyMock());

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().contains('/apex/QRSiteSingpassEmployeeConsentForm'),
            'Expected employee form but got: ' + result.getUrl()
        );
        System.assertEquals('003000000000001AAA', result.getParameters().get('contactId'));
        System.assertEquals('true', result.getParameters().get('returnFromAuth'));
    }

    @isTest
    static void declineConfirmationRedirectsToDeclinationComplete() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteDeclineConfirmation);
        ApexPages.currentPage().getParameters().put('contactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItemRecord.Id);
        ApexPages.currentPage().getParameters().put('token', 'tkn-singpass-001');

        QRSiteSingpassEmpDeclineConfirmCtrl controller = new QRSiteSingpassEmpDeclineConfirmCtrl();
        PageReference result = controller.confirmDecline();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteDeclinationComplete'));
        System.assertEquals(data.contactRecord.Id, result.getParameters().get('ContactId'));
    }

    @isTest
    static void declineConfirmationHelpersAndBackNavigationWork() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteDeclineConfirmation);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItemRecord.Id);
        ApexPages.currentPage().getParameters().put('token', 'tkn-singpass-001');

        QRSiteSingpassEmpDeclineConfirmCtrl controller = new QRSiteSingpassEmpDeclineConfirmCtrl();
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Decline to Give Consent', controller.getConfirmationTitle());
        System.assertEquals(data.accountRecord.Name, controller.getBankName());
        System.assertEquals(3, controller.getConfirmationMessageLines().size());

        PageReference backResult = controller.goBackToConsentForm();
        System.assertNotEquals(null, backResult);
        System.assertEquals('authorize', backResult.getParameters().get('action'));
        System.assertEquals('employee', backResult.getParameters().get('type'));
        System.assertEquals('singpass', backResult.getParameters().get('authType'));
    }

    @isTest
    static void declineConfirmationHandlesMissingAndInvalidContact() {
        Test.setCurrentPage(Page.QRSiteDeclineConfirmation);
        QRSiteSingpassEmpDeclineConfirmCtrl missingContactController = new QRSiteSingpassEmpDeclineConfirmCtrl();
        System.assertEquals(false, missingContactController.showPage);
        System.assertEquals('your employer', missingContactController.getBankName());
        System.assertEquals(null, missingContactController.confirmDecline());

        Test.setCurrentPage(Page.QRSiteDeclineConfirmation);
        ApexPages.currentPage().getParameters().put('contactId', 'not-an-id');
        QRSiteSingpassEmpDeclineConfirmCtrl invalidContactController = new QRSiteSingpassEmpDeclineConfirmCtrl();
        System.assertEquals('your employer', invalidContactController.getBankName());
    }

    @isTest
    static void importantNotesContinuePassesReturnUrlToSingpassAuth() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        controller.initPage();
        PageReference result = controller.continueWithSingpass();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().contains('/apex/QRSiteSingpassLogin')
                || result.getUrl().contains('/apex/ndi_auth'),
            'Expected Singpass auth bridge redirect but got: ' + result.getUrl()
        );
        System.assertEquals('/apex/QRSiteSingpassEmployeeConsentForm', result.getParameters().get('returnUrl'));
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
    }

    private static TestData createValidScenario(String consentStatus) {
        Account accountRecord = new Account(Name = 'Sample Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact(consentStatus);
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord);
        return new TestData(accountRecord, contactRecord, requestItemRecord);
    }

    private static Contact createContact(String consentStatus) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'Singpass Employee Test ' + uniqueSuffix,
            Email = 'singpass.employee+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 15),
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus,
            Principal_Name__c = 'Singpass Employee Test',
            Nationality__c = 'Singaporean',
            Gender__c = 'Female',
            Marital_Status__c = getPicklistValue('Contact', 'Marital_Status__c', 0),
            Pass_Type__c = getPicklistValue('Contact', 'Pass_Type__c', 0),
            Registered_Address__c = '1 Test Street, Singapore 123456',
            Passport_Number__c = 'E1234567'
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', 'Existing Hire');
        }
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', 'Singpass');
        }
        if (contactFields.containsKey('Consent_Type__c')) {
            contactRecord.put('Consent_Type__c', 'Term-Based Consent');
        }
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Singpass Employee Test');
        } else {
            contactRecord.LastName = 'Singpass Employee Test ' + uniqueSuffix;
        }

        insert contactRecord;
        return contactRecord;
    }

    private static Consent_Request_Item__c createRequestItem(Contact contactRecord) {
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        Consent_Request_Item__c requestItemRecord = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = 'Sent',
            Consent_Link_Expires_At__c = System.now().addDays(7)
        );

        insert requestItemRecord;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return requestItemRecord;
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

    private class TestData {
        private Account accountRecord;
        private Contact contactRecord;
        private Consent_Request_Item__c requestItemRecord;

        private TestData(
            Account accountRecord,
            Contact contactRecord,
            Consent_Request_Item__c requestItemRecord
        ) {
            this.accountRecord = accountRecord;
            this.contactRecord = contactRecord;
            this.requestItemRecord = requestItemRecord;
        }
    }

    private class NdiProfileOnlyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"myinfo_profile":{"person_info":{"name":{"value":"EMPLOYEE TEST"}}}}');
            return res;
        }
    }
}