/**
 * Exception__c dashboard for Partner Central / Experience Cloud.
 * TODO: If Exception__c has a client Account lookup, add Experience Cloud user Account scope in buildBaseWhereClauses().
 */
public with sharing class ExceptionDashboardController {
    public static final String OBJECT_API_NAME = 'Exception__c';
    public static final String SOURCE_FIELD = 'Source__c';

    public static final String SOURCE_CONSENT_UPLOAD = 'Consent Upload';
    public static final String SOURCE_DEPARTURE_UPLOAD = 'Departure Upload';
    public static final String SOURCE_REPORT_UPLOAD = 'Report Upload';

    private static final String FLD_EXCEPTION_FIELD_NAME = 'Exception_Field_Name__c';
    private static final String FLD_FIELD_VALUE = 'Field_Value__c';
    private static final String FLD_EXCEPTION_MESSAGE = 'Exception_Message__c';

    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        FLD_EXCEPTION_FIELD_NAME,
        FLD_FIELD_VALUE,
        FLD_EXCEPTION_MESSAGE,
        SOURCE_FIELD,
        'CreatedDate',
        'LastModifiedDate'
    };

    private static final Set<String> DATE_TYPE_WHITELIST = new Set<String>{
        'CreatedDate',
        'LastModifiedDate'
    };

    public class ExceptionSummaryDTO {
        @AuraEnabled public Integer all;
        @AuraEnabled public Integer consentUpload;
        @AuraEnabled public Integer departureUpload;
        @AuraEnabled public Integer reportUpload;
    }

    public class DashboardFilter {
        @AuraEnabled public String ownership;
        @AuraEnabled public String source;
        @AuraEnabled public String dateType;
        @AuraEnabled public String dateRange;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
    }

    public class ExceptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String exceptionFieldName;
        @AuraEnabled public String fieldValue;
        @AuraEnabled public String exceptionMessage;
        @AuraEnabled public String source;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    @AuraEnabled(cacheable=true)
    public static ExceptionSummaryDTO getExceptionSummary() {
        ExceptionSummaryDTO dto = new ExceptionSummaryDTO();
        dto.all = 0;
        dto.consentUpload = 0;
        dto.departureUpload = 0;
        dto.reportUpload = 0;

        if (isGuestUser() || !isExceptionReadable() || !isExceptionFieldAccessible(SOURCE_FIELD)) {
            return dto;
        }

        List<String> baseWhere = buildBaseWhereClauses();
        if (baseWhere.contains('Id = NULL')) {
            return dto;
        }

        String aggregateSoql =
            'SELECT ' + SOURCE_FIELD + ' src, COUNT(Id) cnt FROM ' + OBJECT_API_NAME +
            ' WHERE ' + String.join(baseWhere, ' AND ') +
            ' GROUP BY ' + SOURCE_FIELD;

        try {
            for (AggregateResult ar : Database.query(aggregateSoql)) {
                String sourceValue = (String) ar.get('src');
                Integer countValue = Integer.valueOf(String.valueOf(ar.get('cnt')));
                dto.all += countValue;
                if (SOURCE_CONSENT_UPLOAD.equals(sourceValue)) {
                    dto.consentUpload += countValue;
                } else if (SOURCE_DEPARTURE_UPLOAD.equals(sourceValue)) {
                    dto.departureUpload += countValue;
                } else if (SOURCE_REPORT_UPLOAD.equals(sourceValue)) {
                    dto.reportUpload += countValue;
                }
            }
        } catch (Exception e) {
            return dto;
        }
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<ExceptionDTO> getExceptions(
        String statusFilter,
        String searchKey,
        String sortBy,
        String sortDirection,
        DashboardFilter filters
    ) {
        List<ExceptionDTO> rows = new List<ExceptionDTO>();
        if (isGuestUser() || !isExceptionReadable()) {
            return rows;
        }

        List<String> whereClauses = buildBaseWhereClauses();
        if (whereClauses.contains('Id = NULL')) {
            return rows;
        }

        appendSourceFilterClause(whereClauses, resolveEffectiveSourceFilter(statusFilter, filters));
        appendOwnershipClause(whereClauses, filters);
        appendDateRangeClause(whereClauses, filters);
        appendSearchClause(whereClauses, searchKey);

        String orderClause = buildOrderClause(sortBy, sortDirection);
        String soql =
            buildSelectSoql() + ' FROM ' + OBJECT_API_NAME + ' WHERE ' +
            String.join(whereClauses, ' AND ') + ' ORDER BY ' + orderClause;

        List<Exception__c> raw = Database.query(soql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, raw);
        List<Exception__c> records = (List<Exception__c>) decision.getRecords();

        Integer rowNumber = 1;
        for (Exception__c rec : records) {
            ExceptionDTO dto = new ExceptionDTO();
            dto.id = rec.Id;
            dto.rowNumber = rowNumber++;
            dto.exceptionFieldName = (String) getPopulated(rec, FLD_EXCEPTION_FIELD_NAME);
            dto.fieldValue = (String) getPopulated(rec, FLD_FIELD_VALUE);
            dto.exceptionMessage = (String) getPopulated(rec, FLD_EXCEPTION_MESSAGE);
            dto.source = (String) getPopulated(rec, SOURCE_FIELD);
            dto.createdDate = (Datetime) getPopulated(rec, 'CreatedDate');
            dto.lastModifiedDate = (Datetime) getPopulated(rec, 'LastModifiedDate');
            rows.add(dto);
        }
        return rows;
    }

    private static String buildSelectSoql() {
        return 'SELECT Id, ' + FLD_EXCEPTION_FIELD_NAME + ', ' + FLD_FIELD_VALUE + ', ' +
            FLD_EXCEPTION_MESSAGE + ', ' + SOURCE_FIELD + ', CreatedDate, LastModifiedDate, OwnerId';
    }

    private static void appendSourceFilterClause(List<String> whereClauses, String normalizedSource) {
        if (String.isBlank(normalizedSource) || 'ALL'.equals(normalizedSource)) {
            return;
        }
        if (!isExceptionFieldAccessible(SOURCE_FIELD)) {
            return;
        }
        if ('CONSENT_UPLOAD'.equals(normalizedSource)) {
            whereClauses.add(
                SOURCE_FIELD + ' = \'' + String.escapeSingleQuotes(SOURCE_CONSENT_UPLOAD) + '\''
            );
        } else if ('DEPARTURE_UPLOAD'.equals(normalizedSource)) {
            whereClauses.add(
                SOURCE_FIELD + ' = \'' + String.escapeSingleQuotes(SOURCE_DEPARTURE_UPLOAD) + '\''
            );
        } else if ('REPORT_UPLOAD'.equals(normalizedSource)) {
            whereClauses.add(
                SOURCE_FIELD + ' = \'' + String.escapeSingleQuotes(SOURCE_REPORT_UPLOAD) + '\''
            );
        }
    }

    private static String resolveEffectiveSourceFilter(String statusFilter, DashboardFilter filters) {
        if (filters != null && String.isNotBlank(filters.source)) {
            String filterSource = filters.source.trim().toUpperCase().replace(' ', '_');
            if (!'ALL'.equals(filterSource)) {
                return filterSource;
            }
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
        if (!DATE_TYPE_WHITELIST.contains(dateField) || !isExceptionFieldAccessible(dateField)) {
            return;
        }

        Schema.SObjectField dateFieldRef = Schema.SObjectType.Exception__c.fields.getMap().get(dateField);
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

    private static void appendSearchClause(List<String> whereClauses, String searchKey) {
        if (String.isBlank(searchKey)) {
            return;
        }
        String sanitized = String.escapeSingleQuotes(searchKey.trim());
        String term = '%' + sanitized + '%';
        List<String> searchParts = new List<String>();

        if (isExceptionFieldAccessible(FLD_EXCEPTION_FIELD_NAME)) {
            searchParts.add(FLD_EXCEPTION_FIELD_NAME + ' LIKE \'' + term + '\'');
        }
        if (isExceptionFieldAccessible(FLD_FIELD_VALUE)) {
            searchParts.add(FLD_FIELD_VALUE + ' LIKE \'' + term + '\'');
        }
        if (isExceptionFieldAccessible(FLD_EXCEPTION_MESSAGE)) {
            searchParts.add(FLD_EXCEPTION_MESSAGE + ' LIKE \'' + term + '\'');
        }
        if (isExceptionFieldAccessible(SOURCE_FIELD)) {
            searchParts.add(SOURCE_FIELD + ' LIKE \'' + term + '\'');
        }

        if (!searchParts.isEmpty()) {
            whereClauses.add('(' + String.join(searchParts, ' OR ') + ')');
        }
    }

    private static String buildOrderClause(String sortBy, String sortDirection) {
        String requestedSort = String.isBlank(sortBy) ? null : sortBy.trim();
        if (String.isBlank(requestedSort) || !SORTABLE_FIELDS.contains(requestedSort) || !isExceptionFieldAccessible(requestedSort)) {
            if (isExceptionFieldAccessible('CreatedDate')) {
                return 'CreatedDate DESC NULLS LAST, LastModifiedDate DESC';
            }
            return 'LastModifiedDate DESC';
        }

        String direction = 'DESC';
        if ('asc'.equalsIgnoreCase(sortDirection)) {
            direction = 'ASC';
        } else if ('desc'.equalsIgnoreCase(sortDirection)) {
            direction = 'DESC';
        }

        return requestedSort + ' ' + direction + ' NULLS LAST, LastModifiedDate DESC';
    }

    private static List<String> buildBaseWhereClauses() {
        List<String> parts = new List<String>{ 'Id != NULL' };
        appendExperienceCloudAccountScope(parts);
        return parts;
    }

    /**
     * TODO: If Exception__c has client Account lookup, add Experience Cloud user Account scope here.
     */
    private static void appendExperienceCloudAccountScope(List<String> parts) {
        if (!shouldApplyExperienceCloudScope()) {
            return;
        }

        String accountFieldApi = resolveExceptionAccountFieldApi();
        if (String.isBlank(accountFieldApi)) {
            return;
        }

        User scopedUser = [
            SELECT ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (scopedUser.ContactId == null || scopedUser.Contact.AccountId == null) {
            parts.add('Id = NULL');
            return;
        }
        parts.add(
            accountFieldApi + ' = \'' +
                String.escapeSingleQuotes(String.valueOf(scopedUser.Contact.AccountId)) +
                '\''
        );
    }

    private static String resolveExceptionAccountFieldApi() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Exception__c.fields.getMap();
        if (fieldMap.containsKey('Client_Account__c')) {
            return 'Client_Account__c';
        }
        if (fieldMap.containsKey('Account__c')) {
            return 'Account__c';
        }
        return null;
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

    private static Boolean isExceptionReadable() {
        return Schema.SObjectType.Exception__c.isAccessible();
    }

    private static Boolean isExceptionFieldAccessible(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        Schema.SObjectField fld = Schema.SObjectType.Exception__c.fields.getMap().get(fieldApiName);
        return fld != null && fld.getDescribe().isAccessible();
    }

    private static Object getPopulated(SObject recordRow, String fieldApiName) {
        if (recordRow == null || String.isBlank(fieldApiName)) {
            return null;
        }
        Map<String, Object> populated = recordRow.getPopulatedFieldsAsMap();
        if (populated.containsKey(fieldApiName)) {
            return populated.get(fieldApiName);
        }
        for (String key : populated.keySet()) {
            if (key != null && key.equalsIgnoreCase(fieldApiName)) {
                return populated.get(key);
            }
        }
        return recordRow.get(fieldApiName);
    }

    private static String formatDateLiteral(Date value) {
        return String.valueOf(value.year()) +
            '-' + String.valueOf(value.month()).leftPad(2, '0') +
            '-' + String.valueOf(value.day()).leftPad(2, '0');
    }
}