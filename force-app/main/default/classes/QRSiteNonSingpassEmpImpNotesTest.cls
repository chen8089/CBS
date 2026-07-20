@isTest
private class QRSiteNonSingpassEmpImpNotesTest {
    @isTest
    static void initPageLoadsAndExposesContent() {
        TestData data = createTestData('Sent', 'Pending', null);
        Test.setCurrentPage(Page.QRSiteNonSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', data.tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        QRSiteNonSingpassEmpImportantNotesCtrl controller = new QRSiteNonSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Important Notes Before You Proceed', controller.getImportantNotesTitle());
        System.assert(controller.getWhatThisRequestIsForParagraphs().size() > 0);
        System.assert(controller.getIdentityVerificationParagraphs().size() > 0);
        System.assert(controller.getYourConsentParagraphs().size() > 0);
        System.assert(controller.getDeclineParagraphs().size() > 0);
        System.assert(controller.getWithdrawalParagraphs().size() > 0);
        System.assert(controller.getSecurityParagraphs().size() > 0);
        System.assert(controller.getConsentAuthorisationParagraphs().size() > 0);
        System.assert(controller.getConsentValidityItems().size() > 0);
        System.assert(controller.getDisclaimerParagraphs().size() > 0);
        System.assert(!String.isBlank(controller.getDisplayDataSubjectName()));
        System.assert(!String.isBlank(controller.getDisplayPrincipalName()));
        System.assert(!String.isBlank(controller.getDisplayPassType()));
        System.assert(!String.isBlank(controller.getDisplayIdNumber()));
        System.assert(!String.isBlank(controller.getDisplayPassportNumber()));
        System.assert(!String.isBlank(controller.getDisplayDateOfBirth()));
        System.assert(!String.isBlank(controller.getDisplayNationality()));
        System.assert(!String.isBlank(controller.getDisplayGender()));
        System.assert(!String.isBlank(controller.getDisplayRegisteredAddress()));
        System.assert(!String.isBlank(controller.getDisplayEmailSubjectTitle()));
    }

    @isTest
    static void initPageRedirectsForActiveConsent() {
        String activeLifecycle = resolvePicklistMatchOrNull(
            Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(),
            'Active Consent'
        );
        String authorizedStatus = resolvePicklistMatchOrNull(
            Contact.Current_Consent_Status__c.getDescribe(),
            'Authorized'
        );
        if (String.isBlank(activeLifecycle) || String.isBlank(authorizedStatus)) {
            System.assert(true);
            return;
        }
        TestData data = createTestData('Sent', authorizedStatus, activeLifecycle);
        Test.setCurrentPage(Page.QRSiteNonSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', data.tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        QRSiteNonSingpassEmpImportantNotesCtrl controller = new QRSiteNonSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();
        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/ActiveConsentNotificationPage'));
    }

    @isTest
    static void submitConsentRequiresCheckbox() {
        TestData data = createTestData('Sent', 'Pending', null);
        Test.setCurrentPage(Page.QRSiteNonSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', data.tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        QRSiteNonSingpassEmpImportantNotesCtrl controller = new QRSiteNonSingpassEmpImportantNotesCtrl();
        controller.initPage();
        controller.hasAcceptedConsent = false;

        PageReference result = controller.submitConsent();
        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void submitConsentValidatesEditableFields() {
        TestData data = createTestData('Sent', 'Pending', null);
        Test.setCurrentPage(Page.QRSiteNonSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', data.tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        QRSiteNonSingpassEmpImportantNotesCtrl controller = new QRSiteNonSingpassEmpImportantNotesCtrl();
        controller.initPage();
        controller.hasAcceptedConsent = true;
        controller.inputPrincipalName = '';
        controller.inputIdType = '';
        controller.inputIdNumber = '';
        controller.inputPassType = '';
        controller.inputPassportNumber = '';
        controller.inputDateOfBirth = Date.today().addDays(1);
        controller.inputNationality = '';
        controller.inputGender = '';
        controller.inputRegisteredAddress = '';

        PageReference result = controller.submitConsent();
        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void initPageRejectsInvalidScenario() {
        TestData data = createTestData('Sent', 'Pending', null);
        Test.setCurrentPage(Page.QRSiteNonSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', data.tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        QRSiteNonSingpassEmpImportantNotesCtrl controller = new QRSiteNonSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();
        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void submitConsentUpdatesContactAndRequestItem() {
        TestData data = createTestData('Sent', 'Pending', null);
        String passTypeValue = data.passTypeValue;
        String idTypeValue = data.idTypeValue;
        String genderValue = data.genderValue;
        String nationalityValue = data.nationalityValue;
        String maritalStatusValue = data.maritalStatusValue;

        Test.setCurrentPage(Page.QRSiteNonSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', data.contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', data.requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', data.tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'employee');

        QRSiteNonSingpassEmpImportantNotesCtrl controller = new QRSiteNonSingpassEmpImportantNotesCtrl();
        controller.initPage();
        controller.inputPrincipalName = 'Updated Name';
        controller.inputIdType = idTypeValue;
        controller.inputIdNumber = 'A9876543';
        controller.inputPassType = passTypeValue;
        controller.inputPassportNumber = 'E7654321';
        controller.inputDateOfBirth = Date.newInstance(1992, 2, 2);
        controller.inputNationality = nationalityValue;
        controller.inputGender = genderValue;
        controller.inputMaritalStatus = maritalStatusValue;
        controller.inputRegisteredAddress = 'Updated Registered Address';
        controller.hasAcceptedConsent = true;

        Test.startTest();
        PageReference result = controller.submitConsent();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('true', result.getParameters().get('completed'));
        System.assertEquals('submitted', result.getParameters().get('completedMode'));

        Contact updatedContact = [
            SELECT
                Principal_Name__c,
                Full_Name__c,
                ID_Type__c,
                ID_Number__c,
                Pass_Type__c,
                Passport_Number__c,
                Date_of_Birth__c,
                Nationality__c,
                Gender__c,
                Marital_Status__c,
                Registered_Address__c,
                Data_Subject_Lifecycle_Stage__c,
                Current_Consent_Status__c
            FROM Contact
            WHERE Id = :data.contactRecord.Id
        ];
        System.assertEquals('Updated Name', updatedContact.Principal_Name__c);
        System.assertEquals('Updated Name', updatedContact.Full_Name__c);
        System.assertEquals(idTypeValue, updatedContact.ID_Type__c);
        System.assertEquals('A9876543', updatedContact.ID_Number__c);
        System.assertEquals(passTypeValue, updatedContact.Pass_Type__c);
        System.assertEquals('E7654321', updatedContact.Passport_Number__c);
        System.assertEquals(Date.newInstance(1992, 2, 2), updatedContact.Date_of_Birth__c);
        System.assertEquals(nationalityValue, updatedContact.Nationality__c);
        System.assertEquals(genderValue, updatedContact.Gender__c);
        System.assertEquals(maritalStatusValue, updatedContact.Marital_Status__c);
        System.assertEquals('Updated Registered Address', updatedContact.Registered_Address__c);
        System.assertEquals('Active Consent', updatedContact.Data_Subject_Lifecycle_Stage__c);
        System.assertEquals('Authorized', updatedContact.Current_Consent_Status__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :data.requestItem.Id
        ];
        System.assertEquals('Submitted', updatedRequestItem.Current_Status__c);
    }

    private static TestData createTestData(String requestStatus, String contactStatus, String lifecycleStage) {
        Account accountRecord = new Account(Name = 'NonSingpass Emp Important Notes Bank');
        insert accountRecord;

        TestData data = new TestData();
        data.passTypeValue = resolvePicklistValue(Contact.Pass_Type__c.getDescribe(), 'Employment Pass');
        data.idTypeValue = resolvePicklistValue(Contact.ID_Type__c.getDescribe(), 'Passport');
        data.genderValue = resolvePicklistValue(Contact.Gender__c.getDescribe(), 'Female');
        data.nationalityValue = resolvePicklistValue(Contact.Nationality__c.getDescribe(), 'Singapore');
        data.maritalStatusValue = resolvePicklistValue(Contact.Marital_Status__c.getDescribe(), 'Single');
        String employmentStatusValue = resolvePicklistMatchOrNull(Contact.Employment_Status__c.getDescribe(), 'Existing Hire');
        String authTypeValue = resolvePicklistMatchOrNull(Contact.Authentication_Type__c.getDescribe(), 'Non-Singpass');
        String consentTypeValue = resolvePicklistMatchOrNull(Contact.Consent_Type__c.getDescribe(), 'Term Based Consent');
        String contactStatusValue = resolveContactStatus(contactStatus);
        String lifecycleValue = lifecycleStage == null
            ? null
            : resolvePicklistMatchOrNull(Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(), lifecycleStage);

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'NS Emp Notes',
            Email = 'ns-emp-notes+' + uniqueSuffix + '@example.com',
            AccountId = accountRecord.Id,
            Employment_Status__c = employmentStatusValue,
            Authentication_Type__c = authTypeValue,
            Consent_Type__c = consentTypeValue,
            Current_Consent_Status__c = contactStatusValue,
            Data_Subject_Lifecycle_Stage__c = lifecycleValue,
            Principal_Name__c = 'Old Name',
            Full_Name__c = 'Old Name',
            ID_Type__c = data.idTypeValue,
            ID_Number__c = 'OLD123456',
            Pass_Type__c = data.passTypeValue,
            Passport_Number__c = 'P1234567',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Nationality__c = data.nationalityValue,
            Gender__c = data.genderValue,
            Marital_Status__c = data.maritalStatusValue,
            Registered_Address__c = 'Old Address'
        );
        insert contactRecord;
        data.contactRecord = contactRecord;

        String requestStatusValue = resolveRequestStatus(requestStatus);
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Uploaded_Full_Name__c = contactRecord.Full_Name__c,
            Uploaded_ID_Number__c = contactRecord.ID_Number__c
        );
        if (!String.isBlank(requestStatusValue)) {
            requestItem.Current_Status__c = requestStatusValue;
        }
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        data.requestItem = requestItem;
        data.tokenValue = ConsentTestSupport.getStoredTokenForRequestItem(requestItem.Id);
        return data;
    }

    private static String resolvePicklistValue(Schema.DescribeFieldResult describe, String preferredValue) {
        if (describe == null) {
            return preferredValue;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.getValue().equalsIgnoreCase(preferredValue) || entry.getLabel().equalsIgnoreCase(preferredValue)) {
                return entry.getValue();
            }
        }
        return describe.getPicklistValues().isEmpty()
            ? preferredValue
            : describe.getPicklistValues()[0].getValue();
    }

    private static String resolvePicklistMatchOrNull(Schema.DescribeFieldResult describe, String preferredValue) {
        if (describe == null || String.isBlank(preferredValue)) {
            return null;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.getValue().equalsIgnoreCase(preferredValue) || entry.getLabel().equalsIgnoreCase(preferredValue)) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static String resolveRequestStatus(String preferredStatus) {
        String direct = resolvePicklistMatchOrNull(
            Consent_Request_Item__c.Current_Status__c.getDescribe(),
            preferredStatus
        );
        if (!String.isBlank(direct)) {
            return direct;
        }
        List<String> fallbacks = new List<String>{ 'Sent', 'Pending', 'Pending Verification', 'New', 'Draft' };
        for (String candidate : fallbacks) {
            String value = resolvePicklistMatchOrNull(
                Consent_Request_Item__c.Current_Status__c.getDescribe(),
                candidate
            );
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String resolveContactStatus(String preferredStatus) {
        String direct = resolvePicklistMatchOrNull(
            Contact.Current_Consent_Status__c.getDescribe(),
            preferredStatus
        );
        if (!String.isBlank(direct)) {
            return direct;
        }
        List<String> fallbacks = new List<String>{ 'Pending', 'Pending Verification', 'Verification Pending' };
        for (String candidate : fallbacks) {
            String value = resolvePicklistMatchOrNull(
                Contact.Current_Consent_Status__c.getDescribe(),
                candidate
            );
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private class TestData {
        Contact contactRecord;
        Consent_Request_Item__c requestItem;
        String tokenValue;
        String passTypeValue;
        String idTypeValue;
        String genderValue;
        String nationalityValue;
        String maritalStatusValue;
    }
}