public with sharing class RecentActivityContactController {
    private static final Integer DISPLAY_LIMIT = 20;
    private static final Integer QUERY_WINDOW = 50;
    private static final Integer FEED_CANDIDATE_LIMIT = 20;
    private static final String ICON_NAME = 'standard:lead';
    private static final String FEED_TYPE_TRACKED_CHANGE = 'TrackedChange';

    public static List<ActivityItem> getRecentActivities() {
        return getRecentActivities(DISPLAY_LIMIT);
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityItem> getRecentActivities(Integer maxItems) {
        return getRecentActivityResult(maxItems).activities;
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityItem> getRecentActivitiesByRecordId(Id recordId, Integer maxItems) {
        List<ActivityItem> activities = new List<ActivityItem>();

        if (recordId == null || recordId.getSObjectType() != Contact.SObjectType) {
            return activities;
        }

        Integer activityLimit = normalizeMaxItems(maxItems);
        Map<Id, Contact> contactsById = queryContactsById(new Set<Id>{ recordId });
        if (contactsById.isEmpty()) {
            return activities;
        }

        Map<String, FieldMetadata> contactFieldsByFeedName = buildContactFieldMetadata();
        List<ContactFeed> contactFeeds = queryTrackedContactFeedsByRecordId(recordId, activityLimit);
        if (contactFeeds.isEmpty()) {
            return activities;
        }

        TrackedChangeQueryResult trackedChangeQueryResult = queryTrackedChangesByFeedId(
            getFeedIds(contactFeeds),
            contactFieldsByFeedName
        );
        Map<Id, List<TrackedChangeRecord>> changesByFeedId = trackedChangeQueryResult.changesByFeedId;
        List<TrackedChangeValue> trackedChanges = buildTrackedChangeValues(
            contactFeeds,
            changesByFeedId,
            contactFieldsByFeedName
        );
        Map<Id, String> lookupNamesById = queryLookupNames(trackedChanges, contactFieldsByFeedName);

        for (ContactFeed feedRecord : contactFeeds) {
            List<TrackedChangeRecord> feedTrackedChanges = changesByFeedId.get(feedRecord.Id);
            if (feedTrackedChanges != null && feedTrackedChanges.size() > 0) {
                for (TrackedChangeRecord trackedChange : feedTrackedChanges) {
                    activities.add(buildTrackedChangeActivity(
                        feedRecord,
                        trackedChange,
                        contactsById,
                        contactFieldsByFeedName,
                        lookupNamesById
                    ));
                }
            }
        }

        activities.sort();
        return limitActivities(activities, activityLimit);
    }

    @AuraEnabled(cacheable=true)
    public static ActivityDebugResult getRecentActivitiesWithDebug(Integer maxItems) {
        return getRecentActivityResult(maxItems);
    }

    private static ActivityDebugResult getRecentActivityResult(Integer maxItems) {
        ActivityDebugResult result = new ActivityDebugResult();
        List<ActivityItem> activities = new List<ActivityItem>();
        Integer activityLimit = normalizeMaxItems(maxItems);
        result.debug.userId = UserInfo.getUserId();
        result.debug.username = UserInfo.getUserName();
        result.debug.userType = UserInfo.getUserType();
        result.debug.networkId = Network.getNetworkId();
        result.debug.maxItems = activityLimit;

        List<Contact> createdContacts = queryCreatedContacts();
        List<Contact> modifiedContacts = queryModifiedContacts();
        Map<Id, Contact> candidateContactsById = buildCandidateContactsById(createdContacts, modifiedContacts);
        Map<String, FieldMetadata> contactFieldsByFeedName = buildContactFieldMetadata();
        result.debug.createdContactCount = createdContacts.size();
        result.debug.modifiedContactCount = modifiedContacts.size();
        result.debug.candidateContactCount = candidateContactsById.size();
        result.debug.readableContactFieldCount = contactFieldsByFeedName.size();

        if (createdContacts.size() > 0) {
            for (Contact contactRecord : createdContacts) {
                activities.add(buildCreatedActivity(contactRecord));
            }
        }

        List<ContactFeed> contactFeeds = queryRecentUpdateContactFeeds(activityLimit);
        result.debug.usedGlobalUpdateFeedSearch = true;
        result.debug.updateContactFeedCount = contactFeeds.size();
        appendContactFeedDebug(result.debug, 'global-update-feed', contactFeeds);

        if (contactFeeds.size() > 0) {
            candidateContactsById.putAll(queryContactsById(getContactFeedParentIds(contactFeeds)));
        } else if (candidateContactsById.size() > 0 || activities.isEmpty()) {
            contactFeeds = candidateContactsById.size() > 0
                ? queryContactFeeds(candidateContactsById.keySet(), activityLimit)
                : new List<ContactFeed>();
            result.debug.usedCandidateContactFeedFallback = contactFeeds.size() > 0;
            appendContactFeedDebug(result.debug, 'candidate-feed-fallback', contactFeeds);
        }

        if (contactFeeds.isEmpty()) {
            contactFeeds = queryRecentContactFeeds(activityLimit);
            candidateContactsById.putAll(queryContactsById(getContactFeedParentIds(contactFeeds)));
            result.debug.usedRecentContactFeedFallback = true;
            appendContactFeedDebug(result.debug, 'recent-feed-fallback', contactFeeds);
        }

        if (contactFeeds.size() > 0) {
            result.debug.contactFeedCount = contactFeeds.size();
            TrackedChangeQueryResult trackedChangeQueryResult = queryTrackedChangesByFeedId(
                getFeedIds(contactFeeds),
                contactFieldsByFeedName
            );
            result.debug.feedIdCount = getFeedIds(contactFeeds).size();
            result.debug.trackedChangeQueryFailed = trackedChangeQueryResult.queryFailed;
            result.debug.feedIdsWithTrackedChangesCount = trackedChangeQueryResult.feedIdsWithTrackedChanges.size();
            result.debug.totalTrackedChangeRowCount = trackedChangeQueryResult.totalTrackedChangeRows;
            result.debug.includedTrackedChangeRowCount = trackedChangeQueryResult.includedTrackedChangeRows;
            result.debug.skippedTrackedChangeRowCount = trackedChangeQueryResult.skippedTrackedChangeRows;
            result.debug.trackedChangeDebugEntries.addAll(trackedChangeQueryResult.debugEntries);
            Map<Id, List<TrackedChangeRecord>> changesByFeedId = trackedChangeQueryResult.changesByFeedId;
            List<TrackedChangeValue> trackedChanges = buildTrackedChangeValues(
                contactFeeds,
                changesByFeedId,
                contactFieldsByFeedName
            );
            result.debug.trackedChangeActivityCandidateCount = trackedChanges.size();
            Map<Id, String> lookupNamesById = queryLookupNames(trackedChanges, contactFieldsByFeedName);
            result.debug.lookupNameCount = lookupNamesById.size();

            if (contactFeeds.size() > 0) {
                for (ContactFeed feedRecord : contactFeeds) {
                    List<TrackedChangeRecord> feedTrackedChanges = changesByFeedId.get(feedRecord.Id);
                    if (feedTrackedChanges != null && feedTrackedChanges.size() > 0) {
                        for (TrackedChangeRecord trackedChange : feedTrackedChanges) {
                            activities.add(buildTrackedChangeActivity(
                                feedRecord,
                                trackedChange,
                                candidateContactsById,
                                contactFieldsByFeedName,
                                lookupNamesById
                            ));
                        }
                    } else if (trackedChangeQueryResult.queryFailed || !trackedChangeQueryResult.feedIdsWithTrackedChanges.contains(feedRecord.Id)) {
                        activities.add(buildContactFeedActivity(feedRecord, candidateContactsById));
                    } else {
                        activities.add(buildContactFeedActivity(feedRecord, candidateContactsById));
                        result.debug.errors.add('Feed ' + String.valueOf(feedRecord.Id) + ' had tracked changes, but none matched readable Contact fields.');
                    }
                }
            }
        } else {
            List<ConnectApi.FeedElement> feedElements = queryRecordFeedElements(candidateContactsById.keySet());
            result.debug.usedConnectApiFallback = true;
            result.debug.connectApiFeedElementCount = feedElements.size();
            List<TrackedChangeValue> fallbackTrackedChanges = extractTrackedChanges(feedElements, contactFieldsByFeedName);
            result.debug.connectApiTrackedChangeCount = fallbackTrackedChanges.size();
            Map<Id, String> fallbackLookupNamesById = queryLookupNames(fallbackTrackedChanges, contactFieldsByFeedName);
            addFallbackFeedActivities(activities, feedElements, candidateContactsById, contactFieldsByFeedName, fallbackLookupNamesById);
        }

        result.debug.activityCountBeforeLimit = activities.size();
        activities.sort();
        activities = limitActivities(activities, activityLimit);
        result.activities = activities;
        result.debug.activityCount = activities.size();
        result.debug.generatedAt = System.now();

        return result;
    }

    private static List<Contact> queryCreatedContacts() {
        List<Contact> contactRecords = new List<Contact>();
        Integer queryWindow = QUERY_WINDOW;
        try {
            contactRecords = [
                SELECT Id, Name, CreatedDate, LastModifiedDate
                FROM Contact
                ORDER BY CreatedDate DESC
                LIMIT :queryWindow
            ];
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, contactRecords);
            contactRecords = (List<Contact>) decision.getRecords();
        } catch (Exception ex) {
            contactRecords = new List<Contact>();
        }

        return contactRecords;
    }

    private static List<Contact> queryModifiedContacts() {
        List<Contact> contactRecords = new List<Contact>();
        Integer queryWindow = QUERY_WINDOW;
        try {
            contactRecords = [
                SELECT Id, Name, CreatedDate, LastModifiedDate
                FROM Contact
                ORDER BY LastModifiedDate DESC
                LIMIT :queryWindow
            ];
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, contactRecords);
            contactRecords = (List<Contact>) decision.getRecords();
        } catch (Exception ex) {
            contactRecords = new List<Contact>();
        }

        return contactRecords;
    }

    @TestVisible
    private static Map<Id, Contact> buildCandidateContactsById(List<Contact> createdContacts, List<Contact> modifiedContacts) {
        Map<Id, Contact> contactsById = new Map<Id, Contact>();

        if (createdContacts.size() > 0) {
            for (Contact contactRecord : createdContacts) {
                contactsById.put(contactRecord.Id, contactRecord);
            }
        }

        if (modifiedContacts.size() > 0) {
            for (Contact contactRecord : modifiedContacts) {
                contactsById.put(contactRecord.Id, contactRecord);
            }
        }

        return contactsById;
    }

    @TestVisible
    private static List<ConnectApi.FeedElement> queryRecordFeedElements(Set<Id> contactIds) {
        List<ConnectApi.FeedElement> feedElements = new List<ConnectApi.FeedElement>();
        Integer processedCount = 0;
        String networkId = Network.getNetworkId();

        if (contactIds.size() > 0) {
            for (Id contactId : contactIds) {
                if (processedCount < FEED_CANDIDATE_LIMIT) {
                    try {
                        ConnectApi.FeedElementPage feedElementPage = ConnectApi.ChatterFeeds.getFeedElementsFromFeed(
                            networkId,
                            ConnectApi.FeedType.Record,
                            String.valueOf(contactId)
                        );
                        if (feedElementPage != null && feedElementPage.elements != null && feedElementPage.elements.size() > 0) {
                            for (ConnectApi.FeedElement feedElement : feedElementPage.elements) {
                                feedElements.add(feedElement);
                            }
                        }
                    } catch (Exception ex) {
                        feedElements = feedElements;
                    }
                    processedCount++;
                }
            }
        }

        return feedElements;
    }

    @TestVisible
    private static List<ContactFeed> queryContactFeeds(Set<Id> contactIds, Integer maxItems) {
        List<ContactFeed> feedRecords = new List<ContactFeed>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);

        if (contactIds.size() > 0) {
            try {
                feedRecords = [
                    SELECT Id, ParentId, CreatedDate, Type, Body
                    FROM ContactFeed
                    WHERE ParentId IN :contactIds
                    ORDER BY CreatedDate DESC
                    LIMIT :queryLimit
                ];
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, feedRecords);
                feedRecords = (List<ContactFeed>) decision.getRecords();
            } catch (Exception ex) {
                feedRecords = new List<ContactFeed>();
            }
        }

        return feedRecords;
    }

    @TestVisible
    private static List<ContactFeed> queryRecentContactFeeds(Integer maxItems) {
        List<ContactFeed> feedRecords = new List<ContactFeed>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);

        try {
            feedRecords = [
                SELECT Id, ParentId, CreatedDate, Type, Body
                FROM ContactFeed
                ORDER BY CreatedDate DESC
                LIMIT :queryLimit
            ];
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, feedRecords);
            feedRecords = (List<ContactFeed>) decision.getRecords();
        } catch (Exception ex) {
            feedRecords = new List<ContactFeed>();
        }

        return feedRecords;
    }

    @TestVisible
    private static List<ContactFeed> queryRecentUpdateContactFeeds(Integer maxItems) {
        List<ContactFeed> feedRecords = new List<ContactFeed>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);

        try {
            feedRecords = [
                SELECT Id, ParentId, CreatedDate, Type, Body
                FROM ContactFeed
                WHERE Type = :FEED_TYPE_TRACKED_CHANGE
                ORDER BY CreatedDate DESC
                LIMIT :queryLimit
            ];
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, feedRecords);
            feedRecords = (List<ContactFeed>) decision.getRecords();
        } catch (Exception ex) {
            feedRecords = new List<ContactFeed>();
        }

        return feedRecords;
    }

    @TestVisible
    private static List<ContactFeed> queryTrackedContactFeedsByRecordId(Id recordId, Integer maxItems) {
        List<ContactFeed> feedRecords = new List<ContactFeed>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);

        if (recordId != null) {
            try {
                feedRecords = [
                    SELECT Id, ParentId, CreatedDate, Type, Body
                    FROM ContactFeed
                    WHERE ParentId = :recordId
                    AND Type = :FEED_TYPE_TRACKED_CHANGE
                    ORDER BY CreatedDate DESC
                    LIMIT :queryLimit
                ];
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, feedRecords);
                feedRecords = (List<ContactFeed>) decision.getRecords();
            } catch (Exception ex) {
                feedRecords = new List<ContactFeed>();
            }
        }

        return feedRecords;
    }

    @TestVisible
    private static void appendContactFeedDebug(
        ActivityDebugInfo debug,
        String source,
        List<ContactFeed> feedRecords
    ) {
        debug.feedDebugEntries.add(source + ': count=' + String.valueOf(feedRecords.size()));

        Integer maxEntries = Math.min(10, feedRecords.size());
        for (Integer index = 0; index < maxEntries; index++) {
            ContactFeed feedRecord = feedRecords[index];
            debug.feedDebugEntries.add(
                source +
                ': id=' + String.valueOf(feedRecord.Id) +
                ', parentId=' + String.valueOf(feedRecord.ParentId) +
                ', type=' + String.valueOf(feedRecord.Type) +
                ', createdDate=' + String.valueOf(feedRecord.CreatedDate) +
                ', hasBody=' + String.valueOf(String.isNotBlank(feedRecord.Body))
            );
        }
    }

    @TestVisible
    private static Set<Id> getContactFeedParentIds(List<ContactFeed> feedRecords) {
        Set<Id> parentIds = new Set<Id>();

        if (feedRecords.size() > 0) {
            for (ContactFeed feedRecord : feedRecords) {
                if (feedRecord.ParentId != null) {
                    parentIds.add((Id) feedRecord.ParentId);
                }
            }
        }

        return parentIds;
    }

    @TestVisible
    private static Map<Id, Contact> queryContactsById(Set<Id> contactIds) {
        Map<Id, Contact> contactsById = new Map<Id, Contact>();
        List<Contact> contactRecords = new List<Contact>();

        if (contactIds.size() > 0) {
            try {
                contactRecords = [
                    SELECT Id, Name, CreatedDate, LastModifiedDate
                    FROM Contact
                    WHERE Id IN :contactIds
                ];
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, contactRecords);
                contactRecords = (List<Contact>) decision.getRecords();
            } catch (Exception ex) {
                contactRecords = new List<Contact>();
            }
        }

        if (contactRecords.size() > 0) {
            for (Contact contactRecord : contactRecords) {
                contactsById.put(contactRecord.Id, contactRecord);
            }
        }

        return contactsById;
    }

    @TestVisible
    private static Set<Id> getFeedIds(List<ContactFeed> feedRecords) {
        Set<Id> feedIds = new Set<Id>();

        if (feedRecords.size() > 0) {
            for (ContactFeed feedRecord : feedRecords) {
                feedIds.add(feedRecord.Id);
            }
        }

        return feedIds;
    }

    @TestVisible
    private static TrackedChangeQueryResult queryTrackedChangesByFeedId(
        Set<Id> feedIds,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        TrackedChangeQueryResult result = new TrackedChangeQueryResult();

        if (feedIds.size() > 0) {
            try {
                List<ContactFeed> feedRecords = [
                    SELECT Id, (SELECT Id, FieldName, OldValue, NewValue FROM FeedTrackedChanges ORDER BY Id ASC)
                    FROM ContactFeed
                    WHERE Id IN :feedIds
                ];

                if (feedRecords.size() > 0) {
                    for (ContactFeed feedRecord : feedRecords) {
                        List<SObject> trackedChanges = feedRecord.getSObjects('FeedTrackedChanges');
                        if (trackedChanges != null && trackedChanges.size() > 0) {
                            for (SObject trackedChange : trackedChanges) {
                                TrackedChangeRecord trackedChangeRecord = buildTrackedChangeRecord(feedRecord.Id, trackedChange);
                                result.totalTrackedChangeRows++;
                                result.feedIdsWithTrackedChanges.add(feedRecord.Id);
                                if (shouldIncludeTrackedChange(trackedChangeRecord, contactFieldsByFeedName)) {
                                    if (!result.changesByFeedId.containsKey(feedRecord.Id)) {
                                        result.changesByFeedId.put(feedRecord.Id, new List<TrackedChangeRecord>());
                                    }
                                    result.changesByFeedId.get(feedRecord.Id).add(trackedChangeRecord);
                                    result.includedTrackedChangeRows++;
                                    appendTrackedChangeDebug(result, trackedChangeRecord, true);
                                } else {
                                    result.skippedTrackedChangeRows++;
                                    appendTrackedChangeDebug(result, trackedChangeRecord, false);
                                }
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                result.queryFailed = true;
            }
        }

        deduplicateDisplayDuplicateTrackedChanges(result.changesByFeedId, contactFieldsByFeedName);

        return result;
    }

    @TestVisible
    private static void deduplicateDisplayDuplicateTrackedChanges(
        Map<Id, List<TrackedChangeRecord>> changesByFeedId,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        if (changesByFeedId.size() > 0) {
            for (Id feedId : changesByFeedId.keySet()) {
                changesByFeedId.put(
                    feedId,
                    deduplicateDisplayDuplicateTrackedChanges(
                        changesByFeedId.get(feedId),
                        contactFieldsByFeedName
                    )
                );
            }
        }
    }

    @TestVisible
    private static List<TrackedChangeRecord> deduplicateDisplayDuplicateTrackedChanges(
        List<TrackedChangeRecord> trackedChanges,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        List<TrackedChangeRecord> deduplicatedChanges = new List<TrackedChangeRecord>();
        Map<String, Integer> referenceChangeIndexByKey = new Map<String, Integer>();

        if (trackedChanges != null && trackedChanges.size() > 0) {
            for (TrackedChangeRecord trackedChange : trackedChanges) {
                FieldMetadata metadata = trackedChange != null
                    ? contactFieldsByFeedName.get(trackedChange.fieldName)
                    : null;
                if (metadata != null && metadata.isReference) {
                    String duplicateKey = getTrackedChangeDuplicateKey(trackedChange, metadata);
                    if (referenceChangeIndexByKey.containsKey(duplicateKey)) {
                        Integer existingIndex = referenceChangeIndexByKey.get(duplicateKey);
                        TrackedChangeRecord existingChange = deduplicatedChanges[existingIndex];
                        if (shouldReplaceDisplayDuplicate(existingChange, trackedChange)) {
                            deduplicatedChanges[existingIndex] = trackedChange;
                        }
                    } else {
                        referenceChangeIndexByKey.put(duplicateKey, deduplicatedChanges.size());
                        deduplicatedChanges.add(trackedChange);
                    }
                } else {
                    deduplicatedChanges.add(trackedChange);
                }
            }
        }

        return deduplicatedChanges;
    }

    private static String getTrackedChangeDuplicateKey(TrackedChangeRecord trackedChange, FieldMetadata metadata) {
        String fieldKey = String.isNotBlank(metadata.apiName) ? metadata.apiName : trackedChange.fieldName;
        return String.valueOf(trackedChange.feedItemId) + ':' + fieldKey;
    }

    private static Boolean shouldReplaceDisplayDuplicate(
        TrackedChangeRecord existingChange,
        TrackedChangeRecord candidateChange
    ) {
        Boolean shouldReplace = false;
        Boolean existingHasReadableValue = hasReadableTrackedValue(existingChange);
        Boolean candidateHasReadableValue = hasReadableTrackedValue(candidateChange);

        if (!existingHasReadableValue && candidateHasReadableValue && hasIdTrackedValue(existingChange)) {
            shouldReplace = true;
        }

        return shouldReplace;
    }

    private static Boolean hasReadableTrackedValue(TrackedChangeRecord trackedChange) {
        return isReadableTrackedValue(trackedChange.oldValue) || isReadableTrackedValue(trackedChange.newValue);
    }

    private static Boolean hasIdTrackedValue(TrackedChangeRecord trackedChange) {
        return toId(trackedChange.oldValue) != null || toId(trackedChange.newValue) != null;
    }

    private static Boolean isReadableTrackedValue(Object rawValue) {
        Boolean isReadableValue = false;

        if (rawValue != null && String.isNotBlank(String.valueOf(rawValue)) && toId(rawValue) == null) {
            isReadableValue = true;
        }

        return isReadableValue;
    }

    private static void appendTrackedChangeDebug(
        TrackedChangeQueryResult result,
        TrackedChangeRecord trackedChange,
        Boolean included
    ) {
        if (result.debugEntries.size() < 25) {
            result.debugEntries.add(
                'feedId=' + String.valueOf(trackedChange.feedItemId) +
                ', changeId=' + String.valueOf(trackedChange.id) +
                ', field=' + String.valueOf(trackedChange.fieldName) +
                ', included=' + String.valueOf(included) +
                ', old=' + String.valueOf(trackedChange.oldValue) +
                ', new=' + String.valueOf(trackedChange.newValue)
            );
        }
    }

    @TestVisible
    private static TrackedChangeRecord buildTrackedChangeRecord(Id feedItemId, SObject trackedChange) {
        TrackedChangeRecord record = new TrackedChangeRecord();
        record.id = (Id) trackedChange.get('Id');
        record.feedItemId = feedItemId;
        record.fieldName = normalizeTrackedFieldName((String) trackedChange.get('FieldName'));
        record.oldValue = trackedChange.get('OldValue');
        record.newValue = trackedChange.get('NewValue');

        return record;
    }

    @TestVisible
    private static Boolean shouldIncludeTrackedChange(
        TrackedChangeRecord trackedChange,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        Boolean shouldInclude = false;

        if (trackedChange != null && String.isNotBlank(trackedChange.fieldName)) {
            FieldMetadata metadata = contactFieldsByFeedName.get(trackedChange.fieldName);
            if (metadata != null) {
                shouldInclude = true;
            }
        }

        return shouldInclude;
    }

    @TestVisible
    private static List<TrackedChangeValue> buildTrackedChangeValues(
        List<ContactFeed> feedRecords,
        Map<Id, List<TrackedChangeRecord>> changesByFeedId,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        List<TrackedChangeValue> trackedChanges = new List<TrackedChangeValue>();

        if (feedRecords.size() > 0) {
            for (ContactFeed feedRecord : feedRecords) {
                List<TrackedChangeRecord> feedTrackedChanges = changesByFeedId.get(feedRecord.Id);
                if (feedTrackedChanges != null && feedTrackedChanges.size() > 0) {
                    for (TrackedChangeRecord trackedChange : feedTrackedChanges) {
                        trackedChanges.add(buildTrackedChangeValue(
                            feedRecord,
                            trackedChange,
                            contactFieldsByFeedName
                        ));
                    }
                }
            }
        }

        return trackedChanges;
    }

    @TestVisible
    private static List<TrackedChangeValue> extractTrackedChanges(
        List<ConnectApi.FeedElement> feedElements,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        List<TrackedChangeValue> trackedChanges = new List<TrackedChangeValue>();

        if (feedElements.size() > 0) {
            for (ConnectApi.FeedElement feedElement : feedElements) {
                if (isContactFeedElement(feedElement)) {
                    List<TrackedChangeValue> feedTrackedChanges = extractTrackedChanges(feedElement, contactFieldsByFeedName);
                    if (feedTrackedChanges.size() > 0) {
                        trackedChanges.addAll(feedTrackedChanges);
                    }
                }
            }
        }

        return trackedChanges;
    }

    @TestVisible
    private static List<TrackedChangeValue> extractTrackedChanges(
        ConnectApi.FeedElement feedElement,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        List<TrackedChangeValue> trackedChanges = new List<TrackedChangeValue>();
        Map<String, Object> feedElementMap = deserializeToMap(feedElement);
        trackedChanges = extractTrackedChangesFromMap(feedElementMap, contactFieldsByFeedName);

        return trackedChanges;
    }

    @TestVisible
    private static Boolean isContactFeedElement(ConnectApi.FeedElement feedElement) {
        Map<String, Object> feedElementMap = deserializeToMap(feedElement);
        Boolean isContact = isContactParentId(getParentId(feedElementMap));

        return isContact;
    }

    @TestVisible
    private static Boolean isContactParentId(String parentId) {
        Boolean isContact = false;
        Id recordId = toId(parentId);

        if (recordId != null && recordId.getSObjectType() == Contact.SObjectType) {
            isContact = true;
        }

        return isContact;
    }

    @TestVisible
    private static List<TrackedChangeValue> extractTrackedChangesFromMap(
        Map<String, Object> feedElementMap,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        List<TrackedChangeValue> trackedChanges = new List<TrackedChangeValue>();
        Map<String, Object> capabilities = getMapValue(feedElementMap, 'capabilities');
        Map<String, Object> trackedChangesCapability = getMapValue(capabilities, 'trackedChanges');
        List<Object> changes = getListValue(trackedChangesCapability, 'changes');

        if (changes.size() > 0) {
            for (Object changeObject : changes) {
                Map<String, Object> changeMap = castToMap(changeObject);
                String fieldName = normalizeTrackedFieldName(getStringValue(changeMap, 'fieldName'));
                TrackedChangeValue trackedChange = new TrackedChangeValue();
                trackedChange.feedElementId = getStringValue(feedElementMap, 'id');
                trackedChange.parentId = getParentId(feedElementMap);
                trackedChange.createdDate = parseDatetime(getStringValue(feedElementMap, 'createdDate'));
                trackedChange.fieldName = fieldName;
                trackedChange.oldValue = getStringValue(changeMap, 'oldValue');
                trackedChange.newValue = getStringValue(changeMap, 'newValue');
                FieldMetadata metadata = contactFieldsByFeedName.get(fieldName);
                trackedChange.fieldLabel = metadata != null ? metadata.label : fieldName;
                trackedChanges.add(trackedChange);
            }
        }

        return trackedChanges;
    }

    @TestVisible
    private static String normalizeTrackedFieldName(String fieldName) {
        String normalizedFieldName = fieldName;

        if (String.isNotBlank(normalizedFieldName) && normalizedFieldName.startsWith('Contact.')) {
            normalizedFieldName = normalizedFieldName.substringAfter('Contact.');
        }

        return normalizedFieldName;
    }

    @TestVisible
    private static Map<String, FieldMetadata> buildContactFieldMetadata() {
        Map<String, FieldMetadata> fieldMetadataByFeedName = new Map<String, FieldMetadata>();
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();

        for (String fieldApiName : contactFields.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = contactFields.get(fieldApiName).getDescribe();
            if (fieldDescribe.isAccessible()) {
                FieldMetadata metadata = new FieldMetadata();
                metadata.apiName = fieldDescribe.getName();
                metadata.label = fieldDescribe.getLabel();
                metadata.isReference = fieldDescribe.getType() == Schema.DisplayType.REFERENCE;
                metadata.referenceTo = fieldDescribe.getReferenceTo();
                fieldMetadataByFeedName.put(fieldDescribe.getName(), metadata);

                if (fieldDescribe.getName().endsWith('Id')) {
                    String relationshipFieldName = fieldDescribe.getName().substring(0, fieldDescribe.getName().length() - 2);
                    fieldMetadataByFeedName.put(relationshipFieldName, metadata);
                }

                if (String.isNotBlank(fieldDescribe.getRelationshipName())) {
                    fieldMetadataByFeedName.put(fieldDescribe.getRelationshipName(), metadata);
                }
            }
        }

        return fieldMetadataByFeedName;
    }

    @TestVisible
    private static Map<Id, String> queryLookupNames(
        List<TrackedChangeValue> trackedChanges,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        Map<Id, String> lookupNamesById = new Map<Id, String>();
        Map<Schema.SObjectType, Set<Id>> idsByType = new Map<Schema.SObjectType, Set<Id>>();

        if (trackedChanges.size() > 0) {
            for (TrackedChangeValue trackedChange : trackedChanges) {
                FieldMetadata metadata = contactFieldsByFeedName.get(trackedChange.fieldName);
                if (metadata != null && metadata.isReference) {
                    collectLookupId(idsByType, trackedChange.oldValue);
                    collectLookupId(idsByType, trackedChange.newValue);
                }
            }
        }

        if (idsByType.size() > 0) {
            for (Schema.SObjectType sObjectType : idsByType.keySet()) {
                Set<Id> ids = idsByType.get(sObjectType);
                if (ids.size() > 0) {
                    queryLookupNamesByType(lookupNamesById, sObjectType, ids);
                }
            }
        }

        return lookupNamesById;
    }

    private static void collectLookupId(Map<Schema.SObjectType, Set<Id>> idsByType, Object rawValue) {
        Id lookupId = toId(rawValue);
        if (lookupId != null) {
            Schema.SObjectType sObjectType = lookupId.getSObjectType();
            if (!idsByType.containsKey(sObjectType)) {
                idsByType.put(sObjectType, new Set<Id>());
            }
            idsByType.get(sObjectType).add(lookupId);
        }
    }

    @TestVisible
    private static void queryLookupNamesByType(
        Map<Id, String> lookupNamesById,
        Schema.SObjectType sObjectType,
        Set<Id> ids
    ) {
        Schema.DescribeSObjectResult objectDescribe = sObjectType.getDescribe();
        String objectApiName = objectDescribe.getName();
        String nameField = getNameField(objectDescribe);

        if (String.isNotBlank(nameField)) {
            try {
                List<SObject> lookupRecords = Database.query(
                    'SELECT Id, ' + nameField + ' ' +
                    'FROM ' + objectApiName + ' ' +
                    'WHERE Id IN :ids'
                );
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, lookupRecords);
                lookupRecords = decision.getRecords();

                if (lookupRecords.size() > 0) {
                    for (SObject lookupRecord : lookupRecords) {
                        Object nameValue = lookupRecord.get(nameField);
                        if (nameValue != null) {
                            lookupNamesById.put((Id) lookupRecord.get('Id'), String.valueOf(nameValue));
                        }
                    }
                }
            } catch (Exception ex) {
                lookupNamesById = lookupNamesById;
            }
        }
    }

    @TestVisible
    private static String getNameField(Schema.DescribeSObjectResult objectDescribe) {
        String nameField = null;
        Map<String, Schema.SObjectField> fields = objectDescribe.fields.getMap();

        for (String fieldApiName : fields.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fields.get(fieldApiName).getDescribe();
            if (fieldDescribe.isNameField()) {
                nameField = fieldDescribe.getName();
            }
        }

        return nameField;
    }

    private static ActivityItem buildCreatedActivity(Contact contactRecord) {
        ActivityItem activity = new ActivityItem();
        activity.id = 'created-' + String.valueOf(contactRecord.Id);
        activity.title = 'Contact Created';
        activity.description = '<strong>' + escapeHtml(contactRecord.Name) + '</strong> created';
        activity.displayDate = formatDisplayDate(contactRecord.CreatedDate);
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(contactRecord.Id);
        activity.activityDate = contactRecord.CreatedDate;

        return activity;
    }

    @TestVisible
    private static ActivityItem buildTrackedChangeActivity(
        ConnectApi.FeedElement feedElement,
        TrackedChangeValue trackedChange,
        Map<Id, Contact> contactsById,
        Map<String, FieldMetadata> contactFieldsByFeedName,
        Map<Id, String> lookupNamesById
    ) {
        Id parentId = toId(trackedChange.parentId);
        FieldMetadata metadata = contactFieldsByFeedName.get(trackedChange.fieldName);
        String oldValue = formatTrackedValue(trackedChange.oldValue, metadata, lookupNamesById);
        String newValue = formatTrackedValue(trackedChange.newValue, metadata, lookupNamesById);

        ActivityItem activity = buildTrackedChangeActivityFromValues(
            trackedChange.feedElementId,
            parentId,
            trackedChange.createdDate,
            trackedChange.fieldLabel,
            oldValue,
            newValue,
            contactsById
        );

        return activity;
    }

    @TestVisible
    private static ActivityItem buildTrackedChangeActivity(
        ContactFeed feedRecord,
        TrackedChangeRecord trackedChange,
        Map<Id, Contact> contactsById,
        Map<String, FieldMetadata> contactFieldsByFeedName,
        Map<Id, String> lookupNamesById
    ) {
        TrackedChangeValue trackedChangeValue = buildTrackedChangeValue(
            feedRecord,
            trackedChange,
            contactFieldsByFeedName
        );
        FieldMetadata metadata = contactFieldsByFeedName.get(trackedChangeValue.fieldName);
        String oldValue = formatTrackedValue(trackedChangeValue.oldValue, metadata, lookupNamesById);
        String newValue = formatTrackedValue(trackedChangeValue.newValue, metadata, lookupNamesById);
        ActivityItem activity = buildTrackedChangeActivityFromValues(
            String.valueOf(feedRecord.Id),
            String.valueOf(trackedChange.id),
            (Id) feedRecord.ParentId,
            feedRecord.CreatedDate,
            trackedChangeValue.fieldName,
            trackedChangeValue.fieldLabel,
            oldValue,
            newValue,
            contactsById
        );

        return activity;
    }

    @TestVisible
    private static TrackedChangeValue buildTrackedChangeValue(
        ContactFeed feedRecord,
        TrackedChangeRecord trackedChange,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        TrackedChangeValue trackedChangeValue = new TrackedChangeValue();
        trackedChangeValue.feedElementId = String.valueOf(feedRecord.Id);
        trackedChangeValue.changeId = String.valueOf(trackedChange.id);
        trackedChangeValue.parentId = String.valueOf(feedRecord.ParentId);
        trackedChangeValue.createdDate = feedRecord.CreatedDate;
        trackedChangeValue.fieldName = trackedChange.fieldName;
        trackedChangeValue.fieldLabel = getFieldLabel(
            trackedChangeValue.fieldName,
            contactFieldsByFeedName
        );
        trackedChangeValue.oldValue = trackedChange.oldValue != null ? String.valueOf(trackedChange.oldValue) : null;
        trackedChangeValue.newValue = trackedChange.newValue != null ? String.valueOf(trackedChange.newValue) : null;

        return trackedChangeValue;
    }

    @TestVisible
    private static String getFieldLabel(
        String fieldName,
        Map<String, FieldMetadata> contactFieldsByFeedName
    ) {
        String fieldLabel = fieldName;
        FieldMetadata metadata = contactFieldsByFeedName.get(fieldName);
        if (metadata != null && String.isNotBlank(metadata.label)) {
            fieldLabel = metadata.label;
        }

        return fieldLabel;
    }

    @TestVisible
    private static ActivityItem buildTrackedChangeActivityFromValues(
        String feedElementId,
        Id parentId,
        Datetime createdDate,
        String fieldLabel,
        String oldValue,
        String newValue,
        Map<Id, Contact> contactsById
    ) {
        String contactName = getContactName(parentId, contactsById);

        ActivityItem activity = new ActivityItem();
        activity.id = 'tracked-' + feedElementId + '-' + escapeHtml(fieldLabel);
        activity.title = 'Contact ' + fieldLabel + ' Changed';
        activity.description =
            '<strong>' + escapeHtml(contactName) + '</strong> ' +
            escapeHtml(fieldLabel) +
            ' changed from <strong>' + escapeHtml(formatActivityValue(oldValue)) +
            '</strong> to <strong>' + escapeHtml(formatActivityValue(newValue)) + '</strong>';
        activity.displayDate = formatDisplayDate(createdDate);
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(parentId);
        activity.activityDate = createdDate;

        return activity;
    }

    @TestVisible
    private static ActivityItem buildTrackedChangeActivityFromValues(
        String feedElementId,
        String changeId,
        Id parentId,
        Datetime createdDate,
        String fieldName,
        String fieldLabel,
        String oldValue,
        String newValue,
        Map<Id, Contact> contactsById
    ) {
        String contactName = getContactName(parentId, contactsById);
        String escapedFieldLabel = escapeHtml(fieldLabel);
        String escapedContactName = escapeHtml(contactName);

        ActivityItem activity = new ActivityItem();
        activity.id = feedElementId + '-' + changeId;
        activity.feedId = feedElementId;
        activity.changeId = changeId;
        activity.title = 'Contact ' + fieldLabel + ' Changed';
        activity.description =
            escapedFieldLabel + ' for <strong>' + escapedContactName + '</strong> changed from <strong>' +
            escapeHtml(formatActivityValue(oldValue)) + '</strong> to <strong>' +
            escapeHtml(formatActivityValue(newValue)) + '</strong>';
        activity.displayDate = formatDisplayDate(createdDate);
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(parentId);
        activity.activityDate = createdDate;
        activity.fieldName = fieldName;
        activity.oldValue = oldValue;
        activity.newValue = newValue;

        return activity;
    }

    @TestVisible
    private static FieldMetadata buildFieldMetadata(String label, Boolean isReference) {
        FieldMetadata metadata = new FieldMetadata();
        metadata.label = label;
        metadata.isReference = isReference;

        return metadata;
    }

    @TestVisible
    private static String formatActivityValue(String value) {
        return String.isNotBlank(value) && value != 'blank' ? value : 'None';
    }

    @TestVisible
    private static ActivityItem buildFeedActivity(ConnectApi.FeedElement feedElement, Map<Id, Contact> contactsById) {
        Map<String, Object> feedElementMap = deserializeToMap(feedElement);
        ActivityItem activity = buildFeedActivityFromMap(feedElementMap, contactsById);

        return activity;
    }

    @TestVisible
    private static ActivityItem buildFeedActivityFromMap(Map<String, Object> feedElementMap, Map<Id, Contact> contactsById) {
        Id parentId = toId(getParentId(feedElementMap));
        String contactName = getContactName(parentId, contactsById);
        String feedType = getStringValue(feedElementMap, 'type');
        String body = extractBodyText(feedElementMap);
        Datetime createdDate = parseDatetime(getStringValue(feedElementMap, 'createdDate'));
        String activityText = String.isNotBlank(body) ? body : 'had a ' + feedType + ' activity';

        ActivityItem activity = new ActivityItem();
        activity.id = 'feed-' + getStringValue(feedElementMap, 'id');
        activity.title = 'Contact ' + feedType;
        activity.description = '<strong>' + escapeHtml(contactName) + '</strong> ' + escapeHtml(activityText);
        activity.displayDate = formatDisplayDate(createdDate);
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(parentId);
        activity.activityDate = createdDate;

        return activity;
    }

    @TestVisible
    private static ActivityItem buildContactFeedActivity(ContactFeed feedRecord, Map<Id, Contact> contactsById) {
        Id parentId = (Id) feedRecord.ParentId;
        String contactName = getContactName(parentId, contactsById);
        String feedType = String.isNotBlank(feedRecord.Type) ? feedRecord.Type : 'feed';
        String body = stripHtml(feedRecord.Body);
        String activityText = String.isNotBlank(body) ? body : 'had a ' + feedType + ' activity';

        ActivityItem activity = new ActivityItem();
        activity.id = 'feed-' + String.valueOf(feedRecord.Id);
        activity.feedId = String.valueOf(feedRecord.Id);
        activity.title = 'Contact ' + feedType;
        activity.description = '<strong>' + escapeHtml(contactName) + '</strong> ' + escapeHtml(activityText);
        activity.displayDate = formatDisplayDate(feedRecord.CreatedDate);
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(parentId);
        activity.activityDate = feedRecord.CreatedDate;

        return activity;
    }

    @TestVisible
    private static void addContactFeedFallbackActivities(
        List<ActivityItem> activities,
        List<ContactFeed> contactFeeds,
        Map<Id, Contact> contactsById
    ) {
        if (contactFeeds.size() > 0) {
            for (ContactFeed feedRecord : contactFeeds) {
                activities.add(buildContactFeedActivity(feedRecord, contactsById));
            }
        }
    }

    private static void addFallbackFeedActivities(
        List<ActivityItem> activities,
        List<ConnectApi.FeedElement> feedElements,
        Map<Id, Contact> candidateContactsById,
        Map<String, FieldMetadata> contactFieldsByFeedName,
        Map<Id, String> lookupNamesById
    ) {
        if (feedElements.size() > 0) {
            for (ConnectApi.FeedElement feedElement : feedElements) {
                if (isContactFeedElement(feedElement)) {
                    List<TrackedChangeValue> feedTrackedChanges = extractTrackedChanges(feedElement, contactFieldsByFeedName);
                    if (feedTrackedChanges.size() > 0) {
                        for (TrackedChangeValue trackedChange : feedTrackedChanges) {
                            activities.add(buildTrackedChangeActivity(
                                feedElement,
                                trackedChange,
                                candidateContactsById,
                                contactFieldsByFeedName,
                                lookupNamesById
                            ));
                        }
                    } else {
                        activities.add(buildFeedActivity(feedElement, candidateContactsById));
                    }
                }
            }
        }
    }

    @TestVisible
    private static List<ActivityItem> limitActivities(List<ActivityItem> activities) {
        return limitActivities(activities, DISPLAY_LIMIT);
    }

    @TestVisible
    private static List<ActivityItem> limitActivities(List<ActivityItem> activities, Integer maxItems) {
        List<ActivityItem> limitedActivities = new List<ActivityItem>();
        Integer activityLimit = normalizeMaxItems(maxItems);

        if (activities.size() > 0) {
            Integer maxIndex = Math.min(activityLimit, activities.size());
            for (Integer index = 0; index < maxIndex; index++) {
                limitedActivities.add(activities[index]);
            }
        }

        return limitedActivities;
    }

    @TestVisible
    private static Integer normalizeMaxItems(Integer maxItems) {
        Integer normalizedMaxItems = DISPLAY_LIMIT;

        if (maxItems != null && maxItems > 0) {
            normalizedMaxItems = maxItems;
        }

        return normalizedMaxItems;
    }

    @TestVisible
    private static String getContactName(Id contactId, Map<Id, Contact> contactsById) {
        String contactName = 'Contact';

        if (contactId != null && contactsById.containsKey(contactId)) {
            Contact contactRecord = contactsById.get(contactId);
            if (String.isNotBlank(contactRecord.Name)) {
                contactName = contactRecord.Name;
            }
        }

        return contactName;
    }

    @TestVisible
    private static String formatTrackedValue(
        Object rawValue,
        FieldMetadata metadata,
        Map<Id, String> lookupNamesById
    ) {
        String formattedValue = 'blank';
        Id lookupId = toId(rawValue);

        if (metadata != null && metadata.isReference && lookupId != null && lookupNamesById.containsKey(lookupId)) {
            formattedValue = lookupNamesById.get(lookupId);
        } else if (rawValue != null) {
            formattedValue = String.valueOf(rawValue);
        }

        return formattedValue;
    }

    @TestVisible
    private static Id toId(Object rawValue) {
        Id recordId = null;

        if (rawValue != null) {
            String stringValue = String.valueOf(rawValue);
            if (String.isNotBlank(stringValue)) {
                try {
                    recordId = (Id) stringValue;
                } catch (Exception ex) {
                    recordId = null;
                }
            }
        }

        return recordId;
    }

    @TestVisible
    private static String formatDisplayDate(Datetime value) {
        String formattedDate = '';

        if (value != null) {
            formattedDate = value.format('MM/dd');
        }

        return formattedDate;
    }

    @TestVisible
    private static String stripHtml(String value) {
        String strippedValue = '';

        if (String.isNotBlank(value) && value != 'null') {
            strippedValue = value.replaceAll('<[^>]*>', ' ');
            strippedValue = strippedValue.replaceAll('\\s+', ' ').trim();
        }

        return strippedValue;
    }

    @TestVisible
    private static String escapeHtml(String value) {
        String escapedValue = '';

        if (value != null) {
            escapedValue = value.escapeHtml4();
        }

        return escapedValue;
    }

    @TestVisible
    private static Map<String, Object> deserializeToMap(Object value) {
        Map<String, Object> valueMap = new Map<String, Object>();

        if (value != null) {
            Object parsedValue = JSON.deserializeUntyped(JSON.serialize(value));
            valueMap = castToMap(parsedValue);
        }

        return valueMap;
    }

    @TestVisible
    private static Map<String, Object> castToMap(Object value) {
        Map<String, Object> valueMap = new Map<String, Object>();

        if (value instanceof Map<String, Object>) {
            valueMap = (Map<String, Object>) value;
        }

        return valueMap;
    }

    @TestVisible
    private static Map<String, Object> getMapValue(Map<String, Object> source, String key) {
        Map<String, Object> valueMap = new Map<String, Object>();

        if (source != null && source.containsKey(key)) {
            valueMap = castToMap(source.get(key));
        }

        return valueMap;
    }

    @TestVisible
    private static List<Object> getListValue(Map<String, Object> source, String key) {
        List<Object> values = new List<Object>();

        if (source != null && source.containsKey(key) && source.get(key) instanceof List<Object>) {
            values = (List<Object>) source.get(key);
        }

        return values;
    }

    @TestVisible
    private static String getStringValue(Map<String, Object> source, String key) {
        String value = '';

        if (source != null && source.containsKey(key) && source.get(key) != null) {
            value = String.valueOf(source.get(key));
        }

        return value;
    }

    @TestVisible
    private static String getParentId(Map<String, Object> feedElementMap) {
        String parentId = '';
        Map<String, Object> parent = getMapValue(feedElementMap, 'parent');

        if (parent.size() > 0) {
            parentId = getStringValue(parent, 'id');
        }

        return parentId;
    }

    @TestVisible
    private static String extractBodyText(Map<String, Object> feedElementMap) {
        String bodyText = '';
        Map<String, Object> body = getMapValue(feedElementMap, 'body');
        List<Object> messageSegments = getListValue(body, 'messageSegments');

        if (messageSegments.size() > 0) {
            List<String> textParts = new List<String>();
            for (Object segmentObject : messageSegments) {
                Map<String, Object> segment = castToMap(segmentObject);
                String text = getStringValue(segment, 'text');
                if (String.isNotBlank(text)) {
                    textParts.add(text);
                }
            }
            bodyText = String.join(textParts, ' ');
        }

        if (String.isBlank(bodyText)) {
            bodyText = stripHtml(getStringValue(body, 'text'));
        }

        return bodyText;
    }

    @TestVisible
    private static Datetime parseDatetime(String value) {
        Datetime parsedValue = null;

        if (String.isNotBlank(value)) {
            try {
                parsedValue = (Datetime) JSON.deserialize('"' + value + '"', Datetime.class);
            } catch (Exception ex) {
                parsedValue = null;
            }
        }

        return parsedValue;
    }

    @TestVisible
    private class FieldMetadata {
        private String apiName;
        private String label;
        private Boolean isReference;
        private List<Schema.SObjectType> referenceTo;
    }

    @TestVisible
    private class TrackedChangeValue {
        @TestVisible private String feedElementId;
        @TestVisible private String changeId;
        @TestVisible private String parentId;
        @TestVisible private Datetime createdDate;
        @TestVisible private String fieldName;
        @TestVisible private String fieldLabel;
        @TestVisible private String oldValue;
        @TestVisible private String newValue;
    }

    @TestVisible
    private class TrackedChangeRecord {
        @TestVisible private Id id;
        @TestVisible private Id feedItemId;
        @TestVisible private String fieldName;
        @TestVisible private Object oldValue;
        @TestVisible private Object newValue;
    }

    @TestVisible
    private class TrackedChangeQueryResult {
        @TestVisible private Map<Id, List<TrackedChangeRecord>> changesByFeedId = new Map<Id, List<TrackedChangeRecord>>();
        @TestVisible private Set<Id> feedIdsWithTrackedChanges = new Set<Id>();
        @TestVisible private Boolean queryFailed = false;
        @TestVisible private Integer totalTrackedChangeRows = 0;
        @TestVisible private Integer includedTrackedChangeRows = 0;
        @TestVisible private Integer skippedTrackedChangeRows = 0;
        @TestVisible private List<String> debugEntries = new List<String>();
    }

    public class ActivityDebugResult {
        @AuraEnabled public List<ActivityItem> activities { get; set; }
        @AuraEnabled public ActivityDebugInfo debug { get; set; }

        public ActivityDebugResult() {
            activities = new List<ActivityItem>();
            debug = new ActivityDebugInfo();
        }
    }

    public class ActivityDebugInfo {
        @AuraEnabled public String userId { get; set; }
        @AuraEnabled public String username { get; set; }
        @AuraEnabled public String userType { get; set; }
        @AuraEnabled public String networkId { get; set; }
        @AuraEnabled public Integer maxItems { get; set; }
        @AuraEnabled public Integer createdContactCount { get; set; }
        @AuraEnabled public Integer modifiedContactCount { get; set; }
        @AuraEnabled public Integer candidateContactCount { get; set; }
        @AuraEnabled public Integer readableContactFieldCount { get; set; }
        @AuraEnabled public Integer contactFeedCount { get; set; }
        @AuraEnabled public Integer updateContactFeedCount { get; set; }
        @AuraEnabled public Integer feedIdCount { get; set; }
        @AuraEnabled public Boolean trackedChangeQueryFailed { get; set; }
        @AuraEnabled public Integer feedIdsWithTrackedChangesCount { get; set; }
        @AuraEnabled public Integer totalTrackedChangeRowCount { get; set; }
        @AuraEnabled public Integer includedTrackedChangeRowCount { get; set; }
        @AuraEnabled public Integer skippedTrackedChangeRowCount { get; set; }
        @AuraEnabled public Integer trackedChangeActivityCandidateCount { get; set; }
        @AuraEnabled public Integer lookupNameCount { get; set; }
        @AuraEnabled public Boolean usedGlobalUpdateFeedSearch { get; set; }
        @AuraEnabled public Boolean usedCandidateContactFeedFallback { get; set; }
        @AuraEnabled public Boolean usedRecentContactFeedFallback { get; set; }
        @AuraEnabled public Boolean usedConnectApiFallback { get; set; }
        @AuraEnabled public Integer connectApiFeedElementCount { get; set; }
        @AuraEnabled public Integer connectApiTrackedChangeCount { get; set; }
        @AuraEnabled public Integer activityCountBeforeLimit { get; set; }
        @AuraEnabled public Integer activityCount { get; set; }
        @AuraEnabled public Datetime generatedAt { get; set; }
        @AuraEnabled public List<String> errors { get; set; }
        @AuraEnabled public List<String> feedDebugEntries { get; set; }
        @AuraEnabled public List<String> trackedChangeDebugEntries { get; set; }

        public ActivityDebugInfo() {
            createdContactCount = 0;
            modifiedContactCount = 0;
            candidateContactCount = 0;
            readableContactFieldCount = 0;
            contactFeedCount = 0;
            updateContactFeedCount = 0;
            feedIdCount = 0;
            trackedChangeQueryFailed = false;
            feedIdsWithTrackedChangesCount = 0;
            totalTrackedChangeRowCount = 0;
            includedTrackedChangeRowCount = 0;
            skippedTrackedChangeRowCount = 0;
            trackedChangeActivityCandidateCount = 0;
            lookupNameCount = 0;
            usedGlobalUpdateFeedSearch = false;
            usedCandidateContactFeedFallback = false;
            usedRecentContactFeedFallback = false;
            usedConnectApiFallback = false;
            connectApiFeedElementCount = 0;
            connectApiTrackedChangeCount = 0;
            activityCountBeforeLimit = 0;
            activityCount = 0;
            errors = new List<String>();
            feedDebugEntries = new List<String>();
            trackedChangeDebugEntries = new List<String>();
        }
    }

    public class ActivityItem implements Comparable {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String feedId { get; set; }
        @AuraEnabled public String changeId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String displayDate { get; set; }
        @AuraEnabled public String iconName { get; set; }
        @AuraEnabled public String recordId { get; set; }
        @AuraEnabled public Datetime activityDate { get; set; }
        @AuraEnabled public String fieldName { get; set; }
        @AuraEnabled public String oldValue { get; set; }
        @AuraEnabled public String newValue { get; set; }

        public Integer compareTo(Object compareToObject) {
            ActivityItem compareToActivity = (ActivityItem) compareToObject;
            Integer result = 0;

            if (activityDate == null && compareToActivity.activityDate != null) {
                result = 1;
            } else if (activityDate != null && compareToActivity.activityDate == null) {
                result = -1;
            } else if (activityDate != null && compareToActivity.activityDate != null) {
                Long currentTime = activityDate.getTime();
                Long compareToTime = compareToActivity.activityDate.getTime();
                if (currentTime < compareToTime) {
                    result = 1;
                } else if (currentTime > compareToTime) {
                    result = -1;
                }
            }

            if (result == 0) {
                String currentId = id != null ? id : '';
                String compareToId = compareToActivity.id != null ? compareToActivity.id : '';
                result = currentId.compareTo(compareToId);
            }

            return result;
        }
    }
}