/**
 * Data Subject dashboard using Contact lifecycle stage, authentication type, and consent type card filters.
 */
public with sharing class DataSubjectConsentDashboardController {
    private static final String FILTER_ALL = 'ALL';
    private static final String CARD_ALL = 'ALL';
    private static final String CARD_STAGE_INTAKE = 'STAGE_INTAKE';
    private static final String CARD_STAGE_CONSENT_REQUEST = 'STAGE_CONSENT_REQUEST';
    private static final String CARD_STAGE_AWAITING_ACTION = 'STAGE_AWAITING_ACTION';
    private static final String CARD_STAGE_ACTIVE_CONSENT = 'STAGE_ACTIVE_CONSENT';
    private static final String CARD_STAGE_CONSENT_DECLINED = 'STAGE_CONSENT_DECLINED';
    private static final String CARD_STAGE_CONSENT_EXCEPTION = 'STAGE_CONSENT_EXCEPTION';
    private static final String CARD_STAGE_CONSENT_WITHDRAWN = 'STAGE_CONSENT_WITHDRAWN';
    private static final String CARD_STAGE_CONSENT_EXPIRED = 'STAGE_CONSENT_EXPIRED';
    private static final String CARD_STAGE_REPORT_REQUEST = 'STAGE_REPORT_REQUEST';
    private static final String CARD_STAGE_REPORT_FULFILMENT = 'STAGE_REPORT_FULFILMENT';
    private static final String CARD_STAGE_EXPIRED_CONSUMED = 'STAGE_EXPIRED_CONSUMED';
    private static final String CARD_STAGE_DEPARTURE = 'DEPARTURE';
    private static final String CARD_AUTH_SINGPASS = 'AUTH_SINGPASS';
    private static final String CARD_AUTH_NON_SINGPASS = 'AUTH_NON_SINGPASS';
    private static final String CARD_CONSENT_TYPE_PER_REPORT = 'CONSENT_TYPE_PER_REPORT';
    private static final String CARD_CONSENT_TYPE_TERM_BASED = 'CONSENT_TYPE_TERM_BASED';

    private static final String FLD_LIFECYCLE_STAGE = 'Data_Subject_Lifecycle_Stage__c';
    private static final String FLD_AUTHENTICATION_TYPE = 'Authentication_Type__c';
    private static final String FLD_CONSENT_TYPE = 'Consent_Type__c';
    private static final String FLD_LAST_MATCH_STATUS = 'Last_Match_Status__c';
    private static final String FLD_REPORT = 'Report__c';
    private static final String FLD_LAST_ACTIVITY_DATE = 'Last_Activity_Date__c';

    private static final String AUTH_SINGPASS = 'Singpass';
    private static final String AUTH_NON_SINGPASS = 'Non-Singpass';
    private static final String RT_SINGPASS = 'Singpass';
    private static final String RT_NON_SINGPASS = 'Non_Singpass';
    private static final String CONSENT_PER_REPORT = 'Per-Report Consent';
    private static final String CONSENT_TERM_BASED = 'Term-Based Consent';

    private static final String STAGE_INTAKE = 'Upload';
    private static final String STAGE_CONSENT_REQUEST = 'Consent Request';
    private static final String STAGE_AWAITING_ACTION = 'Awaiting Data Subject Action';
    private static final String STAGE_ACTIVE_CONSENT = 'Active Consent';
    private static final String STAGE_DECLINED = 'Consent Declined';
    private static final String STAGE_PROCESSING = 'Processing';
    private static final String STAGE_WITHDRAWN = 'Consent Withdrawn';
    private static final String STAGE_EXPIRED = 'Consent Expired';
    private static final String STAGE_REPORT_REQUEST = 'Report Request';
    private static final String STAGE_REPORT_FULFILMENT = 'Report Fulfilment';
    private static final String STAGE_EXPIRED_CONSUMED = 'Consumed';
    private static final String STAGE_DEPARTURE = 'Departure';

    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        'Full_Name__c',
        'Email',
        'ID_Type__c',
        'ID_Number__c',
        'Date_of_Birth__c',
        'Employment_Status__c',
        FLD_LIFECYCLE_STAGE,
        FLD_AUTHENTICATION_TYPE,
        FLD_CONSENT_TYPE,
        FLD_LAST_MATCH_STATUS,
        FLD_REPORT,
        'CreatedDate',
        FLD_LAST_ACTIVITY_DATE
    };

    private static final Set<String> CONTACT_DATE_TYPE_WHITELIST = new Set<String>{
        'CreatedDate',
        'LastModifiedDate',
        'Latest_Submission_Datetime__c',
        'Current_Consent_Expiry_Date__c'
    };

    public class ConsentSummaryDto {
        @AuraEnabled public Integer all { get; set; }
        @AuraEnabled public Integer intake { get; set; }
        @AuraEnabled public Integer consentRequest { get; set; }
        @AuraEnabled public Integer awaitingAction { get; set; }
        @AuraEnabled public Integer activeConsent { get; set; }
        @AuraEnabled public Integer declined { get; set; }
        @AuraEnabled public Integer exceptionCount { get; set; }
        @AuraEnabled public Integer withdrawn { get; set; }
        @AuraEnabled public Integer expired { get; set; }
        @AuraEnabled public Integer reportRequest { get; set; }
        @AuraEnabled public Integer reportFulfilment { get; set; }
        @AuraEnabled public Integer expiredConsumed { get; set; }
        @AuraEnabled public Integer departureCount { get; set; }
        @AuraEnabled public Integer singpass { get; set; }
        @AuraEnabled public Integer nonSingpass { get; set; }
        @AuraEnabled public Integer perReportConsent { get; set; }
        @AuraEnabled public Integer termBasedConsent { get; set; }
    }

    public class DataSubjectRowDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public String fullName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String idType { get; set; }
        @AuraEnabled public String idNumber { get; set; }
        @AuraEnabled public Date dateOfBirth { get; set; }
        @AuraEnabled public String employmentStatus { get; set; }
        @AuraEnabled public String lifecycleStage { get; set; }
        @AuraEnabled public String authenticationType { get; set; }
        @AuraEnabled public String consentType { get; set; }
        @AuraEnabled public String lastMatchStatus { get; set; }
        @AuraEnabled public String report { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public Date lastActivityDate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static ConsentSummaryDto getConsentSummary() {
        ConsentSummaryDto dto = initSummaryDto();
        if (isGuestUser() || !isContactReadable()) {
            return dto;
        }

        String baseWhere = buildBaseWhereSoql();
        if (baseWhere == null) {
            return dto;
        }

        try {
            dto.all = Database.countQuery('SELECT COUNT() FROM Contact WHERE ' + baseWhere);
        } catch (Exception e) {
            return dto;
        }

        if (isLifecycleStageReadable()) {
            String lifecycleAggregateSoql =
                'SELECT ' + FLD_LIFECYCLE_STAGE + ' st, COUNT(Id) cnt ' +
                'FROM Contact WHERE ' + baseWhere +
                ' GROUP BY ' + FLD_LIFECYCLE_STAGE;
            try {
                for (AggregateResult ar : Database.query(lifecycleAggregateSoql)) {
                    String stage = ar.get('st') == null ? null : String.valueOf(ar.get('st'));
                    Integer c = ar.get('cnt') == null ? 0 : Integer.valueOf(String.valueOf(ar.get('cnt')));
                    applyLifecycleStageCount(dto, stage, c);
                }
            } catch (Exception e) {
                return dto;
            }
        }

        if (isContactFieldAccessible(FLD_AUTHENTICATION_TYPE)) {
            String authAggregateSoql =
                'SELECT ' + FLD_AUTHENTICATION_TYPE + ' authType, COUNT(Id) cnt ' +
                'FROM Contact WHERE ' + baseWhere +
                ' GROUP BY ' + FLD_AUTHENTICATION_TYPE;
            try {
                for (AggregateResult ar : Database.query(authAggregateSoql)) {
                    String authType = ar.get('authType') == null ? null : String.valueOf(ar.get('authType'));
                    Integer c = ar.get('cnt') == null ? 0 : Integer.valueOf(String.valueOf(ar.get('cnt')));
                    if (AUTH_SINGPASS.equals(authType)) {
                        dto.singpass += c;
                    } else if (AUTH_NON_SINGPASS.equals(authType)) {
                        dto.nonSingpass += c;
                    }
                }
            } catch (Exception e) {
                return dto;
            }
        }

        if (isContactFieldAccessible(FLD_CONSENT_TYPE)) {
            String consentAggregateSoql =
                'SELECT ' + FLD_CONSENT_TYPE + ' consentType, COUNT(Id) cnt ' +
                'FROM Contact WHERE ' + baseWhere +
                ' GROUP BY ' + FLD_CONSENT_TYPE;
            try {
                for (AggregateResult ar : Database.query(consentAggregateSoql)) {
                    String consentType = ar.get('consentType') == null ? null : String.valueOf(ar.get('consentType'));
                    Integer c = ar.get('cnt') == null ? 0 : Integer.valueOf(String.valueOf(ar.get('cnt')));
                    if (CONSENT_PER_REPORT.equals(consentType)) {
                        dto.perReportConsent += c;
                    } else if (CONSENT_TERM_BASED.equals(consentType)) {
                        dto.termBasedConsent += c;
                    }
                }
            } catch (Exception e) {
                return dto;
            }
        }

        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<DataSubjectRowDto> getDataSubjects(
        String selectedCardValue,
        String searchKey,
        String sortBy,
        String sortDirection,
        DashboardFilter filters
    ) {
        List<DataSubjectRowDto> rows = new List<DataSubjectRowDto>();
        if (isGuestUser() || !isContactReadable()) {
            return rows;
        }

        String baseWhere = buildBaseWhereSoql();
        if (baseWhere == null) {
            return rows;
        }

        List<String> filtersClauses = new List<String>{ baseWhere };
        filtersClauses.addAll(buildSelectedCardFilterClauses(selectedCardValue, filters));
        appendOwnershipContact(filtersClauses, filters);
        filtersClauses.addAll(buildContactDateFilterClauses(filters));

        String sk = searchKey != null ? searchKey.trim() : '';
        if (String.isNotBlank(sk)) {
            List<String> searchOr = buildSearchOrClauses(sk);
            if (searchOr.isEmpty()) {
                return rows;
            }
            filtersClauses.add('(' + String.join(searchOr, ' OR ') + ')');
        }

        String soql =
            buildContactSelectSoqlPrefix() +
            ' FROM Contact WHERE ' +
            String.join(filtersClauses, ' AND ') +
            ' ORDER BY ' +
            buildOrderClause(sortBy, sortDirection);

        List<Contact> contacts;
        try {
            contacts = Database.query(soql);
        } catch (Exception e) {
            return rows;
        }

        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, contacts);
        contacts = (List<Contact>) dec.getRecords();

        Integer n = 1;
        for (Contact c : contacts) {
            rows.add(mapContactToDto(c, n++));
        }
        return rows;
    }

    private static List<String> buildSelectedCardFilterClauses(String selectedCardValue, DashboardFilter filters) {
        List<String> clauses = new List<String>();
        String normalizedCard = normalizeSelectedCardValue(selectedCardValue);

        if (!CARD_ALL.equals(normalizedCard)) {
            String lifecycleValue = resolveLifecycleStageForCard(normalizedCard);
            if (String.isNotBlank(lifecycleValue) && isLifecycleStageReadable()) {
                clauses.add(
                    FLD_LIFECYCLE_STAGE + ' = \'' + String.escapeSingleQuotes(lifecycleValue) + '\''
                );
                return clauses;
            }

            String authValue = resolveAuthenticationTypeForCard(normalizedCard);
            if (String.isNotBlank(authValue) && isContactFieldAccessible(FLD_AUTHENTICATION_TYPE)) {
                clauses.add(
                    FLD_AUTHENTICATION_TYPE + ' = \'' + String.escapeSingleQuotes(authValue) + '\''
                );
                return clauses;
            }

            String consentValue = resolveConsentTypeForCard(normalizedCard);
            if (String.isNotBlank(consentValue) && isContactFieldAccessible(FLD_CONSENT_TYPE)) {
                clauses.add(
                    FLD_CONSENT_TYPE + ' = \'' + String.escapeSingleQuotes(consentValue) + '\''
                );
            }
            return clauses;
        }

        appendSupplementalFilterClauses(clauses, filters);
        return clauses;
    }

    private static void appendSupplementalFilterClauses(List<String> clauses, DashboardFilter filters) {
        if (filters == null) {
            return;
        }

        if (String.isNotBlank(filters.status) && !FILTER_ALL.equalsIgnoreCase(filters.status.trim())) {
            String lifecycleFilter = resolveLifecycleStageFilterValue(filters.status);
            if (String.isNotBlank(lifecycleFilter) && isLifecycleStageReadable()) {
                clauses.add(
                    FLD_LIFECYCLE_STAGE + ' = \'' + String.escapeSingleQuotes(lifecycleFilter) + '\''
                );
            }
        }

        if (
            String.isNotBlank(filters.authenticationType) &&
            !FILTER_ALL.equalsIgnoreCase(filters.authenticationType.trim()) &&
            isContactFieldAccessible(FLD_AUTHENTICATION_TYPE)
        ) {
            clauses.add(
                FLD_AUTHENTICATION_TYPE +
                    ' = \'' +
                    String.escapeSingleQuotes(filters.authenticationType.trim()) +
                    '\''
            );
        }

        if (
            String.isNotBlank(filters.consentType) &&
            !FILTER_ALL.equalsIgnoreCase(filters.consentType.trim()) &&
            isContactFieldAccessible(FLD_CONSENT_TYPE)
        ) {
            clauses.add(
                FLD_CONSENT_TYPE + ' = \'' + String.escapeSingleQuotes(filters.consentType.trim()) + '\''
            );
        }
    }

    private static String normalizeSelectedCardValue(String selectedCardValue) {
        if (String.isBlank(selectedCardValue)) {
            return CARD_ALL;
        }
        if ('AUTH_NON_PASS'.equalsIgnoreCase(selectedCardValue.trim())) {
            return CARD_AUTH_NON_SINGPASS;
        }
        return selectedCardValue.trim().toUpperCase();
    }

    private static String resolveLifecycleStageForCard(String normalizedCard) {
        if (CARD_STAGE_INTAKE.equals(normalizedCard)) {
            return STAGE_INTAKE;
        }
        if (CARD_STAGE_CONSENT_REQUEST.equals(normalizedCard)) {
            return STAGE_CONSENT_REQUEST;
        }
        if (CARD_STAGE_AWAITING_ACTION.equals(normalizedCard)) {
            return STAGE_AWAITING_ACTION;
        }
        if (CARD_STAGE_ACTIVE_CONSENT.equals(normalizedCard)) {
            return STAGE_ACTIVE_CONSENT;
        }
        if (CARD_STAGE_CONSENT_DECLINED.equals(normalizedCard)) {
            return STAGE_DECLINED;
        }
        if (CARD_STAGE_CONSENT_EXCEPTION.equals(normalizedCard)) {
            return STAGE_PROCESSING;
        }
        if (CARD_STAGE_CONSENT_WITHDRAWN.equals(normalizedCard)) {
            return STAGE_WITHDRAWN;
        }
        if (CARD_STAGE_CONSENT_EXPIRED.equals(normalizedCard)) {
            return STAGE_EXPIRED;
        }
        if (CARD_STAGE_REPORT_REQUEST.equals(normalizedCard)) {
            return STAGE_REPORT_REQUEST;
        }
        if (CARD_STAGE_REPORT_FULFILMENT.equals(normalizedCard)) {
            return STAGE_REPORT_FULFILMENT;
        }
        if (CARD_STAGE_EXPIRED_CONSUMED.equals(normalizedCard)) {
            return STAGE_EXPIRED_CONSUMED;
        }
        if (CARD_STAGE_DEPARTURE.equals(normalizedCard)) {
            return STAGE_DEPARTURE;
        }
        return null;
    }

    private static String resolveAuthenticationTypeForCard(String normalizedCard) {
        if (CARD_AUTH_SINGPASS.equals(normalizedCard)) {
            return AUTH_SINGPASS;
        }
        if (CARD_AUTH_NON_SINGPASS.equals(normalizedCard)) {
            return AUTH_NON_SINGPASS;
        }
        return null;
    }

    private static String resolveConsentTypeForCard(String normalizedCard) {
        if (CARD_CONSENT_TYPE_PER_REPORT.equals(normalizedCard)) {
            return CONSENT_PER_REPORT;
        }
        if (CARD_CONSENT_TYPE_TERM_BASED.equals(normalizedCard)) {
            return CONSENT_TERM_BASED;
        }
        return null;
    }

    private static void applyLifecycleStageCount(ConsentSummaryDto dto, String stage, Integer c) {
        if (STAGE_INTAKE.equals(stage)) {
            dto.intake += c;
        } else if (STAGE_CONSENT_REQUEST.equals(stage)) {
            dto.consentRequest += c;
        } else if (STAGE_AWAITING_ACTION.equals(stage)) {
            dto.awaitingAction += c;
        } else if (STAGE_ACTIVE_CONSENT.equals(stage)) {
            dto.activeConsent += c;
        } else if (STAGE_DECLINED.equals(stage)) {
            dto.declined += c;
        } else if (STAGE_PROCESSING.equals(stage)) {
            dto.exceptionCount += c;
        } else if (STAGE_WITHDRAWN.equals(stage)) {
            dto.withdrawn += c;
        } else if (STAGE_EXPIRED.equals(stage)) {
            dto.expired += c;
        } else if (STAGE_REPORT_REQUEST.equals(stage)) {
            dto.reportRequest += c;
        } else if (STAGE_REPORT_FULFILMENT.equals(stage)) {
            dto.reportFulfilment += c;
        } else if (STAGE_EXPIRED_CONSUMED.equals(stage)) {
            dto.expiredConsumed += c;
        } else if (STAGE_DEPARTURE.equals(stage)) {
            dto.departureCount += c;
        }
    }

    private static String resolveLifecycleStageFilterValue(String lifecycleStageFilter) {
        if (String.isBlank(lifecycleStageFilter)) {
            return null;
        }
        String trimmed = lifecycleStageFilter.trim();
        if (FILTER_ALL.equalsIgnoreCase(trimmed)) {
            return null;
        }
        if (trimmed.contains(' ')) {
            return trimmed;
        }

        String normalized = trimmed.toUpperCase();
        if ('INTAKE'.equals(normalized) || 'UPLOAD'.equals(normalized) || CARD_STAGE_INTAKE.equals(normalized)) {
            return STAGE_INTAKE;
        }
        if ('CONSENT_REQUEST'.equals(normalized) || CARD_STAGE_CONSENT_REQUEST.equals(normalized)) {
            return STAGE_CONSENT_REQUEST;
        }
        if ('AWAITING_ACTION'.equals(normalized) || CARD_STAGE_AWAITING_ACTION.equals(normalized)) {
            return STAGE_AWAITING_ACTION;
        }
        if ('ACTIVE_CONSENT'.equals(normalized) || CARD_STAGE_ACTIVE_CONSENT.equals(normalized)) {
            return STAGE_ACTIVE_CONSENT;
        }
        if ('DECLINED'.equals(normalized) || CARD_STAGE_CONSENT_DECLINED.equals(normalized)) {
            return STAGE_DECLINED;
        }
        if (
            'EXCEPTION'.equals(normalized) ||
            'PROCESSING'.equals(normalized) ||
            CARD_STAGE_CONSENT_EXCEPTION.equals(normalized)
        ) {
            return STAGE_PROCESSING;
        }
        if ('WITHDRAWN'.equals(normalized) || CARD_STAGE_CONSENT_WITHDRAWN.equals(normalized)) {
            return STAGE_WITHDRAWN;
        }
        if ('EXPIRED'.equals(normalized) || CARD_STAGE_CONSENT_EXPIRED.equals(normalized)) {
            return STAGE_EXPIRED;
        }
        if ('REPORT_REQUEST'.equals(normalized) || CARD_STAGE_REPORT_REQUEST.equals(normalized)) {
            return STAGE_REPORT_REQUEST;
        }
        if ('REPORT_FULFILMENT'.equals(normalized) || CARD_STAGE_REPORT_FULFILMENT.equals(normalized)) {
            return STAGE_REPORT_FULFILMENT;
        }
        if ('EXPIRED_CONSUMED'.equals(normalized) || 'CONSUMED'.equals(normalized) || CARD_STAGE_EXPIRED_CONSUMED.equals(normalized)) {
            return STAGE_EXPIRED_CONSUMED;
        }
        if ('DEPARTURE'.equals(normalized) || CARD_STAGE_DEPARTURE.equals(normalized)) {
            return STAGE_DEPARTURE;
        }
        return trimmed;
    }

    private static List<String> buildSearchOrClauses(String sk) {
        String term = '%' + String.escapeSingleQuotes(sk) + '%';
        List<String> searchOr = new List<String>();
        appendSearchIfAccessible(searchOr, 'Full_Name__c', term);
        appendSearchIfAccessible(searchOr, 'Email', term);
        appendSearchIfAccessible(searchOr, 'ID_Number__c', term);
        appendSearchIfAccessible(searchOr, 'ID_Type__c', term);
        appendSearchIfAccessible(searchOr, 'Employment_Status__c', term);
        appendSearchIfAccessible(searchOr, FLD_LIFECYCLE_STAGE, term);
        appendSearchIfAccessible(searchOr, FLD_AUTHENTICATION_TYPE, term);
        appendSearchIfAccessible(searchOr, FLD_CONSENT_TYPE, term);
        appendSearchIfAccessible(searchOr, FLD_LAST_MATCH_STATUS, term);
        appendSearchIfAccessible(searchOr, FLD_REPORT, term);
        return searchOr;
    }

    private static void appendSearchIfAccessible(List<String> searchOr, String apiName, String term) {
        if (String.isBlank(apiName) || !isContactFieldAccessible(apiName)) {
            return;
        }
        searchOr.add(apiName + ' LIKE \'' + term + '\'');
    }

    private static DataSubjectRowDto mapContactToDto(Contact c, Integer rowNumber) {
        DataSubjectRowDto d = new DataSubjectRowDto();
        d.id = c.Id;
        d.rowNumber = rowNumber;
        d.fullName = (String) getPopulated(c, 'Full_Name__c');
        d.email = (String) getPopulated(c, 'Email');
        d.idType = (String) getPopulated(c, 'ID_Type__c');
        d.idNumber = (String) getPopulated(c, 'ID_Number__c');
        d.dateOfBirth = (Date) getPopulated(c, 'Date_of_Birth__c');
        d.employmentStatus = (String) getPopulated(c, 'Employment_Status__c');
        d.lifecycleStage = (String) getPopulated(c, FLD_LIFECYCLE_STAGE);
        d.authenticationType = (String) getPopulated(c, FLD_AUTHENTICATION_TYPE);
        d.consentType = (String) getPopulated(c, FLD_CONSENT_TYPE);
        d.lastMatchStatus = (String) getPopulated(c, FLD_LAST_MATCH_STATUS);
        d.createdDate = (Datetime) getPopulated(c, 'CreatedDate');
        d.report = (String) getPopulated(c, FLD_REPORT);
        d.lastActivityDate = toDateOnly(getPopulated(c, FLD_LAST_ACTIVITY_DATE));
        return d;
    }

    private static String buildContactSelectSoqlPrefix() {
        List<String> parts = new List<String>{
            'Id',
            'Full_Name__c',
            'Email',
            'ID_Type__c',
            'ID_Number__c',
            'Date_of_Birth__c',
            'Employment_Status__c',
            FLD_LIFECYCLE_STAGE,
            'CreatedDate'
        };
        appendFieldIfExists(parts, FLD_AUTHENTICATION_TYPE);
        appendFieldIfExists(parts, FLD_CONSENT_TYPE);
        appendFieldIfExists(parts, FLD_LAST_MATCH_STATUS);
        appendFieldIfExists(parts, FLD_REPORT);
        appendFieldIfExists(parts, FLD_LAST_ACTIVITY_DATE);
        return 'SELECT ' + String.join(parts, ', ');
    }

    private static void appendFieldIfExists(List<String> parts, String apiName) {
        if (contactFieldExists(apiName) && !parts.contains(apiName)) {
            parts.add(apiName);
        }
    }

    private static Boolean contactFieldExists(String apiName) {
        if (String.isBlank(apiName)) {
            return false;
        }
        return Schema.SObjectType.Contact.fields.getMap().containsKey(apiName);
    }

    private static ConsentSummaryDto initSummaryDto() {
        ConsentSummaryDto dto = new ConsentSummaryDto();
        dto.all = 0;
        dto.intake = 0;
        dto.consentRequest = 0;
        dto.awaitingAction = 0;
        dto.activeConsent = 0;
        dto.declined = 0;
        dto.exceptionCount = 0;
        dto.withdrawn = 0;
        dto.expired = 0;
        dto.reportRequest = 0;
        dto.reportFulfilment = 0;
        dto.expiredConsumed = 0;
        dto.departureCount = 0;
        dto.singpass = 0;
        dto.nonSingpass = 0;
        dto.perReportConsent = 0;
        dto.termBasedConsent = 0;
        return dto;
    }

    private static void appendOwnershipContact(List<String> filtersClauses, DashboardFilter filters) {
        if (filters == null || String.isBlank(filters.ownership)) {
            return;
        }
        if ('MY'.equalsIgnoreCase(filters.ownership.trim())) {
            filtersClauses.add('OwnerId = \'' + String.escapeSingleQuotes(String.valueOf(UserInfo.getUserId())) + '\'');
        }
    }

    private static List<String> buildContactDateFilterClauses(DashboardFilter filters) {
        List<String> out = new List<String>();
        if (filters == null || String.isBlank(filters.dateType) || filters.startDate == null || filters.endDate == null) {
            return out;
        }
        if (filters.endDate < filters.startDate) {
            return out;
        }
        String api = filters.dateType.trim();
        if (!CONTACT_DATE_TYPE_WHITELIST.contains(api)) {
            return out;
        }
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
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

    private static Date toDateOnly(Object raw) {
        if (raw == null) {
            return null;
        }
        if (raw instanceof Date) {
            return (Date) raw;
        }
        if (raw instanceof Datetime) {
            return ((Datetime) raw).date();
        }
        return null;
    }

    private static Boolean isGuestUser() {
        return 'Guest'.equals(UserInfo.getUserType());
    }

    private static Boolean isContactReadable() {
        return Schema.sObjectType.Contact.isAccessible();
    }

    private static Boolean isLifecycleStageReadable() {
        return isContactFieldAccessible(FLD_LIFECYCLE_STAGE);
    }

    private static Boolean isContactFieldAccessible(String apiName) {
        if (String.isBlank(apiName)) {
            return false;
        }
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Contact.fields.getMap();
        Schema.SObjectField f = fieldMap.get(apiName);
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
                parts.add('AccountId = \'' + String.valueOf(accId) + '\'');
            }
        }

        String recordTypeClause = buildAllowedRecordTypeClause();
        if (String.isNotBlank(recordTypeClause)) {
            parts.add(recordTypeClause);
        }

        if (parts.isEmpty()) {
            return 'Id != null';
        }
        return String.join(parts, ' AND ');
    }

    private static String buildAllowedRecordTypeClause() {
        Set<String> developerNames = resolveAllowedContactRecordTypeDeveloperNames();
        if (developerNames.isEmpty()) {
            return 'Id = NULL';
        }
        List<String> quotedNames = new List<String>();
        for (String developerName : developerNames) {
            quotedNames.add('\'' + String.escapeSingleQuotes(developerName) + '\'');
        }
        return 'RecordType.DeveloperName IN (' + String.join(quotedNames, ', ') + ')';
    }

    private static Set<String> resolveAllowedContactRecordTypeDeveloperNames() {
        Set<String> allowed = new Set<String>();
        for (Schema.RecordTypeInfo rtInfo : Schema.SObjectType.Contact.getRecordTypeInfos()) {
            if (rtInfo == null || rtInfo.isMaster() || !rtInfo.isAvailable()) {
                continue;
            }
            String developerName = rtInfo.getDeveloperName();
            if (RT_SINGPASS.equals(developerName) || RT_NON_SINGPASS.equals(developerName)) {
                allowed.add(developerName);
            }
        }
        return allowed;
    }

    private static String buildOrderClause(String sortBy, String sortDirection) {
        String field = String.isBlank(sortBy) ? null : sortBy.trim();
        if (field == null || !SORTABLE_FIELDS.contains(field) || !isSortFieldAccessible(field)) {
            return 'LastModifiedDate DESC';
        }
        String dir = 'ASC';
        if (!String.isBlank(sortDirection) && 'desc'.equalsIgnoreCase(sortDirection.trim())) {
            dir = 'DESC';
        } else if (!String.isBlank(sortDirection) && 'asc'.equalsIgnoreCase(sortDirection.trim())) {
            dir = 'ASC';
        }
        return field + ' ' + dir + ', LastModifiedDate DESC';
    }

    private static Boolean isSortFieldAccessible(String fieldApi) {
        if (fieldApi.contains('.')) {
            return false;
        }
        return isContactFieldAccessible(fieldApi);
    }
}