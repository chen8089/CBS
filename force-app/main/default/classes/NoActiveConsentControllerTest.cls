@isTest
private class NoActiveConsentControllerTest {
    @isTest
    static void initShowsPageWhenContactHasNoConsent() {
        Contact contactRecord = createContactWithEmployer('Pending', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'no-active-token-a');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, null, requestItem.Id, 'no-active-token-a');

        NoActiveConsentController controller = new NoActiveConsentController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(false, controller.getHasActiveConsent());
        System.assertEquals(true, controller.showDetailInfo);
        System.assertEquals('No active consent has been submitted yet.', controller.statusMessage);
        System.assert(controller.getIntroText().contains('no active consent record available for withdrawal'));
        System.assertEquals(6, controller.getReasonBullets().size());
        System.assertEquals('Sample Bank Pte Ltd', controller.bankName);
        System.assertEquals('[BANK HR SUPPORT EMAIL]', controller.getHrSupportEmailDisplay());
    }

    @isTest
    static void initShowsWithdrawnStatusMessage() {
        Contact contactRecord = createContactWithEmployer('Withdrawn', 'Singpass', 'Existing Hire');
        Consent__c consentRecord = createConsent(contactRecord, 'Withdrawn');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Withdrawn', 'no-active-token-b');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'no-active-token-b');

        NoActiveConsentController controller = new NoActiveConsentController();
        controller.initPage();

        System.assertEquals(false, controller.getHasActiveConsent());
        System.assertEquals(true, controller.showDetailInfo);
        System.assertEquals('Your consent has already been withdrawn.', controller.statusMessage);
        System.assertEquals('Withdrawn', controller.currentConsentStatus);
    }

    @isTest
    static void initShowsDeclinedStatusMessage() {
        Contact contactRecord = createContactWithEmployer('Declined', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createConsent(contactRecord, 'Declined');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Declined', 'no-active-token-c');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'no-active-token-c');

        NoActiveConsentController controller = new NoActiveConsentController();
        controller.initPage();

        System.assertEquals('You have previously declined this consent request.', controller.statusMessage);
        System.assertEquals(true, controller.showDetailInfo);
    }

    @isTest
    static void initShowsExpiredStatusMessage() {
        Contact contactRecord = createContactWithEmployer('Expired', 'Singpass', 'Existing Hire');
        contactRecord.Current_Consent_Expiry_Date__c = Date.today().addDays(-1);
        update contactRecord;

        Consent__c consentRecord = createConsent(contactRecord, 'Expired');
        consentRecord.Consent_Expiry_Date__c = Date.today().addDays(-1);
        update consentRecord;

        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Expired', 'no-active-token-d');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'no-active-token-d');

        NoActiveConsentController controller = new NoActiveConsentController();
        controller.initPage();

        System.assertEquals('Your consent is no longer active because it has expired.', controller.statusMessage);
    }

    @isTest
    static void initShowsConsumedStatusMessage() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Pre-Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Consumed', 'no-active-token-e');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, null, requestItem.Id, 'no-active-token-e');

        NoActiveConsentController controller = new NoActiveConsentController();
        controller.initPage();

        System.assertEquals(
            'This pre-hire consent has already been consumed for a credit report request.',
            controller.statusMessage
        );
        System.assertEquals('Pre-Hire', controller.employmentStatus);
    }

    @isTest
    static void pageTextUsesBankNameAndHrEmailWhenAvailable() {
        Contact contactRecord = createContactWithEmployer('Pending', 'Singpass', 'Existing Hire');
        Account employer = [SELECT Id, Name FROM Account WHERE Id = :contactRecord.AccountId];
        employer.Name = 'Mock Bank Ltd';
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (accountFields.containsKey('Notification_Email__c')) {
            employer.put('Notification_Email__c', 'hr.support@mockbank.example');
        }
        update employer;

        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'no-active-token-j');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, null, requestItem.Id, 'no-active-token-j');

        NoActiveConsentController controller = new NoActiveConsentController();
        controller.initPage();

        System.assert(controller.getContactHrText().contains('Mock Bank Ltd Human Resources'));
        if (accountFields.containsKey('Notification_Email__c')) {
            System.assertEquals('hr.support@mockbank.example', controller.getHrSupportEmailDisplay());
            System.assertEquals(true, controller.getShowHrEmailLink());
        }
    }

    @isTest
    static void initRedirectsWhenActiveConsentExists() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent__c consentRecord = createConsent(contactRecord, 'Active');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'no-active-token-f');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'no-active-token-f');

        NoActiveConsentController controller = new NoActiveConsentController();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assertEquals(true, controller.getHasActiveConsent());
        System.assert(result.getUrl().contains('/apex/WithdrawalImportantNotesPage'));
        System.assertEquals('withdraw', result.getParameters().get('action'));
        System.assertEquals(String.valueOf(contactRecord.Id), result.getParameters().get('ContactId'));
    }

    @isTest
    static void initRedirectsWhenValidConsentExists() {
        Contact contactRecord = createContactWithEmployer('Valid', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createConsent(contactRecord, 'Valid');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'no-active-token-g');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'no-active-token-g');

        NoActiveConsentController controller = new NoActiveConsentController();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assertEquals(true, controller.getHasActiveConsent());
        System.assert(result.getUrl().contains('/apex/WithdrawalImportantNotesPage'));
        System.assertEquals(String.valueOf(consentRecord.Id), result.getParameters().get('id'));
    }

    @isTest
    static void initHandlesEmptyUrlParametersWithoutException() {
        Test.setCurrentPage(Page.NoActiveConsentPage);

        NoActiveConsentController controller = new NoActiveConsentController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(false, controller.showDetailInfo);
        System.assertEquals(false, controller.getHasActiveConsent());
        System.assertEquals(
            'We could not find an active consent record for this request.',
            controller.statusMessage
        );
    }

    @isTest
    static void initHandlesInvalidUrlParametersWithoutException() {
        Test.setCurrentPage(Page.NoActiveConsentPage);
        ApexPages.currentPage().getParameters().put('ContactId', 'invalid-contact-id');
        ApexPages.currentPage().getParameters().put('token', 'bad-token');
        ApexPages.currentPage().getParameters().put('consentId', 'invalid-consent-id');

        NoActiveConsentController controller = new NoActiveConsentController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(false, controller.showDetailInfo);
        System.assertEquals(
            'We could not find an active consent record for this request.',
            controller.statusMessage
        );
    }

    @isTest
    static void initDoesNotExposeDataWhenTokenDoesNotMatch() {
        Contact contactRecord = createContactWithEmployer('Withdrawn', 'Singpass', 'Existing Hire');
        createConsent(contactRecord, 'Withdrawn');
        createRequestItem(contactRecord, 'Withdrawn', 'no-active-token-h');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        ApexPages.currentPage().getParameters().put('ContactId', contactRecord.Id);
        ApexPages.currentPage().getParameters().put('token', 'wrong-token');

        NoActiveConsentController controller = new NoActiveConsentController();
        controller.initPage();

        System.assertEquals(false, controller.showDetailInfo);
        System.assertEquals(
            'We could not find an active consent record for this request.',
            controller.statusMessage
        );
    }

    @isTest
    static void initPopulatesDetailFieldsWhenContextIsResolved() {
        Contact contactRecord = createContactWithEmployer('Pending', 'Singpass', 'Pre-Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Requested', 'no-active-token-i');

        Test.setCurrentPage(Page.NoActiveConsentPage);
        setBaseParams(contactRecord.Id, null, requestItem.Id, 'no-active-token-i');

        NoActiveConsentController controller = new NoActiveConsentController();
        controller.initPage();

        System.assertEquals(true, controller.showDetailInfo);
        System.assertEquals('No Active Consent Test Subject', controller.dataSubjectName);
        System.assert(controller.email.contains('noactive.test+'));
        System.assertEquals('Sample Bank Pte Ltd', controller.bankName);
        System.assertEquals(String.valueOf(requestItem.Id), controller.referenceId);
        System.assertEquals('Pre-Hire', controller.employmentStatus);
    }

    private static void setBaseParams(Id contactId, Id consentId, Id requestItemId, String tokenValue) {
        ApexPages.currentPage().getParameters().put('ContactId', contactId);
        if (consentId != null) {
            ApexPages.currentPage().getParameters().put('consentId', consentId);
            ApexPages.currentPage().getParameters().put('id', consentId);
        }
        if (requestItemId != null) {
            ApexPages.currentPage().getParameters().put('requestItemId', requestItemId);
        }
        ApexPages.currentPage().getParameters().put('token', tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
    }

    private static Contact createContactWithEmployer(String consentStatus, String authType, String employmentStatus) {
        Account employer = new Account(Name = 'Sample Bank Pte Ltd');
        insert employer;

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();

        Contact contactRecord = new Contact(
            LastName = 'No Active Consent Subject',
            Email = 'noactive.test+' + uniqueSuffix + '@example.com',
            AccountId = employer.Id,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = 'No Active Consent Test Subject',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Employment_Status__c = employmentStatus,
            Current_Consent_Status__c = consentStatus
        );
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', authType);
        }
        insert contactRecord;
        return contactRecord;
    }

    private static Consent__c createConsent(Contact contactRecord, String status) {
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Status__c = status,
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        insert consentRecord;
        return consentRecord;
    }

    private static Consent_Request_Item__c createRequestItem(Contact contactRecord, String status, String tokenValue) {
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = status,
            Consent_Link_Expires_At__c = System.now().addDays(7)
        );
        Map<String, Schema.SObjectField> itemFields = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        if (itemFields.containsKey('Token__c')) {
            requestItem.put('Token__c', tokenValue);
        } else if (itemFields.containsKey('Secure_Token__c')) {
            requestItem.put('Secure_Token__c', tokenValue);
        } else if (itemFields.containsKey('Access_Token__c')) {
            requestItem.put('Access_Token__c', tokenValue);
        }
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return requestItem;
    }
}