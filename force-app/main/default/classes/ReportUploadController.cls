public without sharing class ReportUploadController {
    public static final String STATUS_UPDATED_CONSENT = 'Updated Consent';
    public static final String STATUS_NO_VALID_CONSENT = 'No Valid Consent';

    public static final String SOURCE_REPORT_UPLOAD = UploadSourceService.SOURCE_REPORT_UPLOAD;
    public static final String EXC_MSG_DUPLICATE_EMAIL = 'Duplicate Email';
    public static final String EXC_MSG_REQUIRED_EMAIL = 'Email Address is required';
    public static final String EXC_MSG_INVALID_EMAIL = 'Invalid Email Address format';
    public static final String EXC_MSG_NO_ACTIVE_CONSENT = 'No Active Consent';
    public static final String EXC_FIELD_NAME_EMAIL = 'Email Address';

    private static final String FLD_BATCH_SOURCE = 'Source__c';
    private static final String FLD_BATCH_TOTAL_RECORDS = 'Total_Records__c';
    private static final String FLD_BATCH_VALIDATED_RECORDS = 'Validated_Records__c';
    private static final String FLD_BATCH_FAILED_VALIDATION_RECORDS = 'Failed_Validation_Records__c';
    private static final String FLD_CONSENT_STATUS = 'Consent_Status__c';
    private static final String FLD_UPDATED_DATE = 'Updated_Date__c';
    private static final String FLD_EXCEPTION_BATCH_LOOKUP = 'Batch__c';
    private static final String FLD_EXCEPTION_BATCH_TEXT = 'Batch_Id__c';
    private static final String FLD_EXCEPTION_EXCEL_ROW_NUMBER = 'Excel_Row_Number__c';

    private static final List<String> REPORT_EMAIL_FIELD_CANDIDATES = new List<String>{ 'Email_Address__c', 'Email__c' };
    private static final List<String> REPORT_BATCH_LOOKUP_CANDIDATES = new List<String>{ 'Batch__c', 'Batch__c__c', 'Related_Batch__c' };
    private static final List<String> REPORT_BATCH_TEXT_CANDIDATES = new List<String>{ 'Batch_ID__c', 'Batch_Id__c' };

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
    );
    public class ReportUploadRow {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String emailAddress;
        @AuraEnabled public String email;
        @AuraEnabled public String batchId;
    }

    public class UploadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public Integer successRows;
        @AuraEnabled public Integer exceptionRows;
        @AuraEnabled public Integer createdExceptions;
        @AuraEnabled public String message;
        @AuraEnabled public Integer insertedRows;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public Integer skippedDuplicateCount;
        @AuraEnabled public Integer duplicateInFileCount;
        @AuraEnabled public Integer duplicateExistingCount;
        @AuraEnabled public Integer exceptionCreatedCount;
        @AuraEnabled public List<RowError> errors;
        @AuraEnabled public Id batchId;
        @AuraEnabled public Integer validatedRecords;
        @AuraEnabled public Integer failedValidationRecords;
        @AuraEnabled public Integer casesCreated;
        @AuraEnabled public Integer caseBindingErrors;
    }

    public class RowError {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String value;
        @AuraEnabled public String message;
    }

    private class RowValidationError {
        public String fieldName;
        public String fieldValue;
        public String message;

        public RowValidationError(String fieldName, String fieldValue, String message) {
            this.fieldName = fieldName;
            this.fieldValue = fieldValue;
            this.message = message;
        }
    }

    @AuraEnabled
    public static UploadResult uploadReports(String rowsJson) {
        return uploadReportsWithBatch(rowsJson, null, null, null);
    }

    @AuraEnabled
    public static UploadResult uploadReportsWithBatch(
        String rowsJson,
        String fileName,
        String fileBase64,
        String contentType
    ) {
        List<ReportUploadRow> rows = (List<ReportUploadRow>) JSON.deserialize(rowsJson, List<ReportUploadRow>.class);
        if (rows == null || rows.isEmpty()) {
            throw new AuraHandledException('No rows to import.');
        }
        if (!Schema.sObjectType.Reports__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create report records.');
        }
        if (!Schema.sObjectType.Batch__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create batch records.');
        }
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create Exception records.');
        }

        UploadResult result = new UploadResult();
        result.success = true;
        result.totalRows = rows.size();
        result.successRows = 0;
        result.exceptionRows = 0;
        result.createdExceptions = 0;
        result.message = 'Report upload completed successfully.';
        result.insertedRows = 0;
        result.successCount = 0;
        result.errorCount = 0;
        result.skippedDuplicateCount = 0;
        result.duplicateInFileCount = 0;
        result.duplicateExistingCount = 0;
        result.exceptionCreatedCount = 0;
        result.errors = new List<RowError>();
        result.validatedRecords = 0;
        result.failedValidationRecords = result.totalRows;
        result.casesCreated = 0;
        result.caseBindingErrors = 0;

        Batch__c batchRecord = createReportUploadBatch(result.totalRows, 0, result.totalRows);
        result.batchId = batchRecord.Id;

        if (String.isNotBlank(fileName) && String.isNotBlank(fileBase64)) {
            saveUploadedFileToBatch(batchRecord.Id, fileName, fileBase64, contentType);
        }

        Set<String> seenEmails = new Set<String>();
        Set<String> existingReportEmails = queryExistingReportEmails(collectTrimmedEmailsForQuery(rows));
        List<ReportUploadRow> consentCandidateRows = new List<ReportUploadRow>();
        List<Exception__c> exceptionsToInsert = new List<Exception__c>();
        List<Integer> exceptionRowNumbers = new List<Integer>();
        Map<String, Schema.SObjectField> excFieldMap = Schema.SObjectType.Exception__c.fields.getMap();
        Set<Integer> failedRowNumbers = new Set<Integer>();

        for (ReportUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            Integer rn = row.rowNumber != null ? row.rowNumber : 0;
            String rawEmail = resolveRawEmail(row);
            RowValidationError validationError = validateEmail(rawEmail);
            if (validationError != null) {
                addValidationException(
                    validationError,
                    rn,
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    failedRowNumbers,
                    result,
                    batchRecord.Id,
                    excFieldMap
                );
                continue;
            }

            String normalizedEmail = normalizeEmail(rawEmail);
            if (seenEmails.contains(normalizedEmail)) {
                addDuplicateEmailException(
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    rn,
                    batchRecord.Id,
                    rawEmail,
                    excFieldMap,
                    result,
                    failedRowNumbers
                );
                result.duplicateInFileCount++;
                continue;
            }

            if (existingReportEmails.contains(normalizedEmail)) {
                addDuplicateEmailException(
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    rn,
                    batchRecord.Id,
                    rawEmail,
                    excFieldMap,
                    result,
                    failedRowNumbers
                );
                result.duplicateExistingCount++;
                seenEmails.add(normalizedEmail);
                continue;
            }

            seenEmails.add(normalizedEmail);
            consentCandidateRows.add(row);
        }

        Map<String, Contact> contactByEmail = loadContactsByEmail(consentCandidateRows);
        Map<Id, ConsentEligibilityService.EligibilityResult> consentEligibilityByContactId =
            loadConsentEligibilityByContactIds(contactByEmail);
        List<ReportUploadRow> rowsForReport = new List<ReportUploadRow>();
        for (ReportUploadRow row : consentCandidateRows) {
            Integer rowNumber = row.rowNumber == null ? 0 : row.rowNumber;
            String normalizedEmail = normalizeEmail(resolveRawEmail(row));
            Contact matchedContact = String.isBlank(normalizedEmail) ? null : contactByEmail.get(normalizedEmail);
            ConsentEligibilityService.EligibilityResult eligibility =
                matchedContact == null ? null : consentEligibilityByContactId.get(matchedContact.Id);
            if (eligibility == null || !eligibility.isEligible) {
                String reasonCode = eligibility == null ? 'CONSENT_NOT_FOUND' : eligibility.reasonCode;
                RowValidationError consentError = new RowValidationError(
                    EXC_FIELD_NAME_EMAIL,
                    resolveRawEmail(row),
                    EXC_MSG_NO_ACTIVE_CONSENT + ' (' + reasonCode + ')'
                );
                addValidationException(
                    consentError,
                    rowNumber,
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    failedRowNumbers,
                    result,
                    batchRecord.Id,
                    excFieldMap
                );
                continue;
            }
            rowsForReport.add(row);
        }

        List<Reports__c> toInsert = new List<Reports__c>();
        List<Integer> reportRowNumbers = new List<Integer>();
        List<Id> reportDataSubjectIds = new List<Id>();
        if (!rowsForReport.isEmpty()) {
            for (ReportUploadRow row : rowsForReport) {
                toInsert.add(buildReportRecord(row, contactByEmail, batchRecord.Id));
                reportRowNumbers.add(row.rowNumber != null ? row.rowNumber : 0);
                reportDataSubjectIds.add(resolveDataSubjectIdByEmail(row, contactByEmail));
            }
        }

        List<Reports__c> successfullyInsertedReports = new List<Reports__c>();
        Map<Id, Integer> reportRowNumberById = new Map<Id, Integer>();
        Map<Id, Integer> successfulRetrievalCountBySubject = new Map<Id, Integer>();
        if (!toInsert.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
            List<Reports__c> creatable = (List<Reports__c>) decision.getRecords();
            Database.SaveResult[] saveResults = Database.insert(creatable, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                if (sr.isSuccess()) {
                    result.insertedRows++;
                    result.successRows++;
                    result.successCount++;
                    Reports__c insertedReport = creatable[i];
                    successfullyInsertedReports.add(insertedReport);
                    if (insertedReport != null && insertedReport.Id != null) {
                        Integer rowNumber = i < reportRowNumbers.size() ? reportRowNumbers[i] : 0;
                        reportRowNumberById.put(insertedReport.Id, rowNumber);
                    }
                    if (i < reportDataSubjectIds.size() && reportDataSubjectIds[i] != null) {
                        Integer existingCount = successfulRetrievalCountBySubject.containsKey(reportDataSubjectIds[i])
                            ? successfulRetrievalCountBySubject.get(reportDataSubjectIds[i])
                            : 0;
                        successfulRetrievalCountBySubject.put(reportDataSubjectIds[i], existingCount + 1);
                    }
                } else {
                    result.errorCount++;
                    Integer rowRn = i < reportRowNumbers.size() ? reportRowNumbers[i] : 0;
                    String msg = sr.getErrors().isEmpty() ? 'Insert failed.' : sr.getErrors()[0].getMessage();
                    result.errors.add(rowError(rowRn, 'Report', null, msg));
                    failedRowNumbers.add(rowRn);
                }
            }
        }
        if (!successfullyInsertedReports.isEmpty()) {
            ReportUploadCaseBindingService.BindingResult bindingResult =
                ReportUploadCaseBindingService.createAndBindCases(successfullyInsertedReports, contactByEmail);
            result.casesCreated = bindingResult.createdCaseCount;
            for (Id reportId : bindingResult.reportErrorsById.keySet()) {
                result.caseBindingErrors++;
                Integer rowNumber = reportRowNumberById.containsKey(reportId) ? reportRowNumberById.get(reportId) : 0;
                result.errors.add(rowError(rowNumber, 'Case', null, bindingResult.reportErrorsById.get(reportId)));
            }
        }
        if (!successfulRetrievalCountBySubject.isEmpty()) {
            ReportRequestNotificationService.recordSuccessfulRetrievals(successfulRetrievalCountBySubject);
        }

        if (!exceptionsToInsert.isEmpty()) {
            SObjectAccessDecision excDecision = Security.stripInaccessible(AccessType.CREATABLE, exceptionsToInsert);
            List<Exception__c> creatableExc = (List<Exception__c>) excDecision.getRecords();
            Database.SaveResult[] excResults = Database.insert(creatableExc, false);
            for (Integer i = 0; i < excResults.size(); i++) {
                Database.SaveResult sr = excResults[i];
                if (sr.isSuccess()) {
                    result.exceptionCreatedCount++;
                    result.createdExceptions++;
                } else {
                    result.errorCount++;
                    Integer rowRn = i < exceptionRowNumbers.size() ? exceptionRowNumbers[i] : 0;
                    String msg = sr.getErrors().isEmpty() ? 'Insert failed.' : sr.getErrors()[0].getMessage();
                    result.errors.add(rowError(rowRn, 'Exception', null, msg));
                }
            }
        }

        result.validatedRecords = result.successRows;
        result.failedValidationRecords = Math.max(0, result.totalRows - result.successRows);
        if (result.exceptionRows > 0) {
            result.message = 'Report upload completed with exceptions. Please review the Exceptions list.';
        }

        updateReportUploadBatchCounts(
            batchRecord.Id,
            result.totalRows,
            result.validatedRecords,
            result.failedValidationRecords
        );

        return result;
    }

    private static String resolveRawEmail(ReportUploadRow row) {
        if (row == null) {
            return null;
        }
        if (String.isNotBlank(row.emailAddress)) {
            return row.emailAddress;
        }
        return row.email;
    }

    private static void addValidationException(
        RowValidationError rowValidationError,
        Integer rowNumber,
        List<Exception__c> exceptionsToInsert,
        List<Integer> exceptionRowNumbers,
        Set<Integer> failedRowNumbers,
        UploadResult result,
        Id batchId,
        Map<String, Schema.SObjectField> excFieldMap
    ) {
        exceptionsToInsert.add(buildException(batchId, rowNumber, rowValidationError, excFieldMap));
        exceptionRowNumbers.add(rowNumber);
        failedRowNumbers.add(rowNumber);
        result.exceptionRows++;
        result.errorCount++;
        result.errors.add(rowError(rowNumber, rowValidationError.fieldName, rowValidationError.fieldValue, rowValidationError.message));
    }

    private static void addDuplicateEmailException(
        List<Exception__c> exceptionsToInsert,
        List<Integer> exceptionRowNumbers,
        Integer rowNumber,
        Id batchId,
        String emailRaw,
        Map<String, Schema.SObjectField> excFieldMap,
        UploadResult result,
        Set<Integer> failedRowNumbers
    ) {
        RowValidationError duplicateError = new RowValidationError(
            EXC_FIELD_NAME_EMAIL,
            emailRaw,
            EXC_MSG_DUPLICATE_EMAIL
        );
        exceptionsToInsert.add(buildException(batchId, rowNumber, duplicateError, excFieldMap));
        exceptionRowNumbers.add(rowNumber);
        failedRowNumbers.add(rowNumber);
        result.skippedDuplicateCount++;
        result.exceptionRows++;
        result.errorCount++;
        result.errors.add(rowError(rowNumber, duplicateError.fieldName, duplicateError.fieldValue, duplicateError.message));
    }

    private static Set<String> collectTrimmedEmailsForQuery(List<ReportUploadRow> rows) {
        Set<String> emails = new Set<String>();
        for (ReportUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            String trimmed = trimVal(resolveRawEmail(row));
            if (String.isNotBlank(trimmed)) {
                emails.add(trimmed);
            }
        }
        return emails;
    }

    private static Set<String> expandEmailsForSoqlIn(Set<String> emailValuesForQuery) {
        Set<String> expanded = new Set<String>();
        for (String email : emailValuesForQuery) {
            if (String.isBlank(email)) {
                continue;
            }
            expanded.add(email);
            expanded.add(email.toLowerCase());
        }
        return expanded;
    }

    private static Set<String> queryExistingReportEmails(Set<String> emailValuesForQuery) {
        Set<String> existing = new Set<String>();
        if (emailValuesForQuery.isEmpty()) {
            return existing;
        }
        String emailFieldApiName = resolveReportEmailFieldApiName();
        if (String.isBlank(emailFieldApiName)) {
            return existing;
        }
        Set<String> queryEmails = expandEmailsForSoqlIn(emailValuesForQuery);
        String soql = 'SELECT ' + emailFieldApiName + ' FROM Reports__c WHERE ' + emailFieldApiName + ' IN :queryEmails';
        for (SObject rec : Database.query(soql)) {
            String normalized = normalizeEmail((String) rec.get(emailFieldApiName));
            if (String.isNotBlank(normalized)) {
                existing.add(normalized);
            }
        }
        return existing;
    }

    private static RowValidationError validateEmail(String rawEmail) {
        String trimmedEmail = trimVal(rawEmail);
        if (String.isBlank(trimmedEmail)) {
            return new RowValidationError(EXC_FIELD_NAME_EMAIL, rawEmail, EXC_MSG_REQUIRED_EMAIL);
        }
        if (!EMAIL_PATTERN.matcher(trimmedEmail).matches()) {
            return new RowValidationError(EXC_FIELD_NAME_EMAIL, rawEmail, EXC_MSG_INVALID_EMAIL);
        }
        return null;
    }

    private static Map<String, Contact> loadContactsByEmail(List<ReportUploadRow> rowsForImport) {
        Set<String> emailValues = new Set<String>();
        for (ReportUploadRow row : rowsForImport) {
            if (row == null) {
                continue;
            }
            String normalizedEmail = normalizeEmail(resolveRawEmail(row));
            if (String.isBlank(normalizedEmail)) {
                continue;
            }
            emailValues.add(normalizedEmail);
        }

        Map<String, Contact> contactByEmail = new Map<String, Contact>();
        if (emailValues.isEmpty()) {
            return contactByEmail;
        }

        Set<String> queryEmails = expandEmailsForSoqlIn(emailValues);
        String contactSoql = 'SELECT Id, Email, AccountId FROM Contact WHERE Email IN :queryEmails';
        Map<String, Object> contactBinds = new Map<String, Object>{ 'queryEmails' => queryEmails };
        List<SObject> contactRows = Database.queryWithBinds(contactSoql, contactBinds, AccessLevel.SYSTEM_MODE);
        for (SObject row : contactRows) {
            Contact c = (Contact) row;
            if (String.isNotBlank(c.Email)) {
                String key = normalizeEmail(c.Email);
                if (String.isNotBlank(key)) {
                    contactByEmail.put(key, c);
                }
            }
        }
        return contactByEmail;
    }

    private static Map<Id, ConsentEligibilityService.EligibilityResult> loadConsentEligibilityByContactIds(
        Map<String, Contact> contactByEmail
    ) {
        Map<Id, ConsentEligibilityService.EligibilityResult> result = new Map<Id, ConsentEligibilityService.EligibilityResult>();
        if (contactByEmail == null || contactByEmail.isEmpty()) {
            return result;
        }
        Set<Id> contactIds = new Set<Id>();
        Map<Id, Id> accountByContactId = new Map<Id, Id>();
        for (Contact contactRecord : contactByEmail.values()) {
            if (contactRecord == null || contactRecord.Id == null) {
                continue;
            }
            contactIds.add(contactRecord.Id);
            accountByContactId.put(contactRecord.Id, contactRecord.AccountId);
        }
        if (contactIds.isEmpty()) {
            return result;
        }

        Map<Id, Consent__c> latestConsentBySubjectId = new Map<Id, Consent__c>();
        String consentSoql =
            'SELECT Data_Subject__c, Consent_Status__c, Consent_Expiry_Date__c, Report_Use_Count__c, Employment_Status__c ' +
            'FROM Consent__c WHERE Data_Subject__c IN :contactIds ORDER BY Data_Subject__c ASC, CreatedDate DESC';
        Map<String, Object> consentBinds = new Map<String, Object>{ 'contactIds' => contactIds };
        List<SObject> consentRows = Database.queryWithBinds(consentSoql, consentBinds, AccessLevel.SYSTEM_MODE);
        for (SObject row : consentRows) {
            Consent__c consentRecord = (Consent__c) row;
            if (!latestConsentBySubjectId.containsKey(consentRecord.Data_Subject__c)) {
                latestConsentBySubjectId.put(consentRecord.Data_Subject__c, consentRecord);
            }
        }

        for (Id contactId : contactIds) {
            result.put(
                contactId,
                evaluateConsentEligibility(latestConsentBySubjectId.get(contactId), accountByContactId.get(contactId))
            );
        }
        return result;
    }

    private static ConsentEligibilityService.EligibilityResult evaluateConsentEligibility(
        Consent__c consentRecord,
        Id expectedAccountId
    ) {
        if (consentRecord == null) {
            return new ConsentEligibilityService.EligibilityResult(false, 'CONSENT_NOT_FOUND');
        }

        String canonicalConsentStatus =
            ConsentStatusModelService.normalizeConsentStatus(consentRecord.Consent_Status__c);
        if (ConsentStatusModelService.isBlockedForReport(canonicalConsentStatus)) {
            return new ConsentEligibilityService.EligibilityResult(false, 'CONSENT_STATUS_BLOCKED');
        }
        if (canonicalConsentStatus != ConsentStatusModelService.STATUS_ACTIVE) {
            return new ConsentEligibilityService.EligibilityResult(false, 'CONSENT_STATUS_UNSUPPORTED');
        }
        if (consentRecord.Consent_Expiry_Date__c != null && consentRecord.Consent_Expiry_Date__c < Date.today()) {
            return new ConsentEligibilityService.EligibilityResult(false, 'CONSENT_EXPIRED');
        }
        if (
            expectedAccountId != null &&
            isPrehireEmploymentStatus(consentRecord.Employment_Status__c) &&
            consentRecord.Report_Use_Count__c != null &&
            consentRecord.Report_Use_Count__c >= 1
        ) {
            return new ConsentEligibilityService.EligibilityResult(false, 'PREHIRE_ALREADY_USED');
        }
        return new ConsentEligibilityService.EligibilityResult(true, 'ALLOWED');
    }

    private static Boolean isPrehireEmploymentStatus(String employmentStatus) {
        if (String.isBlank(employmentStatus)) {
            return false;
        }
        String normalized = employmentStatus.trim().toLowerCase();
        return normalized == 'pre-hire'
            || normalized == 'prehire'
            || normalized == 'new hire'
            || normalized == 'newhire';
    }

    private static Reports__c buildReportRecord(
        ReportUploadRow row,
        Map<String, Contact> contactByEmail,
        Id batchId
    ) {
        Date today = Date.today();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Reports__c.fields.getMap();
        Reports__c rec = new Reports__c();
        String rawEmail = resolveRawEmail(row);
        String trimmedEmail = trimVal(rawEmail);

        putEmailField(rec, fieldMap, trimmedEmail);
        putBatchReference(rec, fieldMap, batchId);

        String emailKey = normalizeEmail(rawEmail);
        if (contactByEmail.containsKey(emailKey)) {
            if (fieldMap.containsKey(FLD_CONSENT_STATUS)) {
                rec.put(FLD_CONSENT_STATUS, STATUS_UPDATED_CONSENT);
            }
            if (fieldMap.containsKey(FLD_UPDATED_DATE)) {
                rec.put(FLD_UPDATED_DATE, today);
            }
        } else {
            if (fieldMap.containsKey(FLD_CONSENT_STATUS)) {
                rec.put(FLD_CONSENT_STATUS, STATUS_NO_VALID_CONSENT);
            }
            if (fieldMap.containsKey(FLD_UPDATED_DATE) && isUpdatedDateRequired()) {
                rec.put(FLD_UPDATED_DATE, today);
            }
        }
        return rec;
    }

    private static Id resolveDataSubjectIdByEmail(ReportUploadRow row, Map<String, Contact> contactByEmail) {
        if (row == null || contactByEmail == null || contactByEmail.isEmpty()) {
            return null;
        }
        String emailKey = normalizeEmail(resolveRawEmail(row));
        Contact matchedContact = String.isBlank(emailKey) ? null : contactByEmail.get(emailKey);
        return matchedContact == null ? null : matchedContact.Id;
    }

    private static void putEmailField(SObject target, Map<String, Schema.SObjectField> fieldMap, String emailValue) {
        if (target == null || fieldMap == null) {
            return;
        }
        String emailFieldApiName = resolveReportEmailFieldApiName();
        if (String.isNotBlank(emailFieldApiName) && fieldMap.containsKey(emailFieldApiName)) {
            target.put(emailFieldApiName, emailValue);
        }
    }

    private static String resolveReportEmailFieldApiName() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Reports__c.fields.getMap();
        for (String candidate : REPORT_EMAIL_FIELD_CANDIDATES) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private static void putBatchReference(SObject target, Map<String, Schema.SObjectField> fieldMap, Id batchId) {
        if (target == null || fieldMap == null || batchId == null) {
            return;
        }
        setReferenceOrText(target, fieldMap, REPORT_BATCH_LOOKUP_CANDIDATES, batchId);
        for (String textCandidate : REPORT_BATCH_TEXT_CANDIDATES) {
            if (!fieldMap.containsKey(textCandidate)) {
                continue;
            }
            Schema.DisplayType type = fieldMap.get(textCandidate).getDescribe().getType();
            if (type == Schema.DisplayType.REFERENCE || type == Schema.DisplayType.ID) {
                target.put(textCandidate, batchId);
            } else {
                target.put(textCandidate, String.valueOf(batchId));
            }
            break;
        }
    }

    private static void setReferenceOrText(
        SObject target,
        Map<String, Schema.SObjectField> fieldMap,
        List<String> candidateFields,
        Id idValue
    ) {
        if (target == null || fieldMap == null || candidateFields == null || idValue == null) {
            return;
        }
        for (String fieldApiName : candidateFields) {
            if (!fieldMap.containsKey(fieldApiName)) {
                continue;
            }
            Schema.DisplayType type = fieldMap.get(fieldApiName).getDescribe().getType();
            if (type == Schema.DisplayType.REFERENCE || type == Schema.DisplayType.ID) {
                target.put(fieldApiName, idValue);
            } else {
                target.put(fieldApiName, String.valueOf(idValue));
            }
            return;
        }
    }

    private static Boolean isUpdatedDateRequired() {
        Schema.SObjectField fld = Schema.SObjectType.Reports__c.fields.getMap().get(FLD_UPDATED_DATE);
        if (fld == null) {
            return false;
        }
        return !fld.getDescribe().isNillable();
    }

    private static RowError rowError(Integer rowNumber, String fieldName, String value, String message) {
        RowError e = new RowError();
        e.rowNumber = rowNumber;
        e.fieldName = fieldName;
        e.value = value;
        e.message = message;
        return e;
    }

    private static Exception__c buildException(
        Id batchId,
        Integer excelRowNumber,
        RowValidationError error,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        Exception__c ex = new Exception__c();
        ex.Exception_Field_Name__c = error == null ? null : error.fieldName;
        ex.Field_Value__c = normalizeExceptionFieldValue(error == null ? null : error.fieldValue);
        ex.Exception_Message__c = error == null ? null : error.message;
        ex.Source__c = SOURCE_REPORT_UPLOAD;

        if (fieldMap.containsKey(FLD_EXCEPTION_BATCH_LOOKUP)) {
            ex.put(FLD_EXCEPTION_BATCH_LOOKUP, batchId);
        }
        if (fieldMap.containsKey(FLD_EXCEPTION_BATCH_TEXT)) {
            ex.put(FLD_EXCEPTION_BATCH_TEXT, batchId == null ? null : String.valueOf(batchId));
        }
        if (fieldMap.containsKey(FLD_EXCEPTION_EXCEL_ROW_NUMBER)) {
            ex.put(FLD_EXCEPTION_EXCEL_ROW_NUMBER, excelRowNumber);
        }
        return ex;
    }

    private static String normalizeExceptionFieldValue(String fieldValue) {
        String trimmed = trimVal(fieldValue);
        return String.isBlank(trimmed) ? 'Blank' : trimmed;
    }

    private static Batch__c createReportUploadBatch(
        Integer totalRecords,
        Integer validatedRecords,
        Integer failedValidationRecords
    ) {
        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        Batch__c batch = new Batch__c();
        if (batchFields.containsKey(FLD_BATCH_SOURCE)) {
            batch.put(FLD_BATCH_SOURCE, SOURCE_REPORT_UPLOAD);
        }
        if (batchFields.containsKey(FLD_BATCH_TOTAL_RECORDS)) {
            batch.put(FLD_BATCH_TOTAL_RECORDS, totalRecords == null ? 0 : totalRecords);
        }
        if (batchFields.containsKey(FLD_BATCH_VALIDATED_RECORDS)) {
            batch.put(FLD_BATCH_VALIDATED_RECORDS, validatedRecords == null ? 0 : validatedRecords);
        }
        if (batchFields.containsKey(FLD_BATCH_FAILED_VALIDATION_RECORDS)) {
            batch.put(FLD_BATCH_FAILED_VALIDATION_RECORDS, failedValidationRecords == null ? 0 : failedValidationRecords);
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Batch__c>{ batch });
        List<SObject> creatable = decision.getRecords();
        if (creatable.isEmpty()) {
            throw new AuraHandledException('Failed to create Batch record.');
        }
        Database.SaveResult saveResult = Database.insert(creatable[0], false);
        if (!saveResult.isSuccess()) {
            String msg = saveResult.getErrors().isEmpty() ? 'Batch insert failed.' : saveResult.getErrors()[0].getMessage();
            throw new AuraHandledException('Failed to create Batch record: ' + msg);
        }
        return (Batch__c) creatable[0];
    }

    private static void saveUploadedFileToBatch(Id batchId, String fileName, String fileBase64, String contentType) {
        if (batchId == null || String.isBlank(fileName) || String.isBlank(fileBase64)) {
            throw new AuraHandledException('Uploaded file is missing. Please select a file and try again.');
        }
        if (!Schema.sObjectType.ContentVersion.isCreateable()) {
            throw new AuraHandledException('You do not have permission to upload files.');
        }

        Blob fileBlob;
        try {
            fileBlob = EncodingUtil.base64Decode(fileBase64);
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to decode uploaded file.');
        }
        if (fileBlob == null || fileBlob.size() == 0) {
            throw new AuraHandledException('Uploaded file content is empty.');
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName.contains('.') ? fileName.substringBeforeLast('.') : fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = fileBlob;
        cv.FirstPublishLocationId = batchId;
        if (String.isNotBlank(contentType)) {
            cv.Description = 'Report Upload (' + contentType + ')';
        }
        insert cv;
    }

    private static void updateReportUploadBatchCounts(
        Id batchId,
        Integer totalRecords,
        Integer validatedRecords,
        Integer failedValidationRecords
    ) {
        if (batchId == null) {
            return;
        }
        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        Batch__c toUpdate = new Batch__c(Id = batchId);
        Boolean hasUpdate = false;
        if (batchFields.containsKey(FLD_BATCH_TOTAL_RECORDS)) {
            toUpdate.put(FLD_BATCH_TOTAL_RECORDS, totalRecords == null ? 0 : totalRecords);
            hasUpdate = true;
        }
        if (batchFields.containsKey(FLD_BATCH_VALIDATED_RECORDS)) {
            toUpdate.put(FLD_BATCH_VALIDATED_RECORDS, validatedRecords == null ? 0 : validatedRecords);
            hasUpdate = true;
        }
        if (batchFields.containsKey(FLD_BATCH_FAILED_VALIDATION_RECORDS)) {
            toUpdate.put(FLD_BATCH_FAILED_VALIDATION_RECORDS, failedValidationRecords == null ? 0 : failedValidationRecords);
            hasUpdate = true;
        }
        if (!hasUpdate) {
            return;
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Batch__c>{ toUpdate });
        List<SObject> updateable = decision.getRecords();
        if (!updateable.isEmpty()) {
            Database.update(updateable[0], false);
        }
    }

    private static String normalizeEmail(String raw) {
        return BatchExcelUploadValidationService.normalizeEmail(raw);
    }

    private static String trimVal(String raw) {
        return raw == null ? null : raw.trim();
    }
}