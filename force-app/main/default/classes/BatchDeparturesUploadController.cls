/**
 * Excel import for Departure__c from Partner Central.
 * Matches Contact by Email to set Consent_Status__c and Updated_Date__c.
 *
 * Duplicate Email (trim + lowercase):
 * - Within file: first row -> Departure__c; subsequent -> Exception__c
 * - Already in Departure__c.Email__c -> Exception__c, no insert
 *
 * Test scenarios:
 * 1. File duplicate: first imports, second Exception__c
 * 2. Email exists in Departure__c.Email__c -> Exception__c, no Departure insert
 * 3. Exception: Field_Value__c=email, Message=Duplicate Email, Source=Departure Upload
 */
public with sharing class BatchDeparturesUploadController {
    public static final String STATUS_UPDATED_CONSENT = 'Updated Consent';
    public static final String STATUS_NO_VALID_CONSENT = 'No Valid Consent';

    public static final String SOURCE_DEPARTURE_UPLOAD = 'Departure Upload';
    public static final String EXC_MSG_DUPLICATE_EMAIL = 'Duplicate Email';
    public static final String EXC_FIELD_NAME_EMAIL = 'Email Address';
    public static final String EXC_FIELD_NAME_DEPARTURE_RECORD = 'Departure Record';
    public static final String EXC_FIELD_NAME_ACCOUNT = 'Account';
    public static final String EXC_FIELD_NAME_EMPLOYMENT_STATUS = 'Employment Status';
    public static final String EXC_FIELD_NAME_DEPARTURE_STATUS = 'Departure Status';
    public static final String EXC_MSG_RECORD_NOT_FOUND =
        'Departure Record Not Found: Departure upload has no matching Existing Hire.';
    public static final String EXC_MSG_ACCOUNT_MISMATCH =
        'Data Subject Account Mismatch: The uploaded departure record does not belong to the current client account.';
    public static final String EXC_MSG_PREHIRE_NOT_APPLICABLE =
        'Departure Not Applicable to Pre-hire: Departure upload is only applicable to Existing Hire records.';
    public static final String EXC_MSG_ALREADY_DEPARTED =
        'Data Subject Already Departed: The matched Data Subject is already marked as departed.';
    private static final String EMPLOYMENT_STATUS_EXISTING_HIRE = 'Existing Hire';
    private static final String EMPLOYMENT_STATUS_PRE_HIRE = 'Pre-hire';
    private static final Set<String> DEPARTED_STATUS_TOKENS = new Set<String>{
        'departed',
        'departure',
        'already departed',
        'inactive'
    };

    private static final String FLD_EMAIL = 'Email__c';
    private static final String FLD_DEPARTURE_DATE = 'Departure_Date__c';
    private static final String FLD_CONSENT_STATUS = 'Consent_Status__c';
    private static final String FLD_UPDATED_DATE = 'Updated_Date__c';
    private static final String FLD_CONTACT_EMAIL = 'Email';
    private static final String FLD_CONTACT_EMPLOYMENT_STATUS = 'Employment_Status__c';
    private static final String FLD_CONTACT_LIFECYCLE_STAGE = 'Data_Subject_Lifecycle_Stage__c';
    private static final String FLD_CONTACT_CURRENT_CONSENT_STATUS = 'Current_Consent_Status__c';
    private static final String FLD_CONTACT_WITHDRAWAL_SOURCE = 'Withdrawal_Source__c';
    private static final String FLD_CONTACT_WITHDRAWAL_STATUS = 'Withdrawal_Status__c';
    private static final String FLD_CONTACT_WITHDRAWAL_DATE = 'Withdrawal_Date__c';
    private static final String FLD_CONTACT_WITHDRAWAL_DATE_TIME = 'Withdrawal_Date_Time__c';
    private static final String FLD_CONTACT_REPORT_ELIGIBILITY_STATUS = 'Report_Eligibility_Status__c';
    private static final String FLD_CONTACT_DEPARTURE_REASON = 'Departure_Reason__c';
    private static final String FLD_CONSENT_DATA_SUBJECT = 'Data_Subject__c';
    private static final String FLD_CONSENT_STATUS_OBJECT = 'Consent_Status__c';
    private static final String FLD_CONSENT_REVOKED_AT = 'Revoked_At__c';
    private static final String FLD_CONSENT_ACTION_TYPE = 'Action_Type__c';
    private static final String FLD_CONSENT_WITHDRAWN_BY_CLIENT = 'Withdrawn_By_Client__c';
    private static final String FLD_CONSENT_WITHDRAWAL_BY = 'Withdrawal_By__c';
    private static final String FLD_CONSENT_WITHDRAWAL_CHANNEL = 'Withdrawal_Channel__c';
    private static final String FLD_CONSENT_WITHDRAWN_DATE = 'Consent_Withdrawn_Date__c';
    private static final String FLD_CONSENT_DEPARTURE_REASON = 'Departure_Reason__c';
    private static final Set<String> ACTIVE_CONSENT_STATUSES = new Set<String>{ 'Active', 'Consent Valid', 'Valid', 'Authorized' };
    private static final String CONSENT_ACTION_REVOKED = 'Consent Revoked';
    private static final String CONSENT_ACTION_WITHDRAWN = 'Consent Withdrawn';
    private static final String CONSENT_CHANNEL_CLIENT_ON_BEHALF = 'Client on behalf';
    private static final String CONTACT_WITHDRAWAL_SOURCE_CLIENT = 'Client';
    private static final String CONTACT_WITHDRAWAL_STATUS_COMPLETED = 'Withdrawn / Completed';
    private static final String REPORT_ELIGIBILITY_BLOCKED = 'Blocked';
    private static final String FLD_BATCH_SOURCE = 'Source__c';
    private static final String FLD_BATCH_TOTAL_RECORDS = 'Total_Records__c';
    private static final String FLD_BATCH_VALIDATED_RECORDS = 'Validated_Records__c';
    private static final String FLD_BATCH_FAILED_VALIDATION_RECORDS = 'Failed_Validation_Records__c';
    private static final String FLD_BATCH_ID_TEXT = 'Batch_ID__c';
    private static final String FLD_EXCEPTION_BATCH_LOOKUP = 'Batch__c';
    private static final String FLD_EXCEPTION_BATCH_TEXT = 'Batch_Id__c';
    private static final String FLD_EXCEPTION_EXCEL_ROW_NUMBER = 'Excel_Row_Number__c';
    private static final List<String> BATCH_LOOKUP_CANDIDATES = new List<String>{ 'Batch__c', 'Batch__c__c', 'Related_Batch__c' };

    private static final Pattern ISO_DATE_PATTERN = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}$');

    @TestVisible
    private static Id testAccountOverride;

    public class DepartureUploadRow {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String emailAddress;
        @AuraEnabled public String departureDate;
    }

    public class RowError {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String value;
        @AuraEnabled public String message;
    }

    public class ValidationResult {
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public Integer validRows;
        @AuraEnabled public Integer errorRows;
        @AuraEnabled public List<RowError> errors;
    }

    public class UploadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public Integer successRows;
        @AuraEnabled public Integer exceptionRows;
        @AuraEnabled public Integer createdExceptions;
        @AuraEnabled public String message;
        @AuraEnabled public Integer insertedRows;
        @AuraEnabled public Integer updatedConsentRows;
        @AuraEnabled public Integer noValidConsentRows;
        @AuraEnabled public Integer skippedDuplicateCount;
        @AuraEnabled public Integer duplicateInFileCount;
        @AuraEnabled public Integer duplicateExistingCount;
        @AuraEnabled public Integer exceptionCreatedCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<RowError> errors;
        @AuraEnabled public Id batchId;
        @AuraEnabled public Integer validatedRecords;
        @AuraEnabled public Integer failedValidationRecords;
    }

    public class RowValidationError {
        public String fieldName;
        public String fieldValue;
        public String message;

        public RowValidationError(String fieldName, String fieldValue, String message) {
            this.fieldName = fieldName;
            this.fieldValue = fieldValue;
            this.message = message;
        }
    }

    private class DepartureMatchContext {
        public Map<String, List<Contact>> contactsByEmail = new Map<String, List<Contact>>();
    }

    @AuraEnabled
    public static ValidationResult validateRows(String rowsJson) {
        List<DepartureUploadRow> rows = (List<DepartureUploadRow>) JSON.deserialize(rowsJson, List<DepartureUploadRow>.class);
        return validateAll(rows);
    }

    @AuraEnabled
    public static UploadResult importDepartures(String rowsJson) {
        List<DepartureUploadRow> rows = (List<DepartureUploadRow>) JSON.deserialize(rowsJson, List<DepartureUploadRow>.class);
        return importDeparturesInternal(rows, null);
    }

    @AuraEnabled
    public static UploadResult uploadDepartureDataWithBatch(
        String recordJson,
        Integer totalRecords,
        Integer validatedRecords,
        Integer failedValidationRecords,
        String fileName,
        String fileBase64,
        String contentType
    ) {
        Savepoint sp = Database.setSavepoint();
        try {
            List<DepartureUploadRow> records = (List<DepartureUploadRow>) JSON.deserialize(recordJson, List<DepartureUploadRow>.class);
            List<DepartureUploadRow> failedRows = new List<DepartureUploadRow>();
            if (records == null || records.isEmpty()) {
                throw new AuraHandledException('No rows to import.');
            }
            if (!Schema.sObjectType.Batch__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create batch records.');
            }

            Integer resolvedTotalRecords = totalRecords;
            if (resolvedTotalRecords == null) {
                Integer failedRowsCount = failedRows == null ? 0 : failedRows.size();
                resolvedTotalRecords = records.size() + failedRowsCount;
            }
            Integer resolvedValidatedRecords = validatedRecords == null ? records.size() : validatedRecords;
            Integer resolvedFailedValidationRecords = failedValidationRecords == null
                ? Math.max(0, resolvedTotalRecords - resolvedValidatedRecords)
                : failedValidationRecords;

            Batch__c batchRecord = createDepartureUploadBatch(
                resolvedTotalRecords,
                resolvedValidatedRecords,
                resolvedFailedValidationRecords
            );
            saveUploadedFileToBatch(batchRecord.Id, fileName, fileBase64, contentType);

            UploadResult result = importDeparturesInternal(records, batchRecord.Id);
            Integer finalValidatedRecords = result.insertedRows == null ? 0 : result.insertedRows;
            Integer finalFailedRecords = Math.max(0, resolvedTotalRecords - finalValidatedRecords);
            updateDepartureUploadBatchCounts(
                batchRecord.Id,
                resolvedTotalRecords,
                finalValidatedRecords,
                finalFailedRecords
            );

            result.batchId = batchRecord.Id;
            result.totalRows = resolvedTotalRecords;
            result.validatedRecords = finalValidatedRecords;
            result.failedValidationRecords = finalFailedRecords;
            result.successRows = finalValidatedRecords;
            return result;
        } catch (Exception e) {
            System.debug('Error in importDepartures: ' + e.getMessage());
            System.debug('Error type: ' + e.getTypeName());
            System.debug('Error line: ' + e.getLineNumber());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('Total records: ' + totalRecords);
            System.debug('Validated records: ' + validatedRecords);
            System.debug('Failed validation records: ' + failedValidationRecords);
            System.debug('File name: ' + fileName);
            System.debug('File base64: ' + fileBase64);
            System.debug('Content type: ' + contentType);
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static UploadResult importDeparturesInternal(List<DepartureUploadRow> rows, Id batchId) {
        if (!Schema.sObjectType.Departure__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create departure records.');
        }

        ValidationResult vr = validateAll(rows);
        if (vr.errorRows != null && vr.errorRows > 0) {
            throw new AuraHandledException(formatValidationErrors(vr.errors));
        }
        if (rows == null || rows.isEmpty()) {
            throw new AuraHandledException('No rows to import.');
        }

        if (requiresExceptionRecords(rows) && !Schema.sObjectType.Exception__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create Exception records.');
        }

        UploadResult result = new UploadResult();
        result.success = true;
        result.totalRows = rows.size();
        result.successRows = 0;
        result.exceptionRows = 0;
        result.createdExceptions = 0;
        result.message = 'Departure upload completed successfully.';
        result.insertedRows = 0;
        result.updatedConsentRows = 0;
        result.noValidConsentRows = 0;
        result.skippedDuplicateCount = 0;
        result.duplicateInFileCount = 0;
        result.duplicateExistingCount = 0;
        result.exceptionCreatedCount = 0;
        result.errorCount = 0;
        result.errors = new List<RowError>();
        result.batchId = batchId;
        result.validatedRecords = 0;
        result.failedValidationRecords = result.totalRows;

        Set<String> seenEmails = new Set<String>();
        Set<String> existingDepartureEmails = queryExistingDepartureEmails(collectTrimmedEmailsForQuery(rows));
        List<DepartureUploadRow> rowsForDeparture = new List<DepartureUploadRow>();
        List<Exception__c> exceptionsToInsert = new List<Exception__c>();
        List<Integer> exceptionRowNumbers = new List<Integer>();
        Id currentAccountId = resolveAccountId();
        DepartureMatchContext matchContext = buildDepartureMatchContext(rows);
        Boolean canCreateExceptions = Schema.sObjectType.Exception__c.isCreateable();

        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            Integer rn = row.rowNumber != null ? row.rowNumber : 0;
            String normalizedEmail = normalizeEmail(row.emailAddress);

            if (seenEmails.contains(normalizedEmail)) {
                addDuplicateEmailException(
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    rn,
                    trimVal(row.emailAddress),
                    SOURCE_DEPARTURE_UPLOAD,
                    result,
                    batchId
                );
                result.duplicateInFileCount++;
                continue;
            }

            if (existingDepartureEmails.contains(normalizedEmail)) {
                addDuplicateEmailException(
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    rn,
                    trimVal(row.emailAddress),
                    SOURCE_DEPARTURE_UPLOAD,
                    result,
                    batchId
                );
                result.duplicateExistingCount++;
                seenEmails.add(normalizedEmail);
                continue;
            }

            RowValidationError rowValidationError = validateDepartureRow(row, currentAccountId, matchContext);
            if (rowValidationError != null) {
                if (!canCreateExceptions) {
                    throw new AuraHandledException('You do not have permission to create Exception records.');
                }
                addRowLevelException(
                    rowValidationError,
                    rn,
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    result,
                    batchId
                );
                seenEmails.add(normalizedEmail);
                continue;
            }

            seenEmails.add(normalizedEmail);
            rowsForDeparture.add(row);
        }

        if (!rowsForDeparture.isEmpty()) {
            Map<String, Id> contactByEmail = loadContactIdsByEmail(rowsForDeparture);
            Set<Id> contactsWithRevokedConsent = revokeLatestActiveConsents(contactByEmail, rowsForDeparture, result);
            updateContactsForDeparture(contactByEmail.values(), rowsForDeparture, result);
            notifyDepartureRevocation(contactsWithRevokedConsent, result, batchId);
            List<Departure__c> toInsert = buildDepartureRecords(rowsForDeparture, contactByEmail, contactsWithRevokedConsent, batchId);
            List<Integer> departureRowNumbers = new List<Integer>();
            for (DepartureUploadRow row : rowsForDeparture) {
                departureRowNumbers.add(row.rowNumber != null ? row.rowNumber : 0);
            }

            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
            List<Departure__c> creatable = (List<Departure__c>) decision.getRecords();

            Database.SaveResult[] depResults = Database.insert(creatable, false);
            for (Integer i = 0; i < depResults.size(); i++) {
                Database.SaveResult sr = depResults[i];
                if (sr.isSuccess()) {
                    result.insertedRows++;
                    Departure__c dep = creatable[i];
                    String st = (String) dep.get(FLD_CONSENT_STATUS);
                    if (STATUS_UPDATED_CONSENT.equals(st)) {
                        result.updatedConsentRows++;
                    } else if (STATUS_NO_VALID_CONSENT.equals(st)) {
                        result.noValidConsentRows++;
                    }
                } else {
                    result.errorCount++;
                    Integer rn = i < departureRowNumbers.size() ? departureRowNumbers[i] : 0;
                    String msg = sr.getErrors().isEmpty() ? 'Insert failed.' : sr.getErrors()[0].getMessage();
                    result.errors.add(err(rn, 'Departure', null, msg));
                }
            }
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
                    Integer rn = i < exceptionRowNumbers.size() ? exceptionRowNumbers[i] : 0;
                    String msg = sr.getErrors().isEmpty() ? 'Insert failed.' : sr.getErrors()[0].getMessage();
                    result.errors.add(err(rn, 'Exception', null, EXC_MSG_DUPLICATE_EMAIL + ': ' + msg));
                }
            }
        }

        result.successRows = result.insertedRows;
        result.validatedRecords = result.insertedRows;
        result.failedValidationRecords = Math.max(0, (result.totalRows == null ? 0 : result.totalRows) - result.insertedRows);
        if (result.exceptionRows > 0) {
            result.message = 'Departure upload completed with exceptions. Please review the Exceptions list.';
        }
        return result;
    }

    private static void addRowLevelException(
        RowValidationError rowValidationError,
        Integer rowNumber,
        List<Exception__c> exceptionsToInsert,
        List<Integer> exceptionRowNumbers,
        UploadResult result,
        Id batchId
    ) {
        exceptionsToInsert.add(buildDepartureException(rowValidationError, batchId, rowNumber));
        exceptionRowNumbers.add(rowNumber);
        result.exceptionRows++;
    }

    private static void addDuplicateEmailException(
        List<Exception__c> exceptionsToInsert,
        List<Integer> exceptionRowNumbers,
        Integer rowNumber,
        String emailRaw,
        String source,
        UploadResult result,
        Id batchId
    ) {
        RowValidationError duplicateError = new RowValidationError(
            EXC_FIELD_NAME_EMAIL,
            emailRaw,
            EXC_MSG_DUPLICATE_EMAIL
        );
        exceptionsToInsert.add(buildDepartureException(duplicateError, batchId, rowNumber));
        exceptionRowNumbers.add(rowNumber);
        result.skippedDuplicateCount++;
        result.exceptionRows++;
    }

    private static Boolean requiresExceptionRecords(List<DepartureUploadRow> rows) {
        if (hasDuplicateEmailsInFile(rows)) {
            return true;
        }
        Set<String> trimmed = collectTrimmedEmailsForQuery(rows);
        return !queryExistingDepartureEmails(trimmed).isEmpty();
    }

    private static Set<String> collectTrimmedEmailsForQuery(List<DepartureUploadRow> rows) {
        Set<String> emails = new Set<String>();
        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            String trimmed = trimVal(row.emailAddress);
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
            String lower = email.toLowerCase();
            expanded.add(lower);
        }
        return expanded;
    }

    private static Set<String> queryExistingDepartureEmails(Set<String> emailValuesForQuery) {
        Set<String> existing = new Set<String>();
        if (emailValuesForQuery.isEmpty() || !isDepartureReadable() || !isDepartureFieldAccessible(FLD_EMAIL)) {
            return existing;
        }

        Set<String> queryEmails = expandEmailsForSoqlIn(emailValuesForQuery);
        for (Departure__c dep : [SELECT Email__c FROM Departure__c WHERE Email__c IN :queryEmails]) {
            String normalized = normalizeEmail((String) dep.get(FLD_EMAIL));
            if (String.isNotBlank(normalized)) {
                existing.add(normalized);
            }
        }
        return existing;
    }

    private static Boolean isDepartureReadable() {
        return Schema.sObjectType.Departure__c.isAccessible();
    }

    private static Boolean isDepartureFieldAccessible(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        Schema.SObjectField fld = Schema.SObjectType.Departure__c.fields.getMap().get(fieldApiName);
        return fld != null && fld.getDescribe().isAccessible();
    }

    private static Boolean hasDuplicateEmailsInFile(List<DepartureUploadRow> rows) {
        Set<String> seen = new Set<String>();
        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            String normalized = normalizeEmail(row.emailAddress);
            if (String.isBlank(normalized)) {
                continue;
            }
            if (seen.contains(normalized)) {
                return true;
            }
            seen.add(normalized);
        }
        return false;
    }

    private static String normalizeEmail(String raw) {
        return BatchExcelUploadValidationService.normalizeEmail(raw);
    }

    private static ValidationResult validateAll(List<DepartureUploadRow> rows) {
        ValidationResult vr = new ValidationResult();
        vr.totalRows = rows == null ? 0 : rows.size();
        vr.validRows = 0;
        vr.errorRows = 0;
        vr.errors = new List<RowError>();

        if (rows == null || rows.isEmpty()) {
            vr.errors.add(err(0, 'File', null, 'Upload file contains no data rows.'));
            vr.errorRows = 1;
            return vr;
        }

        Set<Integer> rowsWithErrors = new Set<Integer>();

        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            Integer rn = row.rowNumber != null ? row.rowNumber : 0;
            List<RowError> rowErrors = validateRow(row);
            if (!rowErrors.isEmpty()) {
                rowsWithErrors.add(rn);
                vr.errors.addAll(rowErrors);
            }
        }

        vr.errorRows = rowsWithErrors.size();
        vr.validRows = vr.totalRows - vr.errorRows;
        return vr;
    }

    private static RowValidationError validateDepartureRow(
        DepartureUploadRow row,
        Id currentAccountId,
        DepartureMatchContext matchContext
    ) {
        String fallbackValue = resolveFallbackFieldValue(row);
        List<Contact> matchedContacts = getMatchedContactsForRow(row, matchContext);
        if (matchedContacts.isEmpty()) {
            return new RowValidationError(
                EXC_FIELD_NAME_DEPARTURE_RECORD,
                fallbackValue,
                EXC_MSG_RECORD_NOT_FOUND
            );
        }

        List<Contact> currentAccountMatches = new List<Contact>();
        for (Contact c : matchedContacts) {
            if (c != null && c.AccountId == currentAccountId) {
                currentAccountMatches.add(c);
            }
        }
        if (currentAccountMatches.isEmpty()) {
            return new RowValidationError(
                EXC_FIELD_NAME_ACCOUNT,
                fallbackValue,
                EXC_MSG_ACCOUNT_MISMATCH
            );
        }

        for (Contact c : currentAccountMatches) {
            String employmentStatus = normalizeEmploymentStatus(getStringFieldValue(c, FLD_CONTACT_EMPLOYMENT_STATUS));
            if (EMPLOYMENT_STATUS_PRE_HIRE.equals(employmentStatus)) {
                return new RowValidationError(
                    EXC_FIELD_NAME_EMPLOYMENT_STATUS,
                    EMPLOYMENT_STATUS_PRE_HIRE,
                    EXC_MSG_PREHIRE_NOT_APPLICABLE
                );
            }
        }

        for (Contact c : currentAccountMatches) {
            if (isContactAlreadyDeparted(c)) {
                return new RowValidationError(
                    EXC_FIELD_NAME_DEPARTURE_STATUS,
                    resolveDepartureStatusValue(c),
                    EXC_MSG_ALREADY_DEPARTED
                );
            }
        }

        for (Contact c : currentAccountMatches) {
            String employmentStatus = normalizeEmploymentStatus(getStringFieldValue(c, FLD_CONTACT_EMPLOYMENT_STATUS));
            if (EMPLOYMENT_STATUS_EXISTING_HIRE.equals(employmentStatus)) {
                return null;
            }
        }

        return new RowValidationError(
            EXC_FIELD_NAME_DEPARTURE_RECORD,
            fallbackValue,
            EXC_MSG_RECORD_NOT_FOUND
        );
    }

    private static List<RowError> validateRow(DepartureUploadRow row) {
        List<RowError> errors = new List<RowError>();
        Integer rn = row.rowNumber != null ? row.rowNumber : 0;

        String email = trimVal(row.emailAddress);
        if (String.isBlank(email)) {
            errors.add(err(rn, 'Email Address', row.emailAddress, 'Email Address is required.'));
        } else if (!BatchExcelUploadValidationService.isValidEmail(email)) {
            errors.add(err(rn, 'Email Address', row.emailAddress, 'Invalid email format.'));
        }

        String depDate = trimVal(row.departureDate);
        if (String.isBlank(depDate)) {
            errors.add(err(rn, 'Departure Date', row.departureDate, 'Departure Date is required.'));
        } else if (!isValidIsoDate(depDate)) {
            errors.add(
                err(rn, 'Departure Date', row.departureDate, 'Departure Date must be a valid date in YYYY-MM-DD format.')
            );
        }

        return errors;
    }

    private static Map<String, Id> loadContactIdsByEmail(List<DepartureUploadRow> rows) {
        Set<String> emailValues = new Set<String>();
        for (DepartureUploadRow row : rows) {
            if (row == null || String.isBlank(trimVal(row.emailAddress))) {
                continue;
            }
            emailValues.add(trimVal(row.emailAddress));
        }

        Map<String, Id> contactByEmail = new Map<String, Id>();
        if (emailValues.isEmpty() || !Schema.SObjectType.Contact.isAccessible()) {
            return contactByEmail;
        }

        for (Contact c : [SELECT Id, Email FROM Contact WHERE Email IN :emailValues]) {
            if (String.isNotBlank(c.Email)) {
                contactByEmail.put(c.Email.trim().toLowerCase(), c.Id);
            }
        }
        return contactByEmail;
    }

    private static DepartureMatchContext buildDepartureMatchContext(List<DepartureUploadRow> rows) {
        DepartureMatchContext context = new DepartureMatchContext();
        if (rows == null || rows.isEmpty() || !Schema.SObjectType.Contact.isAccessible()) {
            return context;
        }

        Set<String> emailKeys = new Set<String>();
        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            String normalizedEmail = normalizeEmail(row.emailAddress);
            if (String.isNotBlank(normalizedEmail)) {
                emailKeys.add(normalizedEmail);
            }
        }
        if (emailKeys.isEmpty()) {
            return context;
        }

        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        Boolean hasEmploymentField = contactFields.containsKey(FLD_CONTACT_EMPLOYMENT_STATUS);
        Boolean hasLifecycleField = contactFields.containsKey(FLD_CONTACT_LIFECYCLE_STAGE);
        Boolean hasCurrentConsentField = contactFields.containsKey(FLD_CONTACT_CURRENT_CONSENT_STATUS);

        String soql = 'SELECT Id, AccountId, Email';
        if (hasEmploymentField) {
            soql += ', ' + FLD_CONTACT_EMPLOYMENT_STATUS;
        }
        if (hasLifecycleField) {
            soql += ', ' + FLD_CONTACT_LIFECYCLE_STAGE;
        }
        if (hasCurrentConsentField) {
            soql += ', ' + FLD_CONTACT_CURRENT_CONSENT_STATUS;
        }
        soql += ' FROM Contact';

        Set<String> emailWhereValues = new Set<String>();
        for (String em : emailKeys) {
            if (String.isBlank(em)) {
                continue;
            }
            emailWhereValues.add(em);
            emailWhereValues.add(em.toLowerCase());
        }

        if (!emailWhereValues.isEmpty()) {
            soql += ' WHERE Email IN :emailWhereValues';
        } else {
            return context;
        }

        for (Contact c : Database.query(soql)) {
            String normalizedEmail = normalizeEmail((String) c.get(FLD_CONTACT_EMAIL));
            if (String.isNotBlank(normalizedEmail)) {
                addContactIndex(context.contactsByEmail, normalizedEmail, c);
            }
        }
        return context;
    }

    private static List<Contact> getMatchedContactsForRow(DepartureUploadRow row, DepartureMatchContext matchContext) {
        String normalizedEmail = normalizeEmail(row == null ? null : row.emailAddress);
        Map<Id, Contact> uniqueMatches = new Map<Id, Contact>();

        if (String.isNotBlank(normalizedEmail) && matchContext.contactsByEmail.containsKey(normalizedEmail)) {
            for (Contact c : matchContext.contactsByEmail.get(normalizedEmail)) {
                uniqueMatches.put(c.Id, c);
            }
        }

        return uniqueMatches.values();
    }

    private static void addContactIndex(Map<String, List<Contact>> indexByValue, String key, Contact contactRec) {
        if (!indexByValue.containsKey(key)) {
            indexByValue.put(key, new List<Contact>());
        }
        indexByValue.get(key).add(contactRec);
    }

    private static String resolveFallbackFieldValue(DepartureUploadRow row) {
        return trimVal(row == null ? null : row.emailAddress);
    }

    private static Exception__c buildDepartureException(RowValidationError error, Id batchId, Integer rowNumber) {
        Exception__c ex = new Exception__c();
        Map<String, Schema.SObjectField> exceptionFields = Schema.SObjectType.Exception__c.fields.getMap();
        ex.Exception_Field_Name__c = error.fieldName;
        ex.Field_Value__c = normalizeExceptionFieldValue(error.fieldValue);
        ex.Exception_Message__c = error.message;
        ex.Source__c = SOURCE_DEPARTURE_UPLOAD;
        if (exceptionFields.containsKey(FLD_EXCEPTION_BATCH_LOOKUP)) {
            ex.put(FLD_EXCEPTION_BATCH_LOOKUP, batchId);
        }
        if (exceptionFields.containsKey(FLD_EXCEPTION_BATCH_TEXT)) {
            ex.put(FLD_EXCEPTION_BATCH_TEXT, batchId == null ? null : String.valueOf(batchId));
        }
        if (exceptionFields.containsKey(FLD_EXCEPTION_EXCEL_ROW_NUMBER)) {
            ex.put(FLD_EXCEPTION_EXCEL_ROW_NUMBER, rowNumber);
        }
        return ex;
    }

    private static String normalizeExceptionFieldValue(String fieldValue) {
        String trimmed = trimVal(fieldValue);
        return String.isBlank(trimmed) ? 'Blank' : trimmed;
    }

    private static String normalizeEmploymentStatus(String raw) {
        String value = trimVal(raw);
        if (String.isBlank(value)) {
            return value;
        }
        if ('Existing Hire'.equalsIgnoreCase(value) || 'Existing'.equalsIgnoreCase(value)) {
            return EMPLOYMENT_STATUS_EXISTING_HIRE;
        }
        if ('Pre-hire'.equalsIgnoreCase(value) || 'Pre Hire'.equalsIgnoreCase(value) || 'Prehire'.equalsIgnoreCase(value)) {
            return EMPLOYMENT_STATUS_PRE_HIRE;
        }
        return value;
    }

    private static String getStringFieldValue(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName)) {
            return null;
        }
        try {
            Object raw = row.get(fieldApiName);
            return raw == null ? null : String.valueOf(raw);
        } catch (Exception e) {
            System.debug('Error getting string field value: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('Field API name: ' + fieldApiName);
            System.debug('Row: ' + row);  
            return null;
        }
    }

    private static Boolean isContactAlreadyDeparted(Contact c) {
        return isDepartureLikeStatus(getStringFieldValue(c, FLD_CONTACT_LIFECYCLE_STAGE)) ||
            isDepartureLikeStatus(getStringFieldValue(c, FLD_CONTACT_CURRENT_CONSENT_STATUS)) ||
            isDepartureLikeStatus(getStringFieldValue(c, FLD_CONTACT_EMPLOYMENT_STATUS));
    }

    private static String resolveDepartureStatusValue(Contact c) {
        String lifecycleStage = trimVal(getStringFieldValue(c, FLD_CONTACT_LIFECYCLE_STAGE));
        if (isDepartureLikeStatus(lifecycleStage)) {
            return lifecycleStage;
        }
        String consentStatus = trimVal(getStringFieldValue(c, FLD_CONTACT_CURRENT_CONSENT_STATUS));
        if (isDepartureLikeStatus(consentStatus)) {
            return consentStatus;
        }
        String employmentStatus = trimVal(getStringFieldValue(c, FLD_CONTACT_EMPLOYMENT_STATUS));
        if (isDepartureLikeStatus(employmentStatus)) {
            return employmentStatus;
        }
        return employmentStatus;
    }

    private static Boolean isDepartureLikeStatus(String rawStatus) {
        String normalized = String.isBlank(rawStatus) ? null : rawStatus.trim().toLowerCase();
        if (String.isBlank(normalized)) {
            return false;
        }
        if (DEPARTED_STATUS_TOKENS.contains(normalized)) {
            return true;
        }
        return normalized.contains('depart');
    }

    private static List<Departure__c> buildDepartureRecords(
        List<DepartureUploadRow> rows,
        Map<String, Id> contactByEmail,
        Set<Id> contactsWithRevokedConsent,
        Id batchId
    ) {
        Date today = Date.today();
        List<Departure__c> records = new List<Departure__c>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Departure__c.fields.getMap();

        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            Departure__c dep = new Departure__c();
            if (fieldMap.containsKey(FLD_EMAIL)) {
                dep.put(FLD_EMAIL, trimVal(row.emailAddress));
            }
            if (fieldMap.containsKey(FLD_DEPARTURE_DATE) && isValidIsoDate(trimVal(row.departureDate))) {
                dep.put(FLD_DEPARTURE_DATE, parseDate(trimVal(row.departureDate)));
            }
            String emailKey = normalizeEmail(row.emailAddress);
            Id contactId = contactByEmail.get(emailKey);
            if (contactId != null && contactsWithRevokedConsent.contains(contactId)) {
                if (fieldMap.containsKey(FLD_CONSENT_STATUS)) {
                    dep.put(FLD_CONSENT_STATUS, STATUS_UPDATED_CONSENT);
                }
                if (fieldMap.containsKey(FLD_UPDATED_DATE)) {
                    dep.put(FLD_UPDATED_DATE, today);
                }
            } else {
                if (fieldMap.containsKey(FLD_CONSENT_STATUS)) {
                    dep.put(FLD_CONSENT_STATUS, STATUS_NO_VALID_CONSENT);
                }
            }
            putBatchReference(dep, fieldMap, batchId);
            records.add(dep);
        }
        return records;
    }

    private static Set<Id> revokeLatestActiveConsents(
        Map<String, Id> contactByEmail,
        List<DepartureUploadRow> rows,
        UploadResult result
    ) {
        Set<Id> revokedContactIds = new Set<Id>();
        if (contactByEmail == null || contactByEmail.isEmpty()) {
            return revokedContactIds;
        }

        Set<Id> candidateContactIds = new Set<Id>(contactByEmail.values());
        Map<Id, Consent__c> latestActiveConsentByContact = queryLatestActiveConsentByContact(candidateContactIds);
        if (latestActiveConsentByContact.isEmpty()) {
            return revokedContactIds;
        }

        Map<Id, List<Integer>> rowNumbersByContact = new Map<Id, List<Integer>>();
        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            Id contactId = contactByEmail.get(normalizeEmail(row.emailAddress));
            if (contactId == null) {
                continue;
            }
            if (!rowNumbersByContact.containsKey(contactId)) {
                rowNumbersByContact.put(contactId, new List<Integer>());
            }
            rowNumbersByContact.get(contactId).add(row.rowNumber == null ? 0 : row.rowNumber);
        }

        Datetime revokedAt = System.now();
        List<Consent__c> updates = new List<Consent__c>();
        List<Id> updateContactIds = new List<Id>();
        for (Id contactId : latestActiveConsentByContact.keySet()) {
            Consent__c activeConsent = latestActiveConsentByContact.get(contactId);
            Consent__c updateRow = buildConsentRevocationUpdate(activeConsent, revokedAt);
            if (updateRow != null) {
                updates.add(updateRow);
                updateContactIds.add(contactId);
            }
        }
        if (updates.isEmpty()) {
            return revokedContactIds;
        }

        Database.SaveResult[] saveResults = Database.update(updates, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult saveResult = saveResults[i];
            Id contactId = i < updateContactIds.size() ? updateContactIds[i] : null;
            if (saveResult.isSuccess()) {
                if (contactId != null) {
                    revokedContactIds.add(contactId);
                }
            } else {
                String msg = saveResult.getErrors().isEmpty() ? 'Consent update failed.' : saveResult.getErrors()[0].getMessage();
                if (contactId != null && rowNumbersByContact.containsKey(contactId)) {
                    for (Integer rn : rowNumbersByContact.get(contactId)) {
                        result.errorCount++;
                        result.errors.add(err(rn, 'Consent', null, msg));
                    }
                } else {
                    result.errorCount++;
                    result.errors.add(err(0, 'Consent', null, msg));
                }
            }
        }

        return revokedContactIds;
    }

    private static void updateContactsForDeparture(
        Iterable<Id> contactIds,
        List<DepartureUploadRow> rows,
        UploadResult result
    ) {
        Set<Id> uniqueContactIds = new Set<Id>();
        if (contactIds != null) {
            for (Id contactId : contactIds) {
                if (contactId != null) {
                    uniqueContactIds.add(contactId);
                }
            }
        }
        if (uniqueContactIds.isEmpty()) {
            return;
        }

        Map<Id, List<Integer>> rowNumbersByContact = new Map<Id, List<Integer>>();
        Map<String, Id> contactByEmail = loadContactIdsByEmail(rows);
        for (DepartureUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            Id contactId = contactByEmail.get(normalizeEmail(row.emailAddress));
            if (contactId == null) {
                continue;
            }
            if (!rowNumbersByContact.containsKey(contactId)) {
                rowNumbersByContact.put(contactId, new List<Integer>());
            }
            rowNumbersByContact.get(contactId).add(row.rowNumber == null ? 0 : row.rowNumber);
        }

        Datetime eventTime = System.now();
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        List<Contact> updates = new List<Contact>();
        List<Id> updateContactIds = new List<Id>();
        for (Id contactId : uniqueContactIds) {
            Contact updateRow = new Contact(Id = contactId);
            Boolean hasUpdate = false;

            // Keep Contact status model synchronized through the canonical state service.
            ConsentStatusModelService.applyContactState(updateRow, ConsentStatusModelService.STATUS_WITHDRAWN);
            if (contactFields.containsKey(FLD_CONTACT_CURRENT_CONSENT_STATUS)) {
                hasUpdate = String.isNotBlank((String) updateRow.get(FLD_CONTACT_CURRENT_CONSENT_STATUS)) || hasUpdate;
            }
            if (contactFields.containsKey(FLD_CONTACT_LIFECYCLE_STAGE)) {
                hasUpdate = String.isNotBlank((String) updateRow.get(FLD_CONTACT_LIFECYCLE_STAGE)) || hasUpdate;
            }
            hasUpdate = setPicklistIfAvailable(
                updateRow,
                contactFields,
                FLD_CONTACT_WITHDRAWAL_SOURCE,
                new List<String>{ CONTACT_WITHDRAWAL_SOURCE_CLIENT, 'System' }
            ) || hasUpdate;
            hasUpdate = setPicklistIfAvailable(
                updateRow,
                contactFields,
                FLD_CONTACT_WITHDRAWAL_STATUS,
                new List<String>{ CONTACT_WITHDRAWAL_STATUS_COMPLETED, 'Review Required' }
            ) || hasUpdate;
            hasUpdate = setPicklistIfAvailable(
                updateRow,
                contactFields,
                FLD_CONTACT_REPORT_ELIGIBILITY_STATUS,
                new List<String>{ REPORT_ELIGIBILITY_BLOCKED, 'Not Eligible', 'Consent Withdrawn' }
            ) || hasUpdate;
            hasUpdate = setTextIfAvailable(
                updateRow,
                contactFields,
                FLD_CONTACT_DEPARTURE_REASON,
                SOURCE_DEPARTURE_UPLOAD
            ) || hasUpdate;
            hasUpdate = setDateLikeIfAvailable(
                updateRow,
                contactFields,
                FLD_CONTACT_WITHDRAWAL_DATE,
                eventTime
            ) || hasUpdate;
            hasUpdate = setDateLikeIfAvailable(
                updateRow,
                contactFields,
                FLD_CONTACT_WITHDRAWAL_DATE_TIME,
                eventTime
            ) || hasUpdate;
            if (hasUpdate) {
                updates.add(updateRow);
                updateContactIds.add(contactId);
            }
        }
        if (updates.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.update(updates, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult saveResult = saveResults[i];
            if (saveResult.isSuccess()) {
                continue;
            }
            Id contactId = i < updateContactIds.size() ? updateContactIds[i] : null;
            String msg = saveResult.getErrors().isEmpty() ? 'Contact update failed.' : saveResult.getErrors()[0].getMessage();
            if (contactId != null && rowNumbersByContact.containsKey(contactId)) {
                for (Integer rn : rowNumbersByContact.get(contactId)) {
                    result.errorCount++;
                    result.errors.add(err(rn, 'Contact', null, msg));
                }
            } else {
                result.errorCount++;
                result.errors.add(err(0, 'Contact', null, msg));
            }
        }
    }

    private static Map<Id, Consent__c> queryLatestActiveConsentByContact(Set<Id> contactIds) {
        Map<Id, Consent__c> latestByContact = new Map<Id, Consent__c>();
        if (contactIds == null || contactIds.isEmpty()) {
            return latestByContact;
        }
        if (!Schema.SObjectType.Consent__c.isAccessible()) {
            return latestByContact;
        }
        for (Consent__c consent : [
            SELECT Id, Data_Subject__c, Consent_Status__c
            FROM Consent__c
            WHERE Data_Subject__c IN :contactIds
            AND Consent_Status__c IN :ACTIVE_CONSENT_STATUSES
            ORDER BY Data_Subject__c ASC, CreatedDate DESC
        ]) {
            if (consent.Data_Subject__c != null && !latestByContact.containsKey(consent.Data_Subject__c)) {
                latestByContact.put(consent.Data_Subject__c, consent);
            }
        }
        return latestByContact;
    }

    private static Consent__c buildConsentRevocationUpdate(Consent__c activeConsent, Datetime revokedAt) {
        if (activeConsent == null || activeConsent.Id == null) {
            return null;
        }
        Map<String, Schema.SObjectField> consentFields = Schema.SObjectType.Consent__c.fields.getMap();
        Consent__c updateRow = new Consent__c(Id = activeConsent.Id);

        if (consentFields.containsKey(FLD_CONSENT_STATUS_OBJECT)) {
            String statusValue = choosePicklistValue(
                consentFields.get(FLD_CONSENT_STATUS_OBJECT).getDescribe(),
                new List<String>{ 'Revoked', 'Withdrawn' }
            );
            if (String.isNotBlank(statusValue)) {
                updateRow.put(FLD_CONSENT_STATUS_OBJECT, statusValue);
            }
        }
        if (consentFields.containsKey(FLD_CONSENT_REVOKED_AT)) {
            updateRow.put(FLD_CONSENT_REVOKED_AT, revokedAt);
        }
        if (consentFields.containsKey(FLD_CONSENT_WITHDRAWN_DATE)) {
            updateRow.put(FLD_CONSENT_WITHDRAWN_DATE, revokedAt);
        }
        if (consentFields.containsKey(FLD_CONSENT_ACTION_TYPE)) {
            String actionValue = choosePicklistValue(
                consentFields.get(FLD_CONSENT_ACTION_TYPE).getDescribe(),
                new List<String>{ CONSENT_ACTION_REVOKED, CONSENT_ACTION_WITHDRAWN, 'Withdraw' }
            );
            if (String.isNotBlank(actionValue)) {
                updateRow.put(FLD_CONSENT_ACTION_TYPE, actionValue);
            }
        }
        if (consentFields.containsKey(FLD_CONSENT_WITHDRAWN_BY_CLIENT)) {
            updateRow.put(FLD_CONSENT_WITHDRAWN_BY_CLIENT, true);
        }
        if (consentFields.containsKey(FLD_CONSENT_WITHDRAWAL_BY)) {
            updateRow.put(FLD_CONSENT_WITHDRAWAL_BY, UserInfo.getUserId());
        }
        if (consentFields.containsKey(FLD_CONSENT_WITHDRAWAL_CHANNEL)) {
            String channelValue = choosePicklistValue(
                consentFields.get(FLD_CONSENT_WITHDRAWAL_CHANNEL).getDescribe(),
                new List<String>{ CONSENT_CHANNEL_CLIENT_ON_BEHALF }
            );
            if (String.isNotBlank(channelValue)) {
                updateRow.put(FLD_CONSENT_WITHDRAWAL_CHANNEL, channelValue);
            }
        }
        if (consentFields.containsKey(FLD_CONSENT_DEPARTURE_REASON)) {
            updateRow.put(FLD_CONSENT_DEPARTURE_REASON, SOURCE_DEPARTURE_UPLOAD);
        }

        return updateRow;
    }

    private static void notifyDepartureRevocation(Iterable<Id> contactIds, UploadResult result, Id batchId) {
        Set<Id> uniqueContactIds = new Set<Id>();
        if (contactIds != null) {
            for (Id contactId : contactIds) {
                if (contactId != null) {
                    uniqueContactIds.add(contactId);
                }
            }
        }
        if (uniqueContactIds.isEmpty()) {
            return;
        }
        try {
            DepartureRevocationNotificationService.notifyClientAndCbs(uniqueContactIds, batchId);
        } catch (Exception ex) {
            result.errorCount++;
            result.errors.add(err(0, 'Notification', null, 'Notification send failed: ' + ex.getMessage()));
        }
    }

    private static Boolean setPicklistIfAvailable(
        SObject target,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName,
        List<String> preferredValues
    ) {
        if (target == null || fieldMap == null || String.isBlank(fieldApiName) || !fieldMap.containsKey(fieldApiName)) {
            return false;
        }
        String value = choosePicklistValue(fieldMap.get(fieldApiName).getDescribe(), preferredValues);
        if (String.isBlank(value)) {
            return false;
        }
        target.put(fieldApiName, value);
        return true;
    }

    private static Boolean setTextIfAvailable(
        SObject target,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName,
        String value
    ) {
        if (
            target == null ||
            fieldMap == null ||
            String.isBlank(fieldApiName) ||
            String.isBlank(value) ||
            !fieldMap.containsKey(fieldApiName)
        ) {
            return false;
        }
        target.put(fieldApiName, value);
        return true;
    }

    private static Boolean setDateLikeIfAvailable(
        SObject target,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName,
        Datetime value
    ) {
        if (target == null || fieldMap == null || String.isBlank(fieldApiName) || value == null || !fieldMap.containsKey(fieldApiName)) {
            return false;
        }
        Schema.DisplayType fieldType = fieldMap.get(fieldApiName).getDescribe().getType();
        if (fieldType == Schema.DisplayType.DATETIME) {
            target.put(fieldApiName, value);
            return true;
        }
        if (fieldType == Schema.DisplayType.DATE) {
            target.put(fieldApiName, Date.newInstance(value.year(), value.month(), value.day()));
            return true;
        }
        return false;
    }

    private static String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
        if (describe == null || preferredValues == null) {
            return null;
        }
        for (String preferred : preferredValues) {
            if (String.isBlank(preferred)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferred) || entry.getLabel().equalsIgnoreCase(preferred)) {
                    return entry.getValue();
                }
            }
        }
        return null;
    }

    private static Batch__c createDepartureUploadBatch(
        Integer totalRecords,
        Integer validatedRecords,
        Integer failedValidationRecords
    ) {
        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        Batch__c batch = new Batch__c();

        if (batchFields.containsKey(FLD_BATCH_SOURCE)) {
            batch.put(FLD_BATCH_SOURCE, SOURCE_DEPARTURE_UPLOAD);
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
            cv.Description = 'Departure Upload (' + contentType + ')';
        }
        insert cv;
    }

    private static void updateDepartureUploadBatchCounts(
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

    private static void putBatchReference(SObject recordRow, Map<String, Schema.SObjectField> fieldMap, Id batchId) {
        if (recordRow == null || batchId == null || fieldMap == null) {
            return;
        }
        setReferenceOrText(recordRow, fieldMap, BATCH_LOOKUP_CANDIDATES, batchId);
        if (fieldMap.containsKey(FLD_BATCH_ID_TEXT)) {
            Schema.DisplayType type = fieldMap.get(FLD_BATCH_ID_TEXT).getDescribe().getType();
            if (type == Schema.DisplayType.REFERENCE || type == Schema.DisplayType.ID) {
                recordRow.put(FLD_BATCH_ID_TEXT, batchId);
            } else {
                recordRow.put(FLD_BATCH_ID_TEXT, String.valueOf(batchId));
            }
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

    private static Boolean isValidIsoDate(String dateStr) {
        if (!ISO_DATE_PATTERN.matcher(dateStr).matches()) {
            return false;
        }
        try {
            List<String> parts = dateStr.split('-');
            Integer y = Integer.valueOf(parts[0]);
            Integer m = Integer.valueOf(parts[1]);
            Integer d = Integer.valueOf(parts[2]);
            Date testDate = Date.newInstance(y, m, d);
            return testDate.year() == y && testDate.month() == m && testDate.day() == d;
        } catch (Exception e) {
            return false;
        }
    }

    private static Date parseDate(String isoDate) {
        List<String> parts = isoDate.split('-');
        return Date.newInstance(
            Integer.valueOf(parts[0]),
            Integer.valueOf(parts[1]),
            Integer.valueOf(parts[2])
        );
    }

    private static RowError err(Integer rowNumber, String fieldName, String value, String message) {
        RowError e = new RowError();
        e.rowNumber = rowNumber;
        e.fieldName = fieldName;
        e.value = value;
        e.message = message;
        return e;
    }

    private static String trimVal(String raw) {
        return raw == null ? null : raw.trim();
    }

    private static Id resolveAccountId() {
        if (Test.isRunningTest() && testAccountOverride != null) {
            return testAccountOverride;
        }
        if ('Guest'.equals(UserInfo.getUserType())) {
            throw new AuraHandledException('Guest users cannot upload departures.');
        }

        User u = [
            SELECT ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (u.ContactId == null || u.Contact.AccountId == null) {
            throw new AuraHandledException(
                'Partner account not found. Your user must be linked to a Contact with an Account.'
            );
        }
        return u.Contact.AccountId;
    }

    private static String formatValidationErrors(List<RowError> errors) {
        if (errors == null || errors.isEmpty()) {
            return 'Validation failed.';
        }
        List<String> lines = new List<String>();
        Integer maxLines = Math.min(errors.size(), 5);
        for (Integer i = 0; i < maxLines; i++) {
            RowError e = errors[i];
            lines.add('Row ' + String.valueOf(e.rowNumber) + ' (' + e.fieldName + '): ' + e.message);
        }
        if (errors.size() > maxLines) {
            lines.add('...and ' + String.valueOf(errors.size() - maxLines) + ' more error(s).');
        }
        return String.join(lines, '\n');
    }
}