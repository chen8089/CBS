@isTest
private class QRSiteSingpassEmpImportantNotesTest {
    @isTest
    static void initPageShowsContentForValidSingpassEmployeeLink() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(data.accountRecord.Name, controller.getBankName());
    }

    @isTest
    static void initPageRedirectsToInvalidLinkWhenTokenMissing() {
        Contact contact = createContact('Pending');
        Consent_Request_Item__c requestItem = createRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('contactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageRedirectsToInvalidLinkWhenTokenIsTampered() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        String validToken = ConsentTestSupport.applyGuestLinkParams(
            data.contactRecord.Id,
            data.requestItemRecord
        );
        String tamperedToken = validToken.left(Math.max(1, validToken.length() - 4)) + 'abcd';
        if (tamperedToken == validToken) {
            tamperedToken = validToken + 'x';
        }
        ApexPages.currentPage().getParameters().put('token', tamperedToken);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageSupportsRequestItemAndTokenWithoutContactId() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);
        ApexPages.currentPage().getParameters().remove('contactId');
        ApexPages.currentPage().getParameters().remove('ContactId');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
        System.assertEquals(data.contactRecord.Id, controller.contactId);
    }

    @isTest
    static void initPageRedirectsToActiveConsentWhenLifecycleAndStatusMatch() {
        TestData data = createValidScenario('Authorized');
        setLifecycleStage(data.contactRecord, 'Active Consent');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/ActiveConsentNotificationPage'));
        System.assertEquals(data.contactRecord.Id, result.getParameters().get('contactId'));
    }

    @isTest
    static void initPageShowsFormWhenAuthorizedWithoutMatchingLifecycleStage() {
        TestData data = createValidScenario('Authorized');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
    }

    @isTest
    static void initPageRedirectsToAlreadyActionedForDeclinedStatus() {
        TestData data = createValidScenario('Declined');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void initPageRedirectsToLinkExpiredWhenRequestItemExpired() {
        TestData data = createValidScenario('Pending');
        data.requestItemRecord.Consent_Link_Expires_At__c = System.now().addDays(-1);
        update data.requestItemRecord;

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void continueWithSingpassRedirectsToSingpassAuthPage() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        String expectedToken = ConsentTestSupport.applyGuestLinkParams(
            data.contactRecord.Id,
            data.requestItemRecord
        );
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        controller.initPage();
        PageReference result = controller.continueWithSingpass();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().contains('/apex/QRSiteSingpassLogin')
                || result.getUrl().contains('/apex/ndi_auth')
        );
        System.assertEquals('authorize', result.getParameters().get('action'));
        System.assertEquals(data.contactRecord.Id, result.getParameters().get('contactId'));
        System.assertEquals(data.requestItemRecord.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(expectedToken, result.getParameters().get('token'));
    }

    @isTest
    static void continueWithSingpassRoutesToSingpassAuthRegardlessOfAuthorizedStatus() {
        TestData data = createValidScenario('Authorized');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.continueWithSingpass();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().contains('/apex/QRSiteSingpassLogin')
                || result.getUrl().contains('/apex/ndi_auth')
        );
        System.assertEquals(data.contactRecord.Id, result.getParameters().get('contactId'));
    }

    @isTest
    static void continueWithSingpassRedirectsToSingpassForValidStatus() {
        TestData data = createValidScenario('Valid');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.continueWithSingpass();

        System.assertNotEquals(null, result);
        System.assert(
            result.getUrl().contains('/apex/QRSiteSingpassLogin')
                || result.getUrl().contains('/apex/ndi_auth')
        );
    }

    @isTest
    static void declineConsentRedirectsToDeclineConfirmationPage() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        String expectedToken = ConsentTestSupport.applyGuestLinkParams(
            data.contactRecord.Id,
            data.requestItemRecord
        );
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        controller.initPage();
        PageReference result = controller.declineConsent();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSDeclineConsentConfirmation'));
        System.assertEquals(data.contactRecord.Id, result.getParameters().get('contactId'));
        System.assertEquals(data.requestItemRecord.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(expectedToken, result.getParameters().get('token'));
    }

    @isTest
    static void initPageRedirectsToInvalidLinkForNonSingpassScenario() {
        TestData data = createValidScenario('Pending');
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Authentication_Type__c')) {
            Contact updateContact = new Contact(
                Id = data.contactRecord.Id,
                Authentication_Type__c = 'Non-Singpass'
            );
            update updateContact;
        }

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void displayGettersReturnExpectedContentForValidLink() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        controller.initPage();

        System.assertEquals('Important Notes Before You Proceed', controller.getImportantNotesTitle());
        System.assert(controller.getIntroText().contains(data.accountRecord.Name));
        System.assertEquals('Please read the following notes carefully before you proceed.', controller.getReadNotesPrompt());
        System.assertEquals(2, controller.getWhatThisRequestIsForParagraphs().size());
        System.assertEquals(3, controller.getSingpassMyinfoParagraphs().size());
        System.assertEquals(2, controller.getYourConsentParagraphs().size());
        System.assertEquals(2, controller.getDeclineParagraphs().size());
        System.assertEquals(3, controller.getWithdrawalParagraphs().size());
        System.assertEquals(2, controller.getSecurityParagraphs().size());
        System.assert(controller.getWhatThisRequestIsForParagraphs()[0].contains(data.accountRecord.Name));
        System.assert(
            controller.getSingpassMyinfoParagraphs()[1].contains('This may include your name, NRIC / FIN, pass type, passport number')
        );
        System.assert(
            controller.getYourConsentParagraphs()[0].contains('for employment-related credit assessment / background screening purposes.')
        );
        System.assert(controller.getDeclineParagraphs()[1].contains('declined and ' + data.accountRecord.Name));
        System.assert(
            controller.getWithdrawalParagraphs()[2].contains('It will not affect any request that was already submitted, processed or completed')
        );
        System.assertEquals('Continue with Singpass', controller.getContinueButtonMain());
        System.assertEquals('', controller.getContinueButtonSub());
        System.assertEquals('Decline to Give Consent', controller.getDeclineButtonMain());
        System.assertEquals('', controller.getDeclineButtonSub());
    }

    @isTest
    static void initPageSupportsCapitalContactIdParameter() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
        ApexPages.currentPage().getParameters().put('consentRequestItemId', data.requestItemRecord.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
    }

    @isTest
    static void initPageShowsFormForValidContactStatusWithoutMatchingLifecycleStage() {
        TestData data = createValidScenario('Valid');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
    }

    @isTest
    static void initPageRedirectsForWithdrawnContactStatus() {
        TestData data = createValidScenario('Withdrawn');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void initPageRedirectsForExpiredContactStatus() {
        TestData data = createValidScenario('Expired');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteLinkExpired'));
    }

    @isTest
    static void initPageRedirectsWhenRequestItemSubmitted() {
        TestData data = createValidScenario('Pending');
        data.requestItemRecord.Current_Status__c = 'Submitted';
        update data.requestItemRecord;

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void initPageRedirectsWhenRequestItemDeclined() {
        TestData data = createValidScenario('Pending');
        data.requestItemRecord.Current_Status__c = 'Declined';
        update data.requestItemRecord;

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/CBSConsentAlreadyActionedPage'));
    }

    @isTest
    static void initPageRedirectsWhenRequestItemExpired() {
        TestData data = createValidScenario('Pending');
        data.requestItemRecord.Current_Status__c = 'Expired';
        update data.requestItemRecord;

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteLinkExpired'));
    }

    @isTest
    static void initPageRedirectsForInvalidContactId() {
        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        ApexPages.currentPage().getParameters().put('contactId', 'not-a-valid-id');
        ApexPages.currentPage().getParameters().put('token', 'tkn-singpass-001');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageRedirectsForInvalidActionParam() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageShowsFormWhenActiveConsentRecordExistsWithoutMatchingContactState() {
        TestData data = createValidScenario('Pending');
        insert new Consent__c(
            Data_Subject__c = data.contactRecord.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        PageReference result = controller.initPage();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.showPage);
    }

    @isTest
    static void getSection6Point2UsesHrEmailPlaceholder() {
        TestData data = createValidScenario('Pending');

        Test.setCurrentPage(Page.QRSiteSingpassEmployeeImportantNotes);
        setStandardParams(data);

        QRSiteSingpassEmpImportantNotesCtrl controller = new QRSiteSingpassEmpImportantNotesCtrl();
        controller.initPage();

        System.assertEquals('[BANK HR SUPPORT EMAIL]', controller.getHrSupportEmail());
        System.assert(controller.getSecurityParagraphs()[1].contains('[BANK HR SUPPORT EMAIL]'));
        System.assert(controller.getSecurityParagraphs()[1].contains('If you have any questions about this request'));
        System.assert(controller.getSecurityParagraphs()[1].contains(data.accountRecord.Name));
    }

    private static void setStandardParams(TestData data) {
        ConsentTestSupport.applyGuestLinkParams(data.contactRecord.Id, data.requestItemRecord);
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

    private static TestData createValidScenario(String consentStatus) {
        Account accountRecord = new Account(Name = 'Sample Bank Pte Ltd');
        insert accountRecord;

        Contact contactRecord = createContact(consentStatus);
        contactRecord.AccountId = accountRecord.Id;
        update contactRecord;

        Consent_Request_Item__c requestItemRecord = createRequestItem(contactRecord);
        return new TestData(accountRecord, contactRecord, requestItemRecord);
    }

    private static Contact createContact(String consentStatus) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'Singpass Employee Test ' + uniqueSuffix,
            Email = 'singpass.employee+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 15),
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', 'Existing Hire');
        }
        if (contactFields.containsKey('Authentication_Type__c')) {
            contactRecord.put('Authentication_Type__c', 'Singpass');
        }
        if (contactFields.containsKey('Consent_Type__c')) {
            contactRecord.put('Consent_Type__c', 'Term-Based Consent');
        }
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Singpass Employee Test');
        }

        insert contactRecord;
        return contactRecord;
    }

    private static Consent_Request_Item__c createRequestItem(Contact contactRecord) {
        Consent_Request_Item__c requestItemRecord = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = 'Sent',
            Consent_Link_Expires_At__c = System.now().addDays(7)
        );

        if (Schema.SObjectType.Consent_Request_Item__c.fields.getMap().containsKey('Uploaded_Full_Name__c')) {
            requestItemRecord.Uploaded_Full_Name__c = 'Singpass Employee Test';
        }
        if (Schema.SObjectType.Consent_Request_Item__c.fields.getMap().containsKey('Uploaded_ID_Number__c')) {
            requestItemRecord.Uploaded_ID_Number__c = contactRecord.ID_Number__c;
        }

        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItemRecord;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return requestItemRecord;
    }

    private class TestData {
        private Account accountRecord;
        private Contact contactRecord;
        private Consent_Request_Item__c requestItemRecord;

        private TestData(
            Account accountRecord,
            Contact contactRecord,
            Consent_Request_Item__c requestItemRecord
        ) {
            this.accountRecord = accountRecord;
            this.contactRecord = contactRecord;
            this.requestItemRecord = requestItemRecord;
        }
    }
}