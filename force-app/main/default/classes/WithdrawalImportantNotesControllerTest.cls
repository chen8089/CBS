@isTest
private class WithdrawalImportantNotesControllerTest {
    @isTest
    static void initRendersPageForActiveSingpassConsent() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-a');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'withdraw-token-a');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        PageReference initResult = controller.init();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(true, controller.canProceed);
        System.assertEquals(false, controller.hasError);
        System.assertEquals(true, controller.isSingpass);
        System.assertEquals(false, controller.isManualVerification);
        System.assertEquals('Sample Bank Pte Ltd', controller.bankName);
        System.assertEquals('Withdrawal Test Subject', controller.dataSubjectName);
        System.assert(controller.email.contains('withdraw.test+'));
        System.assertEquals('Existing Employee', controller.employmentStatus);
        System.assertEquals('Active', controller.currentConsentStatus);
        System.assertEquals(consentRecord.Id, controller.consentId);
        System.assertEquals('Important Notes Before You Withdraw Consent', controller.getPageTitle());
        System.assert(controller.getIntroText().contains('Sample Bank Pte Ltd'));
        System.assert(controller.getIntroText().contains('consumer credit report(s)'));
        System.assert(controller.getIntroText().contains('employment-related credit assessment'));
        System.assertEquals('Effects of withdrawal', controller.getEffectOfWithdrawalHeading());
        System.assertEquals(3, controller.getWithdrawalEffectBullets().size());
        System.assertEquals('For Singpass-verified withdrawals, your consent status will be updated directly.', controller.getWithdrawalEffectBullets()[0]);
        System.assert(controller.getWithdrawalEffectBullets()[1].contains('privacy@creditbureau.com.sg'));
        System.assert(controller.getWithdrawalEffectBullets()[1].contains('Sample Bank Pte Ltd'));
        System.assert(controller.getProceedNote().contains('authenticate via Singpass'));
        System.assert(controller.getProceedNote().contains('complete identity verification'));
        System.assertEquals('Continue to Withdrawal Form', controller.getContinueButtonLabel());
    }

    @isTest
    static void initRendersPageForActiveNonSingpassConsent() {
        Contact contactRecord = createContactWithEmployer('Valid', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-b');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'withdraw-token-b');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        PageReference initResult = controller.init();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(true, controller.isManualVerification);
        System.assertEquals(false, controller.isSingpass);
        System.assert(controller.getWithdrawalEffectBullets()[1].contains('non-Singpass users'));
    }

    @isTest
    static void continueToWithdrawalRoutesSingpassToNdiAuth() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-c');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'withdraw-token-c');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        controller.init();

        PageReference continueResult = controller.continueToWithdrawal();

        System.assertNotEquals(null, continueResult);
        System.assert(continueResult.getUrl().contains('/apex/ndi_auth'));
        System.assertEquals('/apex/SingpassWithdrawalConsentPage', continueResult.getParameters().get('returnUrl'));
        System.assertEquals('withdraw', continueResult.getParameters().get('action'));
        System.assertEquals(String.valueOf(consentRecord.Id), continueResult.getParameters().get('id'));
    }

    @isTest
    static void continueToWithdrawalRoutesNonSingpassToWithdrawConsentPage() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-d');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'withdraw-token-d');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        controller.init();

        PageReference continueResult = controller.continueToWithdrawal();

        System.assertNotEquals(null, continueResult);
        System.assert(continueResult.getUrl().contains('/apex/QRSiteWithdrawConsent'));
        System.assertEquals('withdraw', continueResult.getParameters().get('action'));
    }

    @isTest
    static void cancelDoesNotUpdateConsent() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-e');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'withdraw-token-e');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        controller.init();

        Test.startTest();
        PageReference cancelResult = controller.cancel();
        Test.stopTest();

        System.assertEquals(null, cancelResult);
        System.assertEquals(true, controller.cancelled);
        System.assertEquals(false, controller.canProceed);
        System.assertEquals(false, controller.showPage);

        Consent__c unchangedConsent = [
            SELECT Consent_Status__c
            FROM Consent__c
            WHERE Id = :consentRecord.Id
        ];
        System.assertEquals('Active', unchangedConsent.Consent_Status__c);
    }

    @isTest
    static void initRedirectsForInvalidAndExpiredLinks() {
        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        ApexPages.currentPage().getParameters().put('ContactId', 'invalid-contact-id');
        ApexPages.currentPage().getParameters().put('token', 'bad-token');
        WithdrawalImportantNotesController invalidController = new WithdrawalImportantNotesController();
        PageReference invalidResult = invalidController.init();
        System.assert(invalidResult.getUrl().contains('/apex/QRSiteInvalidLink'));

        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-f');
        requestItem.Consent_Link_Expires_At__c = System.now().addDays(-1);
        update requestItem;

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, null, requestItem.Id, 'withdraw-token-f');
        WithdrawalImportantNotesController expiredController = new WithdrawalImportantNotesController();
        PageReference expiredResult = expiredController.init();
        System.assert(expiredResult.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initRedirectsWhenConsentAlreadyWithdrawnOrDeclined() {
        Contact withdrawnContact = createContactWithEmployer('Withdrawn', 'Singpass', 'Existing Hire');
        setLifecycleStage(withdrawnContact, 'Consent Withdrawn');
        Consent__c withdrawnConsent = createActiveConsent(withdrawnContact);
        Consent_Request_Item__c withdrawnItem = createRequestItem(withdrawnContact, 'Submitted', 'withdraw-token-g');
        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(withdrawnContact.Id, withdrawnConsent.Id, withdrawnItem.Id, 'withdraw-token-g');
        WithdrawalImportantNotesController withdrawnController = new WithdrawalImportantNotesController();
        System.assert(withdrawnController.init().getUrl().contains('/apex/NoActiveConsentPage'));

        Contact declinedContact = createContactWithEmployer('Declined', 'Singpass', 'Existing Hire');
        Consent__c declinedConsent = createActiveConsent(declinedContact);
        Consent_Request_Item__c declinedItem = createRequestItem(declinedContact, 'Submitted', 'withdraw-token-h');
        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(declinedContact.Id, declinedConsent.Id, declinedItem.Id, 'withdraw-token-h');
        WithdrawalImportantNotesController declinedController = new WithdrawalImportantNotesController();
        PageReference declinedInitResult = declinedController.init();
        System.assertEquals(null, declinedInitResult);
        System.assertEquals(true, declinedController.showPage);
        System.assertEquals(true, declinedController.canProceed);
    }

    @isTest
    static void continueToWithdrawalRoutesToSingpassAuthRegardlessOfDeclinedStatus() {
        Contact declinedContact = createContactWithEmployer('Declined', 'Singpass', 'Existing Hire');
        Consent__c declinedConsent = createActiveConsent(declinedContact);
        Consent_Request_Item__c declinedItem = createRequestItem(declinedContact, 'Submitted', 'withdraw-token-h2');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(declinedContact.Id, declinedConsent.Id, declinedItem.Id, 'withdraw-token-h2');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        controller.init();
        PageReference continueResult = controller.continueToWithdrawal();

        System.assertNotEquals(null, continueResult);
        System.assert(continueResult.getUrl().contains('/apex/ndi_auth'));
        System.assertEquals('withdraw', continueResult.getParameters().get('action'));
    }

    @isTest
    static void initRedirectsToNoActiveConsentWhenStatusNotActive() {
        Contact contactRecord = createContactWithEmployer('Pending', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-i');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, null, requestItem.Id, 'withdraw-token-i');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        PageReference result = controller.init();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/NoActiveConsentPage'));
        System.assertEquals('withdraw', result.getParameters().get('action'));
    }

    @isTest
    static void redirectMethodsBuildExpectedPages() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, null, 'withdraw-token-j');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        controller.init();

        PageReference noActiveResult = controller.redirectToNoActiveConsentPage();
        System.assert(noActiveResult.getUrl().contains('/apex/NoActiveConsentPage'));
        System.assertEquals('withdraw', noActiveResult.getParameters().get('action'));

        PageReference invalidResult = controller.redirectToInvalidLinkPage();
        System.assert(invalidResult.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initShowsPreHirePurposeText() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Pre-Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'withdraw-token-k');

        Test.setCurrentPage(Page.WithdrawalImportantNotesPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'withdraw-token-k');

        WithdrawalImportantNotesController controller = new WithdrawalImportantNotesController();
        controller.init();

        System.assertEquals('Pre-Hire', controller.employmentStatus);
        System.assert(controller.getIntroText().contains('pre-employment screening'));
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

    private static Contact createContactWithEmployer(String consentStatus, String authType, String employmentStatus) {
        Account employer = new Account(Name = 'Sample Bank Pte Ltd');
        insert employer;

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();

        Contact contactRecord = new Contact(
            LastName = 'Withdrawal Subject',
            Email = 'withdraw.test+' + uniqueSuffix + '@example.com',
            AccountId = employer.Id,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = 'Withdrawal Test Subject',
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

    private static Consent__c createActiveConsent(Contact contactRecord) {
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Status__c = 'Active',
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