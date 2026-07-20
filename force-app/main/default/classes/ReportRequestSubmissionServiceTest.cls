@IsTest
private class ReportRequestSubmissionServiceTest {
    @TestSetup
    static void setupData() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(5);
        ReportRequestTestSupport.createActiveConsents(seedData.dataSubjects);
    }

    @IsTest
    static void submitPositiveCreatesCaseAndItems() {
        ReportRequestTestSupport.SeedData seedData = fetchSeedData(2);
        ReportRequestSubmissionService.SubmissionRequest request =
            ReportRequestTestSupport.buildSubmissionRequest(seedData.clientAccount, seedData.requester, seedData.dataSubjects);

        ReportRequestSubmissionService.SubmissionResult result;
        ReportRequestSubmissionService.skipRunningUserContextValidationForTests = true;
        try {
            Test.startTest();
            result = ReportRequestSubmissionService.submit(request);
            Test.stopTest();
        } finally {
            ReportRequestSubmissionService.skipRunningUserContextValidationForTests = false;
        }

        System.assertEquals(true, result.isSuccess);
        System.assertEquals('SUBMITTED', result.reasonCode);
        System.assertNotEquals(null, result.caseId);
        System.assertEquals(2, result.itemIds.size());

        Case createdCase = [SELECT Id, OwnerId, Status FROM Case WHERE Id = :result.caseId LIMIT 1];
        System.assertEquals('New', createdCase.Status);

        List<Report_Request_Item__c> createdItems = [
            SELECT Id, Data_Subject__c, Report_Request_Case__c
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c = :result.caseId
        ];
        System.assertEquals(2, createdItems.size());
    }

    @IsTest
    static void submitNegativeBlocksInvalidConsent() {
        ReportRequestTestSupport.SeedData seedData = fetchSeedData(2);
        delete [
            SELECT Id
            FROM Consent__c
            WHERE Data_Subject__c = :seedData.dataSubjects[0].Id
            LIMIT 1
        ];
        ReportRequestTestSupport.createBlockedConsent(seedData.dataSubjects[0]);

        ReportRequestSubmissionService.SubmissionRequest request =
            ReportRequestTestSupport.buildSubmissionRequest(seedData.clientAccount, seedData.requester, seedData.dataSubjects);
        ReportRequestSubmissionService.skipRunningUserContextValidationForTests = true;
        ReportRequestSubmissionService.SubmissionResult result;
        try {
            result = ReportRequestSubmissionService.submit(request);
        } finally {
            ReportRequestSubmissionService.skipRunningUserContextValidationForTests = false;
        }

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('CONSENT_VALIDATION_FAILED', result.reasonCode);
        System.assert(!result.errors.isEmpty());
    }

    @IsTest
    static void submitBulkCreatesMultipleItems() {
        ReportRequestTestSupport.SeedData seedData = fetchSeedData(5);
        ReportRequestSubmissionService.SubmissionRequest request =
            ReportRequestTestSupport.buildSubmissionRequest(seedData.clientAccount, seedData.requester, seedData.dataSubjects);

        ReportRequestSubmissionService.SubmissionResult result;
        ReportRequestSubmissionService.skipRunningUserContextValidationForTests = true;
        try {
            Test.startTest();
            result = ReportRequestSubmissionService.submit(request);
            Test.stopTest();
        } finally {
            ReportRequestSubmissionService.skipRunningUserContextValidationForTests = false;
        }

        System.assertEquals(true, result.isSuccess);
        System.assertEquals(5, result.itemIds.size());
    }

    @IsTest
    static void submitRejectsRequesterAccountMismatch() {
        ReportRequestTestSupport.SeedData seedData = fetchSeedData(1);
        Account otherAccount = new Account(Name = 'Mismatched Submitter Account');
        insert otherAccount;

        ReportRequestSubmissionService.SubmissionRequest request =
            ReportRequestTestSupport.buildSubmissionRequest(otherAccount, seedData.requester, seedData.dataSubjects);
        ReportRequestSubmissionService.SubmissionResult result = ReportRequestSubmissionService.submit(request);

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('REQUESTER_ACCOUNT_MISMATCH', result.reasonCode);
    }

    private static ReportRequestTestSupport.SeedData fetchSeedData(Integer subjectCount) {
        Account accountRecord = [SELECT Id FROM Account LIMIT 1];
        Contact requester = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'HR Requester'
            LIMIT 1
        ];
        List<Contact> dataSubjects = [
            SELECT Id
            FROM Contact
            WHERE LastName LIKE 'Data Subject %'
            ORDER BY LastName ASC
            LIMIT :subjectCount
        ];

        ReportRequestTestSupport.SeedData seedData = new ReportRequestTestSupport.SeedData();
        seedData.clientAccount = accountRecord;
        seedData.requester = requester;
        seedData.dataSubjects = dataSubjects;
        return seedData;
    }
}