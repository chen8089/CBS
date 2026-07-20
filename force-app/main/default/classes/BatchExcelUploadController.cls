/**
 * Excel upload for Batch__c + Contact from batchExcelUploadModal.
 * Contact validation/classification mirrors ConsentUploadController (Consent Upload rules).
 * Batch__c is created before Contact inserts; Contact.Batch_Id__c lookup receives the new Batch Id.
 */
public with sharing class BatchExcelUploadController {
    private static final Integer MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;
    private static final Integer MAX_FILE_ROW_LIMIT = 5000;
    private static final Set<String> ALLOWED_UPLOAD_EXTENSIONS = new Set<String>{ 'xlsx', 'xls', 'csv' };
    private static final List<String> REQUIRED_HEADERS = new List<String>{
        'Full Name',
        'Email Address',
        'ID Type',
        'ID Number',
        'Date of Birth',
        'Employment Status'
    };
    private static final Set<String> ALLOWED_HEADERS = new Set<String>(REQUIRED_HEADERS);

    public static final String SOURCE_CONSENT_UPLOAD = 'Consent Upload';
    public static final String EXC_MSG_INVALID_EMAIL = 'Invalid Email Format';
    public static final String EXC_MSG_DUPLICATE_EMAIL = 'Duplicate Email';
    public static final String EXC_MSG_INVALID_FULL_NAME = 'Invalid Full Name Format';
    public static final String EXC_MSG_INVALID_EMPLOYMENT_STATUS = 'Invalid Employment Status';
    public static final String EXC_MSG_INVALID_ID_TYPE = 'Invalid ID Type';
    public static final String EXC_MSG_INVALID_NRIC_FIN = 'Invalid NRIC / FIN Format';
    public static final String EXC_MSG_INVALID_PASSPORT = 'Invalid Passport Number Format';
    public static final String EXC_MSG_DUPLICATE_ID_NUMBER = 'Duplicate ID Number';
    public static final String EXC_MSG_INVALID_DOB = 'Invalid Date of Birth';
    public static final String EXC_MSG_INVALID_LAST_EMPLOYMENT_DATE = 'Invalid Last Employment Date';
    public static final String EXC_MSG_EXISTING_HIRE_EMAIL_DOMAIN = 'Existing Hire Email Domain Mismatch';
    public static final String EXC_MSG_DUPLICATE_ROW = 'Duplicate Row in Upload File';
    public static final String EXC_MSG_EXISTING_DS_MATCH = 'Existing Data Subject Match Found';
    public static final String EXC_MSG_EXISTING_ACTIVE_CONSENT = 'Existing Active Consent Found';
    public static final String EXC_MSG_DO_NOT_CONTACT = 'Do Not Contact';
    public static final String EXC_FIELD_NAME_EMAIL = 'Email Address';
    public static final String EXC_FIELD_NAME_ID_NUMBER = 'ID Number';
    public static final String EXC_FIELD_NAME_FULL_NAME = 'Full Name';
    public static final String EXC_FIELD_NAME_ROW = 'Consent Upload Row';
    public static final String EXC_FIELD_NAME_SAVE_EXCEPTION = 'Save Exception';
    public static final String EXC_FIELD_NAME_EMPLOYMENT_STATUS = 'Employment Status';
    public static final String EXC_FIELD_NAME_ID_TYPE = 'ID Type';
    public static final String EXC_FIELD_VALUE_DB_SAVE_FAILED = 'Database Save Failed';

    private static final String RECORD_TYPE_SINGPASS = 'Singpass';
    private static final String RECORD_TYPE_NON_SINGPASS = 'Non_Singpass';
    private static final String RECORD_TYPE_LABEL_SINGPASS = 'Singpass';
    private static final String RECORD_TYPE_LABEL_NON_SINGPASS = 'Non-Singpass';
    private static final String CONSENT_TYPE_PER_REPORT = 'Per-Report Consent';
    private static final String CONSENT_TYPE_TERM_BASED = 'Term-Based Consent';
    private static final String AUTH_SINGPASS = 'Singpass';
    private static final String AUTH_NON_SINGPASS = 'Non-Singpass';
    private static final String STAGE_INTAKE = 'Upload';
    private static final String FLD_LIFECYCLE_STAGE = 'Data_Subject_Lifecycle_Stage__c';
    private static final String FLD_LAST_MATCH_STATUS = 'Last_Match_Status__c';
    private static final String FLD_LAST_ACTIVITY_DATE = 'Last_Activity_Date__c';
    private static final String FLD_AUTHENTICATION_TYPE = 'Authentication_Type__c';
    private static final String FLD_CONSENT_TYPE = 'Consent_Type__c';
    private static final String FLD_CONTACT_BATCH = 'Batch_Id__c';
    private static final String FLD_BATCH_NAME = 'Batch_Name__c';
    private static final String FLD_CLIENT_ACCOUNT = 'Client_Account__c';
    private static final String FLD_APPROVAL_STATUS = 'Approval_Status__c';
    private static final String FLD_PENDING_UPLOAD_STATUS = 'Pending_Upload_Status__c';
    private static final String FLD_TOTAL_RECORDS = 'Total_Records__c';
    private static final String FLD_VALIDATED_RECORDS = 'Validated_Records__c';
    private static final String FLD_DO_NOT_CONTACT_RECORDS = 'Do_Not_Contact_Records__c';
    private static final String FLD_EXCEPTION_BATCH = 'Batch_Id__c';
    private static final String APPROVAL_STATUS_DRAFT = 'Draft';
    private static final String PENDING_UPLOAD_STATUS_UPLOADED = 'Uploaded';

    private static final Set<String> DEFAULT_ALLOWED_ID_TYPES = new Set<String>{
        'NRIC',
        'FIN',
        'Passport',
        'Other'
    };
    private static final Set<String> DEFAULT_ALLOWED_EMPLOYMENT = new Set<String>{
        'Existing Hire',
        'Pre-hire'
    };

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
    );
    private static final Pattern NRIC_FIN_PATTERN = Pattern.compile('^[STFGM][0-9]{7}[A-Z]$');
    private static final Pattern PASSPORT_PATTERN = Pattern.compile('^[A-Za-z0-9]{5,20}$');
    private static final Pattern FULL_NAME_SPACES_PATTERN = Pattern.compile('.*\\s{3,}.*');
    private static final Pattern FULL_NAME_ALLOWED_PATTERN = Pattern.compile('^[A-Za-z][A-Za-z .\\\'-]*$');
    private static final Pattern FULL_NAME_DIGITS_ONLY_PATTERN = Pattern.compile('^[0-9\\s]+$');
    private static final Pattern FULL_NAME_SPECIAL_ONLY_PATTERN = Pattern.compile('^[^A-Za-z0-9]+$');
    private static final Pattern DATE_PATTERN_ISO = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}$');
    private static final Pattern DATE_PATTERN_SLASH = Pattern.compile('^\\d{1,2}/\\d{1,2}/\\d{4}$');

    private static final Set<String> ACTIVE_CONSENT_STATUSES = new Set<String>{ 'ACTIVE', 'VALID', 'AUTHORIZED' };

    @TestVisible
    private static Id testAccountOverride;

    public class BatchUploadRow {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String email;
        @AuraEnabled public String fullName;
        @AuraEnabled public String idType;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String dateOfBirth;
        @AuraEnabled public String lastEmploymentDate;
        @AuraEnabled public String employmentStatus;
    }

    public class RowValidationError {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String errorReason;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String fieldValue;
    }

    public class UploadResult {
        @AuraEnabled public Id batchId;
        @AuraEnabled public String batchName;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public Integer successRows;
        @AuraEnabled public Integer exceptionRows;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer createdContacts;
        @AuraEnabled public Integer createdExceptions;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public Integer exceptionCreatedCount;
        @AuraEnabled public Integer skippedDuplicateCount;
        @AuraEnabled public Integer duplicateInFileCount;
        @AuraEnabled public Integer duplicateExistingCount;
        @AuraEnabled public Integer validationExceptionCount;
        @AuraEnabled public String message;
        @AuraEnabled public List<RowError> errors;
        @AuraEnabled public List<RowValidationError> rowErrors;
    }

    public class UploadValidationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorReason;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String message;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public List<String> errors;
        @AuraEnabled public UploadResult uploadResult;
    }

    public class RowError {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String message;
    }

    private class ConsentClassification {
        public String normalizedEmploymentStatus;
        public String normalizedIdType;
        public String recordTypeDeveloperName;
        public String authenticationType;
        public String consentType;
    }

    private class PreparedUploadRow {
        BatchUploadRow row;
        ConsentClassification classification;
    }

    private class UploadValidationContext {
        public BatchExcelUploadValidationService.ValidationContext sharedContext;
        public Set<String> allowedEmploymentStatuses = new Set<String>();
        public Set<String> allowedIdTypes = new Set<String>();
        public Map<String, Integer> emailDuplicateCounts = new Map<String, Integer>();
        public Map<String, Integer> idDuplicateCounts = new Map<String, Integer>();
        public Map<String, List<Contact>> existingContactsByEmail = new Map<String, List<Contact>>();
        public Map<String, List<Contact>> existingContactsById = new Map<String, List<Contact>>();
        public Set<Id> contactsWithActiveConsent = new Set<Id>();
        public Set<String> allowedExistingHireDomains = new Set<String>();
        public String exceptionBatchReference;
        public Id accountId;
        public Id batchId;
    }

    @AuraEnabled(cacheable=true)
    public static Id getCurrentClientAccountId() {
        return resolveAccountId();
    }

    @AuraEnabled
    public static UploadResult createBatchAndContacts(String batchName, String fileName, String rowsJson) {
        List<BatchUploadRow> rows = (List<BatchUploadRow>) JSON.deserialize(rowsJson, List<BatchUploadRow>.class);
        return uploadBatchContacts(rows, batchName, fileName);
    }

    @AuraEnabled
    public static UploadValidationResult validateAndUpload(
        String batchName,
        String fileName,
        String rowsJson,
        String headersJson,
        Integer fileSizeBytes,
        String fileBodyBase64,
        String fileMimeType
    ) {
        try {
            if (!isAllowedFileExtension(fileName)) {
                return buildFailedResult(
                    'Invalid File Format',
                    'Invalid File Format: Please upload the approved Excel / CSV template only.'
                );
            }

            if (fileSizeBytes != null && fileSizeBytes > MAX_FILE_SIZE_BYTES) {
                return buildFailedResult(
                    'Upload File Exceeds Size Limit',
                    'Upload File Exceeds Size Limit: The uploaded file exceeds the configured file-size limit.'
                );
            }

            List<String> parsedHeaders = parseHeaders(headersJson);
            UploadValidationResult headerValidationResult = validateFileHeaders(parsedHeaders);
            if (headerValidationResult != null) {
                return headerValidationResult;
            }

            List<BatchUploadRow> rows = parseRows(rowsJson);
            if (rows == null) {
                return buildFailedResult(
                    'No Readable Records in File',
                    'No Readable Records in File: The file cannot be parsed into usable rows.'
                );
            }
            if (rows.size() > MAX_FILE_ROW_LIMIT) {
                return buildFailedResult(
                    'Upload File Exceeds Size Limit',
                    'Upload File Exceeds Size Limit: The uploaded file exceeds the configured row limit.'
                );
            }
            if (rows.isEmpty()) {
                return buildFailedResult(
                    'Empty Upload File',
                    'Empty Upload File: The file contains headers but no data rows.'
                );
            }

            Integer importableRows = countImportableRows(rows);
            if (importableRows == 0) {
                return buildFailedResult(
                    'No Readable Records in File',
                    'No Readable Records in File: The file cannot be parsed into usable rows.'
                );
            }

            UploadResult uploadResult = uploadBatchContacts(rows, batchName, fileName);
            if (uploadResult != null && uploadResult.batchId != null && String.isNotBlank(fileBodyBase64)) {
                saveUploadedFileToBatch(uploadResult.batchId, fileName, fileBodyBase64, fileMimeType, fileSizeBytes);
            }
            UploadValidationResult successResult = new UploadValidationResult();
            successResult.success = true;
            successResult.totalRows = uploadResult == null ? importableRows : uploadResult.totalRows;
            successResult.errors = new List<String>();
            successResult.uploadResult = uploadResult;
            successResult.message = uploadResult == null ? 'Upload completed successfully.' : uploadResult.message;
            return successResult;
        } catch (AuraHandledException e) {
            System.debug('AuraHandledException: ' + e.getMessage());
            System.debug('AuraHandledException Stack Trace: ' + e.getStackTraceString());
            return buildFailedResult('Upload Failed', e.getMessage());
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            System.debug('Exception Stack Trace: ' + e.getStackTraceString());
            UploadValidationResult failure = buildFailedResult(
                'No Readable Records in File',
                'No Readable Records in File: The file cannot be parsed into usable rows.'
            );
            failure.errors.add(e.getMessage());
            return failure;
        }
    }

    @AuraEnabled
    public static UploadResult uploadBatchContacts(List<BatchUploadRow> rows, String batchName, String fileName) {
        UploadResult result = new UploadResult();
        result.errors = new List<RowError>();
        result.rowErrors = new List<RowValidationError>();
        result.totalRows = countImportableRows(rows);
        result.successRows = 0;
        result.exceptionRows = 0;
        result.successCount = 0;
        result.createdContacts = 0;
        result.createdExceptions = 0;
        result.errorCount = 0;
        result.exceptionCreatedCount = 0;
        result.skippedDuplicateCount = 0;
        result.duplicateInFileCount = 0;
        result.duplicateExistingCount = 0;
        result.validationExceptionCount = 0;
        Integer doNotContactRecordCount = 0;

        if (rows == null || result.totalRows == 0) {
            throw new AuraHandledException('No rows to import.');
        }

        if (!Schema.sObjectType.Batch__c.isCreateable() || !Schema.sObjectType.Contact.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create batch or contact records.');
        }

        Id accountId = resolveAccountId();
        Map<String, Id> contactRecordTypeIdsByDeveloperName = queryConsentContactRecordTypeIdsByDeveloperName();

        Batch__c insertedBatch = createUploadBatch(batchName, fileName, result.totalRows, accountId);
        result.batchId = insertedBatch.Id;
        result.batchName = resolveBatchDisplayName(insertedBatch, batchName, fileName);
        String exceptionBatchReference = resolveExceptionBatchReference(insertedBatch);        

        UploadValidationContext validationContext = buildValidationContext(
            rows,
            accountId,
            insertedBatch.Id,
            exceptionBatchReference
        );
        List<PreparedUploadRow> rowsForContact = new List<PreparedUploadRow>();
        List<Exception__c> exceptionsToInsert = new List<Exception__c>();
        List<Integer> exceptionRowNumbers = new List<Integer>();
        List<String> exceptionMessages = new List<String>();

        for (BatchUploadRow row : rows) {
            if (row == null) {
                continue;
            }
            Integer rn = row.rowNumber != null ? row.rowNumber : 0;
            if (isBlankRow(row)) {
                continue;
            }
            List<RowValidationError> rowErrors = validateUploadRow(row, rn, validationContext);
            if (!rowErrors.isEmpty()) {
                result.exceptionRows++;
                result.validationExceptionCount += rowErrors.size();
                for (RowValidationError validationErr : rowErrors) {
                    if (EXC_MSG_DUPLICATE_ROW.equals(validationErr.errorReason)) {
                        result.duplicateInFileCount++;
                    } else if (
                        EXC_MSG_DUPLICATE_EMAIL.equals(validationErr.errorReason) ||
                        EXC_MSG_DUPLICATE_ID_NUMBER.equals(validationErr.errorReason)
                    ) {
                        result.duplicateExistingCount++;
                        result.skippedDuplicateCount++;
                    } else if (EXC_MSG_DO_NOT_CONTACT.equals(validationErr.errorReason)) {
                        doNotContactRecordCount++;
                    }
                    result.rowErrors.add(validationErr);
                    result.errors.add(rowError(validationErr.rowNumber, validationErr.errorMessage));
                }
                addExceptionsForRowErrors(
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    exceptionMessages,
                    rn,
                    row,
                    rowErrors,
                    validationContext
                );
                continue;
            }

            ConsentClassification classification = classifyConsentRow(
                row,
                validationContext.allowedEmploymentStatuses,
                validationContext.allowedIdTypes
            );
            if (classification == null || String.isBlank(classification.recordTypeDeveloperName)) {
                List<RowValidationError> classificationError = new List<RowValidationError>{
                    buildRowValidationError(
                        rn,
                        EXC_MSG_INVALID_ID_TYPE,
                        'Invalid ID Type: ID Type is not supported.',
                        EXC_FIELD_NAME_ID_TYPE,
                        row.idType
                    )
                };
                result.exceptionRows++;
                result.validationExceptionCount++;
                result.rowErrors.add(classificationError[0]);
                result.errors.add(rowError(rn, classificationError[0].errorMessage));
                addExceptionsForRowErrors(
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    exceptionMessages,
                    rn,
                    row,
                    classificationError,
                    validationContext
                );
                continue;
            }
            if (!contactRecordTypeIdsByDeveloperName.containsKey(classification.recordTypeDeveloperName)) {
                String missingRecordTypeMessage =
                    'Missing Contact Record Type: ' +
                    recordTypeLabelForDeveloperName(classification.recordTypeDeveloperName);
                List<RowValidationError> missingRtErrors = new List<RowValidationError>{
                    buildRowValidationError(
                        rn,
                        missingRecordTypeMessage,
                        missingRecordTypeMessage,
                        EXC_FIELD_NAME_ROW,
                        classification.recordTypeDeveloperName
                    )
                };
                result.exceptionRows++;
                result.validationExceptionCount++;
                result.rowErrors.add(missingRtErrors[0]);
                result.errors.add(rowError(rn, missingRecordTypeMessage));
                addExceptionsForRowErrors(
                    exceptionsToInsert,
                    exceptionRowNumbers,
                    exceptionMessages,
                    rn,
                    row,
                    missingRtErrors,
                    validationContext
                );
                continue;
            }

            PreparedUploadRow prepared = new PreparedUploadRow();
            prepared.row = row;
            prepared.classification = classification;
            rowsForContact.add(prepared);
        }

        if (!rowsForContact.isEmpty()) {
            List<Contact> toInsert = buildContacts(
                rowsForContact,
                contactRecordTypeIdsByDeveloperName,
                accountId,
                insertedBatch.Id
            );
            List<Integer> contactRowNumbers = new List<Integer>();
            for (PreparedUploadRow prepared : rowsForContact) {
                BatchUploadRow row = prepared.row;
                contactRowNumbers.add(row != null && row.rowNumber != null ? row.rowNumber : 0);
            }

            Database.SaveResult[] saveResults = Database.insert(toInsert, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                if (sr.isSuccess()) {
                    result.successRows++;
                    result.successCount++;
                    result.createdContacts++;
                } else {
                    Contact attempted = i < toInsert.size() ? toInsert[i] : null;
                    if (shouldRetryWithoutOwner(sr, attempted)) {
                        Contact retryContact = cloneContactWithoutOwner(attempted);
                        Database.SaveResult retrySr = Database.insert(retryContact, false);
                        if (retrySr.isSuccess()) {
                            result.successRows++;
                            result.successCount++;
                            result.createdContacts++;
                            continue;
                        }
                        sr = retrySr;
                    }

                    result.errorCount++;
                    Integer rowRn = i < contactRowNumbers.size() ? contactRowNumbers[i] : 0;
                    String msg = sr.getErrors().isEmpty() ? 'Insert failed.' : sr.getErrors()[0].getMessage();
                    result.errors.add(rowError(rowRn, msg));
                    BatchUploadRow failedRow = i < rowsForContact.size() ? rowsForContact[i].row : null;
                    if (failedRow != null) {
                        List<RowValidationError> saveErrors = new List<RowValidationError>{
                            buildRowValidationError(
                                rowRn,
                                'Save Exception',
                                msg,
                                EXC_FIELD_NAME_SAVE_EXCEPTION,
                                EXC_FIELD_VALUE_DB_SAVE_FAILED
                            )
                        };
                        addExceptionsForRowErrors(
                            exceptionsToInsert,
                            exceptionRowNumbers,
                            exceptionMessages,
                            rowRn,
                            failedRow,
                            saveErrors,
                            validationContext
                        );
                    }
                }
            }
        }

        if (!exceptionsToInsert.isEmpty()) {
            if (!Schema.sObjectType.Exception__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create Exception records.');
            }
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
                    String exceptionMessage = i < exceptionMessages.size()
                        ? exceptionMessages[i]
                        : 'Exception insert failed';
                    String msg = sr.getErrors().isEmpty() ? 'Insert failed.' : sr.getErrors()[0].getMessage();
                    result.errors.add(rowError(rowRn, exceptionMessage + ': ' + msg));
                }
            }
        }

        updateBatchValidatedRecordCount(insertedBatch.Id, result.successCount);
        updateBatchDoNotContactRecordCount(insertedBatch.Id, doNotContactRecordCount);
        result.message = result.exceptionRows > 0
            ? 'Upload completed with exceptions. Please review the Exceptions list.'
            : 'Upload completed successfully.';

        return result;
    }

    private static void updateBatchValidatedRecordCount(Id batchId, Integer validatedCount) {
        if (batchId == null) {
            return;
        }
        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        if (!batchFields.containsKey(FLD_VALIDATED_RECORDS)) {
            return;
        }
        if (!batchFields.get(FLD_VALIDATED_RECORDS).getDescribe().isUpdateable()) {
            return;
        }

        Batch__c toUpdate = new Batch__c(Id = batchId);
        toUpdate.put(FLD_VALIDATED_RECORDS, validatedCount == null ? 0 : validatedCount);

        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE,
            new List<Batch__c>{ toUpdate }
        );
        Database.update(decision.getRecords(), false);
    }

    private static void updateBatchDoNotContactRecordCount(Id batchId, Integer blockedCount) {
        if (batchId == null) {
            return;
        }
        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        if (!batchFields.containsKey(FLD_DO_NOT_CONTACT_RECORDS)) {
            return;
        }
        if (!batchFields.get(FLD_DO_NOT_CONTACT_RECORDS).getDescribe().isUpdateable()) {
            return;
        }

        Batch__c toUpdate = new Batch__c(Id = batchId);
        toUpdate.put(FLD_DO_NOT_CONTACT_RECORDS, blockedCount == null ? 0 : blockedCount);

        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE,
            new List<Batch__c>{ toUpdate }
        );
        Database.update(decision.getRecords(), false);
    }

    private static Batch__c createUploadBatch(
        String batchName,
        String fileName,
        Integer totalRows,
        Id currentUserAccountId
    ) {
        Batch__c batchRecord = new Batch__c();
        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();

        if (batchFields.containsKey(FLD_CLIENT_ACCOUNT)) {
            batchRecord.put(FLD_CLIENT_ACCOUNT, currentUserAccountId);
        }
        if (batchFields.containsKey(FLD_BATCH_NAME)) {
            batchRecord.put(FLD_BATCH_NAME, resolveBatchName(batchName, fileName));
        }
        if (batchFields.containsKey(FLD_TOTAL_RECORDS)) {
            batchRecord.put(FLD_TOTAL_RECORDS, totalRows);
        }
        if (batchFields.containsKey(FLD_APPROVAL_STATUS)) {
            batchRecord.put(FLD_APPROVAL_STATUS, resolvePicklistValue(batchFields.get(FLD_APPROVAL_STATUS), APPROVAL_STATUS_DRAFT));
        }
        if (batchFields.containsKey(FLD_PENDING_UPLOAD_STATUS)) {
            batchRecord.put(
                FLD_PENDING_UPLOAD_STATUS,
                resolvePicklistValue(batchFields.get(FLD_PENDING_UPLOAD_STATUS), PENDING_UPLOAD_STATUS_UPLOADED)
            );
        }

        SObjectAccessDecision batchDecision = Security.stripInaccessible(
            AccessType.CREATABLE,
            new List<Batch__c>{ batchRecord }
        );
        batchRecord = (Batch__c) batchDecision.getRecords()[0];
        ensureBatchRetainsClientAccountId(batchRecord, currentUserAccountId);

        Database.SaveResult batchSaveResult = Database.insert(batchRecord, false);
        if (!batchSaveResult.isSuccess()) {
            String msg = batchSaveResult.getErrors().isEmpty()
                ? 'Batch insert failed.'
                : batchSaveResult.getErrors()[0].getMessage();
            throw new AuraHandledException('Failed to create Batch record: ' + msg);
        }

        List<Batch__c> inserted = [
            SELECT Id, Name, Batch_Name__c
            FROM Batch__c
            WHERE Id = :batchRecord.Id
            LIMIT 1
        ];
        return inserted.isEmpty() ? batchRecord : inserted[0];
    }

    private static String resolveBatchDisplayName(Batch__c batchRecord, String batchName, String fileName) {
        if (batchRecord != null && batchRecord.get(FLD_BATCH_NAME) != null) {
            return String.valueOf(batchRecord.get(FLD_BATCH_NAME));
        }
        return resolveBatchName(batchName, fileName);
    }

    private static String resolveExceptionBatchReference(Batch__c batchRecord) {
        if (batchRecord == null) {
            return null;
        }
        Schema.SObjectField exceptionBatchField = Schema.SObjectType.Exception__c.fields.getMap().get(FLD_EXCEPTION_BATCH);
        if (exceptionBatchField == null) {
            return String.valueOf(batchRecord.Id);
        }
        Schema.DisplayType fieldType = exceptionBatchField.getDescribe().getType();
        if (fieldType == Schema.DisplayType.REFERENCE) {
            return String.valueOf(batchRecord.Id);
        }
        if (String.isNotBlank(batchRecord.Name)) {
            return batchRecord.Name;
        }
        return String.valueOf(batchRecord.Id);
    }

    private static Boolean isAllowedFileExtension(String fileName) {
        String extension = resolveFileExtension(fileName);
        return String.isNotBlank(extension) && ALLOWED_UPLOAD_EXTENSIONS.contains(extension);
    }

    private static void saveUploadedFileToBatch(
        Id batchId,
        String fileName,
        String fileBodyBase64,
        String fileMimeType,
        Integer fileSizeBytes
    ) {
        if (batchId == null || String.isBlank(fileBodyBase64)) {
            return;
        }
        if (!Schema.sObjectType.ContentVersion.isCreateable()) {
            throw new AuraHandledException('You do not have permission to upload files to batch records.');
        }
        if (fileSizeBytes != null && fileSizeBytes > MAX_FILE_SIZE_BYTES) {
            throw new AuraHandledException('Uploaded file exceeds the configured file-size limit.');
        }

        Blob fileBlob;
        try {
            fileBlob = EncodingUtil.base64Decode(fileBodyBase64);
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to process uploaded file content.');
        }
        if (fileBlob == null || fileBlob.size() <= 0) {
            throw new AuraHandledException('Uploaded file content is empty.');
        }
        if (fileBlob.size() > MAX_FILE_SIZE_BYTES) {
            throw new AuraHandledException('Uploaded file exceeds the configured file-size limit.');
        }

        ContentVersion uploadVersion = new ContentVersion();
        uploadVersion.Title = String.isBlank(fileName) ? 'Consent Upload' : fileName.substringBeforeLast('.');
        uploadVersion.PathOnClient = String.isBlank(fileName) ? 'consent-upload.xlsx' : fileName;
        uploadVersion.VersionData = fileBlob;
        uploadVersion.FirstPublishLocationId = batchId;
        if (String.isNotBlank(fileMimeType)) {
            uploadVersion.Description = 'Uploaded via batch import (' + fileMimeType + ')';
        }
        insert uploadVersion;
    }

    private static String resolveFileExtension(String fileName) {
        if (String.isBlank(fileName) || !fileName.contains('.')) {
            return null;
        }
        Integer dotIndex = fileName.lastIndexOf('.');
        if (dotIndex < 0 || dotIndex >= fileName.length() - 1) {
            return null;
        }
        return fileName.substring(dotIndex + 1).trim().toLowerCase();
    }

    private static List<String> parseHeaders(String headersJson) {
        if (String.isBlank(headersJson)) {
            return new List<String>();
        }
        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(headersJson);
        List<String> headers = new List<String>();
        for (Object item : parsed) {
            headers.add(item == null ? '' : String.valueOf(item));
        }
        return headers;
    }

    private static List<BatchUploadRow> parseRows(String rowsJson) {
        if (String.isBlank(rowsJson)) {
            return null;
        }
        return (List<BatchUploadRow>) JSON.deserialize(rowsJson, List<BatchUploadRow>.class);
    }

    private static UploadValidationResult validateFileHeaders(List<String> parsedHeaders) {
        if (parsedHeaders == null || parsedHeaders.isEmpty()) {
            return buildFailedResult(
                'No Readable Records in File',
                'No Readable Records in File: The file cannot be parsed into usable rows.'
            );
        }

        Map<String, Integer> headerCountMap = new Map<String, Integer>();
        for (String header : parsedHeaders) {
            String normalizedHeader = header == null ? '' : header.trim();
            if (String.isBlank(normalizedHeader)) {
                continue;
            }
            Integer headerCount = headerCountMap.containsKey(normalizedHeader) ? headerCountMap.get(normalizedHeader) : 0;
            headerCountMap.put(normalizedHeader, headerCount + 1);
        }

        for (String headerName : headerCountMap.keySet()) {
            if (headerCountMap.get(headerName) > 1) {
                return buildFailedResult(
                    'Duplicate Column Header',
                    'Duplicate Column Header: The uploaded file contains duplicate column: ' + headerName + '.'
                );
            }
        }

        for (String requiredHeader : REQUIRED_HEADERS) {
            if (!headerCountMap.containsKey(requiredHeader)) {
                return buildFailedResult(
                    'Missing Required Column',
                    'Missing Required Column: The uploaded file does not contain required column: ' + requiredHeader + '.'
                );
            }
        }

        for (String headerName : headerCountMap.keySet()) {
            if (!ALLOWED_HEADERS.contains(headerName)) {
                return buildFailedResult(
                    'Invalid Column Header',
                    'Invalid Column Header: Column "' + headerName + '" is not valid. Please use the approved Excel / CSV template.'
                );
            }
        }

        return null;
    }

    private static UploadValidationResult buildFailedResult(String reason, String message) {
        UploadValidationResult result = new UploadValidationResult();
        result.success = false;
        result.errorReason = reason;
        result.errorMessage = message;
        result.message = message;
        result.totalRows = 0;
        result.errors = new List<String>{ message };
        result.uploadResult = null;
        return result;
    }

    private static Integer countImportableRows(List<BatchUploadRow> rows) {
        Integer count = 0;
        if (rows == null) {
            return count;
        }
        for (BatchUploadRow row : rows) {
            if (row != null && !isBlankRow(row)) {
                count++;
            }
        }
        return count;
    }

    @TestVisible
    private static Boolean shouldRetryWithoutOwner(Database.SaveResult sr, Contact attempted) {
        if (sr == null || attempted == null || attempted.OwnerId == null || sr.isSuccess()) {
            return false;
        }
        for (Database.Error err : sr.getErrors()) {
            if (err == null || String.isBlank(err.getMessage())) {
                continue;
            }
            if (err.getMessage().toLowerCase().contains('insufficient access rights on cross-reference id')) {
                return true;
            }
        }
        return false;
    }

    private static Contact cloneContactWithoutOwner(Contact source) {
        Contact retryContact = source.clone(false, false, false, false);
        retryContact.OwnerId = null;
        return retryContact;
    }

    private static UploadValidationContext buildValidationContext(
        List<BatchUploadRow> rows,
        Id accountId,
        Id batchId,
        String exceptionBatchReference
    ) {
        UploadValidationContext context = new UploadValidationContext();
        List<BatchExcelUploadValidationService.ConsentValidationRow> svcRows = new List<BatchExcelUploadValidationService.ConsentValidationRow>();
        for (BatchUploadRow row : rows) {
            svcRows.add(toValidationRow(row));
        }
        context.sharedContext = BatchExcelUploadValidationService.buildValidationContext(
            svcRows,
            accountId,
            batchId,
            exceptionBatchReference,
            SOURCE_CONSENT_UPLOAD
        );
        context.accountId = context.sharedContext.accountId;
        context.batchId = context.sharedContext.batchId;
        context.exceptionBatchReference = context.sharedContext.batchReference;
        context.allowedEmploymentStatuses = context.sharedContext.allowedEmploymentStatuses;
        context.allowedIdTypes = context.sharedContext.allowedIdTypes;
        context.emailDuplicateCounts = context.sharedContext.emailDuplicateCounts;
        context.idDuplicateCounts = context.sharedContext.idDuplicateCounts;
        context.existingContactsByEmail = context.sharedContext.existingContactsByEmail;
        context.existingContactsById = context.sharedContext.existingContactsById;
        context.contactsWithActiveConsent = context.sharedContext.contactsWithActiveConsent;
        context.allowedExistingHireDomains = context.sharedContext.allowedExistingHireDomains;
        return context;
    }

    private static List<RowValidationError> validateUploadRow(
        BatchUploadRow row,
        Integer rowNumber,
        UploadValidationContext context
    ) {
        List<BatchExcelUploadValidationService.RowValidationError> svcErrors =
            BatchExcelUploadValidationService.validateConsentRowStrict(
                toValidationRow(row),
                rowNumber,
                context.sharedContext
            );
        return fromServiceErrors(svcErrors);
    }

    private static List<Contact> buildContacts(
        List<PreparedUploadRow> rows,
        Map<String, Id> contactRecordTypeIdsByDeveloperName,
        Id accountId,
        Id batchId
    ) {
        Boolean canSetLastMatchPending = isPicklistValueActive(FLD_LAST_MATCH_STATUS, 'Pending');
        Date today = Date.today();
        List<Contact> contacts = new List<Contact>();
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();

        for (PreparedUploadRow prepared : rows) {
            if (prepared == null || prepared.row == null || prepared.classification == null) {
                continue;
            }
            BatchUploadRow row = prepared.row;
            ConsentClassification classification = prepared.classification;
            Contact c = new Contact();
            c.AccountId = accountId;
            c.RecordTypeId = contactRecordTypeIdsByDeveloperName.get(classification.recordTypeDeveloperName);

            applyNameFields(c, trimVal(row.fullName));
            c.Email = trimVal(row.email);

            if (contactFields.containsKey('Full_Name__c')) {
                c.put('Full_Name__c', trimVal(row.fullName));
            }
            if (contactFields.containsKey('ID_Type__c')) {
                c.put('ID_Type__c', classification.normalizedIdType);
            }
            if (contactFields.containsKey('ID_Number__c')) {
                c.put('ID_Number__c', normalizeIdNumber(row.idNumber));
            }
            Date parsedDob = BatchExcelUploadValidationService.parseSupportedDate(row.dateOfBirth);
            if (contactFields.containsKey('Date_of_Birth__c') && parsedDob != null) {
                c.put('Date_of_Birth__c', parsedDob);
            }
            if (contactFields.containsKey('Employment_Status__c')) {
                c.put('Employment_Status__c', classification.normalizedEmploymentStatus);
            }
            if (contactFields.containsKey(FLD_AUTHENTICATION_TYPE)) {
                c.put(FLD_AUTHENTICATION_TYPE, classification.authenticationType);
            }
            if (contactFields.containsKey(FLD_CONSENT_TYPE)) {
                c.put(FLD_CONSENT_TYPE, classification.consentType);
            }
            ConsentStatusModelService.applyPendingVerificationState(c);
            if (canSetLastMatchPending && contactFields.containsKey(FLD_LAST_MATCH_STATUS)) {
                c.put(FLD_LAST_MATCH_STATUS, 'Pending');
            }
            if (contactFields.containsKey(FLD_LAST_ACTIVITY_DATE)) {
                c.put(FLD_LAST_ACTIVITY_DATE, today);
            }
            if (contactFields.containsKey(FLD_CONTACT_BATCH) && batchId != null) {
                c.put(FLD_CONTACT_BATCH, batchId);
            }

            contacts.add(c);
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, contacts);
        List<Contact> creatable = (List<Contact>) decision.getRecords();
        ensureContactsRetainAccountId(creatable, accountId);
        ensureContactsRetainBatchId(creatable, batchId);
        return creatable;
    }

    private static void ensureBatchRetainsClientAccountId(Batch__c batchRec, Id accountId) {
        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        if (!batchFields.containsKey(FLD_CLIENT_ACCOUNT)) {
            return;
        }
        if (!isBatchClientAccountCreatable()) {
            throw new AuraHandledException(
                'You do not have permission to set Client Account on batch records. Please contact your administrator.'
            );
        }
        if (batchRec.get(FLD_CLIENT_ACCOUNT) == null) {
            batchRec.put(FLD_CLIENT_ACCOUNT, accountId);
        }
        if (batchRec.get(FLD_CLIENT_ACCOUNT) == null) {
            throw new AuraHandledException(
                'Unable to determine current user\'s Account. Please contact your administrator.'
            );
        }
    }

    private static Boolean isBatchClientAccountCreatable() {
        Schema.SObjectField accountFld = Schema.SObjectType.Batch__c.fields.getMap().get(FLD_CLIENT_ACCOUNT);
        return accountFld != null && accountFld.getDescribe().isCreateable();
    }

    private static void ensureContactsRetainAccountId(List<Contact> contacts, Id accountId) {
        if (!isContactAccountIdCreatable()) {
            throw new AuraHandledException(
                'You do not have permission to set Account on contact records. Please contact your administrator.'
            );
        }
        for (Contact c : contacts) {
            if (c.AccountId == null) {
                c.AccountId = accountId;
            }
            if (c.AccountId == null) {
                throw new AuraHandledException(
                    'Unable to determine current user\'s Account. Please contact your administrator.'
                );
            }
        }
    }

    private static void ensureContactsRetainBatchId(List<Contact> contacts, Id batchId) {
        if (batchId == null) {
            return;
        }
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        if (!contactFields.containsKey(FLD_CONTACT_BATCH)) {
            return;
        }
        Schema.SObjectField batchField = contactFields.get(FLD_CONTACT_BATCH);
        if (batchField.getDescribe().getType() != Schema.DisplayType.REFERENCE) {
            return;
        }
        for (Contact c : contacts) {
            if (c.get(FLD_CONTACT_BATCH) == null) {
                c.put(FLD_CONTACT_BATCH, batchId);
            }
        }
    }

    private static Boolean isContactAccountIdCreatable() {
        Schema.SObjectField accountFld = Schema.SObjectType.Contact.fields.getMap().get('AccountId');
        return accountFld != null && accountFld.getDescribe().isCreateable();
    }

    private static void applyNameFields(Contact c, String fullName) {
        if (String.isBlank(fullName)) {
            c.LastName = 'Data Subject';
            return;
        }
        c.LastName = fullName.trim();
    }

    private static String resolveLifecycleStageValue() {
        if (isPicklistValueActive(FLD_LIFECYCLE_STAGE, STAGE_INTAKE)) {
            return STAGE_INTAKE;
        }
        return STAGE_INTAKE;
    }

    private static Boolean isPicklistValueActive(String fieldApi, String value) {
        Schema.SObjectField fld = Schema.SObjectType.Contact.fields.getMap().get(fieldApi);
        if (fld == null || String.isBlank(value)) {
            return false;
        }
        for (Schema.PicklistEntry pe : fld.getDescribe().getPicklistValues()) {
            if (pe.isActive() && value.equals(pe.getValue())) {
                return true;
            }
        }
        return false;
    }

    private static String resolvePicklistValue(Schema.SObjectField fieldToken, String preferredValue) {
        if (fieldToken == null) {
            return preferredValue;
        }
        for (Schema.PicklistEntry pe : fieldToken.getDescribe().getPicklistValues()) {
            if (pe.isActive() && preferredValue.equals(pe.getValue())) {
                return preferredValue;
            }
        }
        return firstActivePicklistValue(fieldToken);
    }

    private static String firstActivePicklistValue(Schema.SObjectField fieldToken) {
        if (fieldToken == null) {
            return null;
        }
        for (Schema.PicklistEntry pe : fieldToken.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static String resolveBatchName(String batchName, String fileName) {
        String trimmed = trimVal(batchName);
        if (String.isNotBlank(trimmed)) {
            return trimmed;
        }
        String trimmedFileName = trimVal(fileName);
        if (String.isNotBlank(trimmedFileName)) {
            return trimmedFileName;
        }
        Datetime now = Datetime.now();
        return 'Consent Upload - ' + now.format('yyyy-MM-dd HH:mm');
    }

    private static Id resolveAccountId() {
        if (Test.isRunningTest() && testAccountOverride != null) {
            return testAccountOverride;
        }
        if (isGuestUser()) {
            throw new AuraHandledException('Guest users cannot upload batches.');
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

    private static Boolean isGuestUser() {
        return 'Guest'.equals(UserInfo.getUserType());
    }

    private static String normalizeEmail(String raw) {
        String trimmed = trimVal(raw);
        return String.isBlank(trimmed) ? null : trimmed.toLowerCase();
    }

    private static String normalizeIdNumber(String raw) {
        String trimmed = trimVal(raw);
        return String.isBlank(trimmed) ? trimmed : trimmed.toUpperCase();
    }

    private static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        return EMAIL_PATTERN.matcher(email.trim()).matches();
    }

    private static Boolean isValidNricOrFin(String idNumber) {
        if (String.isBlank(idNumber)) {
            return false;
        }
        String value = idNumber.trim().toUpperCase();
        return NRIC_FIN_PATTERN.matcher(value).matches();
    }

    private static Boolean isValidPassportNumber(String idNumber) {
        if (String.isBlank(idNumber)) {
            return false;
        }
        return PASSPORT_PATTERN.matcher(idNumber.trim()).matches();
    }

    private static Boolean hasMoreThanTwoConsecutiveSpaces(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        return FULL_NAME_SPACES_PATTERN.matcher(value).matches();
    }

    private static void addExceptionsForRowErrors(
        List<Exception__c> exceptionsToInsert,
        List<Integer> exceptionRowNumbers,
        List<String> exceptionMessages,
        Integer rowNumber,
        BatchUploadRow row,
        List<RowValidationError> rowErrors,
        UploadValidationContext context
    ) {
        if (rowErrors == null || rowErrors.isEmpty()) {
            return;
        }
        for (RowValidationError rowError : rowErrors) {
            if (rowError == null) {
                continue;
            }
            Exception__c ex = buildExceptionFromRowError(row, rowError, context);
            if (ex == null) {
                continue;
            }
            exceptionsToInsert.add(ex);
            exceptionRowNumbers.add(rowNumber);
            exceptionMessages.add(rowError.errorMessage);
        }
    }

    private static String normalizeEmploymentStatus(String raw) {
        String v = trimVal(raw);
        if (String.isBlank(v)) {
            return v;
        }
        if ('Existing Hire'.equalsIgnoreCase(v) || 'Existing'.equalsIgnoreCase(v)) {
            return 'Existing Hire';
        }
        if ('Pre-hire'.equalsIgnoreCase(v) || 'Pre Hire'.equalsIgnoreCase(v) || 'Prehire'.equalsIgnoreCase(v)) {
            return 'Pre-hire';
        }
        return v;
    }

    private static String normalizeIdType(String raw) {
        String v = trimVal(raw);
        if (String.isBlank(v)) {
            return v;
        }
        if ('NRIC'.equalsIgnoreCase(v)) {
            return 'NRIC';
        }
        if ('FIN'.equalsIgnoreCase(v)) {
            return 'FIN';
        }
        if ('Passport'.equalsIgnoreCase(v)) {
            return 'Passport';
        }
        if ('Other'.equalsIgnoreCase(v)) {
            return 'Other';
        }
        return v;
    }

    private static Boolean isSingpassIdType(String normalizedIdType) {
        return 'NRIC'.equals(normalizedIdType) || 'FIN'.equals(normalizedIdType);
    }

    private static ConsentClassification classifyConsentRow(
        BatchUploadRow row,
        Set<String> allowedEmploymentStatuses,
        Set<String> allowedIdTypes
    ) {
        if (row == null) {
            return null;
        }

        String employment = normalizeEmploymentStatus(row.employmentStatus);
        String idType = normalizeIdType(row.idType);

        if (!allowedEmploymentStatuses.contains(employment) || !allowedIdTypes.contains(idType)) {
            return null;
        }

        ConsentClassification classification = new ConsentClassification();
        classification.normalizedEmploymentStatus = employment;
        classification.normalizedIdType = idType;

        Boolean isExistingHire = 'Existing Hire'.equals(employment);
        Boolean isPreHire = 'Pre-hire'.equals(employment);
        Boolean isSingpass = isSingpassIdType(idType);

        if (isSingpass) {
            classification.recordTypeDeveloperName = RECORD_TYPE_SINGPASS;
            classification.authenticationType = AUTH_SINGPASS;
        } else {
            classification.recordTypeDeveloperName = RECORD_TYPE_NON_SINGPASS;
            classification.authenticationType = AUTH_NON_SINGPASS;
        }

        if (isPreHire && isSingpass) {
            classification.consentType = CONSENT_TYPE_PER_REPORT;
        } else if (isExistingHire || isPreHire) {
            classification.consentType = CONSENT_TYPE_TERM_BASED;
        } else {
            return null;
        }

        return classification;
    }

    private static Map<String, Id> queryConsentContactRecordTypeIdsByDeveloperName() {
        Map<String, Id> contactRecordTypeIdsByDeveloperName = new Map<String, Id>();
        Map<String, Schema.RecordTypeInfo> availableByDeveloperName =
            Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        Set<String> expectedDeveloperNames = new Set<String>{
            RECORD_TYPE_SINGPASS,
            RECORD_TYPE_NON_SINGPASS
        };
        Set<String> expectedLabels = new Set<String>{
            RECORD_TYPE_LABEL_SINGPASS,
            RECORD_TYPE_LABEL_NON_SINGPASS
        };

        for (RecordType rt : [
            SELECT Id, DeveloperName, Name
            FROM RecordType
            WHERE SObjectType = 'Contact'
            AND (DeveloperName IN :expectedDeveloperNames OR Name IN :expectedLabels)
        ]) {
            if (!isConsentRecordTypeUsable(availableByDeveloperName.get(rt.DeveloperName))) {
                continue;
            }
            if (
                RECORD_TYPE_SINGPASS.equals(rt.DeveloperName) ||
                RECORD_TYPE_LABEL_SINGPASS.equalsIgnoreCase(rt.Name)
            ) {
                contactRecordTypeIdsByDeveloperName.put(RECORD_TYPE_SINGPASS, rt.Id);
            } else if (
                RECORD_TYPE_NON_SINGPASS.equals(rt.DeveloperName) ||
                RECORD_TYPE_LABEL_NON_SINGPASS.equalsIgnoreCase(rt.Name)
            ) {
                contactRecordTypeIdsByDeveloperName.put(RECORD_TYPE_NON_SINGPASS, rt.Id);
            }
        }
        return contactRecordTypeIdsByDeveloperName;
    }

    private static Boolean isConsentRecordTypeUsable(Schema.RecordTypeInfo rtInfo) {
        if (Test.isRunningTest()) {
            return true;
        }
        return rtInfo != null && rtInfo.isAvailable();
    }

    private static String recordTypeLabelForDeveloperName(String developerName) {
        if (RECORD_TYPE_SINGPASS.equals(developerName)) {
            return RECORD_TYPE_LABEL_SINGPASS;
        }
        if (RECORD_TYPE_NON_SINGPASS.equals(developerName)) {
            return RECORD_TYPE_LABEL_NON_SINGPASS;
        }
        return developerName;
    }

    private static RowValidationError buildRowValidationError(
        Integer rowNumber,
        String reason,
        String message,
        String fieldName,
        String fieldValue
    ) {
        RowValidationError error = new RowValidationError();
        error.rowNumber = rowNumber;
        error.errorReason = reason;
        error.errorMessage = message;
        error.fieldName = fieldName;
        error.fieldValue = fieldValue;
        return error;
    }

    private static String joinErrorMessages(List<RowValidationError> rowErrors) {
        List<String> messages = new List<String>();
        for (RowValidationError error : rowErrors) {
            if (error != null && String.isNotBlank(error.errorMessage)) {
                messages.add(error.errorMessage);
            }
        }
        return String.join(messages, ' | ');
    }

    private static Exception__c buildExceptionFromRowError(
        BatchUploadRow row,
        RowValidationError error,
        UploadValidationContext context
    ) {
        return BatchExcelUploadValidationService.buildExceptionFromConsentError(
            toValidationRow(row),
            toServiceError(error),
            context.sharedContext
        );
    }

    private static BatchExcelUploadValidationService.ConsentValidationRow toValidationRow(BatchUploadRow row) {
        BatchExcelUploadValidationService.ConsentValidationRow svcRow = new BatchExcelUploadValidationService.ConsentValidationRow();
        if (row == null) {
            return svcRow;
        }
        svcRow.rowNumber = row.rowNumber;
        svcRow.email = row.email;
        svcRow.fullName = row.fullName;
        svcRow.idType = row.idType;
        svcRow.idNumber = row.idNumber;
        svcRow.dateOfBirth = row.dateOfBirth;
        svcRow.lastEmploymentDate = row.lastEmploymentDate;
        svcRow.employmentStatus = row.employmentStatus;
        return svcRow;
    }

    private static BatchExcelUploadValidationService.RowValidationError toServiceError(RowValidationError error) {
        BatchExcelUploadValidationService.RowValidationError svcErr = new BatchExcelUploadValidationService.RowValidationError();
        if (error == null) {
            return svcErr;
        }
        svcErr.rowNumber = error.rowNumber;
        svcErr.errorReason = error.errorReason;
        svcErr.errorMessage = error.errorMessage;
        svcErr.fieldName = error.fieldName;
        svcErr.fieldValue = error.fieldValue;
        return svcErr;
    }

    private static List<RowValidationError> fromServiceErrors(List<BatchExcelUploadValidationService.RowValidationError> errors) {
        List<RowValidationError> converted = new List<RowValidationError>();
        for (BatchExcelUploadValidationService.RowValidationError error : errors) {
            RowValidationError localErr = new RowValidationError();
            localErr.rowNumber = error.rowNumber;
            localErr.errorReason = error.errorReason;
            localErr.errorMessage = error.errorMessage;
            localErr.fieldName = error.fieldName;
            localErr.fieldValue = error.fieldValue;
            converted.add(localErr);
        }
        return converted;
    }

    private static RowError rowError(Integer rowNumber, String message) {
        RowError e = new RowError();
        e.rowNumber = rowNumber;
        e.message = message;
        return e;
    }

    private static String trimVal(String raw) {
        return raw == null ? null : raw.trim();
    }

    private static Boolean isBlankRow(BatchUploadRow row) {
        return String.isBlank(trimVal(row.email)) &&
            String.isBlank(trimVal(row.fullName)) &&
            String.isBlank(trimVal(row.idType)) &&
            String.isBlank(trimVal(row.idNumber)) &&
            String.isBlank(trimVal(row.dateOfBirth)) &&
            String.isBlank(trimVal(row.lastEmploymentDate)) &&
            String.isBlank(trimVal(row.employmentStatus));
    }
}