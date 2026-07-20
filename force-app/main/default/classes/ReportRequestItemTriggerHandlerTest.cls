@IsTest
private class ReportRequestItemTriggerHandlerTest {
    @IsTest
    static void beforeInsert_blocksIneligibleConsent() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(1);
        ReportRequestTestSupport.createActiveConsents(seedData.dataSubjects);
        delete [
            SELECT Id
            FROM Consent__c
            WHERE Data_Subject__c = :seedData.dataSubjects[0].Id
            LIMIT 1
        ];
        ReportRequestTestSupport.createBlockedConsent(seedData.dataSubjects[0]);

        Case reportCase = new Case(
            AccountId = seedData.clientAccount.Id,
            ContactId = seedData.requester.Id,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Trigger eligibility blocking test'
        );
        insert reportCase;

        Report_Request_Item__c blockedItem = new Report_Request_Item__c(
            Data_Subject__c = seedData.dataSubjects[0].Id,
            Report_Request_Case__c = reportCase.Id,
            Request_Type__c = 'Report Request',
            Client_Account__c = seedData.clientAccount.Id
        );

        try {
            insert blockedItem;
            System.assert(false, 'Expected insertion to be blocked by trigger.');
        } catch (DmlException ex) {
            System.assert(
                ex.getMessage().contains('Report Request Item blocked'),
                'Expected eligibility guardrail message but got: ' + ex.getMessage()
            );
        }
    }

    @IsTest
    static void beforeInsert_allowsEligibleConsentAndMarksPassed() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(1);
        ReportRequestTestSupport.createActiveConsents(seedData.dataSubjects);

        Case reportCase = new Case(
            AccountId = seedData.clientAccount.Id,
            ContactId = seedData.requester.Id,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Trigger eligibility allow test'
        );
        insert reportCase;

        Report_Request_Item__c allowedItem = new Report_Request_Item__c(
            Data_Subject__c = seedData.dataSubjects[0].Id,
            Report_Request_Case__c = reportCase.Id,
            Request_Type__c = 'Report Request',
            Client_Account__c = seedData.clientAccount.Id
        );
        insert allowedItem;

        Report_Request_Item__c insertedItem = [
            SELECT Id, Eligibility_Status__c, Consent_Revalidation_Status__c
            FROM Report_Request_Item__c
            WHERE Id = :allowedItem.Id
            LIMIT 1
        ];
        System.assertEquals('Eligible', insertedItem.Eligibility_Status__c);
        System.assertEquals('Passed', insertedItem.Consent_Revalidation_Status__c);
    }

    @IsTest
    static void beforeUpdate_blocksWhenConsentBecomesIneligible() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(1);
        ReportRequestTestSupport.createActiveConsents(seedData.dataSubjects);

        Case reportCase = new Case(
            AccountId = seedData.clientAccount.Id,
            ContactId = seedData.requester.Id,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Trigger eligibility update blocking test'
        );
        insert reportCase;

        Report_Request_Item__c itemRecord = new Report_Request_Item__c(
            Data_Subject__c = seedData.dataSubjects[0].Id,
            Report_Request_Case__c = reportCase.Id,
            Request_Type__c = 'Report Request',
            Client_Account__c = seedData.clientAccount.Id
        );
        insert itemRecord;

        delete [
            SELECT Id
            FROM Consent__c
            WHERE Data_Subject__c = :seedData.dataSubjects[0].Id
            LIMIT 1
        ];
        ReportRequestTestSupport.createBlockedConsent(seedData.dataSubjects[0]);

        itemRecord.Consent_Revalidation_Status__c = 'Pending';
        try {
            update itemRecord;
            System.assert(false, 'Expected update to be blocked when consent becomes ineligible.');
        } catch (DmlException ex) {
            System.assert(
                ex.getMessage().contains('Report Request Item blocked'),
                'Expected eligibility guardrail message but got: ' + ex.getMessage()
            );
        }
    }

    @IsTest
    static void bulkInsert_mixedEligibility_keepsValidBusinessFlowRunning() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(2);
        ReportRequestTestSupport.createActiveConsents(seedData.dataSubjects);

        // Build mixed consent dataset: one subject remains valid, one becomes blocked.
        delete [
            SELECT Id
            FROM Consent__c
            WHERE Data_Subject__c = :seedData.dataSubjects[1].Id
            LIMIT 1
        ];
        ReportRequestTestSupport.createBlockedConsent(seedData.dataSubjects[1]);

        Case reportCase = new Case(
            AccountId = seedData.clientAccount.Id,
            ContactId = seedData.requester.Id,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Trigger mixed eligibility bulk test'
        );
        insert reportCase;

        List<Report_Request_Item__c> mixedItems = new List<Report_Request_Item__c>{
            new Report_Request_Item__c(
                Data_Subject__c = seedData.dataSubjects[0].Id,
                Report_Request_Case__c = reportCase.Id,
                Request_Type__c = 'Report Request',
                Client_Account__c = seedData.clientAccount.Id
            ),
            new Report_Request_Item__c(
                Data_Subject__c = seedData.dataSubjects[1].Id,
                Report_Request_Case__c = reportCase.Id,
                Request_Type__c = 'Report Request',
                Client_Account__c = seedData.clientAccount.Id
            )
        };

        Database.SaveResult[] saveResults = Database.insert(mixedItems, false);
        System.assertEquals(2, saveResults.size(), 'Expected two save results.');
        System.assert(saveResults[0].isSuccess(), 'Eligible row should continue through business flow.');
        System.assert(!saveResults[1].isSuccess(), 'Blocked row should be stopped by server-side guardrail.');
        System.assert(
            saveResults[1].getErrors()[0].getMessage().contains('Report Request Item blocked'),
            'Expected eligibility block error message for ineligible row.'
        );

        List<Report_Request_Item__c> createdItems = [
            SELECT Id, Data_Subject__c, Eligibility_Status__c, Consent_Revalidation_Status__c
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c = :reportCase.Id
        ];
        System.assertEquals(1, createdItems.size(), 'Only eligible row should be persisted.');
        System.assertEquals(seedData.dataSubjects[0].Id, createdItems[0].Data_Subject__c);
        System.assertEquals('Eligible', createdItems[0].Eligibility_Status__c);
        System.assertEquals('Passed', createdItems[0].Consent_Revalidation_Status__c);
    }
}