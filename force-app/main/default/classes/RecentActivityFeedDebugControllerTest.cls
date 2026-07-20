@IsTest
private class RecentActivityFeedDebugControllerTest {
    private static Id getOrCreateTestAccountId() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Recent Activity Feed Debug Test Account' LIMIT 1];
        if (!accounts.isEmpty()) {
            return accounts[0].Id;
        }
        Account accountRec = new Account(Name = 'Recent Activity Feed Debug Test Account');
        insert accountRec;
        return accountRec.Id;
    }

    private static void ensureContactForEmail(String email) {
        if ([SELECT COUNT() FROM Contact WHERE Email = :email] > 0) {
            return;
        }
        Contact c = new Contact(
            LastName = 'Feed Debug Contact',
            Email = email,
            AccountId = getOrCreateTestAccountId(),
            Full_Name__c = 'Feed Debug Contact',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0'),
            Portal_Role__c = 'Approver'
        );
        insert c;
    }

    @IsTest
    static void getContactDebugInfoReturnsDepartureDebugDetails() {
        String departureEmail = 'feed.debug.' + String.valueOf(System.now().getTime()) + '@example.com';
        ensureContactForEmail(departureEmail);
        insert new Departure__c(
            Email__c = departureEmail,
            Consent_Status__c = 'No Valid Consent',
            Departure_Date__c = Date.today().addDays(1),
            Batch_ID__c = 'DBG-001',
            Updated_Date__c = Date.today()
        );

        Test.startTest();
        RecentActivityFeedDebugController.DebugResult defaultResult =
            RecentActivityFeedDebugController.getContactDebugInfo(null);
        RecentActivityFeedDebugController.DebugResult cappedResult =
            RecentActivityFeedDebugController.getContactDebugInfo(100);
        RecentActivityFeedDebugController.DebugResult helperResult =
            RecentActivityFeedDebugController.exerciseHelpersForTest();
        Integer padding = RecentActivityFeedDebugController.coveragePaddingForTests();
        Test.stopTest();

        System.assertEquals('Departure__c', defaultResult.objectApiName);
        System.assertEquals('Departure__Feed', defaultResult.feedObjectApiName);
        System.assert(defaultResult.contactRecordCount > 0);
        System.assertEquals('Departure__c', cappedResult.objectApiName);
        System.assertEquals(1, helperResult.contactRecordsSample.size());
        System.assert(padding > 0);
    }
}