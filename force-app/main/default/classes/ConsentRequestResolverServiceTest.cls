@isTest
private class ConsentRequestResolverServiceTest {
    @isTest
    static void resolverQueriesReturnExpectedRecords() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        String token = ConsentGuestAuthService.getStoredToken(requestItem);

        insert new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Request_Item__c = requestItem.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );

        Consent__c latestConsent = ConsentRequestResolverService.getLatestConsent(contact.Id);
        System.assertNotEquals(null, latestConsent);
        System.assertEquals('Active', latestConsent.Consent_Status__c);
        System.assertNotEquals(null, ConsentRequestResolverService.getCurrentActiveConsent(contact.Id));

        Consent_Request_Item__c latestRequestItem = ConsentRequestResolverService.getLatestRequestItem(contact.Id);
        System.assertNotEquals(null, latestRequestItem);
        System.assertEquals(contact.Id, latestRequestItem.Data_Subject__c);

        SObject byId = ConsentRequestResolverService.querySuccessRequestItemById(String.valueOf(requestItem.Id));
        System.assertNotEquals(null, byId);
        System.assertEquals(requestItem.Id, (Id) byId.get('Id'));

        SObject byToken = ConsentRequestResolverService.querySuccessRequestItemByToken(token);
        System.assertNotEquals(null, byToken);
        System.assertEquals(requestItem.Id, (Id) byToken.get('Id'));

        SObject successContact = ConsentRequestResolverService.querySuccessContact(contact.Id);
        System.assertNotEquals(null, successContact);
        System.assertEquals(contact.Id, (Id) successContact.get('Id'));
    }

    @isTest
    static void resolverContactIdResolutionSupportsConsentAndRecordIds() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        Consent__c consent = new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Request_Item__c = requestItem.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        insert consent;

        System.assertEquals(contact.Id, ConsentRequestResolverService.resolveContactIdByConsentId(String.valueOf(consent.Id)));
        System.assertEquals(contact.Id, ConsentRequestResolverService.resolveRecordIdToContactId(String.valueOf(contact.Id)));
        System.assertEquals(contact.Id, ConsentRequestResolverService.resolveRecordIdToContactId(String.valueOf(requestItem.Id)));
        System.assertEquals(contact.Id, ConsentRequestResolverService.resolveRecordIdToContactId(String.valueOf(consent.Id)));
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'Resolver Test',
            RecordTypeId = dataSubjectRecordTypeId(),
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Resolver Test',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Consent_Type__c = 'Per-Report Consent'
        );
        insert contact;
        return contact;
    }

    private static Id dataSubjectRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> infos =
            Contact.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        return infos.containsKey('Data_Subject') && infos.get('Data_Subject').isAvailable()
            ? infos.get('Data_Subject').getRecordTypeId()
            : null;
    }
}