@IsTest
private class PortalReportRequestControllerTest {
    @TestSetup
    static void setupData() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(4);
        ReportRequestTestSupport.createActiveConsents(
            new List<Contact>{ seedData.dataSubjects[0], seedData.dataSubjects[1], seedData.dataSubjects[2] }
        );
        ReportRequestTestSupport.createBlockedConsent(seedData.dataSubjects[3]);
    }

    @IsTest
    static void getEligibleDataSubjectsReturnsOnlyAllowedSubjects() {
        ReportRequestTestSupport.SeedData seedData = fetchSeedData();
        PortalReportRequestController.overrideContactIdForTests = seedData.requester.Id;
        PortalReportRequestController.overrideAccountIdForTests = seedData.clientAccount.Id;

        List<PortalReportRequestController.DataSubjectOption> options =
            PortalReportRequestController.getEligibleDataSubjects(null);

        System.assertEquals(3, options.size(), 'Only active/valid consent subjects should be listed.');
        Set<Id> returnedIds = new Set<Id>();
        for (PortalReportRequestController.DataSubjectOption option : options) {
            returnedIds.add(option.contactId);
        }
        System.assert(!returnedIds.contains(seedData.dataSubjects[3].Id), 'Blocked consent subject must be excluded.');
    }

    @IsTest
    static void createReportRequestCaseCreatesCaseAndItems() {
        ReportRequestTestSupport.SeedData seedData = fetchSeedData();
        PortalReportRequestController.overrideContactIdForTests = seedData.requester.Id;
        PortalReportRequestController.overrideAccountIdForTests = seedData.clientAccount.Id;
        List<Id> selectedIds = new List<Id>{ seedData.dataSubjects[0].Id, seedData.dataSubjects[1].Id };
        ReportRequestSubmissionService.skipRunningUserContextValidationForTests = true;

        Test.startTest();
        PortalReportRequestController.CreateRequestResult result =
            PortalReportRequestController.createReportRequestCase('Portal multi select submit', selectedIds, 5);
        Test.stopTest();

        System.assertNotEquals(null, result.caseId);
        System.assertEquals(2, result.itemCount);

        Case createdCase = [
            SELECT Id, RecordType.DeveloperName, Origin
            FROM Case
            WHERE Id = :result.caseId
            LIMIT 1
        ];
        System.assertEquals('CBS_Report_Request', createdCase.RecordType.DeveloperName);
        System.assertEquals('Portal', createdCase.Origin);
    }

    @IsTest
    static void createReportRequestCaseRejectsBlockedConsentSubject() {
        ReportRequestTestSupport.SeedData seedData = fetchSeedData();
        PortalReportRequestController.overrideContactIdForTests = seedData.requester.Id;
        PortalReportRequestController.overrideAccountIdForTests = seedData.clientAccount.Id;
        List<Id> selectedIds = new List<Id>{ seedData.dataSubjects[3].Id };
        ReportRequestSubmissionService.skipRunningUserContextValidationForTests = true;
        Boolean thrown = false;

        try {
            PortalReportRequestController.createReportRequestCase('Blocked subject test', selectedIds, 5);
        } catch (AuraHandledException e) {
            thrown = true;
            System.assertNotEquals(null, e);
        }
        System.assertEquals(true, thrown, 'Blocked consent selection must be rejected.');
    }

    private static ReportRequestTestSupport.SeedData fetchSeedData() {
        ReportRequestTestSupport.SeedData seedData = new ReportRequestTestSupport.SeedData();
        seedData.clientAccount = [SELECT Id FROM Account LIMIT 1];
        seedData.requester = [
            SELECT Id, AccountId, FirstName, LastName
            FROM Contact
            WHERE LastName = 'HR Requester'
            LIMIT 1
        ];
        seedData.dataSubjects = [
            SELECT Id, LastName
            FROM Contact
            WHERE LastName LIKE 'Data Subject %'
            ORDER BY LastName ASC
        ];
        return seedData;
    }

}