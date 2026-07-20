@IsTest
private class ActiveConsentNotificationControllerTest {
    private class TestData {
        Account accountRecord;
        Contact contactRecord;
        Consent_Request_Item__c requestItemRecord;
        Consent__c consentRecord;

        TestData(Account accountRecord, Contact contactRecord, Consent_Request_Item__c requestItemRecord, Consent__c consentRecord) {
            this.accountRecord = accountRecord;
            this.contactRecord = contactRecord;
            this.requestItemRecord = requestItemRecord;
            this.consentRecord = consentRecord;
        }
    }

    @IsTest
    static void initPageShowsErrorWhenParametersMissing() {
        Test.setCurrentPage(Page.ActiveConsentNotificationPage);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showError);
        System.assertEquals(false, controller.showPage);
        System.assertEquals('Invalid or missing request reference.', controller.errorMessage);
    }

    @IsTest
    static void initPageShowsErrorWhenContactNotFound() {
        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        ApexPages.currentPage().getParameters().put('contactId', 'not-a-valid-id');

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        controller.initPage();

        System.assertEquals(true, controller.showError);
        System.assertEquals('We are unable to locate this consent request.', controller.errorMessage);
    }

    @IsTest
    static void initPageShowsActiveConsentForSingpassEmployee() {
        TestData data = createSingpassEmployeeScenario('Authorized', 'Existing Hire', 'Term-Based Consent', 'Active');

        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        setStandardParams(data);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(false, controller.showError);
        System.assertEquals('Your consent is currently active.', controller.getPageTitle());
        System.assertEquals(data.accountRecord.Name, controller.bankName);
        System.assert(controller.getMainBodyText().contains(data.accountRecord.Name));
        System.assert(controller.getMainBodyText().contains('[EMPLOYMENT-RELATED CREDIT ASSESSMENT / PRE-EMPLOYMENT SCREENING]'));
        System.assert(controller.getMainBodyText().contains('No further action is required from you.'));
        System.assert(controller.getWithdrawalText().contains(data.accountRecord.Name));
        System.assert(controller.getWithdrawalText().contains('Privacy@creditbureau.com.sg'));
        System.assert(controller.getWithdrawalTextHtml().contains('text-decoration: underline;'));
        System.assertEquals(true, controller.getShowBankName());
        System.assertEquals(true, controller.getShowConsentStatus());
        System.assertEquals(true, controller.getShowConsentExpiryDate());
        System.assertEquals(true, controller.getShowPurpose());
    }

    @IsTest
    static void initPageShowsPreHirePurposeForNonSingpassScenario() {
        TestData data = createSingpassEmployeeScenario('Valid', 'Pre-hire', 'Per-Report Consent', 'Valid');

        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        setStandardParams(data);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        controller.initPage();

        System.assertEquals(true, controller.showPage);
        System.assertEquals('pre-employment screening', controller.purposeText);
        System.assert(controller.getMainBodyText().contains('[EMPLOYMENT-RELATED CREDIT ASSESSMENT / PRE-EMPLOYMENT SCREENING]'));
    }

    @IsTest
    static void initPageRedirectsPreHireSingpassToPrehireImportantNotesWhenNoActiveConsent() {
        TestData data = createSingpassEmployeeScenario('Pending', 'Pre-hire', 'Per-Report Consent', 'Pending');
        update new Contact(
            Id = data.contactRecord.Id,
            Current_Consent_Status__c = 'Pending',
            Current_Consent_Expiry_Date__c = null
        );
        delete data.consentRecord;

        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        setStandardParams(data);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.getRedirect());
        System.assert(
            result.getUrl().toLowerCase().contains('qrsitesingpassprehireimportantnotes'),
            'Unexpected redirect URL: ' + result.getUrl()
        );
        System.assertEquals('prehire', result.getParameters().get('type'));
    }

    @IsTest
    static void initPageRedirectsWhenNoValidConsentExists() {
        TestData data = createSingpassEmployeeScenario('Pending', 'Existing Hire', 'Term-Based Consent', 'Pending');
        update new Contact(
            Id = data.contactRecord.Id,
            Current_Consent_Status__c = 'Pending',
            Current_Consent_Expiry_Date__c = null
        );
        delete data.consentRecord;

        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        setStandardParams(data);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.getRedirect());
        System.assert(
            result.getUrl().toLowerCase().contains('qrsitesingpassemployeeimportantnotes'),
            'Unexpected redirect URL: ' + result.getUrl()
        );
    }

    @IsTest
    static void initPageRedirectsNonSingpassToImportantNotesWhenNoActiveConsent() {
        TestData data = createNonSingpassScenario('Pending', 'Pending');
        delete data.consentRecord;

        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().toLowerCase().contains('qrsitenonsingpassprehireimportantnotes'),
            'Unexpected redirect URL: ' + result.getUrl()
        );
    }

    @IsTest
    static void initPageRedirectsWithdrawnContactToAlreadyActionedPage() {
        TestData data = createSingpassEmployeeScenario('Withdrawn', 'Existing Hire', 'Term-Based Consent', 'Withdrawn');

        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        setStandardParams(data);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @IsTest
    static void initPageResolvesContactFromRequestItemId() {
        TestData data = createSingpassEmployeeScenario('Authorized', 'Existing Hire', 'Term-Based Consent', 'Active');

        Test.setCurrentPage(Page.ActiveConsentNotificationPage);
        ApexPages.currentPage().getParameters().put('consentRequestItemId', data.requestItemRecord.Id);

        ActiveConsentNotificationController controller = new ActiveConsentNotificationController();
        controller.initPage();

        System.assertEquals(true, controller.showPage);
        System.assertEquals(data.accountRecord.Name, controller.bankName);
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
    }

    private static TestData createSingpassEmployeeScenario(
        String contactStatus,
        String employmentStatus,
        String consentType,
        String consentStatus
    ) {
        Account accountRecord = new Account(Name = 'Active Consent Bank');
        insert accountRecord;

        Contact contactRecord = createContact(contactStatus, 'Singpass', employmentStatus, consentType);
        contactRecord.AccountId = accountRecord.Id;
        contactRecord.Current_Consent_Expiry_Date__c = Date.today().addYears(5);
        if (Contact.SObjectType.getDescribe().fields.getMap().containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Active Consent Employee');
        }
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord);
        Consent__c consentRecord = createConsent(contactRecord, requestItemRecord, consentStatus, Date.today().addYears(5));
        return new TestData(accountRecord, contactRecord, requestItemRecord, consentRecord);
    }

    private static TestData createNonSingpassScenario(String contactStatus, String consentStatus) {
        Account accountRecord = new Account(Name = 'Manual Verification Bank');
        insert accountRecord;

        Contact contactRecord = createContact(contactStatus, 'Non-Singpass', 'Pre-hire', 'Per-Report Consent');
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord);
        Consent__c consentRecord = consentStatus == null
            ? null
            : createConsent(contactRecord, requestItemRecord, consentStatus, Date.today().addMonths(1));
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
            LastName = 'Active Consent Test ' + uniqueSuffix,
            Email = 'active.consent+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Active Consent Test User');
        }
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', authType);
        }
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', employmentStatus);
        }
        if (contactFields.containsKey('Consent_Type__c')) {
            contactRecord.put('Consent_Type__c', consentType);
        }

        insert contactRecord;
        return contactRecord;
    }

    private static Consent_Request_Item__c createRequestItem(Contact contactRecord) {
        Consent_Request_Item__c requestItemRecord = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = 'Submitted',
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

        insert consentRecord;
        return consentRecord;
    }

    private static String chooseActionType() {
        Schema.DescribeFieldResult describe = Consent__c.Action_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return 'Authorize';
    }
}