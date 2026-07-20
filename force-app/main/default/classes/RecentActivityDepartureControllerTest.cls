@IsTest
private class RecentActivityDepartureControllerTest {
    private static Id getOrCreateTestAccountId() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Recent Activity Departure Test Account' LIMIT 1];
        if (!accounts.isEmpty()) {
            return accounts[0].Id;
        }
        Account accountRec = new Account(Name = 'Recent Activity Departure Test Account');
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
            LastName = 'Departure Contact',
            Email = email,
            AccountId = getOrCreateTestAccountId(),
            Full_Name__c = 'Departure Contact',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0'),
            Portal_Role__c = 'Approver'
        );
        insert c;
    }

    private static void ensureContactsForDepartures(List<Departure__c> departures) {
        for (Departure__c departureRecord : departures) {
            ensureContactForEmail(departureRecord.Email__c);
        }
    }

    @IsTest
    static void getRecentActivitiesReturnsCreatedDepartures() {
        List<Departure__c> departures = new List<Departure__c>();
        for (Integer index = 0; index < 8; index++) {
            departures.add(buildDeparture(index));
        }
        ensureContactsForDepartures(departures);
        insert departures;

        Test.startTest();
        List<RecentActivityDepartureController.ActivityItem> activities =
            RecentActivityDepartureController.getRecentActivities(5);
        Test.stopTest();

        System.assertEquals(5, activities.size(), 'The activity list should respect the requested max size.');
        System.assertEquals('Departure Created', activities[0].title);
        System.assertEquals('standard:lead', activities[0].iconName);
        System.assertNotEquals(null, activities[0].recordId);
    }

    @IsTest
    static void trackedChangeHelpersBuildDepartureActivities() {
        Departure__c departureRecord = buildDeparture(100);
        ensureContactForEmail(departureRecord.Email__c);
        insert departureRecord;

        SObject feedRecord = (SObject) JSON.deserialize(
            '{"attributes":{"type":"Departure__Feed"},"Id":"0D5000000000001AAA","ParentId":"' + String.valueOf(departureRecord.Id) +
            '","CreatedDate":"' + System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') +
            '","Type":"TrackedChange","Body":"<p>This departure was updated.</p>"}',
            SObject.class
        );
        RecentActivityDepartureController.TrackedChangeRecord trackedChangeRecord =
            new RecentActivityDepartureController.TrackedChangeRecord();
        trackedChangeRecord.id = '0D6000000000001AAA';
        trackedChangeRecord.feedItemId = (Id) feedRecord.get('Id');
        trackedChangeRecord.fieldName = RecentActivityDepartureController.normalizeTrackedFieldName('Departure__c.Consent_Status__c');
        trackedChangeRecord.oldValue = 'No Valid Consent';
        trackedChangeRecord.newValue = 'Updated Consent';
        RecentActivityDepartureController.TrackedChangeRecord setChangeRecord =
            new RecentActivityDepartureController.TrackedChangeRecord();
        setChangeRecord.id = '0D6000000000002AAA';
        setChangeRecord.feedItemId = (Id) feedRecord.get('Id');
        setChangeRecord.fieldName = RecentActivityDepartureController.normalizeTrackedFieldName('Departure__c.Name');
        setChangeRecord.oldValue = null;
        setChangeRecord.newValue = 'DN-0001';
        RecentActivityDepartureController.TrackedChangeRecord clearedChangeRecord =
            new RecentActivityDepartureController.TrackedChangeRecord();
        clearedChangeRecord.id = '0D6000000000003AAA';
        clearedChangeRecord.feedItemId = (Id) feedRecord.get('Id');
        clearedChangeRecord.fieldName = RecentActivityDepartureController.normalizeTrackedFieldName('Departure__c.Name');
        clearedChangeRecord.oldValue = 'DN-0001';
        clearedChangeRecord.newValue = null;
        Map<String, RecentActivityDepartureController.FieldMetadata> fieldMetadata =
            RecentActivityDepartureController.buildDepartureFieldMetadata();
        Map<Id, SObject> departuresById = new Map<Id, SObject>{ departureRecord.Id => departureRecord };

        RecentActivityDepartureController.ActivityItem trackedActivity =
            RecentActivityDepartureController.buildTrackedChangeActivity(
                feedRecord,
                trackedChangeRecord,
                departuresById,
                fieldMetadata,
                new Map<Id, String>()
            );
        RecentActivityDepartureController.ActivityItem setActivity =
            RecentActivityDepartureController.buildTrackedChangeActivity(
                feedRecord,
                setChangeRecord,
                departuresById,
                fieldMetadata,
                new Map<Id, String>()
            );
        RecentActivityDepartureController.ActivityItem clearedActivity =
            RecentActivityDepartureController.buildTrackedChangeActivity(
                feedRecord,
                clearedChangeRecord,
                departuresById,
                fieldMetadata,
                new Map<Id, String>()
            );
        RecentActivityDepartureController.ActivityItem feedActivity =
            RecentActivityDepartureController.buildFeedActivity(feedRecord, departuresById);

        System.assertEquals('Consent_Status__c', trackedChangeRecord.fieldName);
        System.assertEquals(true, RecentActivityDepartureController.shouldIncludeTrackedChange(trackedChangeRecord, fieldMetadata));
        System.assert(trackedActivity.title.contains('Consent Status'));
        System.assert(trackedActivity.description.contains('Updated Consent'));
        System.assert(setActivity.description.contains('changed from'));
        System.assert(setActivity.description.contains('None'));
        System.assert(clearedActivity.description.contains('changed from'));
        System.assert(clearedActivity.description.contains('None'));
        System.assert(feedActivity.description.contains('This departure was updated.'));
    }

    @IsTest
    static void referenceTrackedChangesResolveNamesAndDeduplicateDisplayRows() {
        Id feedId = '0D5000000000006AAA';
        Map<String, RecentActivityDepartureController.FieldMetadata> fieldMetadata =
            RecentActivityDepartureController.buildDepartureFieldMetadata();

        RecentActivityDepartureController.TrackedChangeRecord readableOwnerChange =
            new RecentActivityDepartureController.TrackedChangeRecord();
        readableOwnerChange.id = '0D6000000000006AAA';
        readableOwnerChange.feedItemId = feedId;
        readableOwnerChange.fieldName = RecentActivityDepartureController.normalizeTrackedFieldName('Departure__c.Owner');
        readableOwnerChange.oldValue = 'Yee Hui Koh';
        readableOwnerChange.newValue = 'cai chen';

        RecentActivityDepartureController.TrackedChangeRecord idOwnerChange =
            new RecentActivityDepartureController.TrackedChangeRecord();
        idOwnerChange.id = '0D6000000000007AAA';
        idOwnerChange.feedItemId = feedId;
        idOwnerChange.fieldName = RecentActivityDepartureController.normalizeTrackedFieldName('Departure__c.Owner');
        idOwnerChange.oldValue = UserInfo.getUserId();
        idOwnerChange.newValue = UserInfo.getUserId();

        RecentActivityDepartureController.TrackedChangeRecord statusChange =
            new RecentActivityDepartureController.TrackedChangeRecord();
        statusChange.id = '0D6000000000008AAA';
        statusChange.feedItemId = feedId;
        statusChange.fieldName = 'Consent_Status__c';
        statusChange.oldValue = 'Old Status';
        statusChange.newValue = 'New Status';

        List<RecentActivityDepartureController.TrackedChangeRecord> deduplicatedChanges =
            RecentActivityDepartureController.deduplicateDisplayDuplicateTrackedChanges(
                new List<RecentActivityDepartureController.TrackedChangeRecord>{
                    idOwnerChange,
                    readableOwnerChange,
                    statusChange
                },
                fieldMetadata
            );
        Map<Id, List<RecentActivityDepartureController.TrackedChangeRecord>> changesByFeedId =
            new Map<Id, List<RecentActivityDepartureController.TrackedChangeRecord>>{
                feedId => new List<RecentActivityDepartureController.TrackedChangeRecord>{ idOwnerChange }
            };
        Map<Id, String> lookupNamesById = RecentActivityDepartureController.queryLookupNames(changesByFeedId, fieldMetadata);

        System.assertEquals(2, deduplicatedChanges.size(), 'Only the duplicate Owner ID row should be removed.');
        System.assertEquals(readableOwnerChange.id, deduplicatedChanges[0].id);
        System.assertEquals(statusChange.id, deduplicatedChanges[1].id);
        System.assertEquals(UserInfo.getName(), lookupNamesById.get(UserInfo.getUserId()));
        System.assertEquals(
            UserInfo.getName(),
            RecentActivityDepartureController.formatTrackedValue(
                UserInfo.getUserId(),
                fieldMetadata.get('Owner'),
                lookupNamesById
            )
        );
    }

    @IsTest
    static void utilityHelpersHandleFallbacksAndSorting() {
        Departure__c departureRecord = buildDeparture(200);
        ensureContactForEmail(departureRecord.Email__c);
        insert departureRecord;
        departureRecord = [
            SELECT Id, Name
            FROM Departure__c
            WHERE Id = :departureRecord.Id
        ];

        List<RecentActivityDepartureController.ActivityItem> activities =
            new List<RecentActivityDepartureController.ActivityItem>();
        for (Integer index = 0; index < 25; index++) {
            RecentActivityDepartureController.ActivityItem activity =
                new RecentActivityDepartureController.ActivityItem();
            activity.id = 'activity-' + index;
            activity.activityDate = System.now().addMinutes(index);
            activities.add(activity);
        }
        activities.sort();

        System.assertEquals(20, RecentActivityDepartureController.limitActivities(activities, null).size());
        System.assertEquals(3, RecentActivityDepartureController.limitActivities(activities, 3).size());
        System.assertEquals(20, RecentActivityDepartureController.normalizeMaxItems(0));
        System.assertEquals('Departure', RecentActivityDepartureController.getDepartureName(null, new Map<Id, SObject>()));
        System.assertEquals(departureRecord.Name, RecentActivityDepartureController.getDepartureName(
            departureRecord.Id,
            new Map<Id, SObject>{ departureRecord.Id => departureRecord }
        ));
        System.assertEquals('Email__c', RecentActivityDepartureController.normalizeTrackedFieldName('Departure__c.Email__c'));
        System.assertEquals('hello world', RecentActivityDepartureController.stripHtml('<p>hello <b>world</b></p>'));
        System.assertEquals('&lt;b&gt;', RecentActivityDepartureController.escapeHtml('<b>'));
        System.assert(RecentActivityDepartureController.formatDisplayDate(System.now()).contains('/'));
        System.assertEquals('', RecentActivityDepartureController.formatDisplayDate(null));
        System.assertEquals(1, RecentActivityDepartureController.buildRecordsById(new List<SObject>{ departureRecord }).size());
        System.assertEquals(0, RecentActivityDepartureController.queryDepartureFeeds(new Set<Id>(), 5).size());
        System.assertEquals(0, RecentActivityDepartureController.getFeedIds(new List<SObject>()).size());
        System.assertEquals(0, RecentActivityDepartureController.getFeedParentIds(new List<SObject>()).size());
        System.assertEquals(false, RecentActivityDepartureController.shouldIncludeTrackedChange(null, RecentActivityDepartureController.buildDepartureFieldMetadata()));
        System.assertEquals(false, RecentActivityDepartureController.queryTrackedChangesByFeedId(new Set<Id>(), RecentActivityDepartureController.buildDepartureFieldMetadata()).queryFailed);
        System.assertNotEquals(null, RecentActivityDepartureController.queryRecentDepartureFeeds(1));
        System.assertNotEquals(null, RecentActivityDepartureController.queryRecentUpdateDepartureFeeds(1));
        System.assertNotEquals(null, RecentActivityDepartureController.queryDeparturesById(new Set<Id>{ departureRecord.Id }));
    }

    private static Departure__c buildDeparture(Integer index) {
        return new Departure__c(
            Email__c = 'departure' + index + '@example.com',
            Consent_Status__c = 'Updated Consent',
            Departure_Date__c = Date.today().addDays(index),
            Batch_ID__c = 'BATCH-' + String.valueOf(index),
            Updated_Date__c = Date.today()
        );
    }
}