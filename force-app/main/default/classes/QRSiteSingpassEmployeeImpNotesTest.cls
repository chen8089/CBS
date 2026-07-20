@isTest
private class QRSiteSingpassEmployeeImpNotesTest {
    @isTest
    static void initializePageShowsImportantNotesForValidLink() {
        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-emp-1');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-emp-1');

        QRSiteSingpassEmployeeImportantNotesCtrl controller = new QRSiteSingpassEmployeeImportantNotesCtrl();
        PageReference result = controller.initializePage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.canRenderPage);
        System.assertEquals('Important Notes Before You Proceed', controller.getPageTitle());
        System.assertEquals('Singpass Employee - 5-year Term-based Consent', controller.getPageSubtitle());
        System.assert(controller.getIntroText().contains('Sample Bank Pte Ltd'));
        System.assert(controller.getSection1Point1().contains('Sample Bank Pte Ltd'));
        System.assert(controller.getSection1Point2().contains('consent form'));
        System.assert(controller.getSection3Point1().contains('Sample Bank Pte Ltd'));
        System.assert(controller.getSection4Point3().contains('will be notified'));
        System.assert(controller.getSection4Point4().contains('will not be able'));
        System.assert(controller.getSection5Point1().contains('withdraw your consent later'));
        System.assert(controller.getSection5Point3().contains('new credit report request'));
        System.assert(controller.getSection6Point2().contains('Human Resources'));
    }

    @isTest
    static void initializePageRedirectsWhenTokenMissing() {
        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-emp-2');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);

        QRSiteSingpassEmployeeImportantNotesCtrl controller = new QRSiteSingpassEmployeeImportantNotesCtrl();
        PageReference result = controller.initializePage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void continueWithSingpassRedirectsToAuthPage() {
        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-emp-3');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-emp-3');

        QRSiteSingpassEmployeeImportantNotesCtrl controller = new QRSiteSingpassEmployeeImportantNotesCtrl();
        controller.initializePage();
        PageReference result = controller.continueWithSingpass();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/ndi_auth'));
        System.assertEquals('authorize', result.getParameters().get('action'));
        System.assertEquals('employee', result.getParameters().get('type'));
        System.assertEquals('singpass', result.getParameters().get('authType'));
        System.assertEquals(String.valueOf(contactRecord.Id), result.getParameters().get('ContactId'));
    }

    @isTest
    static void declineConsentRedirectsToConfirmationPage() {
        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-emp-4');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-emp-4');

        QRSiteSingpassEmployeeImportantNotesCtrl controller = new QRSiteSingpassEmployeeImportantNotesCtrl();
        controller.initializePage();
        PageReference result = controller.declineConsent();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteDeclineConfirmation'));
    }

    @isTest
    static void initializePageRedirectsForActionedAndExpiredStatuses() {
        Contact activeContact = createSingpassEmployeeContact('Authorized');
        Consent_Request_Item__c activeItem = createRequestItem(activeContact, 'Sent', 'token-emp-5');
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(activeContact.Id, activeItem.Id, 'token-emp-5');
        QRSiteSingpassEmployeeImportantNotesCtrl activeController = new QRSiteSingpassEmployeeImportantNotesCtrl();
        System.assert(activeController.initializePage().getUrl().contains('/apex/QRSiteActiveConsentNotification'));

        Contact declinedContact = createSingpassEmployeeContact('Declined');
        Consent_Request_Item__c declinedItem = createRequestItem(declinedContact, 'Sent', 'token-emp-6');
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(declinedContact.Id, declinedItem.Id, 'token-emp-6');
        QRSiteSingpassEmployeeImportantNotesCtrl declinedController = new QRSiteSingpassEmployeeImportantNotesCtrl();
        System.assert(declinedController.initializePage().getUrl().contains('/apex/QRSiteConsentAlreadyActioned'));

        Contact pendingContact = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c expiredItem = createRequestItem(pendingContact, 'Sent', 'token-emp-7');
        expiredItem.Consent_Link_Expires_At__c = System.now().addDays(-1);
        update expiredItem;
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(pendingContact.Id, expiredItem.Id, 'token-emp-7');
        QRSiteSingpassEmployeeImportantNotesCtrl expiredController = new QRSiteSingpassEmployeeImportantNotesCtrl();
        System.assert(expiredController.initializePage().getUrl().contains('/apex/QRSiteLinkExpired'));
    }

    @isTest
    static void initializePageRedirectsWhenActionIsInvalid() {
        Contact contactRecord = createSingpassEmployeeContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Sent', 'token-emp-8');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setBaseParams(contactRecord.Id, requestItem.Id, 'token-emp-8');
        ApexPages.currentPage().getParameters().put('action', 'withdraw');

        QRSiteSingpassEmployeeImportantNotesCtrl controller = new QRSiteSingpassEmployeeImportantNotesCtrl();
        PageReference result = controller.initializePage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    private static void setBaseParams(Id contactId, Id requestItemId, String tokenValue) {
        ApexPages.currentPage().getParameters().put('ContactId', contactId);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItemId);
        ApexPages.currentPage().getParameters().put('token', tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
    }

    private static Contact createSingpassEmployeeContact(String consentStatus) {
        Account employer = new Account(Name = 'Sample Bank Pte Ltd');
        insert employer;

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'Employee Notes Test',
            Email = 'employee.notes+' + uniqueSuffix + '@example.com',
            AccountId = employer.Id,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = 'Employee Notes Test',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Employment_Status__c = 'Existing Hire',
            Current_Consent_Status__c = consentStatus
        );
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
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
        insert requestItem;
        return requestItem;
    }
}