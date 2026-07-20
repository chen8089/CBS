public without sharing class ReportRequestExportService {
    @TestVisible
    private static Boolean skipWhitelistNotificationSendDuringTests = true;
    @TestVisible
    private static Integer lastWhitelistNotificationRecipientCountForTest = 0;
    private static final List<String> CORE_EXPORT_COLUMNS = new List<String>{
        'Case_Number',
        'Report_Request_Item_Id',
        'Report_Request_Item_Name',
        'Data_Subject_Id',
        'Data_Subject_Name',
        'Data_Subject_Client_ID_HMAC',
        'Export_Allowed',
        'Export_Note',
        'Principal Name',
        'NRIC / FIN',
        'Pass Type',
        'Passport Number',
        'Date of Birth',
        'Gender'
    };
    private static final String CONTACT_COLUMN_PRINCIPAL_NAME = 'Principal Name';
    private static final String CONTACT_COLUMN_NRIC_FIN = 'NRIC / FIN';
    private static final String CONTACT_COLUMN_PASS_TYPE = 'Pass Type';
    private static final String CONTACT_COLUMN_PASSPORT_NUMBER = 'Passport Number';
    private static final String CONTACT_COLUMN_DATE_OF_BIRTH = 'Date of Birth';
    private static final String CONTACT_COLUMN_GENDER = 'Gender';
    private static final List<String> CASE_CONTACT_EXPORT_COLUMNS = new List<String>{
        CONTACT_COLUMN_PRINCIPAL_NAME,
        CONTACT_COLUMN_NRIC_FIN,
        CONTACT_COLUMN_PASS_TYPE,
        CONTACT_COLUMN_PASSPORT_NUMBER,
        CONTACT_COLUMN_DATE_OF_BIRTH,
        CONTACT_COLUMN_GENDER
    };

    private static final Set<String> ALLOWED_EXPORT_FIELDS = new Set<String>{
        'Id',
        'Data_Subject__c',
        'Consent__c',
        'Eligibility_Status__c',
        'Consent_Revalidation_Status__c',
        'Delivery_Status__c',
        'SLA_Due_Date__c'
    };
    private static final Set<String> DEPARTED_STATUS_TOKENS = new Set<String>{
        'departed',
        'departure',
        'already departed',
        'inactive',
        'terminated',
        'resigned'
    };
    private static final List<String> REPORT_BATCH_FIELD_CANDIDATES = new List<String>{
        'Batch_ID__c',
        'Batch_Id__c',
        'Batch__c'
    };
    private static final String CASE_SOURCE_REPORT_FIELD = 'Source_Report__c';

    public class BatchExportResult {
        @AuraEnabled public String csvBody;
        @AuraEnabled public String batchReference;
        @AuraEnabled public Integer totalCandidateRows;
        @AuraEnabled public Integer exportedRows;
        @AuraEnabled public Integer filteredRows;
    }

    @AuraEnabled
    public static String exportAuthorizedList(Id caseId, List<String> requestedFields) {
        if (caseId == null) {
            throw new AuraHandledException('CASE_REQUIRED');
        }

        List<Case> matchingCases = [
            SELECT Id, CaseNumber, AccountId, ContactId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (matchingCases.isEmpty()) {
            throw new AuraHandledException('CASE_NOT_FOUND');
        }

        Map<String, Schema.SObjectField> itemFieldMap = Schema.SObjectType.Report_Request_Item__c.fields.getMap();
        List<String> exportFields = normalizeFields(requestedFields, itemFieldMap.keySet());
        if (exportFields.isEmpty()) {
            if (itemFieldMap.containsKey('Data_Subject__c')) {
                exportFields.add('Data_Subject__c');
            }
            if (itemFieldMap.containsKey('Consent__c')) {
                exportFields.add('Consent__c');
            }
            if (itemFieldMap.containsKey('Eligibility_Status__c')) {
                exportFields.add('Eligibility_Status__c');
            }
        }

        Set<String> queryFieldSet = new Set<String>{ 'Id' };
        if (itemFieldMap.containsKey('Data_Subject__c')) {
            queryFieldSet.add('Data_Subject__c');
        }
        queryFieldSet.add('Report_Request_Case__c');
        queryFieldSet.addAll(exportFields);
        queryFieldSet.add('Name');
        Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
        if (itemFieldMap.containsKey('Data_Subject__c')) {
            queryFieldSet.add('Data_Subject__r.Name');
        }
        if (itemFieldMap.containsKey('Data_Subject__c') && contactFieldMap.containsKey('Client_ID_HMAC__c')) {
            queryFieldSet.add('Data_Subject__r.Client_ID_HMAC__c');
        }
        if (itemFieldMap.containsKey('Data_Subject__c')) {
            if (contactFieldMap.containsKey('Employment_Status__c')) {
                queryFieldSet.add('Data_Subject__r.Employment_Status__c');
            }
            if (contactFieldMap.containsKey('Data_Subject_Lifecycle_Stage__c')) {
                queryFieldSet.add('Data_Subject__r.Data_Subject_Lifecycle_Stage__c');
            }
            if (contactFieldMap.containsKey('Current_Consent_Status__c')) {
                queryFieldSet.add('Data_Subject__r.Current_Consent_Status__c');
            }
        }
        List<String> queryFields = new List<String>();
        queryFields.addAll(queryFieldSet);
        queryFields.sort();

        String soql =
            'SELECT ' + String.join(queryFields, ',') +
            ' FROM Report_Request_Item__c WHERE Report_Request_Case__c = :caseId';
        List<Report_Request_Item__c> items = Database.query(soql);
        if (items.isEmpty()) {
            List<String> emptyHeaderColumns = new List<String>();
            emptyHeaderColumns.addAll(CORE_EXPORT_COLUMNS);
            emptyHeaderColumns.addAll(exportFields);
            return String.join(emptyHeaderColumns, ',') + '\n';
        }

        List<Report_Request_Item__c> csvItems = new List<Report_Request_Item__c>();
        List<Report_Request_Item__c> exportableItems = new List<Report_Request_Item__c>();
        Set<Id> departedItemIds = new Set<Id>();
        for (Report_Request_Item__c itemRecord : items) {
            ExportAuthorizationService.ExportAuthorizationResult authResult =
                ExportAuthorizationService.canExport(caseId, itemRecord.Data_Subject__c, matchingCases[0].AccountId);
            if (!authResult.isAuthorized) {
                if (authResult.reasonCode == 'USER_NOT_PROCESSING_OFFICER') {
                    throw new AuraHandledException('EXPORT_NOT_AUTHORIZED:' + authResult.reasonCode);
                }
                continue;
            }
            if (isDataSubjectDeparted(itemRecord)) {
                csvItems.add(itemRecord);
                departedItemIds.add(itemRecord.Id);
                continue;
            }
            csvItems.add(itemRecord);
            exportableItems.add(itemRecord);
        }

        Map<Id, Case> caseById = new Map<Id, Case>(matchingCases);
        Map<String, String> caseContactFieldByColumn = resolveCaseContactFieldByColumn();
        Map<Id, SObject> contactSnapshotById = loadCaseContactSnapshots(caseById.values(), caseContactFieldByColumn);
        String csvBody = buildCsvBody(csvItems, exportFields, caseById, departedItemIds, contactSnapshotById, caseContactFieldByColumn);

        List<Report_Request_Item__c> updates = new List<Report_Request_Item__c>();
        for (Report_Request_Item__c itemRecord : exportableItems) {
            Report_Request_Item__c updateRecord = new Report_Request_Item__c(Id = itemRecord.Id);
            setFieldIfAvailable(updateRecord, 'Authorized_List_Exported__c', true);
            setFieldIfAvailable(updateRecord, 'Authorized_List_Exported_At__c', System.now());
            setFieldIfAvailable(updateRecord, 'Authorized_List_Exported_By__c', UserInfo.getUserId());
            updates.add(updateRecord);
        }
        if (!updates.isEmpty()) {
            update updates;
        }

        return csvBody;
    }

    @AuraEnabled
    public static BatchExportResult exportAuthorizedListForLatestBatch(List<String> requestedFields) {
        return exportAuthorizedListForLatestBatchInternal(requestedFields, true);
    }

    @AuraEnabled
    public static BatchExportResult exportAuthorizedListForLatestBatchNoTracking(List<String> requestedFields) {
        return exportAuthorizedListForLatestBatchInternal(requestedFields, false);
    }

    private static BatchExportResult exportAuthorizedListForLatestBatchInternal(
        List<String> requestedFields,
        Boolean shouldMarkExported
    ) {
        String reportBatchFieldApiName = resolveReportBatchFieldApiName();
        if (String.isBlank(reportBatchFieldApiName)) {
            throw new AuraHandledException('BATCH_FIELD_NOT_FOUND');
        }

        List<SObject> latestReports = Database.query(
            'SELECT Id, ' + reportBatchFieldApiName +
            ' FROM Reports__c WHERE ' + reportBatchFieldApiName + ' != null ORDER BY CreatedDate DESC LIMIT 1'
        );
        if (latestReports.isEmpty()) {
            throw new AuraHandledException('LATEST_BATCH_NOT_FOUND');
        }
        SObject latestReport = latestReports[0];
        Object batchValue = latestReport.get(reportBatchFieldApiName);
        if (batchValue == null) {
            throw new AuraHandledException('LATEST_BATCH_NOT_FOUND');
        }

        List<SObject> batchReports = Database.query(
            'SELECT Id, CreatedDate FROM Reports__c WHERE ' + reportBatchFieldApiName + ' = :batchValue'
        );
        Set<Id> reportIds = new Set<Id>();
        Datetime batchMinCreatedAt;
        Datetime batchMaxCreatedAt;
        for (SObject reportRow : batchReports) {
            reportIds.add((Id) reportRow.get('Id'));
            Datetime reportCreatedAt = (Datetime) reportRow.get('CreatedDate');
            if (reportCreatedAt != null) {
                if (batchMinCreatedAt == null || reportCreatedAt < batchMinCreatedAt) {
                    batchMinCreatedAt = reportCreatedAt;
                }
                if (batchMaxCreatedAt == null || reportCreatedAt > batchMaxCreatedAt) {
                    batchMaxCreatedAt = reportCreatedAt;
                }
            }
        }

        BatchExportResult result = new BatchExportResult();
        result.batchReference = String.valueOf(batchValue);
        result.totalCandidateRows = 0;
        result.exportedRows = 0;
        result.filteredRows = 0;

        if (reportIds.isEmpty()) {
            result.csvBody = buildEmptyCsv(requestedFields);
            return result;
        }

        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!caseFieldMap.containsKey(CASE_SOURCE_REPORT_FIELD)) {
            throw new AuraHandledException('CASE_SOURCE_REPORT_FIELD_MISSING');
        }

        List<Case> relatedCases = [
            SELECT Id, CaseNumber, AccountId, ContactId, Submitted_By__c, Submitted_By__r.Email
            FROM Case
            WHERE Source_Report__c IN :reportIds
        ];
        if (relatedCases.isEmpty()) {
            List<String> reportIdStrings = new List<String>();
            for (Id reportId : reportIds) {
                reportIdStrings.add(String.valueOf(reportId));
            }
            reportIdStrings.add(String.valueOf(batchValue));
            relatedCases = [
                SELECT Id, CaseNumber, AccountId, ContactId, Submitted_By__c, Submitted_By__r.Email
                FROM Case
                WHERE Consent_Batch_Reference__c IN :reportIdStrings
            ];
        }
        if (relatedCases.isEmpty()) {
            relatedCases = resolveCasesByBatchCreationWindow(batchMinCreatedAt, batchMaxCreatedAt);
        }
        if (relatedCases.isEmpty()) {
            result.csvBody = buildEmptyCsv(requestedFields);
            return result;
        }

        Map<Id, Case> caseById = new Map<Id, Case>(relatedCases);
        Set<Id> caseIds = caseById.keySet();

        Map<String, Schema.SObjectField> itemFieldMap = Schema.SObjectType.Report_Request_Item__c.fields.getMap();
        List<String> exportFields = normalizeFields(requestedFields, itemFieldMap.keySet());
        if (exportFields.isEmpty()) {
            if (itemFieldMap.containsKey('Data_Subject__c')) {
                exportFields.add('Data_Subject__c');
            }
            if (itemFieldMap.containsKey('Consent__c')) {
                exportFields.add('Consent__c');
            }
            if (itemFieldMap.containsKey('Eligibility_Status__c')) {
                exportFields.add('Eligibility_Status__c');
            }
        }

        List<String> queryFields = buildItemQueryFields(exportFields);
        queryFields.add('Report_Request_Case__c');
        String soql =
            'SELECT ' + String.join(queryFields, ',') +
            ' FROM Report_Request_Item__c WHERE Report_Request_Case__c IN :caseIds';
        List<Report_Request_Item__c> items = Database.query(soql);
        result.totalCandidateRows = items.size();

        List<Report_Request_Item__c> csvItems = new List<Report_Request_Item__c>();
        List<Report_Request_Item__c> exportableItems = new List<Report_Request_Item__c>();
        Set<Id> departedItemIds = new Set<Id>();
        for (Report_Request_Item__c itemRecord : items) {
            Case parentCase = caseById.get(itemRecord.Report_Request_Case__c);
            if (parentCase == null) {
                continue;
            }
            ExportAuthorizationService.ExportAuthorizationResult authResult =
                ExportAuthorizationService.canExport(parentCase.Id, itemRecord.Data_Subject__c, parentCase.AccountId);
            if (!authResult.isAuthorized) {
                if (authResult.reasonCode == 'USER_NOT_PROCESSING_OFFICER') {
                    throw new AuraHandledException('EXPORT_NOT_AUTHORIZED:' + authResult.reasonCode);
                }
                continue;
            }
            if (isDataSubjectDeparted(itemRecord)) {
                csvItems.add(itemRecord);
                departedItemIds.add(itemRecord.Id);
                continue;
            }
            csvItems.add(itemRecord);
            exportableItems.add(itemRecord);
        }
        result.exportedRows = exportableItems.size();
        result.filteredRows = result.totalCandidateRows - result.exportedRows;

        Map<String, String> caseContactFieldByColumn = resolveCaseContactFieldByColumn();
        Map<Id, SObject> contactSnapshotById = loadCaseContactSnapshots(caseById.values(), caseContactFieldByColumn);
        result.csvBody = buildCsvBody(csvItems, exportFields, caseById, departedItemIds, contactSnapshotById, caseContactFieldByColumn);
        sendWhitelistDownloadNotifications(csvItems, caseById, result.batchReference);
        if (shouldMarkExported == true) {
            markAuthorizedExported(exportableItems);
        }
        return result;
    }

    private static String resolveReportBatchFieldApiName() {
        Map<String, Schema.SObjectField> reportFieldMap = Schema.SObjectType.Reports__c.fields.getMap();
        for (String candidate : REPORT_BATCH_FIELD_CANDIDATES) {
            if (reportFieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private static List<String> buildItemQueryFields(List<String> exportFields) {
        Map<String, Schema.SObjectField> itemFieldMap = Schema.SObjectType.Report_Request_Item__c.fields.getMap();
        Set<String> queryFieldSet = new Set<String>{ 'Id', 'Name' };
        if (itemFieldMap.containsKey('Data_Subject__c')) {
            queryFieldSet.add('Data_Subject__c');
            queryFieldSet.add('Data_Subject__r.Name');
            queryFieldSet.add('Data_Subject__r.Email');
        }
        queryFieldSet.addAll(exportFields);

        Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
        if (itemFieldMap.containsKey('Data_Subject__c') && contactFieldMap.containsKey('Client_ID_HMAC__c')) {
            queryFieldSet.add('Data_Subject__r.Client_ID_HMAC__c');
        }
        if (itemFieldMap.containsKey('Data_Subject__c') && contactFieldMap.containsKey('Employment_Status__c')) {
            queryFieldSet.add('Data_Subject__r.Employment_Status__c');
        }
        if (itemFieldMap.containsKey('Data_Subject__c') && contactFieldMap.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            queryFieldSet.add('Data_Subject__r.Data_Subject_Lifecycle_Stage__c');
        }
        if (itemFieldMap.containsKey('Data_Subject__c') && contactFieldMap.containsKey('Current_Consent_Status__c')) {
            queryFieldSet.add('Data_Subject__r.Current_Consent_Status__c');
        }
        List<String> queryFields = new List<String>();
        queryFields.addAll(queryFieldSet);
        queryFields.sort();
        return queryFields;
    }

    private static String buildCsvBody(
        List<Report_Request_Item__c> csvItems,
        List<String> exportFields,
        Map<Id, Case> caseById,
        Set<Id> departedItemIds,
        Map<Id, SObject> contactSnapshotById,
        Map<String, String> caseContactFieldByColumn
    ) {
        List<String> csvLines = new List<String>();
        List<String> headerColumns = new List<String>();
        headerColumns.addAll(CORE_EXPORT_COLUMNS);
        headerColumns.addAll(exportFields);
        csvLines.add(String.join(headerColumns, ','));

        Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
        for (Report_Request_Item__c itemRecord : csvItems) {
            Case parentCase = caseById.get(itemRecord.Report_Request_Case__c);
            List<String> rowValues = new List<String>();
            rowValues.add(escapeCsv(parentCase == null ? '' : parentCase.CaseNumber));
            rowValues.add(escapeCsv(itemRecord.Id));
            rowValues.add(escapeCsv(itemRecord.Name));
            rowValues.add(escapeCsv(itemRecord.Data_Subject__c == null ? '' : String.valueOf(itemRecord.Data_Subject__c)));

            String dataSubjectName = '';
            String dataSubjectClientIdHmac = '';
            if (itemRecord.Data_Subject__r != null) {
                Object dsNameValue = itemRecord.Data_Subject__r.get('Name');
                dataSubjectName = dsNameValue == null ? '' : String.valueOf(dsNameValue);
                if (contactFieldMap.containsKey('Client_ID_HMAC__c')) {
                    Object dsHmacValue = itemRecord.Data_Subject__r.get('Client_ID_HMAC__c');
                    dataSubjectClientIdHmac = dsHmacValue == null ? '' : String.valueOf(dsHmacValue);
                }
            }
            rowValues.add(escapeCsv(dataSubjectName));
            rowValues.add(escapeCsv(dataSubjectClientIdHmac));
            Boolean isDepartedItem = departedItemIds != null && departedItemIds.contains(itemRecord.Id);
            rowValues.add(escapeCsv(isDepartedItem ? 'No' : 'Yes'));
            rowValues.add(escapeCsv(isDepartedItem ? 'Excluded - Departed employee' : 'Authorized'));
            appendCaseContactRowValues(rowValues, parentCase, contactSnapshotById, caseContactFieldByColumn);
            for (String fieldApiName : exportFields) {
                Object rawValue = itemRecord.get(fieldApiName);
                rowValues.add(escapeCsv(rawValue == null ? '' : String.valueOf(rawValue)));
            }
            csvLines.add(String.join(rowValues, ','));
        }
        return String.join(csvLines, '\n');
    }

    private static String buildEmptyCsv(List<String> requestedFields) {
        Map<String, Schema.SObjectField> itemFieldMap = Schema.SObjectType.Report_Request_Item__c.fields.getMap();
        List<String> exportFields = normalizeFields(requestedFields, itemFieldMap.keySet());
        if (exportFields.isEmpty()) {
            if (itemFieldMap.containsKey('Data_Subject__c')) {
                exportFields.add('Data_Subject__c');
            }
            if (itemFieldMap.containsKey('Consent__c')) {
                exportFields.add('Consent__c');
            }
            if (itemFieldMap.containsKey('Eligibility_Status__c')) {
                exportFields.add('Eligibility_Status__c');
            }
        }
        List<String> emptyHeaderColumns = new List<String>();
        emptyHeaderColumns.addAll(CORE_EXPORT_COLUMNS);
        emptyHeaderColumns.addAll(exportFields);
        return String.join(emptyHeaderColumns, ',') + '\n';
    }

    private static List<Case> resolveCasesByBatchCreationWindow(Datetime minCreatedAt, Datetime maxCreatedAt) {
        if (minCreatedAt == null || maxCreatedAt == null) {
            return new List<Case>();
        }
        Datetime windowStart = minCreatedAt.addMinutes(-2);
        Datetime windowEnd = maxCreatedAt.addMinutes(2);
        Set<Id> candidateCaseIds = new Set<Id>();
        for (Report_Request_Item__c itemRecord : [
            SELECT Report_Request_Case__c
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c != null
            AND CreatedDate >= :windowStart
            AND CreatedDate <= :windowEnd
        ]) {
            candidateCaseIds.add(itemRecord.Report_Request_Case__c);
        }
        if (candidateCaseIds.isEmpty()) {
            return new List<Case>();
        }
        return [
            SELECT Id, CaseNumber, AccountId, ContactId, Submitted_By__c, Submitted_By__r.Email
            FROM Case
            WHERE Id IN :candidateCaseIds
        ];
    }

    private static void sendWhitelistDownloadNotifications(
        List<Report_Request_Item__c> csvItems,
        Map<Id, Case> caseById,
        String batchReference
    ) {
        Set<String> uniqueEmails = new Set<String>();
        List<String> recipientEmails = new List<String>();
        Set<String> caseNumbers = new Set<String>();
        Set<String> dataSubjectNames = new Set<String>();
        if (csvItems != null) {
            for (Report_Request_Item__c itemRecord : csvItems) {
                if (itemRecord == null) {
                    continue;
                }
                Case parentCase = caseById == null ? null : caseById.get(itemRecord.Report_Request_Case__c);
                if (parentCase != null && !String.isBlank(parentCase.CaseNumber)) {
                    caseNumbers.add(parentCase.CaseNumber);
                }
                if (itemRecord.Data_Subject__r != null && !String.isBlank(itemRecord.Data_Subject__r.Name)) {
                    dataSubjectNames.add(itemRecord.Data_Subject__r.Name.trim());
                }
                addRecipientEmail(recipientEmails, uniqueEmails, itemRecord.Data_Subject__r == null ? null : itemRecord.Data_Subject__r.Email);
                addRecipientEmail(recipientEmails, uniqueEmails, parentCase != null && parentCase.Submitted_By__r != null
                    ? parentCase.Submitted_By__r.Email
                    : null);
            }
        }
        lastWhitelistNotificationRecipientCountForTest = recipientEmails.size();
        if (recipientEmails.isEmpty()) {
            return;
        }
        if (Test.isRunningTest() && skipWhitelistNotificationSendDuringTests) {
            return;
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        for (String recipient : recipientEmails) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ recipient });
            email.setSaveAsActivity(false);
            email.setSubject('【CBS 官方通知】授权凭证使用通知（批次 ' + String.valueOf(batchReference) + '）');
            email.setPlainTextBody(buildWhitelistDownloadBody(batchReference, caseNumbers, dataSubjectNames));
            emailsToSend.add(email);
        }
        try {
            Messaging.sendEmail(emailsToSend);
        } catch (Exception ex) {
            // Download should not be blocked by notification failures.
            System.debug('Whitelist notification send failed: ' + ex.getMessage());
        }
    }

    private static void addRecipientEmail(
        List<String> recipientEmails,
        Set<String> uniqueEmails,
        String rawEmail
    ) {
        if (recipientEmails == null || uniqueEmails == null || String.isBlank(rawEmail)) {
            return;
        }
        String normalized = rawEmail.trim().toLowerCase();
        if (String.isBlank(normalized) || uniqueEmails.contains(normalized)) {
            return;
        }
        uniqueEmails.add(normalized);
        recipientEmails.add(rawEmail.trim());
    }

    private static String buildWhitelistDownloadBody(
        String batchReference,
        Set<String> caseNumbers,
        Set<String> dataSubjectNames
    ) {
        List<String> caseNumberList = new List<String>();
        if (caseNumbers != null) {
            caseNumberList.addAll(caseNumbers);
            caseNumberList.sort();
        }
        List<String> dataSubjectNameList = new List<String>();
        if (dataSubjectNames != null) {
            dataSubjectNameList.addAll(dataSubjectNames);
            dataSubjectNameList.sort();
        }

        String caseNumbersText = caseNumberList.isEmpty() ? 'N/A' : String.join(caseNumberList, ', ');
        String namesText = dataSubjectNameList.isEmpty() ? '相关数据主体' : String.join(dataSubjectNameList, '、');

        List<String> lines = new List<String>();
        lines.add('尊敬的用户：');
        lines.add('');
        lines.add('您提交的征信请求中，' + namesText + '的授权凭证已被使用。');
        lines.add('本次操作为白名单下载环节触发，用于后续征信处理流程。');
        lines.add('');
        lines.add('批次号：' + String.valueOf(batchReference));
        lines.add('关联 Case：' + caseNumbersText);
        lines.add('处理时间：' + String.valueOf(System.now()));
        lines.add('');
        lines.add('如您对本次使用有任何疑问，请及时联系 CBS 服务团队核查。');
        lines.add('');
        lines.add('此致');
        lines.add('CBS 服务团队');
        return String.join(lines, '\n');
    }

    private static Map<String, String> resolveCaseContactFieldByColumn() {
        Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
        Map<String, String> mapping = new Map<String, String>();
        mapping.put(CONTACT_COLUMN_PRINCIPAL_NAME, firstCaseInsensitiveFieldMatch(contactFieldMap, new List<String>{ 'Principal_Name__c' }));
        mapping.put(CONTACT_COLUMN_NRIC_FIN, firstCaseInsensitiveFieldMatch(contactFieldMap, new List<String>{ 'Nric_Fin_Number__c', 'NRIC_FIN_Number__c' }));
        mapping.put(CONTACT_COLUMN_PASS_TYPE, firstCaseInsensitiveFieldMatch(contactFieldMap, new List<String>{ 'Pass_Type__c' }));
        mapping.put(CONTACT_COLUMN_PASSPORT_NUMBER, firstCaseInsensitiveFieldMatch(contactFieldMap, new List<String>{ 'Passport_Number__c' }));
        mapping.put(CONTACT_COLUMN_DATE_OF_BIRTH, firstCaseInsensitiveFieldMatch(contactFieldMap, new List<String>{ 'Date_of_Birth__c', 'Birthdate' }));
        mapping.put(CONTACT_COLUMN_GENDER, firstCaseInsensitiveFieldMatch(contactFieldMap, new List<String>{ 'Gender__c', 'GenderIdentity' }));
        return mapping;
    }

    private static String firstCaseInsensitiveFieldMatch(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> candidates
    ) {
        if (fieldMap == null || fieldMap.isEmpty() || candidates == null || candidates.isEmpty()) {
            return null;
        }
        for (String candidate : candidates) {
            if (String.isBlank(candidate)) {
                continue;
            }
            for (String fieldName : fieldMap.keySet()) {
                if (fieldName != null && fieldName.equalsIgnoreCase(candidate)) {
                    return fieldName;
                }
            }
        }
        return null;
    }

    private static Map<Id, SObject> loadCaseContactSnapshots(
        List<Case> casesToResolve,
        Map<String, String> caseContactFieldByColumn
    ) {
        Map<Id, SObject> contactById = new Map<Id, SObject>();
        if (casesToResolve == null || casesToResolve.isEmpty()) {
            return contactById;
        }
        Set<Id> contactIds = new Set<Id>();
        for (Case caseRecord : casesToResolve) {
            if (caseRecord != null && caseRecord.ContactId != null) {
                contactIds.add(caseRecord.ContactId);
            }
        }
        if (contactIds.isEmpty()) {
            return contactById;
        }

        Set<String> contactQueryFieldSet = new Set<String>{ 'Id' };
        if (caseContactFieldByColumn != null) {
            for (String columnName : CASE_CONTACT_EXPORT_COLUMNS) {
                String mappedField = caseContactFieldByColumn.get(columnName);
                if (!String.isBlank(mappedField)) {
                    contactQueryFieldSet.add(mappedField);
                }
            }
        }

        List<String> contactQueryFields = new List<String>();
        contactQueryFields.addAll(contactQueryFieldSet);
        contactQueryFields.sort();
        String contactSoql =
            'SELECT ' + String.join(contactQueryFields, ',') +
            ' FROM Contact WHERE Id IN :contactIds';
        for (SObject contactRecord : Database.query(contactSoql)) {
            contactById.put((Id) contactRecord.get('Id'), contactRecord);
        }
        return contactById;
    }

    private static void appendCaseContactRowValues(
        List<String> rowValues,
        Case parentCase,
        Map<Id, SObject> contactSnapshotById,
        Map<String, String> caseContactFieldByColumn
    ) {
        if (rowValues == null) {
            return;
        }
        Id caseContactId = parentCase == null ? null : parentCase.ContactId;
        SObject contactSnapshot = caseContactId == null || contactSnapshotById == null
            ? null
            : contactSnapshotById.get(caseContactId);

        for (String columnName : CASE_CONTACT_EXPORT_COLUMNS) {
            String mappedField = caseContactFieldByColumn == null ? null : caseContactFieldByColumn.get(columnName);
            Object rawValue = (contactSnapshot == null || String.isBlank(mappedField))
                ? null
                : contactSnapshot.get(mappedField);
            rowValues.add(escapeCsv(rawValue == null ? '' : String.valueOf(rawValue)));
        }
    }

    private static void markAuthorizedExported(List<Report_Request_Item__c> exportableItems) {
        if (exportableItems == null || exportableItems.isEmpty()) {
            return;
        }
        List<Report_Request_Item__c> updates = new List<Report_Request_Item__c>();
        for (Report_Request_Item__c itemRecord : exportableItems) {
            Report_Request_Item__c updateRecord = new Report_Request_Item__c(Id = itemRecord.Id);
            setFieldIfAvailable(updateRecord, 'Authorized_List_Exported__c', true);
            setFieldIfAvailable(updateRecord, 'Authorized_List_Exported_At__c', System.now());
            setFieldIfAvailable(updateRecord, 'Authorized_List_Exported_By__c', UserInfo.getUserId());
            updates.add(updateRecord);
        }
        update updates;
    }

    private static Boolean isDataSubjectDeparted(Report_Request_Item__c itemRecord) {
        if (itemRecord == null || itemRecord.Data_Subject__r == null) {
            return false;
        }
        return isDepartureLikeStatus(itemRecord.Data_Subject__r.get('Employment_Status__c')) ||
            isDepartureLikeStatus(itemRecord.Data_Subject__r.get('Data_Subject_Lifecycle_Stage__c')) ||
            isDepartureLikeStatus(itemRecord.Data_Subject__r.get('Current_Consent_Status__c'));
    }

    private static Boolean isDepartureLikeStatus(Object rawStatus) {
        String normalized = rawStatus == null ? null : String.valueOf(rawStatus).trim().toLowerCase();
        if (String.isBlank(normalized)) {
            return false;
        }
        if (DEPARTED_STATUS_TOKENS.contains(normalized)) {
            return true;
        }
        return normalized.contains('depart');
    }

    private static List<String> normalizeFields(List<String> requestedFields, Set<String> availableFields) {
        List<String> normalizedFields = new List<String>();
        if (requestedFields == null) {
            return normalizedFields;
        }
        Set<String> uniqueFields = new Set<String>();
        for (String requestedField : requestedFields) {
            if (String.isBlank(requestedField)) {
                continue;
            }
            String normalizedField = requestedField.trim();
            if (!ALLOWED_EXPORT_FIELDS.contains(normalizedField)) {
                throw new AuraHandledException('FIELD_NOT_WHITELISTED:' + normalizedField);
            }
            if (availableFields != null && !availableFields.contains(normalizedField)) {
                continue;
            }
            uniqueFields.add(normalizedField);
        }
        normalizedFields.addAll(uniqueFields);
        normalizedFields.sort();
        return normalizedFields;
    }

    private static String escapeCsv(String value) {
        String escapedValue = value == null ? '' : value.replace('"', '""');
        return '"' + escapedValue + '"';
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }
}