/**
 * Batch upload dashboard data controller.
 * Uses with sharing + stripInaccessible and scopes Experience Cloud users to their Contact Account.
 */
public with sharing class BatchUploadDashboardController {
    public static final String OBJECT_API_NAME = 'Batch__c';
    public static final String STATUS_FIELD = 'Approval_Status__c';
    public static final String ACCOUNT_LOOKUP_FIELD = 'Client_Account__c';

    public static final String STATUS_DRAFT = 'Draft';
    public static final String STATUS_SUBMITTED = 'Submitted';
    public static final String STATUS_APPROVED = 'Approved';
    public static final String STATUS_SENT_BACK = 'Sent Back';
    public static final String STATUS_FAILED = 'Failed';

    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        'Name',
        'Batch_Name__c',
        'Client_Account__r.Name',
        'Total_Records__c',
        'Validated_Records__c',
        'Duplicate_Records__c',
        'Do_Not_Contact_Records__c',
        'Failed_Validation_Records__c',
        'Pending_Upload_Status__c',
        'Consent_Links_Generated__c',
        'Consent_Emails_Sent__c',
        'Consent_Status_Summary__c',
        'Approval_Status__c',
        'Email_Link_Status__c',
        'Reminder_Review_Period__c',
        'CreatedDate',
        'LastModifiedDate'
    };

    private static final Set<String> DATE_TYPE_WHITELIST = new Set<String>{
        'CreatedDate'
    };

    public class BatchSummaryDTO {
        @AuraEnabled public Integer all;
        @AuraEnabled public Integer draft;
        @AuraEnabled public Integer submitted;
        @AuraEnabled public Integer approved;
        @AuraEnabled public Integer sentBack;
        @AuraEnabled public Integer failed;
    }

    public class DashboardFilter {
        @AuraEnabled public String ownership;
        @AuraEnabled public String status;
        @AuraEnabled public String dateType;
        @AuraEnabled public String dateRange;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
    }

    public class BatchDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String batchId;
        @AuraEnabled public String batchName;
        @AuraEnabled public String clientAccount;
        @AuraEnabled public Decimal totalRecords;
        @AuraEnabled public Decimal validatedRecords;
        @AuraEnabled public Decimal duplicateRecords;
        @AuraEnabled public Decimal doNotContactRecords;
        @AuraEnabled public Decimal failedValidationRecords;
        @AuraEnabled public String pendingUploadStatus;
        @AuraEnabled public Decimal consentLinksGenerated;
        @AuraEnabled public Decimal consentEmailsSent;
        @AuraEnabled public String consentStatusSummary;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String emailLinkStatus;
        @AuraEnabled public String reminderReviewPeriod;
        @AuraEnabled public Datetime createdDate;
    }

    @AuraEnabled(cacheable=true)
    public static BatchSummaryDTO getBatchSummary() {
        BatchSummaryDTO dto = new BatchSummaryDTO();
        dto.all = 0;
        dto.draft = 0;
        dto.submitted = 0;
        dto.approved = 0;
        dto.sentBack = 0;
        dto.failed = 0;

        if (isGuestUser() || !isBatchReadable() || !isBatchFieldAccessible(STATUS_FIELD)) {
            return dto;
        }

        List<String> whereClauses = buildBaseWhereClauses();
        if (whereClauses.contains('Id = NULL')) {
            return dto;
        }

        String soql =
            'SELECT Approval_Status__c st, COUNT(Id) cnt FROM Batch__c WHERE ' +
            String.join(whereClauses, ' AND ') +
            ' GROUP BY Approval_Status__c';

        for (AggregateResult ar : Database.query(soql)) {
            String statusValue = (String) ar.get('st');
            Integer countValue = Integer.valueOf(String.valueOf(ar.get('cnt')));
            dto.all += countValue;
            if (STATUS_DRAFT.equals(statusValue)) {
                dto.draft += countValue;
            } else if (STATUS_SUBMITTED.equals(statusValue)) {
                dto.submitted += countValue;
            } else if (STATUS_APPROVED.equals(statusValue)) {
                dto.approved += countValue;
            } else if (STATUS_SENT_BACK.equals(statusValue)) {
                dto.sentBack += countValue;
            } else if (STATUS_FAILED.equals(statusValue)) {
                dto.failed += countValue;
            }
        }
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<BatchDTO> getBatches(
        String statusFilter,
        String searchKey,
        String sortBy,
        String sortDirection,
        DashboardFilter filters
    ) {
        List<BatchDTO> rows = new List<BatchDTO>();
        if (isGuestUser() || !isBatchReadable()) {
            return rows;
        }

        List<String> whereClauses = buildBaseWhereClauses();
        if (whereClauses.contains('Id = NULL')) {
            return rows;
        }

        appendStatusFilterClause(whereClauses, resolveEffectiveStatusFilter(statusFilter, filters));
        appendOwnershipClause(whereClauses, filters);
        appendDateRangeClause(whereClauses, filters);
        appendSearchClause(whereClauses, searchKey);

        String orderClause = buildOrderClause(sortBy, sortDirection);

        String soql =
            'SELECT Id, Name, Batch_Name__c, Client_Account__c, Client_Account__r.Name, ' +
            'Total_Records__c, Validated_Records__c, ' +
            'Duplicate_Records__c, Do_Not_Contact_Records__c, Failed_Validation_Records__c, ' +
            'Pending_Upload_Status__c, Consent_Links_Generated__c, Consent_Emails_Sent__c, ' +
            'Consent_Status_Summary__c, Approval_Status__c, Email_Link_Status__c, Reminder_Review_Period__c, ' +
            'CreatedDate, LastModifiedDate ' +
            'FROM Batch__c WHERE ' + String.join(whereClauses, ' AND ') +
            ' ORDER BY ' + orderClause;
        // If Reminder_Review_Period__c does not exist in your org, replace with Reminder_Review_Period_Days__c.

        List<Batch__c> raw = Database.query(soql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, raw);
        List<Batch__c> records = (List<Batch__c>) decision.getRecords();

        Integer rowNumber = 1;
        for (Batch__c rec : records) {
            BatchDTO dto = new BatchDTO();
            dto.id = rec.Id;
            dto.rowNumber = rowNumber++;
            dto.batchId = (String) getPopulated(rec, 'Name');
            dto.batchName = (String) getPopulated(rec, 'Batch_Name__c');

            SObject accountRef = rec.getSObject('Client_Account__r');
            if (accountRef != null && accountRef.getPopulatedFieldsAsMap().containsKey('Name')) {
                dto.clientAccount = (String) accountRef.get('Name');
            }

            dto.totalRecords = (Decimal) getPopulated(rec, 'Total_Records__c');
            dto.validatedRecords = (Decimal) getPopulated(rec, 'Validated_Records__c');
            dto.duplicateRecords = (Decimal) getPopulated(rec, 'Duplicate_Records__c');
            dto.doNotContactRecords = (Decimal) getPopulated(rec, 'Do_Not_Contact_Records__c');
            dto.failedValidationRecords = (Decimal) getPopulated(rec, 'Failed_Validation_Records__c');
            dto.pendingUploadStatus = (String) getPopulated(rec, 'Pending_Upload_Status__c');
            dto.consentLinksGenerated = (Decimal) getPopulated(rec, 'Consent_Links_Generated__c');
            dto.consentEmailsSent = (Decimal) getPopulated(rec, 'Consent_Emails_Sent__c');
            dto.consentStatusSummary = (String) getPopulated(rec, 'Consent_Status_Summary__c');
            dto.approvalStatus = (String) getPopulated(rec, 'Approval_Status__c');
            dto.emailLinkStatus = (String) getPopulated(rec, 'Email_Link_Status__c');
            Object reminderVal = getPopulated(rec, 'Reminder_Review_Period__c');
            dto.reminderReviewPeriod = reminderVal == null ? null : String.valueOf(reminderVal);
            dto.createdDate = (Datetime) getPopulated(rec, 'CreatedDate');
            rows.add(dto);
        }
        return rows;
    }

    private static void appendSearchClause(List<String> whereClauses, String searchKey) {
        if (String.isBlank(searchKey)) {
            return;
        }
        String sanitized = String.escapeSingleQuotes(searchKey.trim());
        String term = '%' + sanitized + '%';
        List<String> searchParts = new List<String>();

        if (isBatchFieldAccessible('Name')) {
            searchParts.add('Name LIKE \'' + term + '\'');
        }
        if (isBatchFieldAccessible('Batch_Name__c')) {
            searchParts.add('Batch_Name__c LIKE \'' + term + '\'');
        }
        if (isBatchFieldAccessible(ACCOUNT_LOOKUP_FIELD) && isAccountFieldAccessible('Name')) {
            searchParts.add('Client_Account__r.Name LIKE \'' + term + '\'');
        }
        if (isBatchFieldAccessible(STATUS_FIELD)) {
            searchParts.add('Approval_Status__c LIKE \'' + term + '\'');
        }
        if (isBatchFieldAccessible('Email_Link_Status__c')) {
            searchParts.add('Email_Link_Status__c LIKE \'' + term + '\'');
        }
        if (isBatchFieldAccessible('Pending_Upload_Status__c')) {
            searchParts.add('Pending_Upload_Status__c LIKE \'' + term + '\'');
        }
        if (isBatchFieldAccessible('Consent_Status_Summary__c')) {
            searchParts.add('Consent_Status_Summary__c LIKE \'' + term + '\'');
        }

        if (!searchParts.isEmpty()) {
            whereClauses.add('(' + String.join(searchParts, ' OR ') + ')');
        }
    }

    private static void appendStatusFilterClause(List<String> whereClauses, String normalizedStatus) {
        if ('DRAFT'.equals(normalizedStatus)) {
            whereClauses.add(STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_DRAFT) + '\'');
        } else if ('SUBMITTED'.equals(normalizedStatus)) {
            whereClauses.add(STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_SUBMITTED) + '\'');
        } else if ('APPROVED'.equals(normalizedStatus)) {
            whereClauses.add(STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_APPROVED) + '\'');
        } else if ('SENT_BACK'.equals(normalizedStatus)) {
            whereClauses.add(STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_SENT_BACK) + '\'');
        } else if ('FAILED'.equals(normalizedStatus)) {
            whereClauses.add(STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_FAILED) + '\'');
        }
    }

    private static String resolveEffectiveStatusFilter(String statusFilter, DashboardFilter filters) {
        if (filters != null && String.isNotBlank(filters.status)) {
            String filterStatus = filters.status.trim().toUpperCase().replace(' ', '_');
            if ('ALL'.equals(filterStatus)) {
                return 'ALL';
            }
            return filterStatus;
        }
        if (String.isBlank(statusFilter)) {
            return 'ALL';
        }
        return statusFilter.trim().toUpperCase();
    }

    private static void appendOwnershipClause(List<String> whereClauses, DashboardFilter filters) {
        if (filters == null || String.isBlank(filters.ownership)) {
            return;
        }
        if ('MY'.equalsIgnoreCase(filters.ownership.trim())) {
            whereClauses.add('OwnerId = \'' + String.escapeSingleQuotes(String.valueOf(UserInfo.getUserId())) + '\'');
        }
    }

    private static void appendDateRangeClause(List<String> whereClauses, DashboardFilter filters) {
        if (filters == null || String.isBlank(filters.dateType) || filters.startDate == null || filters.endDate == null) {
            return;
        }
        if (filters.endDate < filters.startDate) {
            return;
        }

        String dateField = filters.dateType.trim();
        if (!DATE_TYPE_WHITELIST.contains(dateField)) {
            return;
        }
        if (!isBatchFieldAccessible(dateField)) {
            return;
        }

        Schema.SObjectField dateFieldRef = Schema.SObjectType.Batch__c.fields.getMap().get(dateField);
        if (dateFieldRef == null) {
            return;
        }
        Schema.DescribeFieldResult fieldDescribe = dateFieldRef.getDescribe();
        if (fieldDescribe.getType() == Schema.DisplayType.DATE) {
            whereClauses.add(
                dateField + ' >= ' + formatDateLiteral(filters.startDate) +
                ' AND ' + dateField + ' <= ' + formatDateLiteral(filters.endDate)
            );
            return;
        }

        String endDatePlusOne = formatDateLiteral(filters.endDate.addDays(1));
        whereClauses.add(
            dateField + ' >= ' + formatDateLiteral(filters.startDate) + 'T00:00:00.000Z' +
            ' AND ' + dateField + ' < ' + endDatePlusOne + 'T00:00:00.000Z'
        );
    }

    private static String buildOrderClause(String sortBy, String sortDirection) {
        String requestedSort = String.isBlank(sortBy) ? null : sortBy.trim();
        if (String.isBlank(requestedSort) || !SORTABLE_FIELDS.contains(requestedSort)) {
            return 'CreatedDate DESC, LastModifiedDate DESC';
        }

        String direction = 'DESC';
        if ('asc'.equalsIgnoreCase(sortDirection)) {
            direction = 'ASC';
        } else if ('desc'.equalsIgnoreCase(sortDirection)) {
            direction = 'DESC';
        }

        return requestedSort + ' ' + direction + ', LastModifiedDate DESC';
    }

    private static List<String> buildBaseWhereClauses() {
        List<String> parts = new List<String>{ 'Id != NULL' };
        if (!shouldApplyExperienceCloudScope()) {
            return parts;
        }

        User scopedUser = [
            SELECT ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (scopedUser.ContactId == null || scopedUser.Contact.AccountId == null) {
            return new List<String>{ 'Id = NULL' };
        }
        parts.add(ACCOUNT_LOOKUP_FIELD + ' = \'' + String.escapeSingleQuotes(String.valueOf(scopedUser.Contact.AccountId)) + '\'');
        return parts;
    }

    private static Boolean shouldApplyExperienceCloudScope() {
        if (Network.getNetworkId() == null) {
            return false;
        }
        String userType = UserInfo.getUserType();
        return userType != 'Standard' && userType != 'Guest' && userType != 'AutomatedProcess';
    }

    private static Boolean isGuestUser() {
        return 'Guest'.equals(UserInfo.getUserType());
    }

    private static Boolean isBatchReadable() {
        return Schema.SObjectType.Batch__c.isAccessible();
    }

    private static Boolean isBatchFieldAccessible(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        Schema.SObjectField fld = Schema.SObjectType.Batch__c.fields.getMap().get(fieldApiName);
        return fld != null && fld.getDescribe().isAccessible();
    }

    private static Boolean isAccountFieldAccessible(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        Schema.SObjectField fld = Schema.SObjectType.Account.fields.getMap().get(fieldApiName);
        return fld != null && fld.getDescribe().isAccessible();
    }

    private static Object getPopulated(SObject recordRow, String fieldApiName) {
        if (recordRow == null || String.isBlank(fieldApiName)) {
            return null;
        }
        Map<String, Object> populated = recordRow.getPopulatedFieldsAsMap();
        return populated.containsKey(fieldApiName) ? populated.get(fieldApiName) : null;
    }

    private static Datetime coerceToDatetime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Datetime) {
            return (Datetime) value;
        }
        if (value instanceof Date) {
            return Datetime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0));
        }
        return null;
    }

    private static String formatDateLiteral(Date value) {
        return String.valueOf(value.year()) +
            '-' + String.valueOf(value.month()).leftPad(2, '0') +
            '-' + String.valueOf(value.day()).leftPad(2, '0');
    }
}