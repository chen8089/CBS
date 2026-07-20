/**
 * Consent upload compatibility layer.
 * Reuses BatchExcelUploadController to keep UI/API behavior consistent with batchExcelUploadModal.
 */
public with sharing class ConsentUploadController {
    public static final String SOURCE_CONSENT_UPLOAD = BatchExcelUploadController.SOURCE_CONSENT_UPLOAD;

    public class ConsentUploadRow {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String email;
        @AuraEnabled public String fullName;
        @AuraEnabled public String idType;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String dateOfBirth;
        @AuraEnabled public String employmentStatus;
    }

    public class RowError {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String message;
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

    @AuraEnabled
    public static UploadValidationResult validateAndUploadConsents(
        String batchName,
        String fileName,
        Integer fileSizeBytes,
        String rowsJson,
        String headersJson,
        String fileBodyBase64,
        String fileMimeType
    ) {
        BatchExcelUploadController.UploadValidationResult delegated = BatchExcelUploadController.validateAndUpload(
            batchName,
            fileName,
            rowsJson,
            headersJson,
            fileSizeBytes,
            fileBodyBase64,
            fileMimeType
        );
        return fromBatchValidationResult(delegated);
    }

    @AuraEnabled
    public static UploadResult uploadConsents(String rowsJson) {
        List<BatchExcelUploadController.BatchUploadRow> rows = toBatchRows(rowsJson);
        BatchExcelUploadController.UploadResult delegated = BatchExcelUploadController.uploadBatchContacts(
            rows,
            null,
            null
        );
        return fromBatchUploadResult(delegated);
    }

    private static List<BatchExcelUploadController.BatchUploadRow> toBatchRows(String rowsJson) {
        if (String.isBlank(rowsJson)) {
            return new List<BatchExcelUploadController.BatchUploadRow>();
        }
        List<ConsentUploadRow> consentRows = (List<ConsentUploadRow>) JSON.deserialize(
            rowsJson,
            List<ConsentUploadRow>.class
        );
        List<BatchExcelUploadController.BatchUploadRow> converted = new List<BatchExcelUploadController.BatchUploadRow>();
        for (ConsentUploadRow row : consentRows) {
            BatchExcelUploadController.BatchUploadRow convertedRow = new BatchExcelUploadController.BatchUploadRow();
            convertedRow.rowNumber = row == null ? null : row.rowNumber;
            convertedRow.email = row == null ? null : row.email;
            convertedRow.fullName = row == null ? null : row.fullName;
            convertedRow.idType = row == null ? null : row.idType;
            convertedRow.idNumber = row == null ? null : row.idNumber;
            convertedRow.dateOfBirth = row == null ? null : row.dateOfBirth;
            convertedRow.lastEmploymentDate = null;
            convertedRow.employmentStatus = row == null ? null : row.employmentStatus;
            converted.add(convertedRow);
        }
        return converted;
    }

    private static UploadValidationResult fromBatchValidationResult(
        BatchExcelUploadController.UploadValidationResult source
    ) {
        UploadValidationResult target = new UploadValidationResult();
        if (source == null) {
            target.success = false;
            target.errorReason = 'Upload Failed';
            target.errorMessage = 'Upload Failed';
            target.message = 'Upload Failed';
            target.totalRows = 0;
            target.errors = new List<String>{ 'Upload Failed' };
            target.uploadResult = null;
            return target;
        }
        target.success = source.success;
        target.errorReason = source.errorReason;
        target.errorMessage = source.errorMessage;
        target.message = source.message;
        target.totalRows = source.totalRows;
        target.errors = source.errors == null ? new List<String>() : new List<String>(source.errors);
        target.uploadResult = fromBatchUploadResult(source.uploadResult);
        return target;
    }

    private static UploadResult fromBatchUploadResult(BatchExcelUploadController.UploadResult source) {
        if (source == null) {
            return null;
        }
        UploadResult target = new UploadResult();
        target.batchId = source.batchId;
        target.batchName = source.batchName;
        target.totalRows = source.totalRows;
        target.successRows = source.successRows;
        target.exceptionRows = source.exceptionRows;
        target.successCount = source.successCount;
        target.createdContacts = source.createdContacts;
        target.createdExceptions = source.createdExceptions;
        target.errorCount = source.errorCount;
        target.exceptionCreatedCount = source.exceptionCreatedCount;
        target.skippedDuplicateCount = source.skippedDuplicateCount;
        target.duplicateInFileCount = source.duplicateInFileCount;
        target.duplicateExistingCount = source.duplicateExistingCount;
        target.validationExceptionCount = source.validationExceptionCount;
        target.message = source.message;
        target.errors = new List<RowError>();
        if (source.errors != null) {
            for (BatchExcelUploadController.RowError rowError : source.errors) {
                RowError convertedError = new RowError();
                convertedError.rowNumber = rowError.rowNumber;
                convertedError.message = rowError.message;
                target.errors.add(convertedError);
            }
        }
        return target;
    }
}