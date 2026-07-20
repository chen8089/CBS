@IsTest
private class RecentActivityReportControllerTest {
    private static Id getOrCreateTestAccountId() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Recent Activity Report Test Account' LIMIT 1];
        if (!accounts.isEmpty()) {
            return accounts[0].Id;
        }
        Account accountRec = new Account(Name = 'Recent Activity Report Test Account');
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

    private static void ensureContactsForReports(List<Reports__c> reports) {
        for (Reports__c reportRecord : reports) {
            ensureContactForEmail(reportRecord.Email__c);
        }
    }

    @IsTest
    static void getRecentActivitiesReturnsCreatedReports() {
        List<Reports__c> reports = new List<Reports__c>();
        for (Integer index = 0; index < 8; index++) {
            reports.add(buildReport(index));
        }
        ensureContactsForReports(reports);
        insert reports;

        Test.startTest();
        List<RecentActivityReportController.ActivityItem> activities =
            RecentActivityReportController.getRecentActivities(5);
        Test.stopTest();

        System.assertEquals(5, activities.size(), 'The activity list should respect the requested max size.');
        System.assertEquals('Report Created', activities[0].title);
        System.assertEquals('standard:lead', activities[0].iconName);
        System.assertNotEquals(null, activities[0].recordId);
    }

    @IsTest
    static void trackedChangeHelpersBuildReportActivities() {
        Reports__c reportRecord = buildReport(100);
        ensureContactForEmail(reportRecord.Email__c);
        insert reportRecord;

        SObject feedRecord = (SObject) JSON.deserialize(
            '{"attributes":{"type":"Reports__Feed"},"Id":"0D5000000000001AAA","ParentId":"' + String.valueOf(reportRecord.Id) +
            '","CreatedDate":"' + System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') +
            '","Type":"TrackedChange","Body":"<p>This report was updated.</p>"}',
            SObject.class
        );
        RecentActivityReportController.TrackedChangeRecord trackedChangeRecord =
            new RecentActivityReportController.TrackedChangeRecord();
        trackedChangeRecord.id = '0D6000000000001AAA';
        trackedChangeRecord.feedItemId = (Id) feedRecord.get('Id');
        trackedChangeRecord.fieldName = RecentActivityReportController.normalizeTrackedFieldName('Reports__c.Consent_Status__c');
        trackedChangeRecord.oldValue = 'No Valid Consent';
        trackedChangeRecord.newValue = 'Updated Consent';
        RecentActivityReportController.TrackedChangeRecord setChangeRecord =
            new RecentActivityReportController.TrackedChangeRecord();
        setChangeRecord.id = '0D6000000000002AAA';
        setChangeRecord.feedItemId = (Id) feedRecord.get('Id');
        setChangeRecord.fieldName = RecentActivityReportController.normalizeTrackedFieldName('Reports__c.Name');
        setChangeRecord.oldValue = null;
        setChangeRecord.newValue = 'RN-0001';
        RecentActivityReportController.TrackedChangeRecord clearedChangeRecord =
            new RecentActivityReportController.TrackedChangeRecord();
        clearedChangeRecord.id = '0D6000000000003AAA';
        clearedChangeRecord.feedItemId = (Id) feedRecord.get('Id');
        clearedChangeRecord.fieldName = RecentActivityReportController.normalizeTrackedFieldName('Reports__c.Name');
        clearedChangeRecord.oldValue = 'RN-0001';
        clearedChangeRecord.newValue = null;

        Map<String, RecentActivityReportController.FieldMetadata> fieldMetadata =
            RecentActivityReportController.buildReportFieldMetadata();
        Map<Id, SObject> reportsById = new Map<Id, SObject>{ reportRecord.Id => reportRecord };
        RecentActivityReportController.ActivityItem trackedActivity =
            RecentActivityReportController.buildTrackedChangeActivity(
                feedRecord,
                trackedChangeRecord,
                reportsById,
                fieldMetadata,
                new Map<Id, String>()
            );
        RecentActivityReportController.ActivityItem setActivity =
            RecentActivityReportController.buildTrackedChangeActivity(
                feedRecord,
                setChangeRecord,
                reportsById,
                fieldMetadata,
                new Map<Id, String>()
            );
        RecentActivityReportController.ActivityItem clearedActivity =
            RecentActivityReportController.buildTrackedChangeActivity(
                feedRecord,
                clearedChangeRecord,
                reportsById,
                fieldMetadata,
                new Map<Id, String>()
            );
        RecentActivityReportController.ActivityItem feedActivity =
            RecentActivityReportController.buildFeedActivity(feedRecord, reportsById);

        System.assertEquals('Consent_Status__c', trackedChangeRecord.fieldName);
        System.assertEquals(true, RecentActivityReportController.shouldIncludeTrackedChange(trackedChangeRecord, fieldMetadata));
        System.assert(trackedActivity.title.contains('Consent Status'));
        System.assert(trackedActivity.description.contains('Updated Consent'));
        System.assert(setActivity.description.contains('changed from'));
        System.assert(setActivity.description.contains('None'));
        System.assert(clearedActivity.description.contains('changed from'));
        System.assert(clearedActivity.description.contains('None'));
        System.assert(feedActivity.description.contains('This report was updated.'));
    }

    @IsTest
    static void referenceTrackedChangesResolveNamesAndDeduplicateDisplayRows() {
        Id feedId = '0D5000000000006AAA';
        Map<String, RecentActivityReportController.FieldMetadata> fieldMetadata =
            RecentActivityReportController.buildReportFieldMetadata();

        RecentActivityReportController.TrackedChangeRecord readableOwnerChange =
            new RecentActivityReportController.TrackedChangeRecord();
        readableOwnerChange.id = '0D6000000000006AAA';
        readableOwnerChange.feedItemId = feedId;
        readableOwnerChange.fieldName = RecentActivityReportController.normalizeTrackedFieldName('Reports__c.Owner');
        readableOwnerChange.oldValue = 'Yee Hui Koh';
        readableOwnerChange.newValue = 'cai chen';

        RecentActivityReportController.TrackedChangeRecord idOwnerChange =
            new RecentActivityReportController.TrackedChangeRecord();
        idOwnerChange.id = '0D6000000000007AAA';
        idOwnerChange.feedItemId = feedId;
        idOwnerChange.fieldName = RecentActivityReportController.normalizeTrackedFieldName('Reports__c.Owner');
        idOwnerChange.oldValue = UserInfo.getUserId();
        idOwnerChange.newValue = UserInfo.getUserId();

        RecentActivityReportController.TrackedChangeRecord statusChange =
            new RecentActivityReportController.TrackedChangeRecord();
        statusChange.id = '0D6000000000008AAA';
        statusChange.feedItemId = feedId;
        statusChange.fieldName = 'Consent_Status__c';
        statusChange.oldValue = 'Old Status';
        statusChange.newValue = 'New Status';

        List<RecentActivityReportController.TrackedChangeRecord> deduplicatedChanges =
            RecentActivityReportController.deduplicateDisplayDuplicateTrackedChanges(
                new List<RecentActivityReportController.TrackedChangeRecord>{
                    idOwnerChange,
                    readableOwnerChange,
                    statusChange
                },
                fieldMetadata
            );
        Map<Id, List<RecentActivityReportController.TrackedChangeRecord>> changesByFeedId =
            new Map<Id, List<RecentActivityReportController.TrackedChangeRecord>>{
                feedId => new List<RecentActivityReportController.TrackedChangeRecord>{ idOwnerChange }
            };
        Map<Id, String> lookupNamesById = RecentActivityReportController.queryLookupNames(changesByFeedId, fieldMetadata);

        System.assertEquals(2, deduplicatedChanges.size(), 'Only the duplicate Owner ID row should be removed.');
        System.assertEquals(readableOwnerChange.id, deduplicatedChanges[0].id);
        System.assertEquals(statusChange.id, deduplicatedChanges[1].id);
        System.assertEquals(UserInfo.getName(), lookupNamesById.get(UserInfo.getUserId()));
        System.assertEquals(
            UserInfo.getName(),
            RecentActivityReportController.formatTrackedValue(
                UserInfo.getUserId(),
                fieldMetadata.get('Owner'),
                lookupNamesById
            )
        );
    }

    @IsTest
    static void utilityHelpersHandleFallbacksAndSorting() {
        Reports__c reportRecord = buildReport(200);
        ensureContactForEmail(reportRecord.Email__c);
        insert reportRecord;
        reportRecord = [
            SELECT Id, Name
            FROM Reports__c
            WHERE Id = :reportRecord.Id
        ];

        List<RecentActivityReportController.ActivityItem> activities =
            new List<RecentActivityReportController.ActivityItem>();
        for (Integer index = 0; index < 25; index++) {
            RecentActivityReportController.ActivityItem activity =
                new RecentActivityReportController.ActivityItem();
            activity.id = 'activity-' + index;
            activity.activityDate = System.now().addMinutes(index);
            activities.add(activity);
        }
        activities.sort();

        System.assertEquals(20, RecentActivityReportController.limitActivities(activities, null).size());
        System.assertEquals(3, RecentActivityReportController.limitActivities(activities, 3).size());
        System.assertEquals(20, RecentActivityReportController.normalizeMaxItems(0));
        System.assertEquals('Report', RecentActivityReportController.getReportName(null, new Map<Id, SObject>()));
        System.assertEquals(reportRecord.Name, RecentActivityReportController.getReportName(
            reportRecord.Id,
            new Map<Id, SObject>{ reportRecord.Id => reportRecord }
        ));
        System.assertEquals('Email__c', RecentActivityReportController.normalizeTrackedFieldName('Reports__c.Email__c'));
        System.assertEquals('hello world', RecentActivityReportController.stripHtml('<p>hello <b>world</b></p>'));
        System.assertEquals('&lt;b&gt;', RecentActivityReportController.escapeHtml('<b>'));
        System.assert(RecentActivityReportController.formatDisplayDate(System.now()).contains('/'));
        System.assertEquals('', RecentActivityReportController.formatDisplayDate(null));
        System.assertEquals(1, RecentActivityReportController.buildRecordsById(new List<SObject>{ reportRecord }).size());
        System.assertEquals(0, RecentActivityReportController.queryReportFeeds(new Set<Id>(), 5).size());
        System.assertEquals(0, RecentActivityReportController.getFeedIds(new List<SObject>()).size());
        System.assertEquals(0, RecentActivityReportController.getFeedParentIds(new List<SObject>()).size());
        System.assertEquals(false, RecentActivityReportController.shouldIncludeTrackedChange(null, RecentActivityReportController.buildReportFieldMetadata()));
        System.assertEquals(false, RecentActivityReportController.queryTrackedChangesByFeedId(new Set<Id>(), RecentActivityReportController.buildReportFieldMetadata()).queryFailed);
        System.assertNotEquals(null, RecentActivityReportController.queryRecentReportFeeds(1));
        System.assertNotEquals(null, RecentActivityReportController.queryRecentUpdateReportFeeds(1));
        System.assertNotEquals(null, RecentActivityReportController.queryReportsById(new Set<Id>{ reportRecord.Id }));
    }

    private static Reports__c buildReport(Integer index) {
        return new Reports__c(
            Email__c = 'report' + index + '@example.com',
            Consent_Status__c = 'Updated Consent',
            Batch_ID__c = 'REPORT-' + String.valueOf(index),
            Updated_Date__c = Date.today()
        );
    }
}