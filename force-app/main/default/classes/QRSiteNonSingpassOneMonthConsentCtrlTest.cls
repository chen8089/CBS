@isTest
private class QRSiteNonSingpassOneMonthConsentCtrlTest {
    @isTest
    static void prehireFlowLoadsAndSubmitsSuccessfully() {
        Account accountRecord = new Account(Name = 'One Month Consent Bank');
        insert accountRecord;

        String employmentStatusValue = resolvePicklistValue(Contact.Employment_Status__c.getDescribe(), 'Pre-hire');
        String authTypeValue = resolvePicklistValue(Contact.Authentication_Type__c.getDescribe(), 'Non-Singpass');
        String consentTypeValue = resolvePicklistValue(Contact.Consent_Type__c.getDescribe(), 'Per-Report Consent');
        String pendingStatusValue = resolvePicklistValue(Contact.Current_Consent_Status__c.getDescribe(), 'Pending');
        String passTypeValue = resolvePicklistValue(Contact.Pass_Type__c.getDescribe(), 'Employment Pass');
        String idTypeValue = resolvePicklistValue(Contact.ID_Type__c.getDescribe(), 'Passport');
        String genderValue = resolvePicklistValue(Contact.Gender__c.getDescribe(), 'Female');
        String nationalityValue = resolvePicklistValue(Contact.Nationality__c.getDescribe(), 'Singapore');
        String maritalStatusValue = resolvePicklistValue(Contact.Marital_Status__c.getDescribe(), 'Single');

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'OneMonth Prehire',
            Email = 'one.month.prehire+' + uniqueSuffix + '@example.com',
            AccountId = accountRecord.Id,
            Employment_Status__c = employmentStatusValue,
            Authentication_Type__c = authTypeValue,
            Consent_Type__c = consentTypeValue,
            Current_Consent_Status__c = pendingStatusValue,
            Principal_Name__c = 'One Month Name',
            Full_Name__c = 'One Month Name',
            ID_Type__c = idTypeValue,
            ID_Number__c = 'OM' + uniqueSuffix.right(7),
            Pass_Type__c = passTypeValue,
            Passport_Number__c = 'P' + uniqueSuffix.right(7),
            Date_of_Birth__c = Date.newInstance(1991, 1, 1),
            Nationality__c = nationalityValue,
            Gender__c = genderValue,
            Marital_Status__c = maritalStatusValue,
            Registered_Address__c = '1 One Month Street'
        );
        insert contactRecord;

        String requestStatusValue = resolvePicklistValue(
            Consent_Request_Item__c.Current_Status__c.getDescribe(),
            'Sent'
        );
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = requestStatusValue,
            Uploaded_Full_Name__c = contactRecord.Full_Name__c,
            Uploaded_ID_Number__c = contactRecord.ID_Number__c
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;

        String tokenValue = ConsentTestSupport.getStoredTokenForRequestItem(requestItem.Id);

        Test.setCurrentPage(Page.QRSiteNonSingpassOneMonthConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contactRecord.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', tokenValue);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'nonsingpass');
        ApexPages.currentPage().getParameters().put('subjectType', 'prehire');

        QRSiteNonSingpassOneMonthConsentCtrl controller = new QRSiteNonSingpassOneMonthConsentCtrl();
        PageReference initResult = controller.initPage();
        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.getShowPage());

        // Exercise delegated getters/setters for wrapper coverage.
        controller.setContactId(controller.getContactId());
        controller.setRequestItemId(controller.getRequestItemId());
        controller.setToken(controller.getToken());
        controller.setEntryAction('authorize');
        controller.setEntryType('prehire');
        controller.setEntryAuthType('nonsingpass');
        controller.setEntrySubjectType('prehire');
        System.assertEquals('authorize', controller.getEntryAction());
        System.assertEquals('prehire', controller.getEntryType());
        System.assertEquals('nonsingpass', controller.getEntryAuthType());
        System.assertEquals('prehire', controller.getEntrySubjectType());
        System.assert(!String.isBlank(controller.getSubmissionTitle()));
        System.assert(!String.isBlank(controller.getDisplayDataSubjectName()));
        System.assert(!String.isBlank(controller.getDisplayPrincipalName()));
        System.assert(!String.isBlank(controller.getDisplayPassType()));
        System.assert(!String.isBlank(controller.getDisplayIdNumber()));
        System.assert(!String.isBlank(controller.getDisplayPassportNumber()));
        System.assert(!String.isBlank(controller.getDisplayDateOfBirth()));
        System.assert(!String.isBlank(controller.getDisplayNationality()));
        System.assert(!String.isBlank(controller.getDisplayGender()));
        System.assert(!String.isBlank(controller.getDisplayMaritalStatus()));
        System.assert(!String.isBlank(controller.getDisplayRegisteredAddress()));
        System.assert(!String.isBlank(controller.getDisplayEmailSubjectTitle()));
        System.assert(!String.isBlank(controller.getBankName()));
        System.assert(!String.isBlank(controller.getSupportingDocumentsNote()));
        System.assert(!String.isBlank(controller.getConsentCheckboxIntro()));
        System.assert(controller.getConsentAuthorisationParagraphs().size() > 0);
        System.assert(!String.isBlank(controller.getConsentValidityIntro()));
        System.assert(controller.getConsentValidityItems().size() > 0);
        System.assert(controller.getDisclaimerParagraphs().size() > 0);
        System.assert(!String.isBlank(controller.getSubmitButtonLabel()));

        controller.setInputPrincipalName('Updated One Month Name');
        controller.setInputIdType(idTypeValue);
        controller.setInputIdNumber('UPDATED1234');
        controller.setInputPassType(passTypeValue);
        controller.setInputPassportNumber('UPDATEDPASS');
        controller.setInputDateOfBirth(Date.newInstance(1992, 2, 2));
        controller.setInputNationality(nationalityValue);
        controller.setInputGender(genderValue);
        controller.setInputMaritalStatus(maritalStatusValue);
        controller.setInputRegisteredAddress('Updated One Month Address');
        controller.setHasAcceptedConsent(true);
        System.assertEquals(true, controller.getHasAcceptedConsent());
        Test.startTest();
        PageReference submitResult = controller.submitConsent();
        Test.stopTest();

        System.assertNotEquals(null, submitResult);
        System.assert(submitResult.getUrl().contains('/apex/ConsentSuccessPage'));

        Contact updatedContact = [
            SELECT
                Principal_Name__c,
                Full_Name__c,
                ID_Number__c,
                Passport_Number__c,
                Date_of_Birth__c,
                Registered_Address__c,
                Data_Subject_Lifecycle_Stage__c,
                Current_Consent_Status__c
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];
        System.assertEquals('Updated One Month Name', updatedContact.Principal_Name__c);
        System.assertEquals('Updated One Month Name', updatedContact.Full_Name__c);
        System.assertEquals('UPDATED1234', updatedContact.ID_Number__c);
        System.assertEquals('UPDATEDPASS', updatedContact.Passport_Number__c);
        System.assertEquals(Date.newInstance(1992, 2, 2), updatedContact.Date_of_Birth__c);
        System.assertEquals('Updated One Month Address', updatedContact.Registered_Address__c);
        System.assertEquals('Active Consent', updatedContact.Data_Subject_Lifecycle_Stage__c);
        System.assertEquals('Authorized', updatedContact.Current_Consent_Status__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Submitted', updatedRequestItem.Current_Status__c);
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
}