@isTest
private class CBSDeclineConsentConfirmCtrlTest {
    @isTest
    static void initPageShowsDeclineFormForValidPendingContact() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        setStandardParams(data);

        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(false, controller.hasError);
        System.assertEquals(data.accountRecord.Name, controller.bankName);
        System.assertEquals('Decline to Give Consent', controller.getPageTitle());
        System.assert(controller.getOpeningStatement().contains(data.accountRecord.Name));
        System.assert(controller.getOpeningStatement().contains('disclose your consumer credit report(s) and/or credit information to'));
        System.assert(controller.getOpeningStatement().contains('EMPLOYMENT-RELATED CREDIT ASSESSMENT / PRE-EMPLOYMENT SCREENING'));
        System.assertEquals('If you confirm that you do not wish to provide your consent:', controller.getConsequencesIntro());
        System.assert(controller.getConsequenceBullet4().contains(data.accountRecord.Name + ' Human Resources'));
        System.assertEquals('To proceed, click the Confirm Decline below.', controller.getProceedInstructionText());
        System.assert(controller.getProceedInstructionHtml().contains('<strong>Confirm Decline</strong>'));
        System.assertEquals('Confirm Decline', controller.getConfirmDeclineButtonLabel());
    }

    @isTest
    static void submitDeclinationUpdatesRecordsAndRedirectsToSuccess() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        setStandardParams(data);

        Test.startTest();
        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        controller.initPage();
        PageReference result = controller.submitDeclination();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSDeclineSuccessPage'));

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c, Declined_Date__c
            FROM Contact
            WHERE Id = :data.contactRecord.Id
        ];
        System.assertEquals('Declined', updatedContact.Current_Consent_Status__c);
        System.assertEquals('Consent Declined', updatedContact.Data_Subject_Lifecycle_Stage__c);
        System.assertNotEquals(null, updatedContact.Declined_Date__c);
    }

    @isTest
    static void initPageShowsErrorForInvalidContactId() {
        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        ApexPages.currentPage().getParameters().put('contactId', 'not-a-valid-id');

        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        PageReference result = controller.initPage();

        System.assertEquals(true, controller.hasError);
        System.assertEquals('Invalid or expired request link.', controller.errorMessage);
    }

    @isTest
    static void initPageShowsDeclineFormWhenContactStatusNullDespiteActiveConsentRecord() {
        TestData data = createValidScenario(null);

        Consent__c activeConsent = new Consent__c(
            Data_Subject__c = data.contactRecord.Id,
            Consent_Status__c = 'Active',
            Action_Type__c = 'Consent Given',
            Submitted_At__c = System.now()
        );
        insert activeConsent;

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        setStandardParams(data);

        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Decline to Give Consent', controller.getPageTitle());
    }

    @isTest
    static void initPageRedirectsWhenContactAlreadyDeclinedWithMatchingLifecycleStage() {
        TestData data = createValidScenario('Declined');
        setLifecycleStage(data.contactRecord, 'Consent Declined');

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        setStandardParams(data);

        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        PageReference result = controller.initPage();

        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void initPageRedirectsWhenPrehireContactAlreadyDeclinedWithMatchingLifecycleStage() {
        TestData data = createValidScenario('Declined');
        setLifecycleStage(data.contactRecord, 'Consent Declined');

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        setStandardParams(data);
        ApexPages.currentPage().getParameters().put('type', 'prehire');

        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        PageReference result = controller.initPage();

        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void initPageShowsDeclineFormWhenDeclinedWithoutMatchingLifecycleStage() {
        TestData data = createValidScenario('Declined');

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        setStandardParams(data);

        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
    }

    @isTest
    static void submitDeclinationShowsFriendlyErrorOnDmlFailure() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        setStandardParams(data);

        CBSDeclineConsentConfirmationController.simulateDmlFailureForTest = true;
        try {
            CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
            controller.initPage();
            PageReference result = controller.submitDeclination();

            System.assertEquals(true, controller.hasError);
            System.assertEquals(
                'We are unable to process your declination at this time. Please contact support.',
                controller.errorMessage
            );
        } finally {
            CBSDeclineConsentConfirmationController.simulateDmlFailureForTest = false;
        }
    }

    @isTest
    static void bankNameFallsBackWhenAccountNameMissing() {
        Contact contactRecord = createContact('Pending');

        Test.setCurrentPage(Page.CBSDeclineConsentConfirmation);
        ApexPages.currentPage().getParameters().put('contactId', contactRecord.Id);

        CBSDeclineConsentConfirmationController controller = new CBSDeclineConsentConfirmationController();
        controller.initPage();

        System.assertEquals('[NAME OF BANK]', controller.bankName);
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
    }

    private static void setLifecycleStage(Contact contactRecord, String lifecycleStage) {
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (!contactFields.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            return;
        }

        contactRecord.put(
            'Data_Subject_Lifecycle_Stage__c',
            choosePicklistValue(
                contactFields.get('Data_Subject_Lifecycle_Stage__c').getDescribe(),
                new List<String>{ lifecycleStage }
            )
        );
        update contactRecord;
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
            Email = 'decline.confirm+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 15),
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus,
            Principal_Name__c = 'Singpass Employee Test'
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Singpass Employee Test');
        }
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', 'Existing Hire');
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
}