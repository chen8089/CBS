@isTest
private class ConsentSuccessControllerTest {
    @isTest
    static void initPageShowsErrorWhenTokenMissing() {
        TestData data = createSingpassEmployeeScenario();

        Test.setCurrentPage(Page.ConsentSuccessPage);
        ApexPages.currentPage().getParameters().put('contactId', data.contactRecord.Id);

        ConsentSuccessController controller = new ConsentSuccessController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showSuccess);
        System.assert(controller.errorMessage.contains('unable to display this consent confirmation'));
    }

    @isTest
    static void initPageShowsErrorWhenContactInvalid() {
        Test.setCurrentPage(Page.ConsentSuccessPage);
        ApexPages.currentPage().getParameters().put('contactId', 'not-a-valid-id');
        ApexPages.currentPage().getParameters().put('token', 'any-token');

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showSuccess);
    }

    @isTest
    static void initPageShowsErrorWhenConsentNotSubmitted() {
        TestData data = createSingpassEmployeeScenario();
        update new Contact(
            Id = data.contactRecord.Id,
            Current_Consent_Status__c = 'Pending',
            Latest_Submission_Datetime__c = null
        );
        update new Consent_Request_Item__c(
            Id = data.requestItemRecord.Id,
            Current_Status__c = 'Sent'
        );
        delete data.consentRecord;

        Test.setCurrentPage(Page.ConsentSuccessPage);
        setStandardParams(data);

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showSuccess);
    }

    @isTest
    static void initPageShowsErrorWhenLinkExpired() {
        TestData data = createSingpassEmployeeScenario();
        update new Consent_Request_Item__c(
            Id = data.requestItemRecord.Id,
            Consent_Link_Expires_At__c = System.now().addDays(-1)
        );

        Test.setCurrentPage(Page.ConsentSuccessPage);
        setStandardParams(data);

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showSuccess);
    }

    @isTest
    static void initPageShowsSingpassEmployeeSuccessSummary() {
        TestData data = createSingpassEmployeeScenario();

        Test.setCurrentPage(Page.ConsentSuccessPage);
        setStandardParams(data);

        ConsentSuccessController controller = new ConsentSuccessController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showSuccess);
        System.assertEquals(false, controller.showError);
        System.assertEquals('Consent Submitted Successfully', controller.getPageTitle());
        System.assertEquals(data.accountRecord.Name, controller.employerBankName);
        System.assert(controller.getSuccessIntroText().contains('well received'));
        System.assert(controller.getCreditRequestNotificationText().contains(data.accountRecord.Name));
        System.assert(controller.getManualVerificationSubmissionText().contains(data.accountRecord.Name));
        System.assert(controller.getWithdrawalText().contains(data.accountRecord.Name));
    }

    @isTest
    static void initPageShowsNonSingpassProcessingStatus() {
        TestData data = createNonSingpassPreHireScenario();

        Test.setCurrentPage(Page.ConsentSuccessPage);
        setStandardParams(data);

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showSuccess);
        System.assertEquals('What happens next', controller.getWhatHappensNextTitle());
        System.assert(controller.getSingpassSubmissionText().contains('will be available'));
        System.assert(controller.getCreditRequestNotificationText().contains(data.accountRecord.Name));
        System.assert(controller.getManualVerificationSubmissionText().contains('identity verification'));
    }

    @isTest
    static void initPageUsesBankNameInWithdrawalCopy() {
        TestData data = createSingpassEmployeeScenario();

        Test.setCurrentPage(Page.ConsentSuccessPage);
        setStandardParams(data);

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assertEquals('Withdrawal of consent', controller.getWithdrawalSectionTitle());
        System.assert(controller.getWithdrawalText().contains('Human Resources'));
        System.assert(controller.getWithdrawalText().contains(data.accountRecord.Name));
        System.assert(controller.getWithdrawalText().contains('Privacy@creditbureau.com.sg'));
    }

    @isTest
    static void initPageResolvesContactFromConsentId() {
        TestData data = createSingpassEmployeeScenario();

        Test.setCurrentPage(Page.ConsentSuccessPage);
        ApexPages.currentPage().getParameters().put('consentId', data.consentRecord.Id);
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assertEquals(true, controller.showSuccess);
        System.assertEquals(String.valueOf(data.contactRecord.Id), controller.contactId);
    }

    @isTest
    static void initPageUsesPlaceholderWhenBankNameMissing() {
        Contact contactRecord = createContact('Authorized', 'Singpass', 'Existing Hire', 'Term-based Consent');
        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Submitted');
        Consent__c consentRecord = createConsent(
            contactRecord,
            requestItemRecord,
            'Active',
            Date.today().addYears(5)
        );

        Test.setCurrentPage(Page.ConsentSuccessPage);
        ConsentTestSupport.applyGuestLinkParams(contactRecord.Id, requestItemRecord);
        ApexPages.currentPage().getParameters().put('consentId', consentRecord.Id);

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assertEquals('[NAME OF BANK]', controller.employerBankName);
        System.assert(controller.getManualVerificationSubmissionText().contains('[NAME OF BANK]'));
        System.assert(controller.getCreditRequestNotificationText().contains('[NAME OF BANK]'));
        System.assert(controller.getWithdrawalText().contains('[NAME OF BANK AND DEPARTMENT]'));
    }

    @isTest
    static void getterHelpersExposeExpectedStaticCopy() {
        TestData data = createSingpassEmployeeScenario();

        Test.setCurrentPage(Page.ConsentSuccessPage);
        setStandardParams(data);

        ConsentSuccessController controller = new ConsentSuccessController();
        controller.initPage();

        System.assert(controller.getSuccessIntroText().contains('well received'));
        System.assertEquals('What happens next', controller.getWhatHappensNextTitle());
        System.assert(controller.getSingpassSubmissionText().contains('will be available'));
        System.assert(controller.getSingpassSubmissionText().contains('authorised credit report request process'));
        System.assert(controller.getCreditRequestNotificationText().contains(data.accountRecord.Name));
        System.assert(controller.getManualVerificationSubmissionText().contains(data.accountRecord.Name));
        System.assertEquals('Withdrawal of consent', controller.getWithdrawalSectionTitle());
        System.assert(controller.getWithdrawalText().contains('withdrawal link'));
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().put('consentId', data.consentRecord.Id);
    }

    private static TestData createSingpassEmployeeScenario() {
        Account accountRecord = new Account(Name = 'Consent Success Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact('Authorized', 'Singpass', 'Existing Hire', 'Term-based Consent');
        contactRecord.AccountId = accountRecord.Id;
        contactRecord.Principal_Name__c = 'Singpass Employee Test';
        contactRecord.ID_Number__c = 'S9876543B';
        contactRecord.Latest_Submission_Datetime__c = System.now();
        contactRecord.Current_Consent_Expiry_Date__c = Date.today().addYears(5);
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Submitted');
        Consent__c consentRecord = createConsent(contactRecord, requestItemRecord, 'Active', Date.today().addYears(5));
        return new TestData(accountRecord, contactRecord, requestItemRecord, consentRecord);
    }

    private static TestData createNonSingpassPreHireScenario() {
        Account accountRecord = new Account(Name = 'Manual Verification Bank');
        insert accountRecord;

        Contact contactRecord = createContact('Pending Verification', 'Non-Singpass', 'Pre-hire', 'Per-Report Consent');
        contactRecord.AccountId = accountRecord.Id;
        contactRecord.Principal_Name__c = 'Non-Singpass Pre-hire Test';
        contactRecord.Latest_Submission_Datetime__c = System.now();
        contactRecord.Current_Consent_Expiry_Date__c = Date.today().addMonths(1);
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord, 'Submitted');
        Consent__c consentRecord = createConsent(
            contactRecord,
            requestItemRecord,
            chooseConsentStatus(new List<String>{ 'Pending', 'Processing', 'Pending Verification' }),
            Date.today().addMonths(1)
        );
        return new TestData(accountRecord, contactRecord, requestItemRecord, consentRecord);
    }

    private static Contact createContact(
        String consentStatus,
        String authType,
        String employmentStatus,
        String consentType
    ) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'Consent Success Test ' + uniqueSuffix,
            Email = 'consent.success+' + uniqueSuffix + '@example.com',
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
        if (contactFields.containsKey('Consent_Type__c')) {
            contactRecord.put('Consent_Type__c', consentType);
        }
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Consent Success Test');
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

    private static Consent__c createConsent(
        Contact contactRecord,
        Consent_Request_Item__c requestItemRecord,
        String consentStatus,
        Date expiryDate
    ) {
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Status__c = consentStatus,
            Submitted_At__c = System.now(),
            Consent_Expiry_Date__c = expiryDate
        );

        Map<String, Schema.SObjectField> consentFields = Consent__c.SObjectType.getDescribe().fields.getMap();
        if (consentFields.containsKey('Consent_Request_Item__c')) {
            consentRecord.put('Consent_Request_Item__c', requestItemRecord.Id);
        }
        if (consentFields.containsKey('Action_Type__c')) {
            consentRecord.put('Action_Type__c', chooseActionType());
        }
        if (consentFields.containsKey('Match_Status__c') && consentStatus == 'Active') {
            consentRecord.put('Match_Status__c', 'Matched');
        }

        insert consentRecord;
        return consentRecord;
    }

    private static String chooseConsentStatus(List<String> preferredValues) {
        Schema.DescribeFieldResult describe = Consent__c.Consent_Status__c.getDescribe();
        for (String preferredValue : preferredValues) {
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue() == preferredValue) {
                    return preferredValue;
                }
            }
        }
        return describe.getPicklistValues()[0].getValue();
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