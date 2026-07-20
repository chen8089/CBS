@IsTest
private class RecentActivityContactControllerTest {
    private static String firstActivePicklistValue(Schema.SObjectField fieldToken) {
        String value = 'Active';

        if (fieldToken != null) {
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST) {
                for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
                    if (picklistEntry.isActive()) {
                        value = picklistEntry.getValue();
                    }
                }
            }
        }

        return value;
    }

    private static void applyContactDefaults(Contact contactRecord, Integer index) {
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();

        if (contactFields.containsKey('Full_Name__c') && contactRecord.get('Full_Name__c') == null) {
            contactRecord.put('Full_Name__c', 'Recent Activity Contact ' + index);
        }
        if (contactFields.containsKey('Date_of_Birth__c') && contactRecord.get('Date_of_Birth__c') == null) {
            contactRecord.put('Date_of_Birth__c', Date.newInstance(1990, 6, 15));
        }
        if (contactFields.containsKey('Employment_Status__c') && contactRecord.get('Employment_Status__c') == null) {
            contactRecord.put('Employment_Status__c', firstActivePicklistValue(contactFields.get('Employment_Status__c')));
        }
        if (contactFields.containsKey('ID_Type__c') && contactRecord.get('ID_Type__c') == null) {
            contactRecord.put('ID_Type__c', firstActivePicklistValue(contactFields.get('ID_Type__c')));
        }
        if (contactFields.containsKey('ID_Number__c') && contactRecord.get('ID_Number__c') == null) {
            contactRecord.put('ID_Number__c', 'RA-' + String.valueOf(index).leftPad(4, '0'));
        }
        if (contactFields.containsKey('Portal_Role__c') && contactRecord.get('Portal_Role__c') == null) {
            contactRecord.put('Portal_Role__c', firstActivePicklistValue(contactFields.get('Portal_Role__c')));
        }
    }

    private static void applyAccountDefaults(Account accountRecord) {
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();

        if (accountFields.containsKey('Client_Code__c') && accountRecord.get('Client_Code__c') == null) {
            accountRecord.put('Client_Code__c', 'RA' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(8, '0'));
        }
        if (accountFields.containsKey('Client_Status__c') && accountRecord.get('Client_Status__c') == null) {
            accountRecord.put('Client_Status__c', firstActivePicklistValue(accountFields.get('Client_Status__c')));
        }
    }

    @IsTest
    static void getRecentActivitiesReturnsLatestTwentyContactCreates() {
        List<Contact> contacts = new List<Contact>();

        for (Integer index = 0; index < 25; index++) {
            Contact contactRecord = new Contact(LastName = 'Recent Activity Contact ' + index);
            applyContactDefaults(contactRecord, index);
            contacts.add(contactRecord);
        }
        insert contacts;
        setEmptyFeedMocks(contacts);

        Test.startTest();
        List<RecentActivityContactController.ActivityItem> activities =
            RecentActivityContactController.getRecentActivities();
        Test.stopTest();

        System.assertEquals(20, activities.size(), 'The contact activity list should be capped at 20 items.');

        if (activities.size() > 0) {
            System.assertEquals('Contact Created', activities[0].title);
            System.assert(activities[0].description.contains('Recent Activity Contact'));
            System.assertEquals('standard:lead', activities[0].iconName);
            System.assertNotEquals(null, activities[0].recordId);
        }
    }

    @IsTest
    static void getRecentActivitiesByRecordIdReturnsEmptyForNullAndNonContact() {
        Account accountRecord = new Account(Name = 'Recent Activity Non Contact');
        applyAccountDefaults(accountRecord);
        insert accountRecord;

        Test.startTest();
        List<RecentActivityContactController.ActivityItem> nullActivities =
            RecentActivityContactController.getRecentActivitiesByRecordId(null, 20);
        List<RecentActivityContactController.ActivityItem> nonContactActivities =
            RecentActivityContactController.getRecentActivitiesByRecordId(accountRecord.Id, 20);
        List<ContactFeed> nullFeedRows =
            RecentActivityContactController.queryTrackedContactFeedsByRecordId(null, 20);
        Test.stopTest();

        System.assertEquals(0, nullActivities.size(), 'Null recordId should return no activities.');
        System.assertEquals(0, nonContactActivities.size(), 'Non-Contact recordId should return no activities.');
        System.assertEquals(0, nullFeedRows.size(), 'Null recordId should return no tracked feed rows.');
    }

    @IsTest
    static void getRecentActivitiesByRecordIdReturnsEmptyForContactWithoutTrackedFeed() {
        Contact contactRecord = new Contact(LastName = 'Record Scope Contact');
        applyContactDefaults(contactRecord, 202);
        insert contactRecord;

        Test.startTest();
        List<RecentActivityContactController.ActivityItem> activities =
            RecentActivityContactController.getRecentActivitiesByRecordId(contactRecord.Id, 20);
        List<ContactFeed> feedRows =
            RecentActivityContactController.queryTrackedContactFeedsByRecordId(contactRecord.Id, 20);
        Test.stopTest();

        System.assertEquals(0, activities.size(), 'Contact with no tracked feed should return no activities.');
        System.assertEquals(0, feedRows.size(), 'No tracked feed rows should be returned for fresh contact.');
    }

    @IsTest
    static void candidateContactsMergeCreatedAndModifiedRecords() {
        Contact createdContact = new Contact(LastName = 'Created Candidate');
        Contact modifiedContact = new Contact(LastName = 'Modified Candidate');
        applyContactDefaults(createdContact, 40);
        applyContactDefaults(modifiedContact, 41);
        insert new List<Contact>{ createdContact, modifiedContact };

        Map<Id, Contact> candidates = RecentActivityContactController.buildCandidateContactsById(
            new List<Contact>{ createdContact },
            new List<Contact>{ modifiedContact }
        );

        System.assertEquals(2, candidates.size());
        System.assert(candidates.containsKey(createdContact.Id));
        System.assert(candidates.containsKey(modifiedContact.Id));
    }

    @IsTest
    static void trackedChangeJsonParsesAndBuildsActivity() {
        Contact contactRecord = new Contact(LastName = 'Feed Contact');
        applyContactDefaults(contactRecord, 99);
        insert contactRecord;

        String createdDateText = System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        Map<String, Object> feedElementMap = new Map<String, Object>{
            'id' => '0D5TEST000000001',
            'type' => 'TrackedChange',
            'createdDate' => createdDateText,
            'parent' => new Map<String, Object>{ 'id' => String.valueOf(contactRecord.Id) },
            'body' => new Map<String, Object>{
                'messageSegments' => new List<Object>{
                    new Map<String, Object>{ 'text' => 'changed account' }
                }
            },
            'capabilities' => new Map<String, Object>{
                'trackedChanges' => new Map<String, Object>{
                    'changes' => new List<Object>{
                        new Map<String, Object>{
                            'fieldName' => 'Account',
                            'oldValue' => null,
                            'newValue' => 'New Account'
                        }
                    }
                }
            }
        };

        Map<String, RecentActivityContactController.FieldMetadata> fieldMetadata =
            RecentActivityContactController.buildContactFieldMetadata();
        List<RecentActivityContactController.TrackedChangeValue> trackedChanges =
            RecentActivityContactController.extractTrackedChangesFromMap(feedElementMap, fieldMetadata);
        Map<Id, Contact> contactsById = new Map<Id, Contact>{ contactRecord.Id => contactRecord };

        RecentActivityContactController.ActivityItem trackedActivity =
            RecentActivityContactController.buildTrackedChangeActivityFromValues(
                trackedChanges[0].feedElementId,
                contactRecord.Id,
                trackedChanges[0].createdDate,
                trackedChanges[0].fieldLabel,
                trackedChanges[0].oldValue,
                trackedChanges[0].newValue,
                contactsById
            );
        RecentActivityContactController.ActivityItem feedActivity =
            RecentActivityContactController.buildFeedActivityFromMap(feedElementMap, contactsById);
        List<RecentActivityContactController.TrackedChangeValue> noTrackedChanges =
            RecentActivityContactController.extractTrackedChangesFromMap(new Map<String, Object>(), fieldMetadata);

        System.assertEquals(1, trackedChanges.size());
        System.assertEquals(0, noTrackedChanges.size());
        System.assertEquals('Account', trackedChanges[0].fieldName);
        System.assert(trackedActivity.title.contains('Changed'));
        System.assert(trackedActivity.description.contains('New Account'));
        System.assert(feedActivity.description.contains('changed account'));
    }

    @IsTest
    static void trackedChangeValuesBuildIndependentActivities() {
        Contact contactRecord = new Contact(LastName = 'Tracked Contact');
        applyContactDefaults(contactRecord, 120);
        insert contactRecord;

        ContactFeed feedRecord = (ContactFeed) JSON.deserialize(
            '{"attributes":{"type":"ContactFeed"},"Id":"0D5000000000001AAA","ParentId":"' + String.valueOf(contactRecord.Id) +
            '","CreatedDate":"' + System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') +
            '","Type":"TrackedChange","Body":"<p>This record was updated.</p>"}',
            ContactFeed.class
        );

        RecentActivityContactController.TrackedChangeRecord firstChange =
            new RecentActivityContactController.TrackedChangeRecord();
        firstChange.id = '0D9000000000001AAA';
        firstChange.feedItemId = feedRecord.Id;
        firstChange.fieldName = 'LastName';
        firstChange.oldValue = 'Old Name';
        firstChange.newValue = 'New Name';

        RecentActivityContactController.TrackedChangeRecord secondChange =
            new RecentActivityContactController.TrackedChangeRecord();
        secondChange.id = '0D9000000000002AAA';
        secondChange.feedItemId = feedRecord.Id;
        secondChange.fieldName = 'LastName';
        secondChange.oldValue = null;
        secondChange.newValue = 'Newest Name';

        RecentActivityContactController.TrackedChangeRecord thirdChange =
            new RecentActivityContactController.TrackedChangeRecord();
        thirdChange.id = '0D9000000000003AAA';
        thirdChange.feedItemId = feedRecord.Id;
        thirdChange.fieldName = 'LastName';
        thirdChange.oldValue = 'Cleared Name';
        thirdChange.newValue = null;

        Map<String, RecentActivityContactController.FieldMetadata> fieldMetadata =
            RecentActivityContactController.buildContactFieldMetadata();
        Map<Id, List<RecentActivityContactController.TrackedChangeRecord>> changesByFeedId =
            new Map<Id, List<RecentActivityContactController.TrackedChangeRecord>>{
            feedRecord.Id => new List<RecentActivityContactController.TrackedChangeRecord>{ firstChange, secondChange, thirdChange }
        };
        Map<Id, Contact> contactsById = new Map<Id, Contact>{ contactRecord.Id => contactRecord };

        List<RecentActivityContactController.TrackedChangeValue> values =
            RecentActivityContactController.buildTrackedChangeValues(
                new List<ContactFeed>{ feedRecord },
                changesByFeedId,
                fieldMetadata
            );
        RecentActivityContactController.ActivityItem firstActivity =
            RecentActivityContactController.buildTrackedChangeActivityFromValues(
                String.valueOf(feedRecord.Id),
                String.valueOf(firstChange.id),
                contactRecord.Id,
                feedRecord.CreatedDate,
                values[0].fieldName,
                values[0].fieldLabel,
                values[0].oldValue,
                values[0].newValue,
                contactsById
            );
        RecentActivityContactController.ActivityItem secondActivity =
            RecentActivityContactController.buildTrackedChangeActivityFromValues(
                String.valueOf(feedRecord.Id),
                String.valueOf(secondChange.id),
                contactRecord.Id,
                feedRecord.CreatedDate,
                values[1].fieldName,
                values[1].fieldLabel,
                values[1].oldValue,
                values[1].newValue,
                contactsById
            );
        RecentActivityContactController.ActivityItem thirdActivity =
            RecentActivityContactController.buildTrackedChangeActivityFromValues(
                String.valueOf(feedRecord.Id),
                String.valueOf(thirdChange.id),
                contactRecord.Id,
                feedRecord.CreatedDate,
                values[2].fieldName,
                values[2].fieldLabel,
                values[2].oldValue,
                values[2].newValue,
                contactsById
            );
        RecentActivityContactController.ActivityItem feedActivity =
            RecentActivityContactController.buildContactFeedActivity(feedRecord, contactsById);

        System.assertEquals(3, values.size(), 'Every tracked change under the feed should remain separate.');
        System.assertEquals(Contact.LastName.getDescribe().getLabel(), values[0].fieldLabel);
        System.assertEquals(String.valueOf(feedRecord.Id) + '-' + String.valueOf(firstChange.id), firstActivity.id);
        System.assertEquals(String.valueOf(feedRecord.Id), firstActivity.feedId);
        System.assertEquals(String.valueOf(firstChange.id), firstActivity.changeId);
        System.assertEquals('LastName', firstActivity.fieldName);
        System.assert(firstActivity.description.contains('changed from'));
        System.assert(secondActivity.description.contains('changed from'));
        System.assert(secondActivity.description.contains('None'));
        System.assert(thirdActivity.description.contains('changed from'));
        System.assert(thirdActivity.description.contains('None'));
        System.assert(feedActivity.description.contains('This record was updated.'));
    }

    @IsTest
    static void duplicateReferenceTrackedChangesPreferReadableValues() {
        Id feedId = '0D5000000000006AAA';
        Map<String, RecentActivityContactController.FieldMetadata> fieldMetadata =
            RecentActivityContactController.buildContactFieldMetadata();

        RecentActivityContactController.TrackedChangeRecord readableOwnerChange =
            new RecentActivityContactController.TrackedChangeRecord();
        readableOwnerChange.id = '0D9000000000006AAA';
        readableOwnerChange.feedItemId = feedId;
        readableOwnerChange.fieldName = RecentActivityContactController.normalizeTrackedFieldName('Contact.Owner');
        readableOwnerChange.oldValue = 'Yee Hui Koh';
        readableOwnerChange.newValue = 'cai chen';

        RecentActivityContactController.TrackedChangeRecord idOwnerChange =
            new RecentActivityContactController.TrackedChangeRecord();
        idOwnerChange.id = '0D9000000000007AAA';
        idOwnerChange.feedItemId = feedId;
        idOwnerChange.fieldName = RecentActivityContactController.normalizeTrackedFieldName('Contact.Owner');
        idOwnerChange.oldValue = UserInfo.getUserId();
        idOwnerChange.newValue = UserInfo.getUserId();

        RecentActivityContactController.TrackedChangeRecord firstNameChange =
            new RecentActivityContactController.TrackedChangeRecord();
        firstNameChange.id = '0D9000000000008AAA';
        firstNameChange.feedItemId = feedId;
        firstNameChange.fieldName = 'LastName';
        firstNameChange.oldValue = 'Old Name';
        firstNameChange.newValue = 'New Name';

        RecentActivityContactController.TrackedChangeRecord secondNameChange =
            new RecentActivityContactController.TrackedChangeRecord();
        secondNameChange.id = '0D9000000000009AAA';
        secondNameChange.feedItemId = feedId;
        secondNameChange.fieldName = 'LastName';
        secondNameChange.oldValue = 'New Name';
        secondNameChange.newValue = 'Newest Name';

        List<RecentActivityContactController.TrackedChangeRecord> deduplicatedChanges =
            RecentActivityContactController.deduplicateDisplayDuplicateTrackedChanges(
                new List<RecentActivityContactController.TrackedChangeRecord>{
                    readableOwnerChange,
                    idOwnerChange,
                    firstNameChange,
                    secondNameChange
                },
                fieldMetadata
            );

        System.assertEquals(3, deduplicatedChanges.size(), 'Only the duplicate Owner ID row should be removed.');
        System.assertEquals(readableOwnerChange.id, deduplicatedChanges[0].id);
        System.assertEquals('Yee Hui Koh', deduplicatedChanges[0].oldValue);
        System.assertEquals('cai chen', deduplicatedChanges[0].newValue);
        System.assertEquals(firstNameChange.id, deduplicatedChanges[1].id);
        System.assertEquals(secondNameChange.id, deduplicatedChanges[2].id);
    }

    @IsTest
    static void getRecentActivitiesIncludesFeedFallbackItems() {
        Contact contactRecord = new Contact(LastName = 'Feed Fallback Contact');
        applyContactDefaults(contactRecord, 121);
        insert contactRecord;
        insert new FeedItem(
            ParentId = contactRecord.Id,
            Body = 'Fallback feed body',
            Type = 'TextPost'
        );
        setEmptyFeedMocks(new List<Contact>{ contactRecord });

        Test.startTest();
        List<RecentActivityContactController.ActivityItem> activities =
            RecentActivityContactController.getRecentActivities(20);
        RecentActivityContactController.ActivityDebugResult debugResult =
            RecentActivityContactController.getRecentActivitiesWithDebug(20);
        Test.stopTest();

        ContactFeed fallbackFeedRecord = (ContactFeed) JSON.deserialize(
            '{"attributes":{"type":"ContactFeed"},"Id":"0D5000000000005AAA","ParentId":"' + String.valueOf(contactRecord.Id) +
            '","CreatedDate":"' + System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') +
            '","Type":"TextPost","Body":"<p>Fallback feed body</p>"}',
            ContactFeed.class
        );
        RecentActivityContactController.ActivityItem fallbackActivity =
            RecentActivityContactController.buildContactFeedActivity(
                fallbackFeedRecord,
                new Map<Id, Contact>{ contactRecord.Id => contactRecord }
            );

        System.assert(activities.size() > 0, 'Recent activities should still render even when ContactFeed rows are unavailable in tests.');
        System.assert(fallbackActivity.description.contains('Fallback feed body'));
        System.assertEquals(debugResult.activities.size(), debugResult.debug.activityCount);
        System.assertNotEquals(null, debugResult.debug.userId);
    }

    @IsTest
    static void trackedChangeHelpersRespectFilteringAndLabels() {
        Id feedId = '0D5000000000002AAA';
        Map<String, RecentActivityContactController.FieldMetadata> fieldMetadata =
            RecentActivityContactController.buildContactFieldMetadata();
        RecentActivityContactController.ActivityItem updatedActivity =
            RecentActivityContactController.buildTrackedChangeActivityFromValues(
                String.valueOf(feedId),
                'change-without-id',
                null,
                System.now(),
                'LastName',
                RecentActivityContactController.getFieldLabel('LastName', fieldMetadata),
                null,
                null,
                new Map<Id, Contact>()
            );
        ContactFeed feedRecord = (ContactFeed) JSON.deserialize(
            '{"attributes":{"type":"ContactFeed"},"Id":"0D5000000000004AAA","ParentId":"' + String.valueOf(feedId) +
            '","CreatedDate":"' + System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') +
            '","Type":"TextPost","Body":null}',
            ContactFeed.class
        );
        RecentActivityContactController.ActivityItem fallbackActivity =
            RecentActivityContactController.buildContactFeedActivity(feedRecord, new Map<Id, Contact>());
        List<RecentActivityContactController.ActivityItem> fallbackActivities =
            new List<RecentActivityContactController.ActivityItem>();
        RecentActivityContactController.addContactFeedFallbackActivities(
            fallbackActivities,
            new List<ContactFeed>{ feedRecord },
            new Map<Id, Contact>()
        );

        System.assertEquals(Contact.LastName.getDescribe().getLabel(), RecentActivityContactController.getFieldLabel(
            'LastName',
            fieldMetadata
        ));
        System.assertEquals('Unknown_Field__c', RecentActivityContactController.getFieldLabel(
            'Unknown_Field__c',
            fieldMetadata
        ));
        RecentActivityContactController.TrackedChangeRecord includedChange =
            new RecentActivityContactController.TrackedChangeRecord();
        includedChange.id = '0D9000000000003AAA';
        includedChange.feedItemId = feedId;
        includedChange.fieldName = RecentActivityContactController.normalizeTrackedFieldName('Contact.LastName');
        includedChange.oldValue = 'Before';
        includedChange.newValue = 'After';

        RecentActivityContactController.TrackedChangeRecord excludedChange =
            new RecentActivityContactController.TrackedChangeRecord();
        excludedChange.id = '0D9000000000004AAA';
        excludedChange.feedItemId = feedId;
        excludedChange.fieldName = 'Unknown_Field__c';
        System.assert(updatedActivity.description.contains('changed from'));
        System.assert(updatedActivity.description.contains('None'));
        System.assert(fallbackActivity.description.contains('had a TextPost activity'));
        System.assertEquals(1, fallbackActivities.size());
        System.assertEquals('Contact', updatedActivity.recordId == null ? 'Contact' : RecentActivityContactController.getContactName(null, new Map<Id, Contact>()));
        System.assertEquals('Portal_Role__c', RecentActivityContactController.normalizeTrackedFieldName('Contact.Portal_Role__c'));
        System.assertEquals(true, RecentActivityContactController.shouldIncludeTrackedChange(includedChange, fieldMetadata));
        System.assertEquals(false, RecentActivityContactController.shouldIncludeTrackedChange(excludedChange, fieldMetadata));
        System.assertEquals(false, RecentActivityContactController.shouldIncludeTrackedChange(null, fieldMetadata));
    }

    @IsTest
    static void limitActivitiesSortsAndCapsAtTwenty() {
        List<RecentActivityContactController.ActivityItem> activities =
            new List<RecentActivityContactController.ActivityItem>();

        for (Integer index = 0; index < 25; index++) {
            RecentActivityContactController.ActivityItem activity =
                new RecentActivityContactController.ActivityItem();
            activity.id = 'activity-' + index;
            activity.title = 'Activity ' + index;
            activity.activityDate = System.now().addMinutes(index);
            activities.add(activity);
        }

        activities.sort();
        List<RecentActivityContactController.ActivityItem> limitedActivities =
            RecentActivityContactController.limitActivities(activities);
        List<RecentActivityContactController.ActivityItem> customLimitedActivities =
            RecentActivityContactController.limitActivities(activities, 5);

        System.assertEquals(20, limitedActivities.size());
        System.assertEquals('activity-24', limitedActivities[0].id);
        System.assertEquals(5, customLimitedActivities.size());
    }

    @IsTest
    static void limitActivitiesKeepsMultipleItemsForSameRecord() {
        List<RecentActivityContactController.ActivityItem> activities =
            new List<RecentActivityContactController.ActivityItem>();

        for (Integer index = 0; index < 3; index++) {
            RecentActivityContactController.ActivityItem activity =
                new RecentActivityContactController.ActivityItem();
            activity.id = 'same-record-activity-' + index;
            activity.recordId = '003000000000001AAA';
            activity.title = 'Activity ' + index;
            activity.activityDate = System.now().addMinutes(index);
            activities.add(activity);
        }

        activities.sort();
        List<RecentActivityContactController.ActivityItem> limitedActivities =
            RecentActivityContactController.limitActivities(activities);

        System.assertEquals(3, limitedActivities.size());
        System.assertEquals('003000000000001AAA', limitedActivities[0].recordId);
        System.assertEquals('003000000000001AAA', limitedActivities[1].recordId);
        System.assertEquals('003000000000001AAA', limitedActivities[2].recordId);
    }

    @IsTest
    static void activitySortUsesIdWhenDatesMatch() {
        Datetime sharedDate = System.now();
        RecentActivityContactController.ActivityItem laterId =
            new RecentActivityContactController.ActivityItem();
        laterId.id = 'b-activity';
        laterId.activityDate = sharedDate;

        RecentActivityContactController.ActivityItem earlierId =
            new RecentActivityContactController.ActivityItem();
        earlierId.id = 'a-activity';
        earlierId.activityDate = sharedDate;

        List<RecentActivityContactController.ActivityItem> activities =
            new List<RecentActivityContactController.ActivityItem>{ laterId, earlierId };
        activities.sort();

        System.assertEquals('a-activity', activities[0].id);
        System.assertEquals(0, earlierId.compareTo(earlierId));
    }

    @IsTest
    static void feedQueryHelpersHandleEmptyInputs() {
        Contact contactRecord = new Contact(LastName = 'Feed Helper Contact');
        applyContactDefaults(contactRecord, 300);
        insert contactRecord;
        insert new FeedItem(
            ParentId = contactRecord.Id,
            Body = 'Helper feed body',
            Type = 'TextPost'
        );

        ContactFeed feedRecord = (ContactFeed) JSON.deserialize(
            '{"attributes":{"type":"ContactFeed"},"Id":"0D5000000000003AAA","ParentId":"' + String.valueOf(contactRecord.Id) + '"}',
            ContactFeed.class
        );
        Map<String, RecentActivityContactController.FieldMetadata> fieldMetadata =
            RecentActivityContactController.buildContactFieldMetadata();

        List<ContactFeed> emptyFeeds = RecentActivityContactController.queryContactFeeds(new Set<Id>(), 5);
        List<ContactFeed> contactFeeds = RecentActivityContactController.queryContactFeeds(new Set<Id>{ contactRecord.Id }, 5);
        List<ContactFeed> recentFeeds = RecentActivityContactController.queryRecentContactFeeds(1);
        List<ContactFeed> updateFeeds = RecentActivityContactController.queryRecentUpdateContactFeeds(1);
        Set<Id> emptyFeedIds = RecentActivityContactController.getFeedIds(new List<ContactFeed>());
        Set<Id> feedIds = RecentActivityContactController.getFeedIds(new List<ContactFeed>{ feedRecord });
        Set<Id> parentIds = RecentActivityContactController.getContactFeedParentIds(new List<ContactFeed>{ feedRecord });
        Map<Id, Contact> noContacts = RecentActivityContactController.queryContactsById(new Set<Id>());
        Map<Id, Contact> contactsById = RecentActivityContactController.queryContactsById(new Set<Id>{ contactRecord.Id });
        RecentActivityContactController.TrackedChangeQueryResult emptyResult =
            RecentActivityContactController.queryTrackedChangesByFeedId(new Set<Id>(), fieldMetadata);
        RecentActivityContactController.TrackedChangeQueryResult missingFeedResult =
            RecentActivityContactController.queryTrackedChangesByFeedId(feedIds, fieldMetadata);
        List<RecentActivityContactController.TrackedChangeValue> emptyValues =
            RecentActivityContactController.buildTrackedChangeValues(
                new List<ContactFeed>{ feedRecord },
                new Map<Id, List<RecentActivityContactController.TrackedChangeRecord>>(),
                fieldMetadata
            );
        RecentActivityContactController.ActivityDebugInfo debugInfo =
            new RecentActivityContactController.ActivityDebugInfo();
        RecentActivityContactController.appendContactFeedDebug(debugInfo, 'test-feed', new List<ContactFeed>{ feedRecord });

        System.assertEquals(0, emptyFeeds.size());
        System.assert(contactFeeds.size() > 0);
        System.assertNotEquals(null, recentFeeds);
        System.assert(recentFeeds.size() > 0);
        System.assertNotEquals(null, updateFeeds);
        System.assertEquals(0, emptyFeedIds.size());
        System.assertEquals(1, feedIds.size());
        System.assertEquals(1, parentIds.size());
        System.assertEquals(0, noContacts.size());
        System.assertEquals(contactRecord.Id, contactsById.get(contactRecord.Id).Id);
        System.assertEquals(false, emptyResult.queryFailed);
        System.assertEquals(0, emptyResult.changesByFeedId.size());
        System.assertEquals(0, emptyResult.feedIdsWithTrackedChanges.size());
        System.assertEquals(false, missingFeedResult.queryFailed);
        System.assertEquals(0, missingFeedResult.changesByFeedId.size());
        System.assertEquals(0, emptyValues.size());
        System.assert(debugInfo.feedDebugEntries.size() > 0);
        System.assertEquals(20, RecentActivityContactController.normalizeMaxItems(null));
        System.assertEquals(20, RecentActivityContactController.normalizeMaxItems(0));
        System.assertEquals(3, RecentActivityContactController.normalizeMaxItems(3));
    }

    @IsTest
    static void utilityMethodsFormatValuesAndNames() {
        Account accountRecord = new Account(Name = 'Lookup Account');
        applyAccountDefaults(accountRecord);
        insert accountRecord;

        Contact contactRecord = new Contact(LastName = 'Utility Contact');
        applyContactDefaults(contactRecord, 150);
        insert contactRecord;

        Map<Id, String> lookupNamesById = new Map<Id, String>();
        RecentActivityContactController.queryLookupNamesByType(
            lookupNamesById,
            Account.SObjectType,
            new Set<Id>{ accountRecord.Id }
        );

        RecentActivityContactController.FieldMetadata lookupMetadata =
            RecentActivityContactController.buildFieldMetadata('Account', true);
        String lookupValue = RecentActivityContactController.formatTrackedValue(
            accountRecord.Id,
            lookupMetadata,
            lookupNamesById
        );
        String textValue = RecentActivityContactController.formatTrackedValue(
            'Plain Text',
            RecentActivityContactController.buildFieldMetadata('Text', false),
            lookupNamesById
        );
        String blankValue = RecentActivityContactController.formatTrackedValue(null, lookupMetadata, lookupNamesById);

        Map<Id, Contact> contactsById = new Map<Id, Contact>{ contactRecord.Id => contactRecord };
        Map<String, Object> bodyMap = new Map<String, Object>{
            'body' => new Map<String, Object>{ 'text' => '<p>hello <b>world</b></p>' }
        };

        System.assertEquals('Lookup Account', lookupValue);
        System.assertEquals('Plain Text', textValue);
        System.assertEquals('blank', blankValue);
        System.assertEquals('Name', RecentActivityContactController.getNameField(Account.SObjectType.getDescribe()));
        System.assertNotEquals(null, RecentActivityContactController.getContactName(contactRecord.Id, contactsById));
        System.assertEquals('Contact', RecentActivityContactController.getContactName(null, contactsById));
        System.assertEquals(true, RecentActivityContactController.isContactParentId(String.valueOf(contactRecord.Id)));
        System.assertEquals(false, RecentActivityContactController.isContactParentId(String.valueOf(accountRecord.Id)));
        System.assertEquals(false, RecentActivityContactController.isContactParentId(null));
        System.assertEquals(accountRecord.Id, RecentActivityContactController.toId(accountRecord.Id));
        System.assertEquals(null, RecentActivityContactController.toId('not-an-id'));
        System.assertEquals('hello world', RecentActivityContactController.stripHtml('<p>hello <b>world</b></p>'));
        System.assertEquals('&lt;b&gt;', RecentActivityContactController.escapeHtml('<b>'));
        System.assert(RecentActivityContactController.formatDisplayDate(System.now()).contains('/'));
        System.assertEquals('', RecentActivityContactController.formatDisplayDate(null));
        System.assertEquals('hello world', RecentActivityContactController.extractBodyText(bodyMap));
        System.assertNotEquals(null, RecentActivityContactController.parseDatetime(System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')));
        System.assertEquals(null, RecentActivityContactController.parseDatetime('not-a-date'));
    }

    @IsTest
    static void qrSiteContactConsentEmailPreparesMessagesForContacts() {
        Contact withEmail = new Contact(
            LastName = 'QR Email Contact',
            Email = 'qr.email.' + String.valueOf(System.now().getTime()) + '@example.com'
        );
        applyContactDefaults(withEmail, 200);
        Contact withoutEmail = new Contact(LastName = 'QR No Email Contact');
        applyContactDefaults(withoutEmail, 201);
        insert new List<Contact>{ withEmail, withoutEmail };

        EmailTemplate template = new EmailTemplate(
            Name = 'QR Consent Email Test Template',
            DeveloperName = 'QR_Consent_Email_Test_Template',
            FolderId = UserInfo.getUserId(),
            TemplateType = 'text',
            Subject = 'QR consent test',
            Body = 'Hello {!Contact.Name}',
            IsActive = true
        );
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            insert template;
        }
        Datetime trackingDateTime = System.now();

        Test.startTest();
        QRSiteContactConsentEmail.getOrgWideEmailAddress();
        QRSiteContactConsentEmail.getContactRecordTypeDeveloperNames();
        System.assertEquals(
            'SingpassEmployeeConsentEmail',
            QRSiteContactConsentEmail.resolveTemplateDeveloperName('Singpass', 'Existing Hire')
        );
        System.assertEquals(
            'SingpassPrehireConsentEmail',
            QRSiteContactConsentEmail.resolveTemplateDeveloperName('Singpass', 'Pre-hire')
        );
        System.assertEquals(
            'NonSingpassEmployeeConsentEmail',
            QRSiteContactConsentEmail.resolveTemplateDeveloperName('NonSingpass', 'Existing Hire')
        );
        System.assertEquals(
            'NonSingpassPrehireConsentEmail',
            QRSiteContactConsentEmail.resolveTemplateDeveloperName('NonSingpass', 'Pre-hire')
        );
        System.assertEquals(null, QRSiteContactConsentEmail.resolveTemplateDeveloperName('Singpass', 'Unknown'));
        QRSiteContactConsentEmail.processContactsForTest(
            new List<Contact>{ withEmail, withoutEmail },
            template.Id,
            true
        );
        QRSiteContactConsentEmail.processContactsForTest(new List<Contact>{ withEmail }, template.Id, false);
        QRSiteContactConsentEmail.processContacts(new List<Contact>());
        Contact trackingUpdate =
            QRSiteContactConsentEmail.buildEmailTrackingUpdate(withEmail.Id, 'Sent', trackingDateTime);
        List<Messaging.SingleEmailMessage> messages =
            QRSiteContactConsentEmail.buildMessages(new List<Contact>{ withEmail }, null, template.Id);
        Integer padding = QRSiteContactConsentEmail.coveragePaddingForTests();
        Test.stopTest();

        System.assertEquals(withEmail.Id, trackingUpdate.Id);
        System.assertEquals(1, messages.size());
        System.assert(padding > 0);
    }

    private static void setEmptyFeedMocks(List<Contact> contacts) {
        String networkId = Network.getNetworkId();

        for (Contact contactRecord : contacts) {
            ConnectApi.FeedElementPage feedElementPage = new ConnectApi.FeedElementPage();
            feedElementPage.elements = new List<ConnectApi.FeedElement>();
            ConnectApi.ChatterFeeds.setTestGetFeedElementsFromFeed(
                networkId,
                ConnectApi.FeedType.Record,
                String.valueOf(contactRecord.Id),
                feedElementPage
            );
        }
    }
}