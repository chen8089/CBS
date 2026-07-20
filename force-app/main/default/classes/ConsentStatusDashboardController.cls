/**
 * Consent__c status dashboard for Experience Cloud and internal apps.
 * with sharing: internal users see Consent__c per sharing; community users scoped via Data_Subject__r.AccountId when applicable.
 */
public with sharing class ConsentStatusDashboardController {
    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_DECLINED = 'Declined';
    public static final String STATUS_WITHDRAWN = 'Withdrawn';
    public static final String STATUS_REVOKED = 'Revoked';
    public static final String STATUS_EXPIRED = 'Expired';

    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        'Name',
        'Data_Subject__c',
        'Data_Subject__r.Full_Name__c',
        'Data_Subject__r.Email',
        'Data_Subject__r.ID_Type__c',
        'Data_Subject__r.ID_Number__c',
        'Data_Subject__r.Date_of_Birth__c',
        'Data_Subject__r.Employment_Status__c',
        'Consent_Status__c',
        'Action_Type__c',
        'Submitted_At__c',
        'Revoked_At__c',
        'Consent_Expiry_Date__c',
        'Match_Status__c',
        'Retention_Until__c',
        'LastModifiedDate'
    };

    private static final Set<String> CONSENT_DATE_TYPE_WHITELIST = new Set<String>{
        'CreatedDate',
        'LastModifiedDate',
        'Submitted_At__c',
        'Revoked_At__c',
        'Consent_Expiry_Date__c',
        'Retention_Until__c'
    };

    public class RecordTypeOptionDto {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
    }

    public class ConsentSummaryDto {
        @AuraEnabled public Integer totalConsents { get; set; }
        @AuraEnabled public Integer active { get; set; }
        @AuraEnabled public Integer pending { get; set; }
        @AuraEnabled public Integer declined { get; set; }
        @AuraEnabled public Integer withdrawn { get; set; }
        @AuraEnabled public Integer revoked { get; set; }
        @AuraEnabled public Integer expired { get; set; }
        @AuraEnabled public Boolean showRecordTypeFilter { get; set; }
        @AuraEnabled public List<RecordTypeOptionDto> consentRecordTypeOptions { get; set; }
    }

    public class ConsentRowDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public String consentName { get; set; }
        @AuraEnabled public Id dataSubjectId { get; set; }
        @AuraEnabled public String fullName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String idType { get; set; }
        @AuraEnabled public String idNumber { get; set; }
        @AuraEnabled public Date dateOfBirth { get; set; }
        @AuraEnabled public String employmentStatus { get; set; }
        @AuraEnabled public String consentStatus { get; set; }
        @AuraEnabled public String actionType { get; set; }
        @AuraEnabled public Datetime submittedAt { get; set; }
        @AuraEnabled public Datetime revokedAt { get; set; }
        @AuraEnabled public Date consentExpiryDate { get; set; }
        @AuraEnabled public String matchStatus { get; set; }
        @AuraEnabled public Datetime retentionUntil { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static ConsentSummaryDto getConsentSummary() {
        ConsentSummaryDto dto = new ConsentSummaryDto();
        dto.totalConsents = 0;
        dto.active = 0;
        dto.pending = 0;
        dto.declined = 0;
        dto.withdrawn = 0;
        dto.revoked = 0;
        dto.expired = 0;
        dto.showRecordTypeFilter = false;
        dto.consentRecordTypeOptions = new List<RecordTypeOptionDto>();

        if (isGuestUser()) {
            return dto;
        }
        if (!isConsentReadable() || !isConsentFieldAccessible('Consent_Status__c')) {
            return dto;
        }

        for (Schema.RecordTypeInfo ri : Consent__c.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (ri.isAvailable() && !ri.isMaster()) {
                dto.showRecordTypeFilter = true;
                RecordTypeOptionDto opt = new RecordTypeOptionDto();
                opt.label = ri.getName();
                opt.value = ri.getDeveloperName();
                dto.consentRecordTypeOptions.add(opt);
            }
        }

        String baseWhere = buildBaseWhereSoql();
        if (baseWhere == null) {
            return dto;
        }

        String aggregateSoql =
            'SELECT Consent_Status__c st, COUNT(Id) cnt FROM Consent__c WHERE ' +
            baseWhere +
            ' GROUP BY Consent_Status__c';

        try {
            for (AggregateResult ar : Database.query(aggregateSoql)) {
                Object stObj = ar.get('st');
                Object cntObj = ar.get('cnt');
                Integer c = cntObj != null ? Integer.valueOf(String.valueOf(cntObj)) : 0;
                String st = stObj != null ? String.valueOf(stObj) : null;
                dto.totalConsents += c;
                if (STATUS_ACTIVE.equals(st)) {
                    dto.active += c;
                } else if (STATUS_PENDING.equals(st)) {
                    dto.pending += c;
                } else if (STATUS_DECLINED.equals(st)) {
                    dto.declined += c;
                } else if (STATUS_WITHDRAWN.equals(st)) {
                    dto.withdrawn += c;
                } else if (STATUS_REVOKED.equals(st)) {
                    dto.revoked += c;
                } else if (STATUS_EXPIRED.equals(st)) {
                    dto.expired += c;
                }
            }
        } catch (Exception e) {
            return dto;
        }
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<ConsentRowDto> getConsents(
        String statusFilter,
        String searchKey,
        String sortBy,
        String sortDirection,
        DashboardFilter filters
    ) {
        List<ConsentRowDto> rows = new List<ConsentRowDto>();
        if (isGuestUser()) {
            return rows;
        }
        if (!isConsentReadable()) {
            return rows;
        }

        String baseWhere = buildBaseWhereSoql();
        if (baseWhere == null) {
            return rows;
        }

        List<String> filtersClauses = new List<String>{ baseWhere };

        String effectiveStatusKey = resolveEffectiveStatusFilter(statusFilter, filters);
        filtersClauses.addAll(buildStatusFilterClauses(effectiveStatusKey));

        appendOwnershipConsent(filtersClauses, filters);
        filtersClauses.addAll(buildConsentRecordTypeClause(filters));
        filtersClauses.addAll(buildConsentDateFilterClauses(filters));

        String sk = searchKey != null ? searchKey.trim() : '';
        if (String.isNotBlank(sk)) {
            String term = '%' + String.escapeSingleQuotes(sk) + '%';
            List<String> searchOr = new List<String>();
            if (isConsentFieldAccessible('Name')) {
                searchOr.add('Name LIKE \'' + term + '\'');
            }
            if (isContactFieldAccessible('Full_Name__c')) {
                searchOr.add('Data_Subject__r.Full_Name__c LIKE \'' + term + '\'');
            }
            if (isContactFieldAccessible('Email')) {
                searchOr.add('Data_Subject__r.Email LIKE \'' + term + '\'');
            }
            if (isContactFieldAccessible('ID_Number__c')) {
                searchOr.add('Data_Subject__r.ID_Number__c LIKE \'' + term + '\'');
            }
            if (searchOr.isEmpty()) {
                return rows;
            }
            filtersClauses.add('(' + String.join(searchOr, ' OR ') + ')');
        }

        String orderClause = buildOrderClause(sortBy, sortDirection);
        String selectClause = buildConsentSelectClause();

        String soql =
            'SELECT ' +
            selectClause +
            ' FROM Consent__c WHERE ' +
            String.join(filtersClauses, ' AND ') +
            ' ORDER BY ' +
            orderClause;

        List<Consent__c> consents;
        try {
            consents = Database.query(soql);
        } catch (Exception e) {
            return rows;
        }

        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, consents);
        consents = (List<Consent__c>) dec.getRecords();

        Integer n = 1;
        for (Consent__c r : consents) {
            ConsentRowDto d = new ConsentRowDto();
            d.id = r.Id;
            d.rowNumber = n++;
            d.consentName = (String) getPopulated(r, 'Name');
            d.dataSubjectId = (Id) getPopulated(r, 'Data_Subject__c');
            SObject ds = r.getSObject('Data_Subject__r');
            if (ds != null) {
                if (ds.getPopulatedFieldsAsMap().containsKey('Full_Name__c')) {
                    d.fullName = (String) ds.get('Full_Name__c');
                }
                if (ds.getPopulatedFieldsAsMap().containsKey('Email')) {
                    d.email = (String) ds.get('Email');
                }
                if (ds.getPopulatedFieldsAsMap().containsKey('ID_Type__c')) {
                    d.idType = (String) ds.get('ID_Type__c');
                }
                if (ds.getPopulatedFieldsAsMap().containsKey('ID_Number__c')) {
                    d.idNumber = (String) ds.get('ID_Number__c');
                }
                if (ds.getPopulatedFieldsAsMap().containsKey('Date_of_Birth__c')) {
                    d.dateOfBirth = (Date) ds.get('Date_of_Birth__c');
                }
                if (ds.getPopulatedFieldsAsMap().containsKey('Employment_Status__c')) {
                    d.employmentStatus = (String) ds.get('Employment_Status__c');
                }
            }
            d.consentStatus = (String) getPopulated(r, 'Consent_Status__c');
            d.actionType = (String) getPopulated(r, 'Action_Type__c');
            d.submittedAt = (Datetime) getPopulated(r, 'Submitted_At__c');
            d.revokedAt = (Datetime) getPopulated(r, 'Revoked_At__c');
            d.consentExpiryDate = (Date) getPopulated(r, 'Consent_Expiry_Date__c');
            d.matchStatus = (String) getPopulated(r, 'Match_Status__c');
            d.retentionUntil = coerceToDatetime(getPopulated(r, 'Retention_Until__c'));
            rows.add(d);
        }
        return rows;
    }

    private static String resolveEffectiveStatusFilter(String cardStatusFilter, DashboardFilter filters) {
        if (filters != null && String.isNotBlank(filters.status)) {
            String s = filters.status.trim().toUpperCase();
            if (!'ALL'.equals(s)) {
                return s;
            }
        }
        return normalizeStatusFilter(cardStatusFilter);
    }

    private static void appendOwnershipConsent(List<String> filtersClauses, DashboardFilter filters) {
        if (filters == null || String.isBlank(filters.ownership)) {
            return;
        }
        if ('MY'.equalsIgnoreCase(filters.ownership.trim())) {
            filtersClauses.add('OwnerId = \'' + String.escapeSingleQuotes(String.valueOf(UserInfo.getUserId())) + '\'');
        }
    }

    private static List<String> buildConsentRecordTypeClause(DashboardFilter filters) {
        List<String> parts = new List<String>();
        if (filters == null || String.isBlank(filters.recordType) || 'ALL'.equalsIgnoreCase(filters.recordType.trim())) {
            return parts;
        }
        String req = filters.recordType.trim();
        Set<String> allowed = new Set<String>();
        for (Schema.RecordTypeInfo ri : Consent__c.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (ri.isAvailable() && !ri.isMaster()) {
                allowed.add(ri.getDeveloperName());
            }
        }
        if (!allowed.contains(req)) {
            return parts;
        }
        parts.add('RecordType.DeveloperName = \'' + String.escapeSingleQuotes(req) + '\'');
        return parts;
    }

    private static List<String> buildConsentDateFilterClauses(DashboardFilter filters) {
        List<String> out = new List<String>();
        if (filters == null || String.isBlank(filters.dateType) || filters.startDate == null || filters.endDate == null) {
            return out;
        }
        if (filters.endDate < filters.startDate) {
            return out;
        }
        String api = filters.dateType.trim();
        if (!CONSENT_DATE_TYPE_WHITELIST.contains(api)) {
            return out;
        }
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Consent__c.fields.getMap();
        Schema.SObjectField fld = fm.get(api);
        if (fld == null || !fld.getDescribe().isAccessible()) {
            return out;
        }
        Schema.DisplayType dt = fld.getDescribe().getType();
        if (dt == Schema.DisplayType.DATE) {
            out.add(
                api +
                    ' >= ' +
                    formatSoqlDateLiteral(filters.startDate) +
                    ' AND ' +
                    api +
                    ' <= ' +
                    formatSoqlDateLiteral(filters.endDate)
            );
        } else {
            String rangeClause = buildDatetimeDayRangeClause(api, filters.startDate, filters.endDate);
            if (rangeClause != null) {
                out.add(rangeClause);
            }
        }
        return out;
    }

    private static String formatSoqlDateLiteral(Date d) {
        return String.valueOf(d.year()) +
            '-' +
            String.valueOf(d.month()).leftPad(2, '0') +
            '-' +
            String.valueOf(d.day()).leftPad(2, '0');
    }

    private static String buildDatetimeDayRangeClause(String fieldApi, Date startDate, Date endDate) {
        String s = formatSoqlDateLiteral(startDate);
        String eNext = formatSoqlDateLiteral(endDate.addDays(1));
        return fieldApi + ' >= ' + s + 'T00:00:00.000Z AND ' + fieldApi + ' < ' + eNext + 'T00:00:00.000Z';
    }

    private static Object getPopulated(SObject rec, String apiName) {
        if (rec == null || String.isBlank(apiName)) {
            return null;
        }
        Map<String, Object> populated = rec.getPopulatedFieldsAsMap();
        return populated.containsKey(apiName) ? populated.get(apiName) : null;
    }

    private static Datetime coerceToDatetime(Object fieldVal) {
        if (fieldVal == null) {
            return null;
        }
        if (fieldVal instanceof Datetime) {
            return (Datetime) fieldVal;
        }
        if (fieldVal instanceof Date) {
            return Datetime.newInstance((Date) fieldVal, Time.newInstance(0, 0, 0, 0));
        }
        return null;
    }

    private static String buildConsentSelectClause() {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Consent__c.fields.getMap();
        List<String> parts = new List<String>{
            'Id',
            'Name',
            'Data_Subject__c',
            'Consent_Status__c',
            'Action_Type__c',
            'Submitted_At__c',
            'Revoked_At__c',
            'LastModifiedDate'
        };
        addFieldIfPresent(fm, parts, 'Consent_Expiry_Date__c');
        addFieldIfPresent(fm, parts, 'Match_Status__c');
        addFieldIfPresent(fm, parts, 'Retention_Until__c');
        parts.add(
            'Data_Subject__r.Full_Name__c, Data_Subject__r.Email, Data_Subject__r.ID_Type__c, ' +
            'Data_Subject__r.ID_Number__c, Data_Subject__r.Date_of_Birth__c, Data_Subject__r.Employment_Status__c'
        );
        return String.join(parts, ', ');
    }

    private static void addFieldIfPresent(Map<String, Schema.SObjectField> fm, List<String> parts, String api) {
        if (fm.containsKey(api)) {
            parts.add(api);
        }
    }

    private static Boolean isGuestUser() {
        return 'Guest'.equals(UserInfo.getUserType());
    }

    private static Boolean isConsentReadable() {
        return Schema.SObjectType.Consent__c.isAccessible();
    }

    private static Boolean isConsentFieldAccessible(String apiName) {
        if (String.isBlank(apiName)) {
            return false;
        }
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Consent__c.fields.getMap();
        Schema.SObjectField f = fm.get(apiName);
        return f != null && f.getDescribe().isAccessible();
    }

    private static Boolean isContactFieldAccessible(String apiName) {
        if (String.isBlank(apiName)) {
            return false;
        }
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        Schema.SObjectField f = fm.get(apiName);
        return f != null && f.getDescribe().isAccessible();
    }

    private static Boolean shouldApplyAccountScope() {
        if (Network.getNetworkId() == null) {
            return false;
        }
        String ut = UserInfo.getUserType();
        if ('Standard'.equals(ut) || 'AutomatedProcess'.equals(ut)) {
            return false;
        }
        return true;
    }

    private static Id resolveScopedAccountId() {
        User u = [
            SELECT AccountId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (u.AccountId != null) {
            return u.AccountId;
        }
        if (u.Contact != null && u.Contact.AccountId != null) {
            return u.Contact.AccountId;
        }
        return null;
    }

    private static String buildBaseWhereSoql() {
        List<String> parts = new List<String>();
        if (shouldApplyAccountScope()) {
            Id accId = resolveScopedAccountId();
            if (accId == null) {
                parts.add('Id = NULL');
            } else {
                parts.add('Data_Subject__r.AccountId = \'' + String.valueOf(accId) + '\'');
            }
        } else {
            parts.add('Id != NULL');
        }
        return String.join(parts, ' AND ');
    }

    private static String normalizeStatusFilter(String statusFilter) {
        if (String.isBlank(statusFilter)) {
            return 'ALL';
        }
        return statusFilter.trim().toUpperCase();
    }

    private static List<String> buildStatusFilterClauses(String normalized) {
        List<String> extra = new List<String>();
        if ('ACTIVE'.equals(normalized)) {
            extra.add('Consent_Status__c = \'' + String.escapeSingleQuotes(STATUS_ACTIVE) + '\'');
        } else if ('PENDING'.equals(normalized)) {
            extra.add('Consent_Status__c = \'' + String.escapeSingleQuotes(STATUS_PENDING) + '\'');
        } else if ('DECLINED'.equals(normalized)) {
            extra.add('Consent_Status__c = \'' + String.escapeSingleQuotes(STATUS_DECLINED) + '\'');
        } else if ('WITHDRAWN'.equals(normalized)) {
            extra.add('Consent_Status__c = \'' + String.escapeSingleQuotes(STATUS_WITHDRAWN) + '\'');
        } else if ('REVOKED'.equals(normalized)) {
            extra.add('Consent_Status__c = \'' + String.escapeSingleQuotes(STATUS_REVOKED) + '\'');
        } else if ('EXPIRED'.equals(normalized)) {
            extra.add('Consent_Status__c = \'' + String.escapeSingleQuotes(STATUS_EXPIRED) + '\'');
        }
        return extra;
    }

    private static String buildOrderClause(String sortBy, String sortDirection) {
        String field = String.isBlank(sortBy) ? null : sortBy.trim();
        if (field == null || !SORTABLE_FIELDS.contains(field)) {
            return 'Submitted_At__c DESC NULLS LAST, LastModifiedDate DESC';
        }
        String dir = 'ASC';
        if (!String.isBlank(sortDirection) && 'desc'.equalsIgnoreCase(sortDirection.trim())) {
            dir = 'DESC';
        } else if (!String.isBlank(sortDirection) && 'asc'.equalsIgnoreCase(sortDirection.trim())) {
            dir = 'ASC';
        }
        if ('Submitted_At__c'.equals(field)) {
            return field + ' ' + dir + ' NULLS LAST, LastModifiedDate ' + dir;
        }
        return field + ' ' + dir + ', LastModifiedDate DESC';
    }
}