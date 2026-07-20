@isTest
private class NonSingPassImportantNotesControllerTest {
    @isTest
    static void goToNextPageRedirectsToActiveConsentForAuthorized() {
        Contact contact = createContact('Authorized', 'Active Consent');
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        String expectedToken = ConsentTestSupport.getStoredTokenForRequestItem(requestItem.Id);

        Test.setCurrentPage(Page.NonSingPassImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', expectedToken);
        ApexPages.currentPage().getParameters().put('recordId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('action', 'consent');

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        PageReference result = controller.goToNextPage();

        System.assertNotEquals(null, result);
        System.assertEquals('true', result.getParameters().get('completed'));
        System.assertEquals('true', result.getParameters().get('activeConsent'));
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(expectedToken, result.getParameters().get('token'));
    }

    @isTest
    static void goToNextPageContinuesFlowForValidWithoutActiveConsentLifecycle() {
        Contact contact = createContact('Valid', resolveLifecycleNonActive());
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        String expectedToken = ConsentTestSupport.getStoredTokenForRequestItem(requestItem.Id);

        Test.setCurrentPage(Page.NonSingPassImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', expectedToken);

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        PageReference result = controller.goToNextPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().toLowerCase().contains('qrsitenonsingpassemployeeimportantnotes'));
        System.assertEquals(null, result.getParameters().get('activeConsent'));
    }

    @isTest
    static void goToNextPageContinuesFlowWhenStatusNotAuthorizedOrValid() {
        Contact contact = createContact(resolveConsentStatus('Pending'), resolveLifecycleNonActive());
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        String expectedToken = ConsentTestSupport.getStoredTokenForRequestItem(requestItem.Id);

        Test.setCurrentPage(Page.NonSingPassImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', expectedToken);

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        PageReference result = controller.goToNextPage();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(requestItem.Id, result.getParameters().get('requestItemId'));
        System.assertEquals('authorize', result.getParameters().get('action'));
        System.assertEquals('employee', result.getParameters().get('type'));
        System.assertEquals('nonsingpass', result.getParameters().get('authType'));
        System.assertEquals(null, result.getParameters().get('activeConsent'));
        System.assertEquals('Continue to Consent Form', controller.getImportantNotesButtonMain());
    }

    @isTest
    static void goToNextPageRoutesPrehireToOneMonthConsent() {
        Contact contact = createContact(resolveConsentStatus('Pending'), resolveLifecycleNonActive());
        contact.Employment_Status__c = 'Pre-hire';
        update contact;

        Consent_Request_Item__c requestItem = createRequestItem(contact);
        String expectedToken = ConsentTestSupport.getStoredTokenForRequestItem(requestItem.Id);

        Test.setCurrentPage(Page.NonSingPassImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', expectedToken);
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('subjectType', 'prehire');

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        PageReference result = controller.goToNextPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().toLowerCase().contains('qrsitenonsingpassonemonthconsent'));
        System.assertEquals('authorize', result.getParameters().get('action'));
        System.assertEquals('prehire', result.getParameters().get('type'));
        System.assertEquals('prehire', result.getParameters().get('subjectType'));
        System.assertEquals('nonsingpass', result.getParameters().get('authType'));
    }

    @isTest
    static void goToNextPageShowsErrorForInvalidContactId() {
        Test.setCurrentPage(Page.NonSingPassImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', 'invalid-contact-id');

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        PageReference result = controller.goToNextPage();

        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void goToNextPageShowsErrorWhenContactNotFound() {
        Test.setCurrentPage(Page.NonSingPassImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', '003000000000001AAA');

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        PageReference result = controller.goToNextPage();

        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void invalidEntryShowsInvalidLinkContent() {
        Test.setCurrentPage(Page.NonSingPassImportantNotes);

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        System.assertEquals(false, controller.getHasValidEntryAction());
        System.assertEquals('Invalid Link', controller.getImportantNotesTitle());
        System.assert(controller.getImportantNotesList().size() > 0);
    }

    @isTest
    static void tamperedTokenCannotProceed() {
        Contact contact = createContact(resolveConsentStatus('Pending'), resolveLifecycleNonActive());
        Consent_Request_Item__c requestItem = createRequestItem(contact);
        String validToken = ConsentTestSupport.getStoredTokenForRequestItem(requestItem.Id);

        Test.setCurrentPage(Page.NonSingPassImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
        ApexPages.currentPage().getParameters().put('token', validToken + 'tampered');

        NonSingPassImportantNotesController controller = new NonSingPassImportantNotesController();
        System.assertEquals(false, controller.getHasValidEntryAction());
        PageReference result = controller.goToNextPage();
        System.assertEquals(null, result);
        System.assert(ApexPages.getMessages().size() > 0);
    }

    private static Contact createContact(String consentStatus, String lifecycleStage) {
        Account accountRecord = new Account(Name = 'Employer Account');
        insert accountRecord;

        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'Important Notes Test',
            Email = 'important.notes+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1992, 5, 12),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Important Notes Test',
            ID_Number__c = 'P' + uniqueSuffix.right(7),
            ID_Type__c = 'Passport',
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = consentStatus,
            Data_Subject_Lifecycle_Stage__c = lifecycleStage,
            AccountId = accountRecord.Id
        );
        insert contact;
        return contact;
    }

    private static String resolveLifecycleNonActive() {
        Schema.DescribeFieldResult describe = Contact.Data_Subject_Lifecycle_Stage__c.getDescribe();
        List<Schema.PicklistEntry> entries = describe.getPicklistValues();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.getValue() != 'Active Consent') {
                return entry.getValue();
            }
        }
        return entries.isEmpty() ? null : entries[0].getValue();
    }

    private static String resolveConsentStatus(String preferredValue) {
        Schema.DescribeFieldResult describe = Contact.Current_Consent_Status__c.getDescribe();
        List<Schema.PicklistEntry> entries = describe.getPicklistValues();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.getValue().equalsIgnoreCase(preferredValue) || entry.getLabel().equalsIgnoreCase(preferredValue)) {
                return entry.getValue();
            }
        }
        return entries.isEmpty() ? preferredValue : entries[0].getValue();
    }

    private static Consent_Request_Item__c createRequestItem(Contact contact) {
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent',
            Uploaded_Full_Name__c = contact.Full_Name__c,
            Uploaded_ID_Number__c = contact.ID_Number__c
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return requestItem;
    }
}