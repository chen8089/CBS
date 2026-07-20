/**
 * Departure__c dashboard for Partner Central / Experience Cloud.
 * TODO: If Departure__c has a client Account lookup, add Experience Cloud user Account scope in buildBaseWhereClauses().
 */
public with sharing class BatchDeparturesDashboardController {
    public static final String OBJECT_API_NAME = 'Departure__c';
    public static final String STATUS_FIELD = 'Consent_Status__c';
    public static final String STATUS_UPDATED_CONSENT = 'Updated Consent';
    public static final String STATUS_NO_VALID_CONSENT = 'No Valid Consent';

    private static final String FLD_EMAIL = 'Email__c';
    private static final String FLD_DEPARTURE_DATE = 'Departure_Date__c';
    private static final String FLD_BATCH_ID = 'Batch_ID__c';
    private static final String FLD_BATCH_LOOKUP = 'Batch__c';
    private static final String FLD_BATCH_LOOKUP_REL = 'Batch__r';
    private static final String FLD_BATCH_LOOKUP_NAME = 'Batch__r.Name';
    private static final String FLD_UPDATED_DATE = 'Updated_Date__c';

    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        FLD_EMAIL,
        FLD_DEPARTURE_DATE,
        FLD_BATCH_LOOKUP,
        STATUS_FIELD,
        FLD_UPDATED_DATE,
        'CreatedDate',
        'LastModifiedDate'
    };

    private static final Set<String> DATE_TYPE_WHITELIST = new Set<String>{
        FLD_DEPARTURE_DATE,
        FLD_UPDATED_DATE,
        'CreatedDate',
        'LastModifiedDate'
    };

    public class DepartureSummaryDTO {
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

    public class DepartureDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String email;
        @AuraEnabled public Date departureDate;
        @AuraEnabled public String batchId;
        @AuraEnabled public String batchName;
        @AuraEnabled public String departureStatus;
        @AuraEnabled public Date updatedDate;
    }

    @AuraEnabled(cacheable=true)
    public static DepartureSummaryDTO getDepartureSummary() {
        DepartureSummaryDTO dto = new DepartureSummaryDTO();
        dto.all = 0;
        dto.updatedConsent = 0;
        dto.noValidConsent = 0;

        if (isGuestUser() || !isDepartureReadable() || !isDepartureFieldAccessible(STATUS_FIELD)) {
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
    public static List<DepartureDTO> getDepartures(
        String statusFilter,
        String searchKey,
        String sortBy,
        String sortDirection,
        DashboardFilter filters
    ) {
        List<DepartureDTO> rows = new List<DepartureDTO>();
        if (isGuestUser() || !isDepartureReadable()) {
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

        List<Departure__c> raw = Database.query(soql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, raw);
        List<Departure__c> records = (List<Departure__c>) decision.getRecords();
        Map<Id, String> batchNameById = buildBatchNameById(records);

        Integer rowNumber = 1;
        for (Departure__c rec : records) {
            DepartureDTO dto = new DepartureDTO();
            dto.id = rec.Id;
            dto.rowNumber = rowNumber++;
            dto.email = (String) getPopulated(rec, FLD_EMAIL);
            dto.departureDate = (Date) getPopulated(rec, FLD_DEPARTURE_DATE);
            dto.batchId = getBatchDisplayValue(rec, batchNameById);
            dto.batchName = getBatchName(rec, batchNameById);
            dto.departureStatus = (String) getPopulated(rec, STATUS_FIELD);
            dto.updatedDate = (Date) getPopulated(rec, FLD_UPDATED_DATE);
            rows.add(dto);
        }
        return rows;
    }

    private static String buildSelectSoql() {
        return 'SELECT Id, ' + FLD_EMAIL + ', ' + FLD_DEPARTURE_DATE + ', ' + FLD_BATCH_ID + ', ' +
            FLD_BATCH_LOOKUP + ', ' + FLD_BATCH_LOOKUP_NAME + ', ' +
            STATUS_FIELD + ', ' + FLD_UPDATED_DATE + ', CreatedDate, LastModifiedDate, OwnerId';
    }

    private static void appendStatusFilterClause(List<String> whereClauses, String normalizedStatus) {
        if (String.isBlank(normalizedStatus) || 'ALL'.equals(normalizedStatus)) {
            return;
        }
        if ('UPDATED_CONSENT'.equals(normalizedStatus) && isDepartureFieldAccessible(STATUS_FIELD)) {
            whereClauses.add(
                STATUS_FIELD + ' = \'' + String.escapeSingleQuotes(STATUS_UPDATED_CONSENT) + '\''
            );
        } else if ('NO_VALID_CONSENT'.equals(normalizedStatus) && isDepartureFieldAccessible(STATUS_FIELD)) {
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
        if (!DATE_TYPE_WHITELIST.contains(dateField) || !isDepartureFieldAccessible(dateField)) {
            return;
        }

        Schema.SObjectField dateFieldRef = Schema.SObjectType.Departure__c.fields.getMap().get(dateField);
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

        if (isDepartureFieldAccessible(FLD_EMAIL)) {
            searchParts.add(FLD_EMAIL + ' LIKE \'' + term + '\'');
        }
        if (isDepartureFieldAccessible(FLD_BATCH_LOOKUP)) {
            searchParts.add(FLD_BATCH_LOOKUP_NAME + ' LIKE \'' + term + '\'');
        } else if (isDepartureFieldAccessible(FLD_BATCH_ID)) {
            searchParts.add(FLD_BATCH_ID + ' LIKE \'' + term + '\'');
        }
        if (isDepartureFieldAccessible(STATUS_FIELD)) {
            searchParts.add(STATUS_FIELD + ' LIKE \'' + term + '\'');
        }

        if (!searchParts.isEmpty()) {
            whereClauses.add('(' + String.join(searchParts, ' OR ') + ')');
        }
    }

    private static String buildOrderClause(String sortBy, String sortDirection) {
        String requestedSort = String.isBlank(sortBy) ? null : sortBy.trim();
        Boolean sortable = !String.isBlank(requestedSort) && SORTABLE_FIELDS.contains(requestedSort);
        if (!sortable) {
            if (isDepartureFieldAccessible(FLD_UPDATED_DATE)) {
                return FLD_UPDATED_DATE + ' DESC NULLS LAST, LastModifiedDate DESC';
            }
            return 'LastModifiedDate DESC';
        }
        if (requestedSort == FLD_BATCH_LOOKUP && !isDepartureFieldAccessible(FLD_BATCH_LOOKUP)) {
            requestedSort = FLD_UPDATED_DATE;
        } else if (requestedSort != FLD_BATCH_LOOKUP && !isDepartureFieldAccessible(requestedSort)) {
            requestedSort = FLD_UPDATED_DATE;
        }

        String direction = 'DESC';
        if ('asc'.equalsIgnoreCase(sortDirection)) {
            direction = 'ASC';
        } else if ('desc'.equalsIgnoreCase(sortDirection)) {
            direction = 'DESC';
        }

        String sortExpr = requestedSort == FLD_BATCH_LOOKUP ? FLD_BATCH_LOOKUP_NAME : requestedSort;
        return sortExpr + ' ' + direction + ' NULLS LAST, LastModifiedDate DESC';
    }

    private static String getBatchDisplayValue(Departure__c rec, Map<Id, String> batchNameById) {
        if (rec == null) {
            return null;
        }
        String batchName = getBatchName(rec, batchNameById);
        if (String.isNotBlank(batchName)) {
            return batchName;
        }
        return (String) getPopulated(rec, FLD_BATCH_ID);
    }

    private static String getBatchName(Departure__c rec, Map<Id, String> batchNameById) {
        if (rec == null) {
            return '';
        }
        try {
            SObject batchRec = rec.getSObject(FLD_BATCH_LOOKUP_REL);
            if (batchRec != null) {
                String batchName = (String) batchRec.get('Name');
                if (String.isNotBlank(batchName)) {
                    return batchName;
                }
            }
        } catch (Exception e) {
            // Relationship not available; return blank display value.
        }
        Id batchId = extractBatchId(rec);
        if (batchId != null && batchNameById != null && batchNameById.containsKey(batchId)) {
            String resolvedName = batchNameById.get(batchId);
            if (String.isNotBlank(resolvedName)) {
                return resolvedName;
            }
        }
        return '';
    }

    private static Map<Id, String> buildBatchNameById(List<Departure__c> records) {
        Map<Id, String> namesById = new Map<Id, String>();
        if (records == null || records.isEmpty()) {
            return namesById;
        }
        if (!Schema.SObjectType.Batch__c.isAccessible() ||
            !Schema.SObjectType.Batch__c.fields.Name.isAccessible()) {
            return namesById;
        }

        Set<Id> batchIds = new Set<Id>();
        for (Departure__c rec : records) {
            Id batchId = extractBatchId(rec);
            if (batchId != null) {
                batchIds.add(batchId);
            }
        }
        if (batchIds.isEmpty()) {
            return namesById;
        }

        for (Batch__c batchRec : [SELECT Id, Name FROM Batch__c WHERE Id IN :batchIds]) {
            if (String.isNotBlank(batchRec.Name)) {
                namesById.put(batchRec.Id, batchRec.Name);
            }
        }
        return namesById;
    }

    private static Id extractBatchId(Departure__c rec) {
        if (rec == null) {
            return null;
        }
        Object lookupValue = getPopulated(rec, FLD_BATCH_LOOKUP);
        if (lookupValue instanceof Id) {
            return (Id) lookupValue;
        }
        if (lookupValue instanceof String) {
            Id parsedLookupId = tryParseId((String) lookupValue);
            if (parsedLookupId != null) {
                return parsedLookupId;
            }
        }
        Object legacyValue = getPopulated(rec, FLD_BATCH_ID);
        if (legacyValue instanceof String) {
            return tryParseId((String) legacyValue);
        }
        return null;
    }

    private static Id tryParseId(String candidate) {
        if (String.isBlank(candidate)) {
            return null;
        }
        try {
            return Id.valueOf(candidate.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static List<String> buildBaseWhereClauses() {
        List<String> parts = new List<String>{ 'Id != NULL' };
        appendExperienceCloudAccountScope(parts);
        return parts;
    }

    /**
     * TODO: If Departure__c has client Account lookup, add Experience Cloud user Account scope here.
     */
    private static void appendExperienceCloudAccountScope(List<String> parts) {
        if (!shouldApplyExperienceCloudScope()) {
            return;
        }

        String accountFieldApi = resolveDepartureAccountFieldApi();
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

    private static String resolveDepartureAccountFieldApi() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Departure__c.fields.getMap();
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

    private static Boolean isDepartureReadable() {
        return Schema.SObjectType.Departure__c.isAccessible();
    }

    private static Boolean isDepartureFieldAccessible(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        Schema.SObjectField fld = Schema.SObjectType.Departure__c.fields.getMap().get(fieldApiName);
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
        try {
            return recordRow.get(fieldApiName);
        } catch (Exception e) {
            return null;
        }
    }

    private static String formatDateLiteral(Date value) {
        return String.valueOf(value.year()) +
            '-' + String.valueOf(value.month()).leftPad(2, '0') +
            '-' + String.valueOf(value.day()).leftPad(2, '0');
    }
}