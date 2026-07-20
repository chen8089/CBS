@isTest
private class ConsentPageContextServiceTest {
    @isTest
    static void ensureSuccessContextLoadsContactForCompletedPage() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        Map<String, String> pageParameters = new Map<String, String>{
            'completed' => 'true',
            'ContactId' => contact.Id,
            'requestItemId' => requestItem.Id,
            'token' => ConsentGuestAuthService.getStoredToken(requestItem)
        };

        ConsentPageContextService.SuccessContextState state = new ConsentPageContextService.SuccessContextState();
        ConsentPageContextService.ensureSuccessContextLoaded(state, pageParameters, contact.Id, false);

        System.assertEquals(true, state.valid);
        System.assertNotEquals(null, state.contactRecord);
        System.assertEquals(contact.Id, state.resolvedContactId);
    }

    @isTest
    static void ensureSuccessContextInvalidatesForBadToken() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        Map<String, String> pageParameters = new Map<String, String>{
            'completed' => 'true',
            'requestItemId' => requestItem.Id,
            'token' => 'invalid-token'
        };

        ConsentPageContextService.SuccessContextState state = new ConsentPageContextService.SuccessContextState();
        ConsentPageContextService.ensureSuccessContextLoaded(state, pageParameters, null, false);

        System.assertEquals(false, state.valid);
        System.assertEquals('The link is invalid or has expired.', state.errorMessage);
    }

    @isTest
    static void ensureWithdrawContextLoadsContactFromRequestItem() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        Map<String, String> pageParameters = new Map<String, String>{
            'requestItemId' => requestItem.Id,
            'token' => ConsentGuestAuthService.getStoredToken(requestItem)
        };

        ConsentPageContextService.WithdrawContextState state = new ConsentPageContextService.WithdrawContextState();
        ConsentPageContextService.ensureWithdrawContextLoaded(state, pageParameters, null);

        System.assertEquals(true, state.valid);
        System.assertNotEquals(null, state.contactRecord);
        System.assertEquals(contact.Id, state.resolvedContactId);
    }

    @isTest
    static void refreshWithdrawContextClearsLoadedState() {
        ConsentPageContextService.WithdrawContextState state = new ConsentPageContextService.WithdrawContextState();
        state.initialized = true;
        state.valid = false;
        state.errorMessage = 'error';
        state.resolvedContactId = UserInfo.getUserId();

        ConsentPageContextService.refreshWithdrawContext(state);

        System.assertEquals(false, state.initialized);
        System.assertEquals(true, state.valid);
        System.assertEquals(null, state.errorMessage);
        System.assertEquals(null, state.resolvedContactId);
    }

    @isTest
    static void isRequestItemLinkExpiredReturnsFalseForValidItem() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        SObject requestItemRecord = ConsentRequestResolverService.querySuccessRequestItemById(requestItem.Id);

        System.assertEquals(false, ConsentPageContextService.isRequestItemLinkExpired(requestItemRecord));
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'Page Context Test',
            Email = 'page.context+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Page Context Test',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver'
        );
        insert contact;
        return contact;
    }
}