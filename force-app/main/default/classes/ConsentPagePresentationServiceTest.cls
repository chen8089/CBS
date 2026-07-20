@isTest
private class ConsentPagePresentationServiceTest {
    @isTest
    static void staticUiCopyMatchesExpectedValues() {
        System.assertNotEquals('', ConsentPagePresentationService.getCurrentDateString());
        System.assertEquals('Important Notes', ConsentPagePresentationService.getImportantNotesTitle('authorize'));
        System.assertEquals(
            'Important Notes Before Withdrawing Consent',
            ConsentPagePresentationService.getImportantNotesTitle('withdraw')
        );
        System.assertEquals('Invalid Link', ConsentPagePresentationService.getImportantNotesTitle(null));
        System.assertEquals(7, ConsentPagePresentationService.getImportantNotesList('authorize').size());
        System.assertEquals(5, ConsentPagePresentationService.getWithdrawImpactNotes().size());
        System.assertEquals('Retrieve Myinfo', ConsentPagePresentationService.getImportantNotesButtonMain('authorize'));
        System.assertEquals('Continue', ConsentPagePresentationService.getImportantNotesButtonMain('withdraw'));
        System.assertEquals('Consent Declined Successfully', ConsentPagePresentationService.getDeclinationCompletionTitle(false));
        System.assertEquals('Consent Already Submitted', ConsentPagePresentationService.getDeclinationCompletionTitle(true));
    }

    @isTest
    static void resolveSuccessBankNameUsesUrlAccountAndRequestPriority() {
        Contact contact = createContact();
        Account employer = new Account(Name = 'Priority Account');
        insert employer;
        contact.AccountId = employer.Id;
        update contact;

        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        if (Schema.SObjectType.Consent_Request_Item__c.fields.getMap().containsKey('Employer_Name__c')) {
            requestItem.put('Employer_Name__c', 'Request Employer');
            update requestItem;
        }

        SObject contactRecord = ConsentRequestResolverService.querySuccessContact(contact.Id);
        SObject requestRecord = ConsentRequestResolverService.querySuccessRequestItemById(requestItem.Id);

        Map<String, String> urlFirst = new Map<String, String>{ 'bankName' => 'URL Bank' };
        System.assertEquals('URL Bank', ConsentPagePresentationService.resolveSuccessBankName(urlFirst, contactRecord, requestRecord));

        Map<String, String> emptyParams = new Map<String, String>();
        System.assertEquals('Priority Account', ConsentPagePresentationService.resolveSuccessBankName(emptyParams, contactRecord, requestRecord));

        System.assertEquals(
            ConsentPagePresentationService.getEmployerBankFallbackText(),
            ConsentPagePresentationService.resolveSuccessBankName(emptyParams, null, null)
        );
    }

    @isTest
    static void resolveAuthTypeFlagsAndActiveStatus() {
        Map<String, String> nonSingpassParams = new Map<String, String>{ 'subjectType' => 'Non-Singpass' };
        Map<String, String> singpassParams = new Map<String, String>{ 'authenticationType' => 'Singpass' };

        System.assertEquals(true, ConsentPagePresentationService.resolveIsNonSingpass(null, nonSingpassParams, null, false));
        System.assertEquals(true, ConsentPagePresentationService.resolveIsSingpass(singpassParams, null, false));
        System.assertEquals(true, ConsentPagePresentationService.isActiveConsentStatus('Authorized'));
        System.assertEquals(true, ConsentPagePresentationService.isActiveConsentStatus(' valid '));
        System.assertEquals(false, ConsentPagePresentationService.isActiveConsentStatus('Declined'));
    }

    @isTest
    static void resolveWithdrawFormFieldsFromContact() {
        Contact contact = createContact();
        contact.Nationality__c = 'Singaporean';
        contact.ID_Number__c = 'S1234567A';
        contact.Registered_Address__c = '123 Test Street';
        update contact;

        SObject contactRecord = ConsentRequestResolverService.querySuccessContact(contact.Id);

        System.assertEquals('Singaporean', ConsentPagePresentationService.resolveWithdrawFormNationality(contactRecord, 'Fallback'));
        System.assertEquals('S1234567A', ConsentPagePresentationService.resolveWithdrawFormNric(contactRecord, 'Fallback'));
        System.assertEquals('123 Test Street', ConsentPagePresentationService.resolveWithdrawFormResidentialAddress(contactRecord, 'Fallback'));
        System.assertEquals('01', ConsentPagePresentationService.resolveWithdrawFormDobDay(contactRecord, '15'));
        System.assertEquals('January', ConsentPagePresentationService.resolveWithdrawFormDobMonth(contactRecord, 'February'));
        System.assertEquals('1990', ConsentPagePresentationService.resolveWithdrawFormDobYear(contactRecord, '1991'));
    }

    @isTest
    static void monthHelpersSupportNameAndNumericValues() {
        System.assertEquals('February', ConsentPagePresentationService.getMonthName(2));
        System.assertEquals(2, ConsentPagePresentationService.getMonthNumber('February'));
        System.assertEquals(2, ConsentPagePresentationService.getMonthNumber('2'));
        System.assertEquals('01', ConsentPagePresentationService.leftPad('1', 2));
    }

    @isTest
    static void completionAndWithdrawalMessagesSwitchByState() {
        System.assertEquals('Active Consent Found', ConsentPagePresentationService.getCompletionMessageLine1(true));
        System.assertEquals('Consent Submitted Successfully', ConsentPagePresentationService.getCompletionMessageLine1(false));
        System.assertEquals(3, ConsentPagePresentationService.getCompletionMessageLines(true).size());
        System.assertEquals(2, ConsentPagePresentationService.getCompletionMessageLines(false).size());
        System.assertEquals(
            'Withdrawal submitted successfully.',
            ConsentPagePresentationService.getWithdrawalCompletionMessageLine1(true)
        );
        System.assertEquals(
            'No Active Consent Record Found',
            ConsentPagePresentationService.getWithdrawalCompletionMessageLine1(false)
        );
        System.assertEquals(
            'To proceed, you may be required to authenticate your identity using Singpass before submitting your withdrawal request.',
            ConsentPagePresentationService.getWithdrawNextStepNote(true, false)
        );
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'Presentation Test',
            Email = 'presentation.test+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Presentation Test',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver'
        );
        insert contact;
        return contact;
    }
}