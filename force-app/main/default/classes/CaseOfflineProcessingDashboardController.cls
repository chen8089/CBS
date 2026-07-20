/**
 * Reports__c dashboard for Partner Central / Experience Cloud.
 * TODO: If Reports__c has a client Account lookup, add Experience Cloud user Account scope in buildBaseWhereClauses().
 */
public with sharing class CaseOfflineProcessingDashboardController {
    public static final String OBJECT_API_NAME = 'Reports__c';
    public static final String STATUS_FIELD = 'Consent_Status__c';
    public static final String STATUS_UPDATED_CONSENT = 'Updated Consent';
    public static final String STATUS_NO_VALID_CONSENT = 'No Valid Consent';

    private static final String FLD_EMAIL = 'Email__c';
    private static final String FLD_BATCH_ID = 'Batch_ID__c';
    private static final String FLD_UPDATED_DATE = 'Updated_Date__c';

    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        FLD_EMAIL,
        FLD_BATCH_ID,
        STATUS_FIELD,
        FLD_UPDATED_DATE,
        'CreatedDate',
        'LastModifiedDate'
    };

    private static final Set<String> DATE_TYPE_WHITELIST = new Set<String>{
        FLD_UPDATED_DATE,
        'CreatedDate',
        'LastModifiedDate'
    };

    public class ReportSummaryDTO {
        @AuraEnabled public Integer all;
        @AuraEnabled public Integer updatedConsent;
        @AuraEnabled public Integer noValidConsent;
    }

    public class DashboardFilter {
        @AuraEnabled public String ownership;
        @AuraEnabled public String status;
        @AuraEnabled public String dateType;
        @AuraEnabled public String dateRange;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
    }

    public class ReportDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String email;
        @AuraEnabled public String batchId;
        @AuraEnabled public String consentStatus;
        @AuraEnabled public Date updatedDate;
    }

    @AuraEnabled(cacheable=true)
    public static ReportSummaryDTO getReportSummary() {
        ReportSummaryDTO dto = new ReportSummaryDTO();
        dto.all = 0;
        dto.updatedConsent = 0;
        dto.noValidConsent = 0;

        if (isGuestUser() || !isReportReadable() || !isReportFieldAccessible(STATUS_FIELD)) {
            return dto;
        }

        List<String> baseWhere = buildBaseWhereClauses();
        if (baseWhere.contains('Id = NULL')) {
            return dto;
        }

        String base = String.join(baseWhere, ' AND ');
        String aggregateSoql =
            'SELECT ' + STATUS_FIELD + ' st, COUNT(Id) cnt FROM ' + OBJECT_API_NAME +
            ' WHERE ' + base + ' GROUP BY ' + STATUS_FIELD;

        try {
            for (AggregateResult ar : Database.query(aggregateSoql)) {
                String statusValue = (String) ar.get('st');
                Integer countValue = Integer.valueOf(String.valueOf(ar.get('cnt')));
                dto.all += countValue;
                if (STATUS_UPDATED_CONSENT.equals(statusValue)) {
                    dto.updatedConsent += countValue;
                } else if (STATUS_NO_VALID_CONSENT.equals(statusValue)) {
                    dto.noValidConsent += countValue;
                }
            }
        } catch (Exception e) {
            return dto;
        }
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<ReportDTO> getReports(
        String statusFilter,
        String searchKey,
        String sortBy,
        String sortDirection,
        DashboardFilter filters
    ) {
        List<ReportDTO> rows = new List<ReportDTO>();
        if (isGuestUser() || !isReportReadable()) {
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
            buildSelectSoql() + ' FROM ' + OBJECT_API_NAME + ' WHERE ' +
            String.join(whereClauses, ' AND ') + ' ORDER BY ' + orderClause;

        List<Reports__c> raw = Database.query(soql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, raw);
        List<Reports__c> records = (List<Reports__c>) decision.getRecords();

        Integer rowNumber = 1;
        for (Reports__c rec : records) {
            ReportDTO dto = new ReportDTO();
            dto.id = rec.Id;
            dto.rowNumber = rowNumber++;
            dto.email = (String) getPopulated(rec, FLD_EMAIL);
            dto.batchId = (String) getPopulated(rec, FLD_BATCH_ID);
            dto.consentStatus = (String) getPopulated(rec, STATUS_FIELD);
            dto.updatedDate = (Date) getPopulated(rec, FLD_UPDATED_DATE);
            rows.add(dto);
        }
        return rows;
    }

    private static String buildSelectSoql() {
        return 'SELECT Id, ' + FLD_EMAIL + ', ' + FLD_BATCH_ID + ', ' + STATUS_FIELD + ', ' +
            FLD_UPDATED_DATE + ', CreatedDate, LastModifiedDate, OwnerId';
    }

    private static void appendStatusFilterClause(List<String> whereClauses, String normalizedStatus) {
        if (String.isBlank(normalizedStatus) || 'ALL'.equals(normalizedStatus)) {
            return;
        }
        if ('UPDATED_CONSENT'.equals(normalizedStatus) && isReportFieldAccessible(STATUS_FIELD)) {
            whereClauses.add(
                STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_UPDATED_CONSENT) + '\''
            );
        } else if ('NO_VALID_CONSENT'.equals(normalizedStatus) && isReportFieldAccessible(STATUS_FIELD)) {
            whereClauses.add(
                STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_NO_VALID_CONSENT) + '\''
            );
        }
    }

    private static String resolveEffectiveStatusFilter(String statusFilter, DashboardFilter filters) {
        if (filters != null && String.isNotBlank(filters.status)) {
            String filterStatus = filters.status.trim().toUpperCase().replace(' ', '_');
            if (!'ALL'.equals(filterStatus)) {
                return filterStatus;
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
        if (!DATE_TYPE_WHITELIST.contains(dateField) || !isReportFieldAccessible(dateField)) {
            return;
        }

        Schema.SObjectField dateFieldRef = Schema.SObjectType.Reports__c.fields.getMap().get(dateField);
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

        if (isReportFieldAccessible(FLD_EMAIL)) {
            searchParts.add(FLD_EMAIL + ' LIKE \'' + term + '\'');
        }
        if (isReportFieldAccessible(FLD_BATCH_ID)) {
            searchParts.add(FLD_BATCH_ID + ' LIKE \'' + term + '\'');
        }
        if (isReportFieldAccessible(STATUS_FIELD)) {
            searchParts.add(STATUS_FIELD + ' LIKE \'' + term + '\'');
        }

        if (!searchParts.isEmpty()) {
            whereClauses.add('(' + String.join(searchParts, ' OR ') + ')');
        }
    }

    private static String buildOrderClause(String sortBy, String sortDirection) {
        String requestedSort = String.isBlank(sortBy) ? null : sortBy.trim();
        if (String.isBlank(requestedSort) || !SORTABLE_FIELDS.contains(requestedSort) || !isReportFieldAccessible(requestedSort)) {
            if (isReportFieldAccessible(FLD_UPDATED_DATE)) {
                return FLD_UPDATED_DATE + ' DESC NULLS LAST, LastModifiedDate DESC';
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
     * TODO: If Reports__c has client Account lookup, add Experience Cloud user Account scope here.
     */
    private static void appendExperienceCloudAccountScope(List<String> parts) {
        if (!shouldApplyExperienceCloudScope()) {
            return;
        }

        String accountFieldApi = resolveReportAccountFieldApi();
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

    private static String resolveReportAccountFieldApi() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Reports__c.fields.getMap();
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

    private static Boolean isReportReadable() {
        return Schema.SObjectType.Reports__c.isAccessible();
    }

    private static Boolean isReportFieldAccessible(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        Schema.SObjectField fld = Schema.SObjectType.Reports__c.fields.getMap().get(fieldApiName);
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