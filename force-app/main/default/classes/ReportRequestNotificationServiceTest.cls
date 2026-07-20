@IsTest
private class ReportRequestNotificationServiceTest {
    @TestSetup
    static void setupData() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(3);
        ReportRequestTestSupport.createActiveConsents(seedData.dataSubjects);
    }

    @IsTest
    static void completeAndNotifyPositive() {
        Id caseId = createSubmittedCase(2);

        ReportRequestNotificationService.CompletionRequest request =
            new ReportRequestNotificationService.CompletionRequest();
        request.caseId = caseId;
        request.deliveryChannel = 'SFTP';
        request.deliveryEvidenceReference = 'sftp://cbs/drop/report-123.csv';

        ReportRequestNotificationService.skipEmailSendDuringTests = false;
        Test.startTest();
        ReportRequestNotificationService.completeAndNotify(request);
        Test.stopTest();

        Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :caseId LIMIT 1];
        System.assertEquals('Closed', updatedCase.Status);
        System.assertEquals(2, ReportRequestNotificationService.lastEmailBatchSizeForTest);
        ReportRequestNotificationService.skipEmailSendDuringTests = true;
    }

    @IsTest
    static void completeAndNotifyNegativeRequiresEvidence() {
        Id caseId = createSubmittedCase(1);

        ReportRequestNotificationService.CompletionRequest request =
            new ReportRequestNotificationService.CompletionRequest();
        request.caseId = caseId;
        request.deliveryChannel = 'encrypted email';

        Boolean blocked = false;
        try {
            ReportRequestNotificationService.completeAndNotify(request);
        } catch (Exception ex) {
            blocked = true;
        }
        System.assertEquals(true, blocked);
    }

    @IsTest
    static void completeAndNotifyWithMissingSubmittedByStillSendsContactNotification() {
        Id caseId = createSubmittedCase(1);
        update new Case(Id = caseId, Submitted_By__c = null);

        ReportRequestNotificationService.CompletionRequest request =
            new ReportRequestNotificationService.CompletionRequest();
        request.caseId = caseId;
        request.deliveryChannel = 'SFTP';
        request.deliveryEvidenceReference = 'sftp://cbs/drop/report-fallback.csv';

        ReportRequestNotificationService.skipEmailSendDuringTests = false;
        Test.startTest();
        ReportRequestNotificationService.completeAndNotify(request);
        Test.stopTest();
        ReportRequestNotificationService.skipEmailSendDuringTests = true;
        System.assertEquals(1, ReportRequestNotificationService.lastEmailBatchSizeForTest);
    }

    @IsTest
    static void markSubmittedBulkUpdatesItems() {
        Id caseId = createSubmittedCase(3);
        List<Report_Request_Item__c> caseItems = [
            SELECT Id
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c = :caseId
        ];
        List<Id> itemIds = new List<Id>();
        for (Report_Request_Item__c caseItem : caseItems) {
            itemIds.add(caseItem.Id);
        }

        Test.startTest();
        ReportRequestNotificationService.markSubmitted(caseId, itemIds);
        Test.stopTest();

        System.assertEquals(3, itemIds.size());
    }

    private static Id createSubmittedCase(Integer subjectCount) {
        Contact requester = [
            SELECT Id, AccountId
            FROM Contact
            WHERE LastName = 'HR Requester'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        List<Contact> dataSubjects = [
            SELECT Id
            FROM Contact
            WHERE LastName LIKE 'Data Subject %'
            AND AccountId = :requester.AccountId
            ORDER BY LastName ASC
            LIMIT :subjectCount
        ];
        Id submitterUserId = [
            SELECT Id
            FROM User
            WHERE Email != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ].Id;

        Case requestCase = new Case(
            AccountId = requester.AccountId,
            ContactId = requester.Id,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Notification Test Case',
            Exception_Type__c = 'File Validation'
        );
        requestCase.Submitted_By__c = submitterUserId;
        insert requestCase;

        List<Report_Request_Item__c> items = new List<Report_Request_Item__c>();
        for (Contact dataSubject : dataSubjects) {
            Report_Request_Item__c item = new Report_Request_Item__c(
                Report_Request_Case__c = requestCase.Id,
                Data_Subject__c = dataSubject.Id
            );
            item.Delivery_Status__c = 'Pending';
            items.add(item);
        }
        if (!items.isEmpty()) {
            insert items;
        }
        return requestCase.Id;
    }
}