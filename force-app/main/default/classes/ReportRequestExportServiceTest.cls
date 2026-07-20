@IsTest
private class ReportRequestExportServiceTest {
    @TestSetup
    static void setupData() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(4);
        ReportRequestTestSupport.createActiveConsents(seedData.dataSubjects);
    }

    @IsTest
    static void exportAuthorizedListReturnsCsvWhenWhitelisted() {
        Id caseId = createSubmittedCaseWithItems(2);
        ExportAuthorizationService.bypassProcessingOfficerCheckInTests = true;

        Test.startTest();
        String csv = ReportRequestExportService.exportAuthorizedList(
            caseId,
            new List<String>{ 'Data_Subject__c', 'Consent_Revalidation_Status__c' }
        );
        Test.stopTest();

        System.assert(csv.contains('Data_Subject__c'));
        System.assert(csv.split('\n').size() >= 2);
    }

    @IsTest
    static void exportAuthorizedListBlocksNonWhitelistedFields() {
        Id caseId = createSubmittedCaseWithItems(1);
        ExportAuthorizationService.bypassProcessingOfficerCheckInTests = true;

        Boolean blocked = false;
        try {
            ReportRequestExportService.exportAuthorizedList(caseId, new List<String>{ 'Name' });
        } catch (Exception ex) {
            blocked = true;
        }
        System.assertEquals(true, blocked);
    }

    @IsTest
    static void exportAuthorizedListSupportsBulkRows() {
        Id caseId = createSubmittedCaseWithItems(4);
        ExportAuthorizationService.bypassProcessingOfficerCheckInTests = true;

        String csv = ReportRequestExportService.exportAuthorizedList(
            caseId,
            new List<String>{ 'Data_Subject__c', 'Delivery_Status__c', 'SLA_Due_Date__c' }
        );
        List<String> lines = csv.split('\n');
        System.assert(lines.size() >= 5);
    }

    @IsTest
    static void exportAuthorizedListFiltersRowsWhenConsentBecomesInvalid() {
        Id caseId = createSubmittedCaseWithItems(2);
        ExportAuthorizationService.bypassProcessingOfficerCheckInTests = true;

        Report_Request_Item__c targetItem = [
            SELECT Id, Data_Subject__c
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c = :caseId
            LIMIT 1
        ];
        insert new Consent__c(
            Data_Subject__c = targetItem.Data_Subject__c,
            Consent_Status__c = 'Withdrawn',
            Consent_Expiry_Date__c = Date.today().addDays(30)
        );

        String csv = ReportRequestExportService.exportAuthorizedList(
            caseId,
            new List<String>{ 'Data_Subject__c' }
        );
        List<String> lines = csv.split('\n');
        System.assertEquals(2, lines.size(), 'Only one still-valid row should remain in export.');
    }

    @IsTest
    static void exportAuthorizedListFiltersDepartedEmployees() {
        Id caseId = createSubmittedCaseWithItems(2);
        ExportAuthorizationService.bypassProcessingOfficerCheckInTests = true;

        Report_Request_Item__c targetItem = [
            SELECT Id, Data_Subject__c
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c = :caseId
            LIMIT 1
        ];
        Boolean markedDeparted = markContactAsDeparted(targetItem.Data_Subject__c);
        System.assertEquals(true, markedDeparted, 'Test org must support at least one departed-like status field/value.');

        String csv = ReportRequestExportService.exportAuthorizedList(
            caseId,
            new List<String>{ 'Data_Subject__c' }
        );
        List<String> lines = csv.split('\n');
        System.assertEquals(3, lines.size(), 'Departed employee should remain in CSV with explicit note.');
        System.assert(csv.contains('Excluded - Departed employee'));
    }

    @IsTest
    static void exportAuthorizedListForLatestBatchReturnsOnlyCurrentBatchRows() {
        BatchSeed seed = createBatchSeedData('BATCH-LATEST-001', 3);
        ExportAuthorizationService.bypassProcessingOfficerCheckInTests = true;
        ReportRequestExportService.skipWhitelistNotificationSendDuringTests = true;
        ReportRequestExportService.lastWhitelistNotificationRecipientCountForTest = 0;

        ReportRequestExportService.BatchExportResult result = ReportRequestExportService.exportAuthorizedListForLatestBatch(
            new List<String>{ 'Data_Subject__c', 'Delivery_Status__c' }
        );

        System.assertEquals('BATCH-LATEST-001', result.batchReference);
        System.assertEquals(3, result.totalCandidateRows);
        System.assertEquals(3, result.exportedRows);
        System.assertEquals(0, result.filteredRows);
        System.assert(result.csvBody.contains('Case_Number'));
        System.assert(result.csvBody.split('\n').size() >= 4);
        System.assert(
            ReportRequestExportService.lastWhitelistNotificationRecipientCountForTest >= 3,
            'Expected whitelist recipients to include data subjects (and optionally HR).'
        );
    }

    @IsTest
    static void exportAuthorizedListForLatestBatchFiltersDepartedAndInvalidConsent() {
        BatchSeed seed = createBatchSeedData('BATCH-LATEST-002', 3);
        ExportAuthorizationService.bypassProcessingOfficerCheckInTests = true;
        ReportRequestExportService.skipWhitelistNotificationSendDuringTests = true;
        ReportRequestExportService.lastWhitelistNotificationRecipientCountForTest = 0;

        Boolean departedMarked = markContactAsDeparted(seed.dataSubjectIds[0]);
        System.assertEquals(true, departedMarked, 'Test org must support at least one departed-like status field/value.');
        insert new Consent__c(
            Data_Subject__c = seed.dataSubjectIds[1],
            Consent_Status__c = 'Withdrawn',
            Consent_Expiry_Date__c = Date.today().addDays(30)
        );

        ReportRequestExportService.BatchExportResult result = ReportRequestExportService.exportAuthorizedListForLatestBatch(
            new List<String>{ 'Data_Subject__c' }
        );

        System.assertEquals('BATCH-LATEST-002', result.batchReference);
        System.assertEquals(3, result.totalCandidateRows);
        System.assertEquals(1, result.exportedRows);
        System.assertEquals(2, result.filteredRows);
        System.assert(result.csvBody.contains('Excluded - Departed employee'));
        System.assertEquals(3, result.csvBody.split('\n').size(), 'CSV should include authorized + departed rows.');
        System.assert(
            ReportRequestExportService.lastWhitelistNotificationRecipientCountForTest >= 2,
            'Expected notifications for remaining whitelist rows.'
        );
    }

    private static Id createSubmittedCaseWithItems(Integer subjectCount) {
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
        ReportRequestSubmissionService.SubmissionRequest request =
            ReportRequestTestSupport.buildSubmissionRequest(accountRecord, requester, dataSubjects);
        ReportRequestSubmissionService.SubmissionResult result = ReportRequestSubmissionService.submit(request);
        System.assertEquals(true, result.isSuccess);
        return result.caseId;
    }

    private static Boolean markContactAsDeparted(Id contactId) {
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        List<String> candidateFields = new List<String>{
            'Employment_Status__c',
            'Data_Subject_Lifecycle_Stage__c',
            'Current_Consent_Status__c'
        };
        Contact updateRecord = new Contact(Id = contactId);
        Boolean assigned = false;
        for (String fieldApiName : candidateFields) {
            if (!contactFields.containsKey(fieldApiName)) {
                continue;
            }
            Schema.DescribeFieldResult describe = contactFields.get(fieldApiName).getDescribe();
            String departedValue = resolveDepartedValue(describe);
            if (String.isBlank(departedValue)) {
                continue;
            }
            updateRecord.put(fieldApiName, departedValue);
            assigned = true;
            break;
        }
        if (assigned) {
            update updateRecord;
        }
        return assigned;
    }

    private static String resolveDepartedValue(Schema.DescribeFieldResult describe) {
        if (describe == null) {
            return null;
        }
        if (describe.getType() != Schema.DisplayType.PICKLIST) {
            return 'Departed';
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            String normalized = entry.getValue() == null ? '' : entry.getValue().trim().toLowerCase();
            if (normalized.contains('depart') || normalized == 'inactive' || normalized == 'terminated' || normalized == 'resigned') {
                return entry.getValue();
            }
        }
        return null;
    }

    private class BatchSeed {
        public Id accountId;
        public Id requesterId;
        public List<Id> dataSubjectIds = new List<Id>();
    }

    private static BatchSeed createBatchSeedData(String batchIdValue, Integer rowCount) {
        BatchSeed seed = new BatchSeed();
        Account accountRecord = [SELECT Id FROM Account LIMIT 1];
        seed.accountId = accountRecord.Id;
        Contact requester = [SELECT Id FROM Contact WHERE LastName = 'HR Requester' LIMIT 1];
        seed.requesterId = requester.Id;
        List<Contact> dataSubjects = [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE LastName LIKE 'Data Subject %'
            ORDER BY LastName ASC
            LIMIT :rowCount
        ];

        List<Reports__c> reports = new List<Reports__c>();
        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        for (Integer i = 0; i < dataSubjects.size(); i++) {
            seed.dataSubjectIds.add(dataSubjects[i].Id);
            contactsByEmail.put(dataSubjects[i].Email.toLowerCase(), dataSubjects[i]);
            reports.add(new Reports__c(
                Email__c = dataSubjects[i].Email,
                Consent_Status__c = 'Updated Consent',
                Updated_Date__c = Date.today(),
                Batch_ID__c = batchIdValue
            ));
        }
        insert reports;
        ReportUploadCaseBindingService.BindingResult bindingResult =
            ReportUploadCaseBindingService.createAndBindCases(reports, contactsByEmail);
        System.assertEquals(rowCount, bindingResult.createdCaseCount);
        System.assertEquals(rowCount, bindingResult.createdItemCount);
        return seed;
    }
}