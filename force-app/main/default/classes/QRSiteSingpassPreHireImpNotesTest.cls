@isTest
private class QRSiteSingpassPreHireImpNotesTest {
    @isTest
    static void initPageWorksForGuestUserWithValidLink() {
        Contact contactRecord = createSingpassPrehireContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'guest-token');

        User guestUser = [
            SELECT Id
            FROM User
            WHERE Username LIKE 'qr_code_site%'
            LIMIT 1
        ];

        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'guest-token');

        System.runAs(guestUser) {
            QRSiteSingpassPrehireImportantNotesCtrl controller = new QRSiteSingpassPrehireImportantNotesCtrl();
            PageReference initResult = controller.initPage();
            System.assertEquals(null, initResult, 'Guest user should render Important Notes page');
            System.assertEquals(true, controller.showPage);
        }
    }

    @isTest
    static void initPageAndGettersRenderForValidPrehireScenario() {
        Contact contactRecord = createSingpassPrehireContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-a');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-a');

        QRSiteSingpassPrehireImportantNotesCtrl controller = new QRSiteSingpassPrehireImportantNotesCtrl();
        PageReference initResult = controller.initPage();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Important Notes Before You Proceed', controller.getImportantNotesTitle());
        System.assert(controller.getIntroText().contains('pre-employment screening / background check purposes'));
        System.assert(controller.getIntroText().contains('Sample Bank Pte Ltd'));
        System.assertEquals(2, controller.getWhatThisRequestIsForParagraphs().size());
        System.assertEquals(3, controller.getSingpassMyinfoParagraphs().size());
        System.assertEquals(2, controller.getYourConsentParagraphs().size());
        System.assert(controller.getYourConsentParagraphs()[1].contains('1 month'));
        System.assertEquals(2, controller.getDeclineParagraphs().size());
        System.assertEquals(3, controller.getWithdrawalParagraphs().size());
        System.assertEquals(2, controller.getSecurityParagraphs().size());
        System.assertEquals('Continue with Singpass', controller.getContinueButtonLabel());
        System.assertEquals('Decline to Give Consent', controller.getDeclineButtonLabel());
    }

    @isTest
    static void continueAndDeclineBuildExpectedRedirects() {
        Contact contactRecord = createSingpassPrehireContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-b');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-b');

        QRSiteSingpassPrehireImportantNotesCtrl controller = new QRSiteSingpassPrehireImportantNotesCtrl();
        controller.initPage();

        PageReference continueResult = controller.continueWithSingpass();
        System.assertNotEquals(null, continueResult);
        System.assert(continueResult.getUrl().contains('/apex/ndi_auth'));
        System.assertEquals('/apex/QRSiteSingpassPrehireConsentForm', continueResult.getParameters().get('returnUrl'));
        System.assertEquals('prehire', continueResult.getParameters().get('type'));
        System.assertEquals('token-b', continueResult.getParameters().get('token'));

        PageReference declineResult = controller.declineConsent();
        System.assertNotEquals(null, declineResult);
        System.assert(declineResult.getUrl().contains('/apex/CBSDeclineConsentConfirmation'));
        System.assertEquals(String.valueOf(contactRecord.Id), declineResult.getParameters().get('contactId'));
        System.assertEquals('prehire', declineResult.getParameters().get('type'));
    }

    @isTest
    static void initPageRedirectsForInvalidExpiredAndScenarioMismatch() {
        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', 'invalid-contact-id');
        ApexPages.currentPage().getParameters().put('token', 'token-c');
        QRSiteSingpassPrehireImportantNotesCtrl invalidIdController = new QRSiteSingpassPrehireImportantNotesCtrl();
        PageReference invalidResult = invalidIdController.initPage();
        System.assert(invalidResult.getUrl().contains('/apex/QRSiteInvalidLink'));

        Contact contactRecord = createSingpassPrehireContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-d');
        requestItem.Consent_Link_Expires_At__c = System.now().addDays(-1);
        update requestItem;

        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-d');
        QRSiteSingpassPrehireImportantNotesCtrl expiredController = new QRSiteSingpassPrehireImportantNotesCtrl();
        PageReference expiredResult = expiredController.initPage();
        System.assert(expiredResult.getUrl().contains('/apex/QRSiteInvalidLink'));

        Contact employeeContact = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c employeeItem = createRequestItem(employeeContact, 'Sent', 'token-e');
        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(employeeContact.Id, employeeItem.Id, 'token-e');
        QRSiteSingpassPrehireImportantNotesCtrl mismatchController = new QRSiteSingpassPrehireImportantNotesCtrl();
        System.assert(mismatchController.initPage().getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageRedirectsForConsentStatuses() {
        Contact authorizedContact = createSingpassPrehireContact('Authorized');
        setLifecycleStage(authorizedContact, 'Active Consent');
        Consent_Request_Item__c authorizedItem = createRequestItem(authorizedContact, 'Sent', 'token-f');
        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(authorizedContact.Id, authorizedItem.Id, 'token-f');
        QRSiteSingpassPrehireImportantNotesCtrl authorizedController = new QRSiteSingpassPrehireImportantNotesCtrl();
        System.assert(authorizedController.initPage().getUrl().contains('/apex/ActiveConsentNotificationPage'));

        Contact declinedContact = createSingpassPrehireContact('Declined');
        Consent_Request_Item__c declinedItem = createRequestItem(declinedContact, 'Sent', 'token-g');
        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(declinedContact.Id, declinedItem.Id, 'token-g');
        QRSiteSingpassPrehireImportantNotesCtrl declinedController = new QRSiteSingpassPrehireImportantNotesCtrl();
        System.assert(declinedController.initPage().getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void securityParagraphUsesHrSupportEmailWhenAvailable() {
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (!accountFields.containsKey('HR_Support_Email__c')) {
            return;
        }

        Account employer = new Account(Name = 'Sample Bank Pte Ltd');
        employer.put('HR_Support_Email__c', 'hr.support@samplebank.com');
        insert employer;

        Contact contactRecord = createSingpassPrehireContact('Pending', employer.Id);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-h');

        Test.setCurrentPage(Page.QRSiteSingpassPrehireImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-h');

        QRSiteSingpassPrehireImportantNotesCtrl controller = new QRSiteSingpassPrehireImportantNotesCtrl();
        controller.initPage();

        System.assert(controller.getSecurityParagraphs()[1].contains('hr.support@samplebank.com'));
    }

    private static void setBaseParams(Id contactId, Id requestItemId, String tokenValue) {
        ApexPages.currentPage().getParameters().put('ContactId', contactId);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItemId);
        ApexPages.currentPage().getParameters().put('token', tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
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

    private static Contact createSingpassPrehireContact(String consentStatus) {
        Account employer = new Account(Name = 'Sample Bank Pte Ltd');
        insert employer;
        return createSingpassPrehireContact(consentStatus, employer.Id);
    }

    private static Contact createSingpassPrehireContact(String consentStatus, Id accountId) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();

        Contact contactRecord = new Contact(
            LastName = 'Singpass Prehire',
            Email = 'singpass.prehire+' + uniqueSuffix + '@example.com',
            AccountId = accountId,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = 'Singpass Prehire',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Employment_Status__c = 'Pre-hire',
            Current_Consent_Status__c = consentStatus
        );
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', 'Singpass');
        }
        if (contactFields.containsKey('Consent_Type__c')) {
            contactRecord.put('Consent_Type__c', 'Per-Report Consent');
        }
        insert contactRecord;
        return contactRecord;
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