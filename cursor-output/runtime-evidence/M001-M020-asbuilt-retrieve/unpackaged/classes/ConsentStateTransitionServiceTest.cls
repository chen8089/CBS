@isTest
private class ConsentStateTransitionServiceTest {
    @isTest
    static void applyDeclinationUpdatesContactAndLatestRequestItem() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        requestItem.Withdrawal_QR_Viewed_At__c = System.now();
        update requestItem;

        ConsentStateTransitionService.applyDeclination(contact.Id);

        Contact declinedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Declined', declinedContact.Current_Consent_Status__c);
        System.assertEquals('Consent Declined', declinedContact.Data_Subject_Lifecycle_Stage__c);

        List<Consent_Request_Item__c> declinedRequestItems = [
            SELECT Current_Status__c, Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :contact.Id
            AND Current_Status__c = 'Declined'
        ];
        System.assert(!declinedRequestItems.isEmpty());
    }

    @isTest
    static void clearQrFlagsApplyOnlyForMatchingStatusRules() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        requestItem.Withdrawal_QR_Viewed_At__c = System.now();
        update requestItem;

        ConsentStateTransitionService.clearAuthorizationQrIfNeeded(requestItem, 'Expired');
        ConsentStateTransitionService.clearWithdrawalQrIfNeeded(requestItem, 'Authorized');

        Consent_Request_Item__c refreshed = [
            SELECT Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals(null, refreshed.Authorization_QR_Viewed_At__c);
        System.assertEquals(null, refreshed.Withdrawal_QR_Viewed_At__c);
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Account account = new Account(Name = 'State Transition Account ' + uniqueSuffix);
        insert account;
        Contact contact = new Contact(
            LastName = 'State Transition Test',
            AccountId = account.Id,
            RecordTypeId = dataSubjectRecordTypeId(),
            Email = 'state.transition.' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'State Transition Test',
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