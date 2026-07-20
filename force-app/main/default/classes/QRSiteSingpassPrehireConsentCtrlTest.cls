@isTest
private class QRSiteSingpassPrehireConsentCtrlTest {
    @isTest
    static void initPageShowsConsentFormForValidPrehireLink() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(true, controller.getShowConsentForm());
        System.assertEquals('Singpass Prehire Test', controller.principalName);
        System.assertEquals(data.accountRecord.Name, controller.getBankName());
        System.assertEquals('Singpass Prehire Test', controller.getCandidateFullName());
        System.assertEquals(8, controller.getUnderstandingClauses().size());
        System.assert(controller.getConsentCheckboxText().contains('pre-employment screening / background check purposes'));
        System.assert(controller.getUnderstandingClauses()[2].contains('may submit a credit report request'));
        System.assert(controller.getUnderstandingClauses()[3].contains('1 month'));
    }

    @isTest
    static void initPageRedirectsToInvalidLinkWhenTokenMissing() {
        Contact contact = createContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        ApexPages.currentPage().getParameters().put('contactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageRedirectsWhenEmployeeScenarioProvided() {
        TestData data = createValidScenario('Pending');
        Contact employeeLikeContact = new Contact(Id = data.contactRecord.Id);
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Employment_Status__c')) {
            employeeLikeContact.put('Employment_Status__c', 'Existing Hire');
        }
        if (contactFields.containsKey('Consent_Type__c')) {
            employeeLikeContact.put('Consent_Type__c', 'Term-Based Consent');
        }
        update employeeLikeContact;

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void submitConsentRequiresCheckbox() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        controller.initPage();
        PageReference result = controller.submitConsent();

        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :data.contactRecord.Id]);
    }

    @isTest
    static void submitConsentCreatesActiveConsentWithOneMonthExpiry() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        Test.startTest();
        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        controller.initPage();
        controller.hasAcceptedConsent = true;
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/ConsentSuccessPage'));
        System.assertNotEquals(null, result.getParameters().get('consentId'));

        Consent__c createdConsent = [
            SELECT Consent_Status__c, Submitted_At__c, Consent_Expiry_Date__c, MyInfo_Name__c
            FROM Consent__c
            WHERE Data_Subject__c = :data.contactRecord.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Active', createdConsent.Consent_Status__c);
        System.assertNotEquals(null, createdConsent.Submitted_At__c);
        System.assertEquals(Date.today().addMonths(1), createdConsent.Consent_Expiry_Date__c);
        System.assertEquals('Singpass Prehire Test', createdConsent.MyInfo_Name__c);

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Current_Consent_Expiry_Date__c, Latest_Submission_Datetime__c
            FROM Contact
            WHERE Id = :data.contactRecord.Id
        ];
        System.assertEquals('Authorized', updatedContact.Current_Consent_Status__c);
        System.assertEquals(Date.today().addMonths(1), updatedContact.Current_Consent_Expiry_Date__c);
        System.assertNotEquals(null, updatedContact.Latest_Submission_Datetime__c);

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

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        controller.initPage();
        PageReference result = controller.declineConsent();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSDeclineConsentConfirmation'));
        System.assertEquals(data.contactRecord.Id, result.getParameters().get('contactId'));
        System.assertEquals('prehire', result.getParameters().get('type'));
    }

    @isTest
    static void initPageRedirectsToActiveConsentForValidStatus() {
        TestData data = createValidScenario('Authorized');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/ActiveConsentNotificationPage'));
    }

    @isTest
    static void initPageRedirectsWhenRequestLinkIsExpired() {
        TestData data = createValidScenario('Pending');
        update new Consent_Request_Item__c(
            Id = data.requestItemRecord.Id,
            Consent_Link_Expires_At__c = System.now().addDays(-1)
        );

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void ndiAuthRedirectsToPrehireConsentForm() {
        Test.setCurrentPage(Page.ndi_auth);
        ApexPages.currentPage().getParameters().put('contactId', '003000000000001AAA');
        ApexPages.currentPage().getParameters().put('requestItemId', 'a02000000000001AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-prehire-001');
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('returnUrl', '/apex/QRSiteSingpassPrehireConsentForm');
        ApexPages.currentPage().getParameters().put('refId', 'cbs-ref-prehire-001');
        Test.setMock(HttpCalloutMock.class, new NdiProfileOnlyMock());

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().contains('/apex/QRSiteSingpassPrehireConsentForm'),
            'Expected prehire form but got: ' + result.getUrl()
        );
        System.assertEquals('003000000000001AAA', result.getParameters().get('contactId'));
        System.assertEquals('true', result.getParameters().get('returnFromAuth'));
    }

    @isTest
    static void markPrehireConsentConsumedOnReportRetrievalRunsWithoutError() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireConsentForm);
        setStandardParams(data);

        QRSiteSingpassPrehireConsentCtrl controller = new QRSiteSingpassPrehireConsentCtrl();
        controller.initPage();
        controller.hasAcceptedConsent = true;
        PageReference submitResult = controller.submitConsent();
        Id consentId = (Id) submitResult.getParameters().get('consentId');

        Test.startTest();
        QRSiteSingpassPrehireConsentCtrl.markPrehireConsentConsumedOnReportRetrieval(consentId, data.contactRecord.Id);
        Test.stopTest();

        System.assertNotEquals(null, [
            SELECT Id
            FROM Consent__c
            WHERE Id = :consentId
            LIMIT 1
        ].Id);
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('returnUrl', '/apex/QRSiteSingpassPrehireConsentForm');
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
            LastName = 'Singpass Prehire Test ' + uniqueSuffix,
            Email = 'singpass.prehire+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 15),
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus,
            Principal_Name__c = 'Singpass Prehire Test',
            Nationality__c = 'Singaporean',
            Gender__c = 'Female',
            Marital_Status__c = getPicklistValue('Contact', 'Marital_Status__c', 0),
            Pass_Type__c = getPicklistValue('Contact', 'Pass_Type__c', 0),
            Registered_Address__c = '1 Test Street, Singapore 123456',
            Passport_Number__c = 'E1234567'
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', 'Pre-hire');
        }
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', 'Singpass');
        }
        if (contactFields.containsKey('Consent_Type__c')) {
            contactRecord.put('Consent_Type__c', 'Per-Report Consent');
        }
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Singpass Prehire Test');
        }

        insert contactRecord;
        return contactRecord;
    }

    private static Consent_Request_Item__c createRequestItem(Contact contactRecord) {
        Consent_Request_Item__c requestItemRecord = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = 'Sent',
            Consent_Link_Expires_At__c = System.now().addDays(7)
        );

        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
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
            res.setBody('{"myinfo_profile":{"person_info":{"name":{"value":"PREHIRE TEST"}}}}');
            return res;
        }
    }
}