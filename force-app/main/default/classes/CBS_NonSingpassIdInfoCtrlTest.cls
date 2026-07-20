@isTest
private class CBS_NonSingpassIdInfoCtrlTest {
    @isTest
    static void continueToConsent_successPath() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.CBS_NonSingpassIdentityInfoPage);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        Test.startTest();
        CBS_NonSingpassIdentityInfoController controller = new CBS_NonSingpassIdentityInfoController();
        controller.principalName = 'Updated Principal';
        controller.passType = getPicklistValue('Contact', 'Pass_Type__c', 0);
        controller.passportNumber = 'P9988776';
        controller.dateOfBirth = Date.newInstance(1990, 10, 5);
        controller.nationality = 'Indian';
        controller.gender = 'Female';
        controller.maritalStatus = getPicklistValue('Contact', 'Marital_Status__c', 0);
        controller.registeredAddress = '10 Updated Street';
        controller.declarationInfoAccurate = true;
        controller.declarationDocumentConsent = true;
        controller.passportBody = Blob.valueOf('passport-content');
        controller.passportFileName = 'passport.pdf';
        controller.selfieBody = Blob.valueOf('selfie-content');
        controller.selfieFileName = 'selfie.jpg';

        PageReference nextPage = controller.continueToConsent();
        Test.stopTest();

        System.assertNotEquals(null, nextPage, controller.lastErrorDetails == null ? 'Continue returned null unexpectedly.' : controller.lastErrorDetails);
        System.assert(nextPage.getUrl().contains('/apex/QRSiteNonSingpassConsentForm'));
        System.assert(nextPage.getUrl().contains('stage=pg3'));

        Contact refreshed = [
            SELECT Principal_Name__c, Passport_Number__c, Registered_Address__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Updated Principal', refreshed.Principal_Name__c);
        System.assertEquals('P9988776', refreshed.Passport_Number__c);
        System.assertEquals('10 Updated Street', refreshed.Registered_Address__c);

        Integer caseCount = [SELECT COUNT() FROM Case WHERE ContactId = :contact.Id AND Subject LIKE 'Manual identity verification required -%'];
        System.assertEquals(1, caseCount);

        Integer fileLinkCount = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :requestItem.Id];
        System.assert(fileLinkCount > 0);
    }

    @isTest
    static void continueToConsent_missingRequiredFields() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.CBS_NonSingpassIdentityInfoPage);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('subjectType', 'prehire');

        Test.startTest();
        CBS_NonSingpassIdentityInfoController controller = new CBS_NonSingpassIdentityInfoController();
        PageReference nextPage = controller.continueToConsent();
        Test.stopTest();

        System.assertEquals(null, nextPage);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void controller_invalidLink() {
        Test.setCurrentPage(Page.CBS_NonSingpassIdentityInfoPage);
        ApexPages.currentPage().getParameters().put('action', 'consent');

        Test.startTest();
        CBS_NonSingpassIdentityInfoController controller = new CBS_NonSingpassIdentityInfoController();
        PageReference nextPage = controller.continueToConsent();
        Test.stopTest();

        System.assertEquals(false, controller.getCanRenderForm());
        System.assertEquals(null, nextPage);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void continueToConsent_unsupportedFileType() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        Test.setCurrentPage(Page.CBS_NonSingpassIdentityInfoPage);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        Test.startTest();
        CBS_NonSingpassIdentityInfoController controller = new CBS_NonSingpassIdentityInfoController();
        controller.principalName = 'Updated Principal';
        controller.passType = getPicklistValue('Contact', 'Pass_Type__c', 0);
        controller.passportNumber = 'P9988776';
        controller.dateOfBirth = Date.newInstance(1990, 10, 5);
        controller.nationality = 'Indian';
        controller.gender = 'Female';
        controller.registeredAddress = '10 Updated Street';
        controller.declarationInfoAccurate = true;
        controller.declarationDocumentConsent = true;
        controller.passportBody = Blob.valueOf('passport-content');
        controller.passportFileName = 'passport.exe';
        controller.selfieBody = Blob.valueOf('selfie-content');
        controller.selfieFileName = 'selfie.jpg';

        PageReference nextPage = controller.continueToConsent();
        Test.stopTest();

        System.assertEquals(null, nextPage);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void controller_duplicateOrAlreadySubmitted() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;

        Test.setCurrentPage(Page.CBS_NonSingpassIdentityInfoPage);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        Test.startTest();
        CBS_NonSingpassIdentityInfoController controller = new CBS_NonSingpassIdentityInfoController();
        PageReference nextPage = controller.continueToConsent();
        Test.stopTest();

        System.assertEquals(false, controller.getCanRenderForm());
        System.assertEquals(null, nextPage);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'Identity Info Test',
            Email = 'identity.info+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1992, 3, 15),
            DOB__c = Date.newInstance(1992, 3, 15),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Identity Info Test',
            ID_Number__c = 'P' + uniqueSuffix.right(7),
            ID_Type__c = 'Passport',
            Portal_Role__c = 'Approver',
            Principal_Name__c = 'Initial Principal',
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

    private static Consent_Request_Item__c createRequestItem(Contact contact) {
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent',
            Uploaded_Full_Name__c = contact.Full_Name__c,
            Uploaded_ID_Number__c = contact.ID_Number__c,
            Uploaded_Date_of_Birth__c = contact.Date_of_Birth__c
        );
        insert requestItem;
        return requestItem;
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
}