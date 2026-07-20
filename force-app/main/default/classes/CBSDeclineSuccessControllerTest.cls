@isTest
private class CBSDeclineSuccessControllerTest {
    @isTest
    static void initPageShowsErrorWhenContactIdMissing() {
        Test.setCurrentPage(Page.CBSDeclineSuccessPage);

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.isSuccess);
        System.assert(controller.errorMessage.contains('unable to display your declination confirmation'));
    }

    @isTest
    static void initPageShowsErrorWhenContactInvalid() {
        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        ApexPages.currentPage().getParameters().put('contactId', 'not-a-valid-id');

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.isSuccess);
    }

    @isTest
    static void initPageShowsErrorWhenConsentNotDeclined() {
        Account accountRecord = new Account(Name = 'Processing Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact('Processing');
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Processing');

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        ApexPages.currentPage().getParameters().put('contactId', contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItemRecord.Id);

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.isSuccess);
    }

    @isTest
    static void initPageShowsDeclineSuccessSummary() {
        TestData data = createDeclinedScenario();

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        setStandardParams(data);

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isSuccess);
        System.assertEquals(false, controller.showError);
        System.assertEquals('Consent Declined', controller.getPageTitle());
        System.assertEquals('Decline Success Bank Pte Ltd', controller.bankName);
        System.assertEquals('Your decision to decline consent has been recorded.', controller.getStatusMessage());
        System.assertEquals('What this means', controller.getWhatThisMeansTitle());
        System.assertEquals(3, controller.getWhatThisMeansBulletPoints().size());
        System.assert(controller.getWhatThisMeansBulletPoints()[0].contains(data.accountRecord.Name));
        System.assert(controller.getWhatThisMeansBulletPoints()[2].contains('Decline Success Bank Pte Ltd Human Resources'));
        System.assert(controller.getContactParagraphPrefix().contains('Decline Success Bank Pte Ltd Human Resources'));
        System.assertEquals('[BANK HR SUPPORT EMAIL]', controller.getHrSupportEmailDisplay());
        System.assertEquals('Close This Page', controller.getClosePageButtonLabel());
    }

    @isTest
    static void initPageResolvesContactFromReferenceId() {
        TestData data = createDeclinedScenario();

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().remove('contactId');
        ApexPages.currentPage().getParameters().remove('ContactId');
        ApexPages.currentPage().getParameters().remove('requestItemId');
        ApexPages.currentPage().getParameters().put('referenceId', data.requestItemRecord.Id);

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.isSuccess);
        System.assertEquals(String.valueOf(data.contactRecord.Id), controller.contactId);
    }

    @isTest
    static void initPageRedirectsWhenContactAlreadyAuthorized() {
        TestData data = createAuthorizedScenario();

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        setStandardParams(data);

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        PageReference result = controller.initPage();

        System.assert(result.getUrl().contains('/apex/ActiveConsentNotificationPage'));
    }

    @isTest
    static void initPageRedirectsWhenContactAlreadyWithdrawn() {
        TestData data = createWithdrawnScenario();

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        setStandardParams(data);

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        PageReference result = controller.initPage();

        System.assert(result.getUrl().contains('/apex/QRSiteConsentAlreadyActioned'));
    }

    @isTest
    static void initPageProcessesPendingDeclineWhenFallbackEnabled() {
        TestData data = createPendingScenario();

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        setStandardParams(data);

        Test.startTest();
        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        PageReference result = controller.initPage();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isSuccess);

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :data.contactRecord.Id
        ];
        System.assertEquals('Declined', updatedContact.Current_Consent_Status__c);
        System.assertEquals('Consent Declined', updatedContact.Data_Subject_Lifecycle_Stage__c);
    }

    @isTest
    static void initPageShowsFriendlyErrorOnDmlFailure() {
        TestData data = createPendingScenario();

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        setStandardParams(data);

        CBSDeclineSuccessController.simulateDmlFailureForTest = true;
        try {
            CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
            controller.initPage();

            System.assertEquals(true, controller.showError);
            System.assertEquals(
                'We are unable to process your declination at this time. Please contact support.',
                controller.errorMessage
            );
        } finally {
            CBSDeclineSuccessController.simulateDmlFailureForTest = false;
        }
    }

    @isTest
    static void initPageUsesAccountNotificationEmailForHrSupport() {
        TestData data = createDeclinedScenario();
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (accountFields.containsKey('Notification_Email__c')) {
            data.accountRecord.put('Notification_Email__c', 'hr.support@declinebank.example');
            update data.accountRecord;
        }

        Test.setCurrentPage(Page.CBSDeclineSuccessPage);
        setStandardParams(data);

        CBSDeclineSuccessController controller = new CBSDeclineSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.isSuccess);
        if (accountFields.containsKey('Notification_Email__c')) {
            System.assertEquals('hr.support@declinebank.example', controller.getHrSupportEmailDisplay());
            System.assertEquals(true, controller.getShowHrEmailLink());
        } else {
            System.assertEquals('[BANK HR SUPPORT EMAIL]', controller.getHrSupportEmailDisplay());
        }
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
    }

    private static TestData createDeclinedScenario() {
        Account accountRecord = new Account(Name = 'Decline Success Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact('Declined');
        contactRecord.AccountId = accountRecord.Id;
        setOptionalStringField(contactRecord, 'Principal_Name__c', 'Decline Success Test Subject');
        setOptionalDatetimeField(contactRecord, 'Latest_Submission_Datetime__c', System.now());
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Declined');
        Consent__c consentRecord = createDeclinedConsent(contactRecord, requestItemRecord, System.now());
        return new TestData(accountRecord, contactRecord, requestItemRecord, consentRecord);
    }

    private static TestData createPendingScenario() {
        Account accountRecord = new Account(Name = 'Pending Decline Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact('Pending');
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Sent');
        return new TestData(accountRecord, contactRecord, requestItemRecord, null);
    }

    private static TestData createAuthorizedScenario() {
        Account accountRecord = new Account(Name = 'Authorized Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact('Authorized');
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Submitted');
        return new TestData(accountRecord, contactRecord, requestItemRecord, null);
    }

    private static TestData createWithdrawnScenario() {
        Account accountRecord = new Account(Name = 'Withdrawn Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact('Withdrawn');
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Withdrawn');
        return new TestData(accountRecord, contactRecord, requestItemRecord, null);
    }

    private static Contact createContact(String consentStatus) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'Decline Success Test ' + uniqueSuffix,
            Email = 'decline.success+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 15),
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Decline Success Test');
        }
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', 'Existing Hire');
        }

        insert contactRecord;
        return contactRecord;
    }

    private static Consent_Request_Item__c createRequestItem(Contact contactRecord, String status) {
        Consent_Request_Item__c requestItemRecord = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = status,
            Consent_Link_Expires_At__c = System.now().addDays(7)
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItemRecord;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return requestItemRecord;
    }

    private static Consent__c createDeclinedConsent(
        Contact contactRecord,
        Consent_Request_Item__c requestItemRecord,
        Datetime submittedAt
    ) {
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Status__c = 'Declined',
            Submitted_At__c = submittedAt
        );

        Map<String, Schema.SObjectField> consentFields = Consent__c.SObjectType.getDescribe().fields.getMap();
        if (consentFields.containsKey('Consent_Request_Item__c')) {
            consentRecord.put('Consent_Request_Item__c', requestItemRecord.Id);
        }
        if (consentFields.containsKey('Action_Type__c')) {
            consentRecord.put('Action_Type__c', chooseDeclineActionType());
        }

        insert consentRecord;
        return consentRecord;
    }

    private static void setOptionalDatetimeField(Contact contactRecord, String fieldApi, Datetime value) {
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey(fieldApi)) {
            contactRecord.put(fieldApi, value);
        }
    }

    private static void setOptionalStringField(Contact contactRecord, String fieldApi, String value) {
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey(fieldApi)) {
            contactRecord.put(fieldApi, value);
        }
    }

    private static String chooseDeclineActionType() {
        Schema.DescribeFieldResult describe = Consent__c.Action_Type__c.getDescribe();
        List<String> preferredValues = new List<String>{ 'Consent Declined', 'Decline' };
        for (String preferredValue : preferredValues) {
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue() == preferredValue) {
                    return preferredValue;
                }
            }
        }
        return describe.getPicklistValues()[0].getValue();
    }

    private class TestData {
        private Account accountRecord;
        private Contact contactRecord;
        private Consent_Request_Item__c requestItemRecord;
        private Consent__c consentRecord;

        private TestData(
            Account accountRecord,
            Contact contactRecord,
            Consent_Request_Item__c requestItemRecord,
            Consent__c consentRecord
        ) {
            this.accountRecord = accountRecord;
            this.contactRecord = contactRecord;
            this.requestItemRecord = requestItemRecord;
            this.consentRecord = consentRecord;
        }
    }
}