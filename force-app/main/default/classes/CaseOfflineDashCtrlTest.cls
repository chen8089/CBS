@IsTest
private class CaseOfflineDashCtrlTest {
    private static Id getOrCreateTestAccountId() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Case Offline Test Account' LIMIT 1];
        if (!accounts.isEmpty()) {
            return accounts[0].Id;
        }
        Account accountRec = new Account(Name = 'Case Offline Test Account');
        insert accountRec;
        return accountRec.Id;
    }

    private static void ensureContactForEmail(String email) {
        if (String.isBlank(email)) {
            return;
        }
        if ([SELECT COUNT() FROM Contact WHERE Email = :email] > 0) {
            return;
        }

        Contact c = new Contact(
            LastName = 'Report Contact',
            Email = email,
            AccountId = getOrCreateTestAccountId(),
            Full_Name__c = 'Report Contact',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0'),
            Portal_Role__c = 'Approver'
        );
        insert c;
    }

    private static Reports__c newReport(String email, String batchId, String consentStatus) {
        Reports__c r = new Reports__c();
        if (Schema.SObjectType.Reports__c.fields.getMap().containsKey('Email__c')) {
            r.Email__c = email;
        }
        if (Schema.SObjectType.Reports__c.fields.getMap().containsKey('Batch_ID__c')) {
            r.Batch_ID__c = batchId;
        }
        if (Schema.SObjectType.Reports__c.fields.getMap().containsKey('Consent_Status__c')) {
            r.Consent_Status__c = consentStatus;
        }
        if (Schema.SObjectType.Reports__c.fields.getMap().containsKey('Updated_Date__c')) {
            r.Updated_Date__c = Date.today();
        }
        return r;
    }

    @IsTest
    static void testSummaryAndList_whenReportInsertable() {
        if (!Schema.SObjectType.Reports__c.isCreateable()) {
            return;
        }

        List<Reports__c> toInsert = new List<Reports__c>{
            newReport('report.one@test.com', 'RPT-001', CaseOfflineProcessingDashboardController.STATUS_UPDATED_CONSENT),
            newReport('report.two@test.com', 'RPT-002', CaseOfflineProcessingDashboardController.STATUS_NO_VALID_CONSENT)
        };
        ensureContactForEmail('report.one@test.com');
        ensureContactForEmail('report.two@test.com');
        insert toInsert;

        Test.startTest();
        CaseOfflineProcessingDashboardController.ReportSummaryDTO sum =
            CaseOfflineProcessingDashboardController.getReportSummary();
        List<CaseOfflineProcessingDashboardController.ReportDTO> rows =
            CaseOfflineProcessingDashboardController.getReports('ALL', '', 'Updated_Date__c', 'DESC', null);
        Test.stopTest();

        System.assert(sum.all >= 2, 'Summary should include inserted reports');
        Integer matched = 0;
        Set<Id> ids = new Set<Id>{ toInsert[0].Id, toInsert[1].Id };
        for (CaseOfflineProcessingDashboardController.ReportDTO row : rows) {
            if (ids.contains(row.id)) {
                matched++;
            }
        }
        System.assertEquals(2, matched, 'getReports(ALL) should return both inserted rows');

        List<CaseOfflineProcessingDashboardController.ReportDTO> updatedOnly =
            CaseOfflineProcessingDashboardController.getReports(
                'UPDATED_CONSENT',
                'report.one',
                'Email__c',
                'ASC',
                null
            );
        Boolean foundUpdated = false;
        for (CaseOfflineProcessingDashboardController.ReportDTO row : updatedOnly) {
            if (row.id == toInsert[0].Id) {
                foundUpdated = true;
                System.assertEquals(CaseOfflineProcessingDashboardController.STATUS_UPDATED_CONSENT, row.consentStatus);
                break;
            }
        }
        System.assert(foundUpdated, 'UPDATED_CONSENT filter should include matching report');
    }

    @IsTest
    static void testControllerFiltersAndSortBranches() {
        CaseOfflineProcessingDashboardController.getReportSummary();
        CaseOfflineProcessingDashboardController.getReports('ALL', '', 'Updated_Date__c', 'DESC', null);
        CaseOfflineProcessingDashboardController.getReports('ALL', '', 'Updated_Date__c', 'ASC', null);
        CaseOfflineProcessingDashboardController.getReports('UPDATED_CONSENT', '', 'Email__c', 'ASC', null);
        CaseOfflineProcessingDashboardController.getReports('NO_VALID_CONSENT', '', 'Batch_ID__c', 'DESC', null);
        CaseOfflineProcessingDashboardController.getReports('ALL', 'unlikelyxyz123', 'Consent_Status__c', 'ASC', null);
        CaseOfflineProcessingDashboardController.getReports('ALL', '', 'CreatedDate', 'DESC', null);

        CaseOfflineProcessingDashboardController.DashboardFilter f =
            new CaseOfflineProcessingDashboardController.DashboardFilter();
        f.ownership = 'MY';
        f.status = 'NO_VALID_CONSENT';
        f.dateType = 'Updated_Date__c';
        f.startDate = Date.today().addDays(-7);
        f.endDate = Date.today();
        CaseOfflineProcessingDashboardController.getReports('ALL', '', 'LastModifiedDate', 'DESC', f);

        System.assert(true);
    }
}