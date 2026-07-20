public with sharing class RecentActivityReportController {
    private static final Integer DISPLAY_LIMIT = 20;
    private static final Integer QUERY_WINDOW = 50;
    private static final Integer FEED_CANDIDATE_LIMIT = 20;
    private static final String OBJECT_API_NAME = 'Reports__c';
    private static final String FEED_OBJECT_API_NAME = 'Reports__Feed';
    private static final String FEED_TYPE_TRACKED_CHANGE = 'TrackedChange';
    private static final String ICON_NAME = 'standard:lead';

    @AuraEnabled(cacheable=true)
    public static List<ActivityItem> getRecentActivities(Integer maxItems) {
        List<ActivityItem> activities = new List<ActivityItem>();
        Integer activityLimit = normalizeMaxItems(maxItems);
        List<SObject> createdReports = queryCreatedReports();
        Map<Id, SObject> reportsById = buildRecordsById(createdReports);
        Map<String, FieldMetadata> reportFieldsByFeedName = buildReportFieldMetadata();

        for (SObject reportRecord : createdReports) {
            activities.add(buildCreatedActivity(reportRecord));
        }

        List<SObject> feedRecords = queryRecentUpdateReportFeeds(activityLimit);
        if (feedRecords.isEmpty() && !reportsById.isEmpty()) {
            feedRecords = queryReportFeeds(reportsById.keySet(), activityLimit);
        }
        if (feedRecords.isEmpty()) {
            feedRecords = queryRecentReportFeeds(activityLimit);
        }

        Set<Id> feedParentIds = getFeedParentIds(feedRecords);
        if (!feedParentIds.isEmpty()) {
            reportsById.putAll(queryReportsById(feedParentIds));
        }

        TrackedChangeQueryResult trackedChangeResult = queryTrackedChangesByFeedId(
            getFeedIds(feedRecords),
            reportFieldsByFeedName
        );
        Map<Id, List<TrackedChangeRecord>> changesByFeedId = trackedChangeResult.changesByFeedId;
        Map<Id, String> lookupNamesById = queryLookupNames(changesByFeedId, reportFieldsByFeedName);

        for (SObject feedRecord : feedRecords) {
            Id feedId = (Id) feedRecord.get('Id');
            List<TrackedChangeRecord> feedTrackedChanges = changesByFeedId.get(feedId);
            if (feedTrackedChanges != null && !feedTrackedChanges.isEmpty()) {
                for (TrackedChangeRecord trackedChange : feedTrackedChanges) {
                    activities.add(buildTrackedChangeActivity(
                        feedRecord,
                        trackedChange,
                        reportsById,
                        reportFieldsByFeedName,
                        lookupNamesById
                    ));
                }
            } else {
                activities.add(buildFeedActivity(feedRecord, reportsById));
            }
        }

        activities.sort();
        return limitActivities(activities, activityLimit);
    }

    @AuraEnabled(cacheable=true)
    public static List<ActivityItem> getRecentActivitiesByRecordId(Id recordId, Integer maxItems) {
        List<ActivityItem> activities = new List<ActivityItem>();
        Schema.SObjectType reportType = Schema.getGlobalDescribe().get(OBJECT_API_NAME);

        if (recordId == null || reportType == null || recordId.getSObjectType() != reportType) {
            return activities;
        }

        Integer activityLimit = normalizeMaxItems(maxItems);
        Map<Id, SObject> reportsById = queryReportsById(new Set<Id>{ recordId });
        if (reportsById.isEmpty()) {
            return activities;
        }

        Map<String, FieldMetadata> reportFieldsByFeedName = buildReportFieldMetadata();
        List<SObject> feedRecords = queryTrackedReportFeedsByRecordId(recordId, activityLimit);
        if (feedRecords.isEmpty()) {
            return activities;
        }

        TrackedChangeQueryResult trackedChangeResult = queryTrackedChangesByFeedId(
            getFeedIds(feedRecords),
            reportFieldsByFeedName
        );
        Map<Id, List<TrackedChangeRecord>> changesByFeedId = trackedChangeResult.changesByFeedId;
        Map<Id, String> lookupNamesById = queryLookupNames(changesByFeedId, reportFieldsByFeedName);

        for (SObject feedRecord : feedRecords) {
            Id feedId = (Id) feedRecord.get('Id');
            List<TrackedChangeRecord> feedTrackedChanges = changesByFeedId.get(feedId);
            if (feedTrackedChanges != null && !feedTrackedChanges.isEmpty()) {
                for (TrackedChangeRecord trackedChange : feedTrackedChanges) {
                    activities.add(buildTrackedChangeActivity(
                        feedRecord,
                        trackedChange,
                        reportsById,
                        reportFieldsByFeedName,
                        lookupNamesById
                    ));
                }
            }
        }

        activities.sort();
        return limitActivities(activities, activityLimit);
    }

    @TestVisible
    private static List<SObject> queryCreatedReports() {
        List<SObject> records = new List<SObject>();
        Integer queryWindow = QUERY_WINDOW;
        try {
            records = Database.query(
                'SELECT Id, Name, CreatedDate, LastModifiedDate FROM ' + OBJECT_API_NAME +
                ' ORDER BY CreatedDate DESC LIMIT :queryWindow'
            );
            records = Security.stripInaccessible(AccessType.READABLE, records).getRecords();
        } catch (Exception ex) {
            records = new List<SObject>();
        }
        return records;
    }

    @TestVisible
    private static List<SObject> queryReportFeeds(Set<Id> reportIds, Integer maxItems) {
        List<SObject> records = new List<SObject>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);
        if (!reportIds.isEmpty()) {
            try {
                records = Database.query(
                    'SELECT Id, ParentId, CreatedDate, Type, Body FROM ' + FEED_OBJECT_API_NAME +
                    ' WHERE ParentId IN :reportIds ORDER BY CreatedDate DESC LIMIT :queryLimit'
                );
                records = Security.stripInaccessible(AccessType.READABLE, records).getRecords();
            } catch (Exception ex) {
                records = new List<SObject>();
            }
        }
        return records;
    }

    @TestVisible
    private static List<SObject> queryRecentUpdateReportFeeds(Integer maxItems) {
        List<SObject> records = new List<SObject>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);
        try {
            records = Database.query(
                'SELECT Id, ParentId, CreatedDate, Type, Body FROM ' + FEED_OBJECT_API_NAME +
                ' WHERE Type = :FEED_TYPE_TRACKED_CHANGE ORDER BY CreatedDate DESC LIMIT :queryLimit'
            );
            records = Security.stripInaccessible(AccessType.READABLE, records).getRecords();
        } catch (Exception ex) {
            records = new List<SObject>();
        }
        return records;
    }

    @TestVisible
    private static List<SObject> queryTrackedReportFeedsByRecordId(Id recordId, Integer maxItems) {
        List<SObject> records = new List<SObject>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);

        if (recordId != null) {
            try {
                records = Database.query(
                    'SELECT Id, ParentId, CreatedDate, Type, Body FROM ' + FEED_OBJECT_API_NAME +
                    ' WHERE ParentId = :recordId AND Type = :FEED_TYPE_TRACKED_CHANGE ORDER BY CreatedDate DESC LIMIT :queryLimit'
                );
                records = Security.stripInaccessible(AccessType.READABLE, records).getRecords();
            } catch (Exception ex) {
                records = new List<SObject>();
            }
        }
        return records;
    }

    @TestVisible
    private static List<SObject> queryRecentReportFeeds(Integer maxItems) {
        List<SObject> records = new List<SObject>();
        Integer queryLimit = Math.max(FEED_CANDIDATE_LIMIT, normalizeMaxItems(maxItems) * 5);
        try {
            records = Database.query(
                'SELECT Id, ParentId, CreatedDate, Type, Body FROM ' + FEED_OBJECT_API_NAME +
                ' ORDER BY CreatedDate DESC LIMIT :queryLimit'
            );
            records = Security.stripInaccessible(AccessType.READABLE, records).getRecords();
        } catch (Exception ex) {
            records = new List<SObject>();
        }
        return records;
    }

    @TestVisible
    private static Map<Id, SObject> queryReportsById(Set<Id> reportIds) {
        Map<Id, SObject> recordsById = new Map<Id, SObject>();
        List<SObject> records = new List<SObject>();
        if (!reportIds.isEmpty()) {
            try {
                records = Database.query(
                    'SELECT Id, Name, CreatedDate, LastModifiedDate FROM ' + OBJECT_API_NAME + ' WHERE Id IN :reportIds'
                );
                records = Security.stripInaccessible(AccessType.READABLE, records).getRecords();
            } catch (Exception ex) {
                records = new List<SObject>();
            }
        }
        for (SObject record : records) {
            recordsById.put((Id) record.get('Id'), record);
        }
        return recordsById;
    }

    @TestVisible
    private static TrackedChangeQueryResult queryTrackedChangesByFeedId(Set<Id> feedIds, Map<String, FieldMetadata> reportFieldsByFeedName) {
        TrackedChangeQueryResult result = new TrackedChangeQueryResult();
        if (!feedIds.isEmpty()) {
            try {
                List<SObject> records = Database.query(
                    'SELECT Id, FeedItemId, FieldName, OldValue, NewValue FROM FeedTrackedChange WHERE FeedItemId IN :feedIds'
                );
                addTrackedChanges(result, records, reportFieldsByFeedName);
            } catch (Exception ex) {
                queryTrackedChangesFromFeedItems(result, feedIds, reportFieldsByFeedName);
            }
        }
        deduplicateDisplayDuplicateTrackedChanges(result.changesByFeedId, reportFieldsByFeedName);
        return result;
    }

    @TestVisible
    private static void deduplicateDisplayDuplicateTrackedChanges(
        Map<Id, List<TrackedChangeRecord>> changesByFeedId,
        Map<String, FieldMetadata> reportFieldsByFeedName
    ) {
        for (Id feedId : changesByFeedId.keySet()) {
            changesByFeedId.put(
                feedId,
                deduplicateDisplayDuplicateTrackedChanges(
                    changesByFeedId.get(feedId),
                    reportFieldsByFeedName
                )
            );
        }
    }

    @TestVisible
    private static List<TrackedChangeRecord> deduplicateDisplayDuplicateTrackedChanges(
        List<TrackedChangeRecord> trackedChanges,
        Map<String, FieldMetadata> reportFieldsByFeedName
    ) {
        List<TrackedChangeRecord> deduplicatedChanges = new List<TrackedChangeRecord>();
        Map<String, Integer> referenceChangeIndexByKey = new Map<String, Integer>();

        if (trackedChanges != null) {
            for (TrackedChangeRecord trackedChange : trackedChanges) {
                FieldMetadata metadata = trackedChange != null ? reportFieldsByFeedName.get(trackedChange.fieldName) : null;
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

    private static Boolean shouldReplaceDisplayDuplicate(TrackedChangeRecord existingChange, TrackedChangeRecord candidateChange) {
        return !hasReadableTrackedValue(existingChange) && hasReadableTrackedValue(candidateChange) && hasIdTrackedValue(existingChange);
    }

    private static Boolean hasReadableTrackedValue(TrackedChangeRecord trackedChange) {
        return isReadableTrackedValue(trackedChange.oldValue) || isReadableTrackedValue(trackedChange.newValue);
    }

    private static Boolean hasIdTrackedValue(TrackedChangeRecord trackedChange) {
        return toId(trackedChange.oldValue) != null || toId(trackedChange.newValue) != null;
    }

    private static Boolean isReadableTrackedValue(Object rawValue) {
        return rawValue != null && String.isNotBlank(String.valueOf(rawValue)) && toId(rawValue) == null;
    }

    private static void queryTrackedChangesFromFeedItems(TrackedChangeQueryResult result, Set<Id> feedIds, Map<String, FieldMetadata> reportFieldsByFeedName) {
        try {
            List<SObject> feedRecords = Database.query(
                'SELECT Id, (SELECT Id, FieldName, OldValue, NewValue FROM FeedTrackedChanges ORDER BY Id ASC) ' +
                'FROM ' + FEED_OBJECT_API_NAME + ' WHERE Id IN :feedIds'
            );
            for (SObject feedRecord : feedRecords) {
                List<SObject> childRecords = feedRecord.getSObjects('FeedTrackedChanges');
                if (childRecords != null) {
                    for (SObject childRecord : childRecords) {
                        addTrackedChange(result, buildTrackedChangeRecord((Id) feedRecord.get('Id'), childRecord), reportFieldsByFeedName);
                    }
                }
            }
        } catch (Exception ex) {
            result.queryFailed = true;
        }
    }

    private static void addTrackedChanges(TrackedChangeQueryResult result, List<SObject> records, Map<String, FieldMetadata> reportFieldsByFeedName) {
        for (SObject record : records) {
            addTrackedChange(result, buildTrackedChangeRecord((Id) record.get('FeedItemId'), record), reportFieldsByFeedName);
        }
    }

    private static void addTrackedChange(TrackedChangeQueryResult result, TrackedChangeRecord trackedChange, Map<String, FieldMetadata> reportFieldsByFeedName) {
        result.feedIdsWithTrackedChanges.add(trackedChange.feedItemId);
        if (shouldIncludeTrackedChange(trackedChange, reportFieldsByFeedName)) {
            if (!result.changesByFeedId.containsKey(trackedChange.feedItemId)) {
                result.changesByFeedId.put(trackedChange.feedItemId, new List<TrackedChangeRecord>());
            }
            result.changesByFeedId.get(trackedChange.feedItemId).add(trackedChange);
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
    private static Boolean shouldIncludeTrackedChange(TrackedChangeRecord trackedChange, Map<String, FieldMetadata> reportFieldsByFeedName) {
        return trackedChange != null && String.isNotBlank(trackedChange.fieldName) && reportFieldsByFeedName.containsKey(trackedChange.fieldName);
    }

    @TestVisible
    private static String normalizeTrackedFieldName(String fieldName) {
        String normalizedFieldName = fieldName;
        if (String.isNotBlank(normalizedFieldName) && normalizedFieldName.contains('.')) {
            normalizedFieldName = normalizedFieldName.substringAfter('.');
        }
        return normalizedFieldName;
    }

    @TestVisible
    private static Map<String, FieldMetadata> buildReportFieldMetadata() {
        Map<String, FieldMetadata> fieldMetadataByFeedName = new Map<String, FieldMetadata>();
        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(OBJECT_API_NAME).getDescribe().fields.getMap();
        for (String fieldApiName : fields.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fields.get(fieldApiName).getDescribe();
            if (fieldDescribe.isAccessible()) {
                FieldMetadata metadata = new FieldMetadata();
                metadata.apiName = fieldDescribe.getName();
                metadata.label = fieldDescribe.getLabel();
                metadata.isReference = fieldDescribe.getType() == Schema.DisplayType.REFERENCE;
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
        Map<Id, List<TrackedChangeRecord>> changesByFeedId,
        Map<String, FieldMetadata> reportFieldsByFeedName
    ) {
        Map<Id, String> lookupNamesById = new Map<Id, String>();
        Map<Schema.SObjectType, Set<Id>> idsByType = new Map<Schema.SObjectType, Set<Id>>();

        for (List<TrackedChangeRecord> trackedChanges : changesByFeedId.values()) {
            for (TrackedChangeRecord trackedChange : trackedChanges) {
                FieldMetadata metadata = reportFieldsByFeedName.get(trackedChange.fieldName);
                if (metadata != null && metadata.isReference) {
                    collectLookupId(idsByType, trackedChange.oldValue);
                    collectLookupId(idsByType, trackedChange.newValue);
                }
            }
        }

        for (Schema.SObjectType sObjectType : idsByType.keySet()) {
            queryLookupNamesByType(lookupNamesById, sObjectType, idsByType.get(sObjectType));
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

    private static void queryLookupNamesByType(Map<Id, String> lookupNamesById, Schema.SObjectType sObjectType, Set<Id> ids) {
        Schema.DescribeSObjectResult objectDescribe = sObjectType.getDescribe();
        String objectApiName = objectDescribe.getName();
        String nameField = getNameField(objectDescribe);

        if (String.isNotBlank(nameField) && ids != null && !ids.isEmpty()) {
            try {
                List<SObject> lookupRecords = Database.query(
                    'SELECT Id, ' + nameField + ' FROM ' + objectApiName + ' WHERE Id IN :ids'
                );
                lookupRecords = Security.stripInaccessible(AccessType.READABLE, lookupRecords).getRecords();
                for (SObject lookupRecord : lookupRecords) {
                    Object nameValue = lookupRecord.get(nameField);
                    if (nameValue != null) {
                        lookupNamesById.put((Id) lookupRecord.get('Id'), String.valueOf(nameValue));
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

    @TestVisible
    private static Map<Id, SObject> buildRecordsById(List<SObject> records) {
        Map<Id, SObject> recordsById = new Map<Id, SObject>();
        for (SObject record : records) {
            recordsById.put((Id) record.get('Id'), record);
        }
        return recordsById;
    }

    @TestVisible
    private static Set<Id> getFeedIds(List<SObject> feedRecords) {
        Set<Id> feedIds = new Set<Id>();
        for (SObject feedRecord : feedRecords) {
            feedIds.add((Id) feedRecord.get('Id'));
        }
        return feedIds;
    }

    @TestVisible
    private static Set<Id> getFeedParentIds(List<SObject> feedRecords) {
        Set<Id> parentIds = new Set<Id>();
        for (SObject feedRecord : feedRecords) {
            if (feedRecord.get('ParentId') != null) {
                parentIds.add((Id) feedRecord.get('ParentId'));
            }
        }
        return parentIds;
    }

    private static ActivityItem buildCreatedActivity(SObject reportRecord) {
        ActivityItem activity = new ActivityItem();
        activity.id = 'created-' + String.valueOf(reportRecord.get('Id'));
        activity.title = 'Report Created';
        activity.description = '<strong>' + escapeHtml(getReportName((Id) reportRecord.get('Id'), buildRecordsById(new List<SObject>{ reportRecord }))) + '</strong> created';
        activity.displayDate = formatDisplayDate((Datetime) reportRecord.get('CreatedDate'));
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(reportRecord.get('Id'));
        activity.activityDate = (Datetime) reportRecord.get('CreatedDate');
        return activity;
    }

    @TestVisible
    private static ActivityItem buildTrackedChangeActivity(
        SObject feedRecord,
        TrackedChangeRecord trackedChange,
        Map<Id, SObject> reportsById,
        Map<String, FieldMetadata> reportFieldsByFeedName,
        Map<Id, String> lookupNamesById
    ) {
        Id parentId = (Id) feedRecord.get('ParentId');
        FieldMetadata metadata = reportFieldsByFeedName.get(trackedChange.fieldName);
        String fieldLabel = metadata != null && String.isNotBlank(metadata.label) ? metadata.label : trackedChange.fieldName;
        String oldValue = formatTrackedValue(trackedChange.oldValue, metadata, lookupNamesById);
        String newValue = formatTrackedValue(trackedChange.newValue, metadata, lookupNamesById);
        String reportName = getReportName(parentId, reportsById);
        ActivityItem activity = new ActivityItem();
        activity.id = String.valueOf(feedRecord.get('Id')) + '-' + String.valueOf(trackedChange.id);
        activity.feedId = String.valueOf(feedRecord.get('Id'));
        activity.changeId = String.valueOf(trackedChange.id);
        activity.title = 'Report ' + fieldLabel + ' Changed';
        activity.description =
            escapeHtml(fieldLabel) + ' for <strong>' + escapeHtml(reportName) + '</strong> changed from <strong>' +
            escapeHtml(formatActivityValue(oldValue)) + '</strong> to <strong>' +
            escapeHtml(formatActivityValue(newValue)) + '</strong>';
        activity.displayDate = formatDisplayDate((Datetime) feedRecord.get('CreatedDate'));
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(parentId);
        activity.activityDate = (Datetime) feedRecord.get('CreatedDate');
        return activity;
    }

    @TestVisible
    private static String formatTrackedValue(Object rawValue, FieldMetadata metadata, Map<Id, String> lookupNamesById) {
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
    private static String formatActivityValue(String value) {
        return String.isNotBlank(value) && value != 'blank' ? value : 'None';
    }

    @TestVisible
    private static Id toId(Object rawValue) {
        Id recordId = null;
        if (rawValue != null && String.isNotBlank(String.valueOf(rawValue))) {
            try {
                recordId = (Id) String.valueOf(rawValue);
            } catch (Exception ex) {
                recordId = null;
            }
        }
        return recordId;
    }

    @TestVisible
    private static ActivityItem buildFeedActivity(SObject feedRecord, Map<Id, SObject> reportsById) {
        Id parentId = (Id) feedRecord.get('ParentId');
        String reportName = getReportName(parentId, reportsById);
        String feedType = String.isNotBlank((String) feedRecord.get('Type')) ? (String) feedRecord.get('Type') : 'feed';
        String body = stripHtml((String) feedRecord.get('Body'));
        String activityText = String.isNotBlank(body) ? body : 'had a ' + feedType + ' activity';
        ActivityItem activity = new ActivityItem();
        activity.id = 'feed-' + String.valueOf(feedRecord.get('Id'));
        activity.feedId = String.valueOf(feedRecord.get('Id'));
        activity.title = 'Report ' + feedType;
        activity.description = '<strong>' + escapeHtml(reportName) + '</strong> ' + escapeHtml(activityText);
        activity.displayDate = formatDisplayDate((Datetime) feedRecord.get('CreatedDate'));
        activity.iconName = ICON_NAME;
        activity.recordId = String.valueOf(parentId);
        activity.activityDate = (Datetime) feedRecord.get('CreatedDate');
        return activity;
    }

    @TestVisible
    private static String getReportName(Id reportId, Map<Id, SObject> reportsById) {
        String reportName = 'Report';
        if (reportId != null && reportsById.containsKey(reportId)) {
            Object nameValue = reportsById.get(reportId).get('Name');
            if (nameValue != null && String.isNotBlank(String.valueOf(nameValue))) {
                reportName = String.valueOf(nameValue);
            }
        }
        return reportName;
    }

    @TestVisible
    private static List<ActivityItem> limitActivities(List<ActivityItem> activities, Integer maxItems) {
        List<ActivityItem> limitedActivities = new List<ActivityItem>();
        Integer maxIndex = Math.min(normalizeMaxItems(maxItems), activities.size());
        for (Integer index = 0; index < maxIndex; index++) {
            limitedActivities.add(activities[index]);
        }
        return limitedActivities;
    }

    @TestVisible
    private static Integer normalizeMaxItems(Integer maxItems) {
        return maxItems != null && maxItems > 0 ? maxItems : DISPLAY_LIMIT;
    }

    @TestVisible
    private static String formatDisplayDate(Datetime value) {
        return value != null ? value.format('MM/dd') : '';
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
        return value != null ? value.escapeHtml4() : '';
    }

    @TestVisible private class FieldMetadata {
        @TestVisible private String apiName;
        @TestVisible private String label;
        @TestVisible private Boolean isReference;
    }

    @TestVisible private class TrackedChangeRecord {
        @TestVisible private Id id;
        @TestVisible private Id feedItemId;
        @TestVisible private String fieldName;
        @TestVisible private Object oldValue;
        @TestVisible private Object newValue;
    }

    @TestVisible private class TrackedChangeQueryResult {
        @TestVisible private Map<Id, List<TrackedChangeRecord>> changesByFeedId = new Map<Id, List<TrackedChangeRecord>>();
        @TestVisible private Set<Id> feedIdsWithTrackedChanges = new Set<Id>();
        @TestVisible private Boolean queryFailed = false;
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

        public Integer compareTo(Object compareToObject) {
            ActivityItem other = (ActivityItem) compareToObject;
            Integer result = 0;
            if (activityDate == null && other.activityDate != null) {
                result = 1;
            } else if (activityDate != null && other.activityDate == null) {
                result = -1;
            } else if (activityDate != null && other.activityDate != null) {
                if (activityDate.getTime() < other.activityDate.getTime()) {
                    result = 1;
                } else if (activityDate.getTime() > other.activityDate.getTime()) {
                    result = -1;
                }
            }
            if (result == 0) {
                result = (id != null ? id : '').compareTo(other.id != null ? other.id : '');
            }
            return result;
        }
    }
}