@isTest
private class QRSiteSingpassEmpImpNotesCtrlTest {
    @isTest
    static void initPageAndGettersRenderForValidScenario() {
        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-a');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-a');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference initResult = controller.initPage();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Important Notes Before You Proceed', controller.getImportantNotesTitle());
        System.assert(controller.getIntroText().contains('Sample Bank Pte Ltd'));
        System.assertEquals(2, controller.getWhatThisRequestIsForParagraphs().size());
        System.assertEquals(3, controller.getSingpassMyinfoParagraphs().size());
        System.assertEquals(2, controller.getYourConsentParagraphs().size());
        System.assertEquals(2, controller.getDeclineParagraphs().size());
        System.assertEquals(3, controller.getWithdrawalParagraphs().size());
        System.assertEquals(2, controller.getSecurityParagraphs().size());
        System.assertEquals('Continue with Singpass', controller.getContinueButtonMain());
        System.assertEquals('', controller.getContinueButtonSub());
        System.assertEquals('Decline to Give Consent', controller.getDeclineButtonMain());
        System.assertEquals('', controller.getDeclineButtonSub());
        System.assertEquals('[BANK HR SUPPORT EMAIL]', controller.getHrSupportEmail());
    }

    @isTest
    static void continueAndDeclineBuildExpectedRedirects() {
        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-b');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-b');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        controller.initPage();

        PageReference continueResult = controller.continueWithSingpass();
        System.assertNotEquals(null, continueResult);
        System.assert(
            continueResult.getUrl().contains('/apex/QRSiteSingpassLogin')
                || continueResult.getUrl().contains('/apex/ndi_auth')
        );
        System.assertEquals('/apex/QRSiteSingpassEmployeeConsentForm', continueResult.getParameters().get('returnUrl'));
        System.assertEquals('token-b', continueResult.getParameters().get('token'));

        PageReference declineResult = controller.declineConsent();
        System.assertNotEquals(null, declineResult);
        System.assert(declineResult.getUrl().contains('/apex/CBSDeclineConsentConfirmation'));
        System.assertEquals(String.valueOf(contactRecord.Id), declineResult.getParameters().get('contactId'));
    }

    @isTest
    static void initPageRedirectsForInvalidAndExpiredCases() {
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', 'invalid-contact-id');
        ApexPages.currentPage().getParameters().put('token', 'token-c');
        QRSiteSingpassEmpImportantNotesCtrl invalidIdController = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference invalidResult = invalidIdController.initPage();
        System.assert(invalidResult.getUrl().contains('/apex/QRSiteInvalidLink'));

        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-d');
        requestItem.Consent_Link_Expires_At__c = System.now().addDays(-1);
        update requestItem;

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-d');
        QRSiteSingpassEmpImportantNotesCtrl expiredController = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference expiredResult = expiredController.initPage();
        System.assert(expiredResult.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageRedirectsForConsentStatusesAndScenarioMismatch() {
        Contact authorizedContact = createSingpassEmployeeContact('Authorized');
        setLifecycleStage(authorizedContact, 'Active Consent');
        Consent_Request_Item__c authorizedItem = createRequestItem(authorizedContact, 'Sent', 'token-e');
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(authorizedContact.Id, authorizedItem.Id, 'token-e');
        QRSiteSingpassEmpImportantNotesCtrl authorizedController = new QRSiteSingpassEmpImportantNotesCtrl();
        System.assert(authorizedController.initPage().getUrl().contains('/apex/ActiveConsentNotificationPage'));

        Contact declinedContact = createSingpassEmployeeContact('Declined');
        Consent_Request_Item__c declinedItem = createRequestItem(declinedContact, 'Sent', 'token-f');
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(declinedContact.Id, declinedItem.Id, 'token-f');
        QRSiteSingpassEmpImportantNotesCtrl declinedController = new QRSiteSingpassEmpImportantNotesCtrl();
        System.assert(declinedController.initPage().getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));

        Contact expiredContact = createSingpassEmployeeContact('Expired');
        Consent_Request_Item__c expiredItem = createRequestItem(expiredContact, 'Sent', 'token-g');
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(expiredContact.Id, expiredItem.Id, 'token-g');
        QRSiteSingpassEmpImportantNotesCtrl expiredController = new QRSiteSingpassEmpImportantNotesCtrl();
        System.assert(expiredController.initPage().getUrl().contains('/apex/QRSiteLinkExpired'));

        Contact mismatchContact = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c mismatchItem = createRequestItem(mismatchContact, 'Sent', 'token-h');
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(mismatchContact.Id, mismatchItem.Id, 'token-h');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        QRSiteSingpassEmpImportantNotesCtrl mismatchController = new QRSiteSingpassEmpImportantNotesCtrl();
        System.assert(mismatchController.initPage().getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    private static void setBaseParams(Id contactId, Id requestItemId, String tokenValue) {
        ApexPages.currentPage().getParameters().put('ContactId', contactId);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItemId);
        ApexPages.currentPage().getParameters().put('token', tokenValue);
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

    private static Contact createSingpassEmployeeContact(String consentStatus) {
        Account employer = new Account(Name = 'Sample Bank Pte Ltd');
        insert employer;

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();

        Contact contactRecord = new Contact(
            LastName = 'Singpass Employee',
            Email = 'singpass.employee+' + uniqueSuffix + '@example.com',
            AccountId = employer.Id,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = 'Singpass Employee',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Employment_Status__c = 'Existing Hire',
            Current_Consent_Status__c = consentStatus
        );
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', 'Singpass');
        }
        if (contactFields.containsKey('Consent_Type__c')) {
            contactRecord.put('Consent_Type__c', 'Term-Based Consent');
        }
        insert contactRecord;
        return contactRecord;
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