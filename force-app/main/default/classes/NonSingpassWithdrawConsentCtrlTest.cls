@isTest
private class NonSingpassWithdrawConsentCtrlTest {
    @isTest
    static void initPageRendersForActiveConsent() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'nswc-token-a');

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'nswc-token-a');

        NonSingpassWithdrawalConsentController controller = new NonSingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Withdrawal Test Subject', controller.principalName);
        System.assertEquals('Sample Bank Pte Ltd', controller.employerBankName);
        System.assertEquals('Active', controller.currentConsentStatus);
        System.assertEquals('Withdrawal of Consent and Authorisation', controller.getPageSubtitle());
        System.assert(controller.getIntroLine().contains('withdraw the consent previously given'));
        System.assertEquals('employment-related credit assessment / background screening', controller.getPurposeDescription());
        System.assertEquals('5 years from the date of submission, unless withdrawn earlier', controller.getConsentValidityDescription());
        System.assertEquals('Employee', controller.getEmploymentStatusLabel());
        System.assert(controller.getWithdrawalCheckboxText().contains('I WITHDRAW MY CONSENT'));
        System.assert(controller.getSupportingVerificationText().contains('supporting identity verification'));
        System.assertEquals('Please email the supporting documents directly to CBS at:', controller.getVerificationEmailLabelText());
        System.assert(!String.isBlank(controller.getVerificationEmailAddress()));
        System.assertEquals(4, controller.getSupportingDocumentIncludes().size());
        System.assertEquals(2, controller.getSupportingDocumentTypes().size());
        System.assertEquals(5, controller.getWithdrawalConsequenceClauses().size());
        System.assertEquals(true, controller.getIsIdTypeReadOnly());
        System.assertEquals(true, controller.getIsIdNumberReadOnly());
        System.assertEquals(false, controller.getIsPreHire());

        Contact preHireContact = createContactWithEmployer('Authorized', 'Non-Singpass', 'Pre-Hire');
        Consent__c preHireConsent = createActiveConsent(preHireContact);
        Consent_Request_Item__c preHireItem = createRequestItem(preHireContact, 'Submitted', 'nswc-token-prehire');
        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(preHireContact.Id, preHireConsent.Id, preHireItem.Id, 'nswc-token-prehire');
        NonSingpassWithdrawalConsentController preHireController = new NonSingpassWithdrawalConsentController();
        preHireController.initPage();
        System.assertEquals(true, preHireController.getIsPreHire());
        System.assertEquals('Pre-Hire', preHireController.getEmploymentStatusLabel());
        System.assert(preHireController.getPurposeDescription().contains('pre-employment'));
    }

    @isTest
    static void submitWithdrawalUpdatesConsentAndContact() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'nswc-token-b');

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'nswc-token-b');

        NonSingpassWithdrawalConsentController controller = new NonSingpassWithdrawalConsentController();
        controller.initPage();
        controller.principalName = 'Updated Withdrawal Subject';
        controller.idType = resolvePicklistValue(Contact.ID_Type__c.getDescribe(), 'NRIC');
        controller.idNumber = 'S1234567A';
        controller.passType = resolvePicklistValue(Contact.Pass_Type__c.getDescribe(), 'Employment Pass');
        controller.passportNumber = 'P1234567';
        controller.dateOfBirthInput = '1990-01-01';
        controller.nationality = 'Singapore';
        controller.gender = 'Male';
        controller.registeredAddress = '1 Test Street';
        controller.hasConfirmedWithdrawal = true;

        Test.startTest();
        PageReference submitResult = controller.submitWithdrawal();
        Test.stopTest();

        System.assertNotEquals(null, submitResult);
        System.assert(submitResult.getUrl().contains('CBSWithdrawSuccessPage'));

        Consent__c updatedConsent = [
            SELECT Consent_Status__c, Revoked_At__c, Action_Type__c, Withdrawn_By_Client__c
            FROM Consent__c
            WHERE Id = :consentRecord.Id
        ];
        System.assertEquals('Withdrawn', updatedConsent.Consent_Status__c);
        System.assertNotEquals(null, updatedConsent.Revoked_At__c);
        System.assertEquals('Consent Withdrawn', updatedConsent.Action_Type__c);
        System.assertEquals(true, updatedConsent.Withdrawn_By_Client__c);

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c, Passport_Number__c
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];
        System.assertEquals('Withdrawn', updatedContact.Current_Consent_Status__c);
        System.assertEquals('Consent Withdrawn', updatedContact.Data_Subject_Lifecycle_Stage__c);
        System.assertEquals('P1234567', updatedContact.Passport_Number__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Withdrawn', updatedRequestItem.Current_Status__c);
    }

    @isTest
    static void submitWithdrawalRequiresIdentityFieldsAndCheckbox() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Non-Singpass', 'Pre-Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'nswc-token-c');

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'nswc-token-c');

        NonSingpassWithdrawalConsentController controller = new NonSingpassWithdrawalConsentController();
        controller.initPage();
        controller.hasConfirmedWithdrawal = false;
        controller.principalName = '';
        controller.dateOfBirthInput = 'bad-date';

        PageReference submitResult = controller.submitWithdrawal();
        System.assertEquals(null, submitResult);
        System.assertEquals(true, ApexPages.hasMessages(ApexPages.Severity.ERROR));
    }

    @isTest
    static void submitWithdrawalRejectsInvalidIdentityValues() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'nswc-token-invalid');

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'nswc-token-invalid');

        NonSingpassWithdrawalConsentController controller = new NonSingpassWithdrawalConsentController();
        controller.initPage();
        controller.hasConfirmedWithdrawal = true;
        controller.principalName = 'Invalid @ Name';
        controller.idType = 'NRIC!';
        controller.idNumber = 'S1234567A#';
        controller.passportNumber = 'P1234567#';
        controller.dateOfBirthInput = String.valueOf(Date.today().addDays(1));

        PageReference submitResult = controller.submitWithdrawal();

        System.assertEquals(null, submitResult);
        System.assertEquals(true, ApexPages.hasMessages(ApexPages.Severity.ERROR));
    }

    @isTest
    static void initPageRedirectsForAlreadyActionedConsent() {
        Contact contactRecord = createContactWithEmployer('Withdrawn', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        consentRecord.Consent_Status__c = 'Withdrawn';
        update consentRecord;
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Withdrawn', 'nswc-token-d');

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'nswc-token-d');

        NonSingpassWithdrawalConsentController controller = new NonSingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();
        System.assertNotEquals(null, initResult);
        System.assert(initResult.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void initPageRedirectsToNoActiveConsentWhenAlreadyWithdrawnLifecycleAndStatus() {
        Contact contactRecord = createContactWithEmployer('Withdrawn', 'Non-Singpass', 'Existing Hire');
        setContactLifecycleStage(contactRecord.Id, 'Consent Withdrawn');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Withdrawn', 'nswc-token-e');

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, null, requestItem.Id, 'nswc-token-e');

        NonSingpassWithdrawalConsentController controller = new NonSingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();
        System.assertNotEquals(null, initResult);
        System.assert(initResult.getUrl().contains('/apex/NoActiveConsentPage'));
    }

    @isTest
    static void initPageBlocksInvalidAndExpiredLinks() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Non-Singpass', 'Existing Hire');
        Consent__c consentRecord = createActiveConsent(contactRecord);
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'nswc-token-expired');
        requestItem.Consent_Link_Expires_At__c = System.now().addDays(-1);
        update requestItem;

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'wrong-token');

        NonSingpassWithdrawalConsentController invalidTokenController = new NonSingpassWithdrawalConsentController();
        PageReference invalidTokenResult = invalidTokenController.initPage();
        System.assertEquals(null, invalidTokenResult);
        System.assertEquals(false, invalidTokenController.showPage);

        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'nswc-token-expired');

        NonSingpassWithdrawalConsentController expiredController = new NonSingpassWithdrawalConsentController();
        PageReference expiredResult = expiredController.initPage();
        System.assertEquals(null, expiredResult);
        System.assertEquals(false, expiredController.showPage);
    }

    @isTest
    static void initPageHandlesMalformedContactId() {
        Test.setCurrentPage(Page.NonSingpassWithdrawalConsentPage);
        ApexPages.currentPage().getParameters().put('ContactId', 'not-a-contact-id');
        ApexPages.currentPage().getParameters().put('token', 'bad-token');

        NonSingpassWithdrawalConsentController controller = new NonSingpassWithdrawalConsentController();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(false, controller.showPage);
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
            LastName = 'Withdrawal Subject',
            Email = 'withdraw.non-singpass+' + uniqueSuffix + '@example.com',
            AccountId = employer.Id,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Full_Name__c = 'Withdrawal Test Subject',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = resolvePicklistValue(Contact.ID_Type__c.getDescribe(), 'NRIC'),
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
            Action_Type__c = 'Consent Given',
            MyInfo_ID_Number__c = contactRecord.ID_Number__c,
            MyInfo_Date_of_Birth__c = contactRecord.Date_of_Birth__c
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

    private static String resolvePicklistValue(Schema.DescribeFieldResult describe, String preferredValue) {
        if (describe == null) {
            return preferredValue;
        }
        List<Schema.PicklistEntry> entries = describe.getPicklistValues();
        if (entries.isEmpty()) {
            return preferredValue;
        }
        for (Schema.PicklistEntry entry : entries) {
            if (entry.getValue() == preferredValue || entry.getLabel() == preferredValue) {
                return entry.getValue();
            }
        }
        return entries[0].getValue();
    }

    private static void setContactLifecycleStage(Id contactId, String preferredValue) {
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (!contactFields.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            return;
        }
        Contact updateContact = new Contact(
            Id = contactId,
            Data_Subject_Lifecycle_Stage__c =
                resolvePicklistValue(Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(), preferredValue)
        );
        update updateContact;
    }
}