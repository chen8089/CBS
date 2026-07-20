@isTest
private class CBSWithdrawSuccessControllerTest {
    @isTest
    static void initPageShowsErrorWhenContactIdMissing() {
        Test.setCurrentPage(Page.CBSWithdrawSuccessPage);

        CBSWithdrawSuccessController controller = new CBSWithdrawSuccessController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showSuccess);
        System.assert(controller.errorMessage.contains('unable to display the withdrawal confirmation'));
    }

    @isTest
    static void initPageShowsErrorWhenContactInvalid() {
        Test.setCurrentPage(Page.CBSWithdrawSuccessPage);
        ApexPages.currentPage().getParameters().put('contactId', 'not-a-valid-id');

        CBSWithdrawSuccessController controller = new CBSWithdrawSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showSuccess);
    }

    @isTest
    static void initPageShowsErrorWhenConsentNotWithdrawn() {
        TestData data = createActiveScenario();

        Test.setCurrentPage(Page.CBSWithdrawSuccessPage);
        ApexPages.currentPage().getParameters().put('contactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('consentId', data.consentRecord.Id);

        CBSWithdrawSuccessController controller = new CBSWithdrawSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showSuccess);
    }

    @isTest
    static void initPageShowsWithdrawalSuccessSummary() {
        TestData data = createWithdrawnScenario();

        Test.setCurrentPage(Page.CBSWithdrawSuccessPage);
        setStandardParams(data);

        CBSWithdrawSuccessController controller = new CBSWithdrawSuccessController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showSuccess);
        System.assertEquals(false, controller.showError);
        System.assertEquals('Withdrawal Submitted Successfully', controller.getPageTitle());
        System.assert(controller.getSuccessIntroText().contains('Your withdrawal request has been submitted successfully'));
        System.assertEquals('What happens next', controller.getWhatHappensNextTitle());
        System.assert(controller.getSingpassWithdrawalText().contains('consent status will be updated directly'));
        System.assert(controller.getManualVerificationWithdrawalTextBeforeEmail().contains('non-Singpass users'));
        System.assertEquals('privacy@creditbureau.com.sg', controller.getPrivacyEmailAddress());
        System.assert(controller.getManualVerificationWithdrawalTextAfterEmail().contains('consent withdrawal status'));
        System.assertEquals('Close This Page', controller.getClosePageButtonLabel());
    }

    @isTest
    static void initPageResolvesContactFromConsentId() {
        TestData data = createWithdrawnScenario();

        Test.setCurrentPage(Page.CBSWithdrawSuccessPage);
        ApexPages.currentPage().getParameters().put('consentId', data.consentRecord.Id);

        CBSWithdrawSuccessController controller = new CBSWithdrawSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showSuccess);
        System.assertEquals(String.valueOf(data.contactRecord.Id), controller.contactId);
    }

    @isTest
    static void initPageResolvesContactFromReferenceId() {
        TestData data = createWithdrawnScenario();

        Test.setCurrentPage(Page.CBSWithdrawSuccessPage);
        ApexPages.currentPage().getParameters().put('referenceId', data.requestItemRecord.Id);

        CBSWithdrawSuccessController controller = new CBSWithdrawSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showSuccess);
        System.assertEquals(String.valueOf(data.contactRecord.Id), controller.contactId);
    }

    @isTest
    static void initPageUsesPlaceholderWhenOptionalFieldsMissing() {
        Contact contactRecord = createContact('Withdrawn', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Withdrawn');
        Consent__c consentRecord = createWithdrawnConsent(contactRecord, requestItemRecord, null);

        Test.setCurrentPage(Page.CBSWithdrawSuccessPage);
        ApexPages.currentPage().getParameters().put('contactId', contactRecord.Id);
        ApexPages.currentPage().getParameters().put('consentId', consentRecord.Id);

        CBSWithdrawSuccessController controller = new CBSWithdrawSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showSuccess);
        System.assertEquals('-', controller.employerBankName);
        System.assertEquals('-', controller.withdrawalDateTime);
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().put('consentId', data.consentRecord.Id);
    }

    private static TestData createWithdrawnScenario() {
        Account accountRecord = new Account(Name = 'Withdraw Success Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact('Withdrawn', 'Singpass', 'Existing Hire');
        contactRecord.AccountId = accountRecord.Id;
        setOptionalStringField(contactRecord, 'Principal_Name__c', 'Withdrawal Test Subject');
        setOptionalDatetimeField(contactRecord, 'Withdrawal_Datetime__c', System.now());
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Withdrawn');
        Consent__c consentRecord = createWithdrawnConsent(contactRecord, requestItemRecord, System.now());
        return new TestData(accountRecord, contactRecord, requestItemRecord, consentRecord);
    }

    private static TestData createActiveScenario() {
        Account accountRecord = new Account(Name = 'Active Consent Bank');
        insert accountRecord;

        Contact contactRecord = createContact('Authorized', 'Singpass', 'Existing Hire');
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Submitted');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItemRecord);
        return new TestData(accountRecord, contactRecord, requestItemRecord, consentRecord);
    }

    private static Contact createContact(
        String consentStatus,
        String authType,
        String employmentStatus
    ) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'Withdraw Success Test ' + uniqueSuffix,
            Email = 'withdraw.success+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1991, 6, 3),
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', authType);
        }
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', employmentStatus);
        }
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Withdraw Success Test');
        }

        insert contactRecord;
        return contactRecord;
    }

    private static Consent_Request_Item__c createRequestItem(Contact contactRecord, String status) {
        Consent_Request_Item__c requestItemRecord = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = status
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItemRecord;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return requestItemRecord;
    }

    private static Consent__c createActiveConsent(
        Contact contactRecord,
        Consent_Request_Item__c requestItemRecord
    ) {
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Consent_Expiry_Date__c = Date.today().addYears(5)
        );

        Map<String, Schema.SObjectField> consentFields = Consent__c.SObjectType.getDescribe().fields.getMap();
        if (consentFields.containsKey('Consent_Request_Item__c')) {
            consentRecord.put('Consent_Request_Item__c', requestItemRecord.Id);
        }
        if (consentFields.containsKey('Action_Type__c')) {
            consentRecord.put('Action_Type__c', chooseActionType());
        }

        insert consentRecord;
        return consentRecord;
    }

    private static Consent__c createWithdrawnConsent(
        Contact contactRecord,
        Consent_Request_Item__c requestItemRecord,
        Datetime revokedAt
    ) {
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Status__c = 'Withdrawn',
            Submitted_At__c = System.now().addDays(-1),
            Consent_Expiry_Date__c = Date.today().addYears(5),
            Revoked_At__c = revokedAt,
            Action_Type__c = 'Consent Withdrawn',
            Withdrawn_By_Client__c = true
        );

        Map<String, Schema.SObjectField> consentFields = Consent__c.SObjectType.getDescribe().fields.getMap();
        if (consentFields.containsKey('Consent_Request_Item__c')) {
            consentRecord.put('Consent_Request_Item__c', requestItemRecord.Id);
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

    private static String chooseActionType() {
        Schema.DescribeFieldResult describe = Consent__c.Action_Type__c.getDescribe();
        List<String> preferredValues = new List<String>{ 'Consent Given', 'Authorize', 'Consent' };
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