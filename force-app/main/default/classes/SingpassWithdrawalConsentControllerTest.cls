@isTest
private class SingpassWithdrawalConsentControllerTest {
    @isTest
    static void initPageRendersForActiveSingpassWithdrawal() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-a');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-a');
        markWithdrawalAuthenticated(requestItem);

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.showPage);
        System.assertEquals('Withdrawal Test Subject', controller.principalName);
        System.assertEquals('Sample Bank Pte Ltd', controller.employerBankName);
        System.assertEquals('Existing Employee', controller.employmentStatus);
        System.assertEquals('Active', controller.currentConsentStatus);
        System.assertEquals('Withdrawal of Consent and Authorisation', controller.getPageSubtitle());
        System.assertEquals('Dear Withdrawal Test Subject,', controller.getGreeting());
        System.assertEquals('You have completed the required Singpass verification.', controller.getSingpassVerificationText());
        System.assertEquals('employment-related credit assessment', controller.getPurposeText());
        System.assertEquals('1. Submitted Consent', controller.getSectionOneTitle());
        System.assertEquals('2. Withdrawal Declaration', controller.getSectionTwoTitle());
        System.assertEquals('By selecting the checkbox and submitting this form, I confirm that:', controller.getDeclarationIntro());
        System.assert(controller.getWithdrawalDeclarationClauses()[0].contains('consumer credit report(s)'));
        System.assertEquals(3, controller.getWithdrawalDeclarationClauses().size());
        System.assertEquals(false, controller.getIsPreHire());
    }

    @isTest
    static void initPageRedirectsToSingpassAuthWhenNotVerified() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-b');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-b');

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();

        System.assertNotEquals(null, initResult);
        System.assert(initResult.getUrl().contains('/apex/ndi_auth'));
        System.assertEquals('/apex/SingpassWithdrawalConsentPage', initResult.getParameters().get('returnUrl'));
        System.assertEquals('withdraw', initResult.getParameters().get('action'));
    }

    @isTest
    static void initPageDoesNotAcceptUrlOnlyAuthenticationFlag() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-url-only');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-url-only');
        ApexPages.currentPage().getParameters().put('returnFromAuth', 'true');

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();

        System.assertNotEquals(null, initResult);
        System.assert(initResult.getUrl().contains('/apex/ndi_auth'));
    }

    @isTest
    static void initPageAcceptsQrAuthenticationFlag() {
        Contact contactRecord = createContactWithEmployer('Valid', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-c');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);
        requestItem.Withdrawal_QR_Viewed_At__c = System.now();
        update requestItem;

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-c');

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();

        System.assertEquals(null, initResult);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(true, controller.isSingpassVerificationComplete());
    }

    @isTest
    static void initPageRedirectsForInvalidAndTerminalStatuses() {
        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        ApexPages.currentPage().getParameters().put('ContactId', 'invalid-contact-id');
        ApexPages.currentPage().getParameters().put('token', 'bad-token');
        ApexPages.currentPage().getParameters().put('returnFromAuth', 'true');
        SingpassWithdrawalConsentController invalidController = new SingpassWithdrawalConsentController();
        System.assert(invalidController.initPage().getUrl().contains('/apex/QRSiteInvalidLink'));

        Contact withdrawnContact = createContactWithEmployer('Withdrawn', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c withdrawnItem = createRequestItem(withdrawnContact, 'Submitted', 'swc-token-d');
        Consent__c withdrawnConsent = createActiveConsent(withdrawnContact, withdrawnItem);
        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(withdrawnContact.Id, withdrawnConsent.Id, withdrawnItem.Id, 'swc-token-d');
        ApexPages.currentPage().getParameters().put('returnFromAuth', 'true');
        SingpassWithdrawalConsentController withdrawnController = new SingpassWithdrawalConsentController();
        System.assert(withdrawnController.initPage().getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));

        Contact pendingContact = createContactWithEmployer('Pending', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c pendingItem = createRequestItem(pendingContact, 'Submitted', 'swc-token-e');
        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(pendingContact.Id, null, pendingItem.Id, 'swc-token-e');
        ApexPages.currentPage().getParameters().put('returnFromAuth', 'true');
        SingpassWithdrawalConsentController noActiveController = new SingpassWithdrawalConsentController();
        PageReference noActiveResult = noActiveController.initPage();
        System.assert(noActiveResult.getUrl().contains('/apex/NoActiveConsentPage'));
        System.assertEquals('withdraw', noActiveResult.getParameters().get('action'));
    }

    @isTest
    static void submitWithdrawalUpdatesConsentContactAndRequestItem() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-f');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-f');
        markWithdrawalAuthenticated(requestItem);
        ApexPages.currentPage().getParameters().put('nric', contactRecord.ID_Number__c);
        ApexPages.currentPage().getParameters().put('dob', String.valueOf(contactRecord.Date_of_Birth__c));

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();
        System.assertEquals(null, initResult);
        controller.hasConfirmedWithdrawal = true;

        Test.startTest();
        PageReference submitResult = controller.submitWithdrawal();
        Test.stopTest();

        if (submitResult != null) {
            System.assertNotEquals(null, submitResult.getUrl());
            System.assert(
                submitResult.getUrl().contains('CBSWithdrawSuccessPage'),
                'Expected redirect to CBSWithdrawSuccessPage but was: ' + submitResult.getUrl()
            );
            System.assertEquals(String.valueOf(contactRecord.Id), submitResult.getParameters().get('ContactId'));
            System.assertEquals(String.valueOf(consentRecord.Id), submitResult.getParameters().get('consentId'));
            System.assertEquals('withdraw', submitResult.getParameters().get('action'));
        }

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
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c, Withdrawal_Date__c
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];
        System.assertEquals('Withdrawn', updatedContact.Current_Consent_Status__c);
        System.assertEquals('Consent Withdrawn', updatedContact.Data_Subject_Lifecycle_Stage__c);
        System.assertNotEquals(null, updatedContact.Withdrawal_Date__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Withdrawn', updatedRequestItem.Current_Status__c);
    }

    @isTest
    static void submitWithdrawalRequiresCheckboxAndActiveConsent() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-g');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-g');
        markWithdrawalAuthenticated(requestItem);

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        controller.initPage();
        controller.hasConfirmedWithdrawal = false;

        PageReference missingCheckboxResult = controller.submitWithdrawal();
        System.assertEquals(null, missingCheckboxResult);
        System.assertEquals(true, ApexPages.hasMessages(ApexPages.Severity.ERROR));

        controller.hasConfirmedWithdrawal = true;
        consentRecord.Consent_Status__c = 'Withdrawn';
        update consentRecord;
        contactRecord.Current_Consent_Status__c = 'Withdrawn';
        update contactRecord;

        PageReference inactiveResult = controller.submitWithdrawal();
        System.assertNotEquals(null, inactiveResult);
        System.assert(inactiveResult.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void submitWithdrawalFailsWhenSingpassIdentityDoesNotMatch() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        contactRecord.ID_Number__c = 'S1234567A';
        update contactRecord;

        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-h');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);
        consentRecord.MyInfo_ID_Number__c = 'S1234567A';
        update consentRecord;

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-h');
        markWithdrawalAuthenticated(requestItem);

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        controller.initPage();
        controller.hasConfirmedWithdrawal = true;
        ApexPages.currentPage().getParameters().put('nric', 'S9999999Z');

        PageReference submitResult = controller.submitWithdrawal();
        System.assertNotEquals(null, submitResult);
        System.assert(submitResult.getUrl().contains('/apex/QRSiteInvalidLink'));

        Consent__c unchangedConsent = [
            SELECT Consent_Status__c
            FROM Consent__c
            WHERE Id = :consentRecord.Id
        ];
        System.assertEquals('Active', unchangedConsent.Consent_Status__c);
    }

    @isTest
    static void initPageRedirectsWhenSingpassIdentityDoesNotMatch() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Existing Hire');
        contactRecord.ID_Number__c = 'S1234567A';
        update contactRecord;
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-k');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-k');
        markWithdrawalAuthenticated(requestItem);
        ApexPages.currentPage().getParameters().put('nric', 'S9999999Z');

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        PageReference initResult = controller.initPage();
        System.assert(initResult.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void preHireScenarioShowsPreHireLabelsAndClause() {
        Contact contactRecord = createContactWithEmployer('Authorized', 'Singpass', 'Pre-Hire');
        Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'swc-token-j');
        Consent__c consentRecord = createActiveConsent(contactRecord, requestItem);

        Test.setCurrentPage(Page.SingpassWithdrawalConsentPage);
        setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'swc-token-j');
        markWithdrawalAuthenticated(requestItem);

        SingpassWithdrawalConsentController controller = new SingpassWithdrawalConsentController();
        controller.initPage();

        System.assertEquals('Pre-Hire', controller.employmentStatus);
        System.assertEquals(true, controller.getIsPreHire());
        System.assertEquals('pre-employment screening', controller.getPurposeText());
        System.assert(controller.getWithdrawalDeclarationClauses()[2].contains('will not be able to submit any new credit report request(s)'));
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

    private static void markWithdrawalAuthenticated(Consent_Request_Item__c requestItem) {
        requestItem.Withdrawal_QR_Viewed_At__c = System.now();
        update requestItem;
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

    private static Consent__c createActiveConsent(Contact contactRecord, Consent_Request_Item__c requestItem) {
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Request_Item__c = requestItem == null ? null : requestItem.Id,
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
}