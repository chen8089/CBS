@isTest
private class QRSiteNonSingpassPrehireConsentCtrlTest {
    @isTest
    static void initPageLoadsFormValues() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteNonSingpassPrehireConsentForm);
        ApexPages.currentPage().getParameters().put('contactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'prehire');

        QRSiteNonSingpassPrehireConsentCtrl controller = new QRSiteNonSingpassPrehireConsentCtrl();
        PageReference initResult = controller.initPage();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.getShowConsentForm());
        System.assertEquals('Test Principal', controller.principalName);
        System.assertEquals('Passport', controller.idType);
        System.assertEquals(contact.ID_Number__c, controller.idNumber);
        System.assertEquals('15 March 1992', controller.dateOfBirthDisplay);
    }

    @isTest
    static void submitConsentRequiresConsentCheckbox() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteNonSingpassPrehireConsentForm);
        ApexPages.currentPage().getParameters().put('contactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'prehire');

        Test.startTest();
        QRSiteNonSingpassPrehireConsentCtrl controller = new QRSiteNonSingpassPrehireConsentCtrl();
        controller.initPage();
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :contact.Id]);
    }

    @isTest
    static void submitConsentCreatesPendingVerificationConsent() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteNonSingpassPrehireConsentForm);
        ApexPages.currentPage().getParameters().put('contactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'prehire');

        Test.startTest();
        QRSiteNonSingpassPrehireConsentCtrl controller = new QRSiteNonSingpassPrehireConsentCtrl();
        controller.initPage();
        controller.hasAcceptedConsent = true;
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected redirect to success page.');
        System.assert(result.getUrl().contains('/apex/ConsentSuccessPage'));
        System.assertNotEquals(null, result.getParameters().get('consentId'));

        Consent__c createdConsent = [
            SELECT Consent_Status__c, Consent_Expiry_Date__c, Submitted_At__c, MyInfo_Name__c, MyInfo_ID_Number__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertNotEquals(null, createdConsent.Submitted_At__c);
        System.assertNotEquals('Active', createdConsent.Consent_Status__c);
        System.assertNotEquals('Valid', createdConsent.Consent_Status__c);
        System.assertEquals(Date.today().addMonths(1), createdConsent.Consent_Expiry_Date__c);
        System.assertEquals('Test Principal', createdConsent.MyInfo_Name__c);
        System.assertEquals(contact.ID_Number__c, createdConsent.MyInfo_ID_Number__c);

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Current_Consent_Expiry_Date__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals(Date.today().addMonths(1), updatedContact.Current_Consent_Expiry_Date__c);
        System.assertNotEquals('Authorized', updatedContact.Current_Consent_Status__c);
        System.assertNotEquals('Valid', updatedContact.Current_Consent_Status__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertNotEquals('Submitted', updatedRequestItem.Current_Status__c);
    }

    @isTest
    static void declineConsentRedirectsToConfirmation() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteNonSingpassPrehireConsentForm);
        ApexPages.currentPage().getParameters().put('contactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'prehire');

        QRSiteNonSingpassPrehireConsentCtrl controller = new QRSiteNonSingpassPrehireConsentCtrl();
        controller.initPage();
        PageReference declineResult = controller.declineConsent();

        System.assertNotEquals(null, declineResult);
        System.assert(declineResult.getUrl().contains('/apex/CBSDeclineConsentConfirmation'));
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'NonSingpass Prehire Test',
            Email = 'nonsingpass.prehire+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1992, 3, 15),
            DOB__c = Date.newInstance(1992, 3, 15),
            Employment_Status__c = 'Pre-hire',
            Full_Name__c = 'NonSingpass Prehire Test',
            ID_Number__c = 'P' + uniqueSuffix.right(7),
            ID_Type__c = 'Passport',
            Portal_Role__c = 'Approver',
            Principal_Name__c = 'Test Principal',
            Pass_Type__c = getPicklistValue('Contact', 'Pass_Type__c', 0),
            Passport_Number__c = 'P1234567',
            Nationality__c = 'Malaysian',
            Gender__c = 'Female',
            Marital_Status__c = getPicklistValue('Contact', 'Marital_Status__c', 0),
            Registered_Address__c = '1 Test Street'
        );
        insert contact;
        return contact;
    }

    private static String getPicklistValue(String objectApiName, String fieldApiName, Integer index) {
        Schema.DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe()
            .get(objectApiName)
            .getDescribe()
            .fields.getMap()
            .get(fieldApiName)
            .getDescribe();
        List<Schema.PicklistEntry> entries = fieldDescribe.getPicklistValues();
        Integer safeIndex = Math.mod(index, entries.size());
        return entries[safeIndex].getValue();
    }

    private static Consent_Request_Item__c createRequestItem(Contact contact) {
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent',
            Uploaded_Full_Name__c = contact.Full_Name__c,
            Uploaded_ID_Number__c = contact.ID_Number__c,
            Uploaded_Date_of_Birth__c = contact.Date_of_Birth__c,
            Uploaded_Email__c = contact.Email,
            Uploaded_ID_Type__c = contact.ID_Type__c
        );
        insert requestItem;
        return requestItem;
    }
}