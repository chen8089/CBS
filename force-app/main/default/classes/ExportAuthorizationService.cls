public without sharing class ExportAuthorizationService {
    @TestVisible
    private static Boolean bypassProcessingOfficerCheckInTests = false;

    public class ExportAuthorizationResult {
        @AuraEnabled public Boolean isAuthorized;
        @AuraEnabled public String reasonCode;

        public ExportAuthorizationResult(Boolean isAuthorized, String reasonCode) {
            this.isAuthorized = isAuthorized;
            this.reasonCode = reasonCode;
        }
    }

    public static ExportAuthorizationResult canExport(Id reportRequestId, Id dataSubjectId, Id clientAccountId) {
        if (!isProcessingOfficer(UserInfo.getUserId())) {
            return new ExportAuthorizationResult(false, 'USER_NOT_PROCESSING_OFFICER');
        }
        ConsentEligibilityService.EligibilityResult eligibility =
            ConsentEligibilityService.isConsentEligibleForExport(dataSubjectId, reportRequestId);
        if (!eligibility.isEligible) {
            return new ExportAuthorizationResult(false, eligibility.reasonCode);
        }
        return new ExportAuthorizationResult(true, 'AUTHORIZED');
    }

    public static Id logExportEvent(
        String exportType,
        Id sourceCaseId,
        Id clientAccountId,
        Integer recordCount,
        String exportFileId,
        String validationStatus,
        String exportStatus
    ) {
        return logExportEvent(
            exportType,
            sourceCaseId,
            clientAccountId,
            recordCount,
            exportFileId,
            validationStatus,
            exportStatus,
            resolveSourceIp()
        );
    }

    public static Id logExportEvent(
        String exportType,
        Id sourceCaseId,
        Id clientAccountId,
        Integer recordCount,
        String exportFileId,
        String validationStatus,
        String exportStatus,
        String sourceIp
    ) {
        Export_Log__c recordToInsert = new Export_Log__c(
            Export_Type__c = exportType,
            Source_Case__c = sourceCaseId,
            Client_Account__c = clientAccountId,
            Exported_By__c = UserInfo.getUserId(),
            Exported_At__c = System.now(),
            Record_Count__c = recordCount,
            Export_File_Id__c = exportFileId,
            Consent_Validation_Status__c = validationStatus,
            Export_Status__c = exportStatus
        );
        setFieldIfAvailable(recordToInsert, 'Source_IP__c', sourceIp);
        insert recordToInsert;
        return recordToInsert.Id;
    }

    private static Boolean isProcessingOfficer(Id userId) {
        if (Test.isRunningTest() && bypassProcessingOfficerCheckInTests) {
            return true;
        }
        User actingUser = [
            SELECT Profile.PermissionsModifyAllData
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        if (actingUser.Profile.PermissionsModifyAllData) {
            return true;
        }
        return [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSet.Name = 'CBS_Processing_Officer'
        ] > 0;
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        if (targetRecord == null || String.isBlank(fieldApiName)) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }

    private static String resolveSourceIp() {
        try {
            if (ApexPages.currentPage() != null) {
                Map<String, String> headers = ApexPages.currentPage().getHeaders();
                List<String> headerCandidates = new List<String>{
                    'True-Client-IP',
                    'X-Forwarded-For',
                    'X-Real-IP',
                    'CF-Connecting-IP'
                };
                for (String headerName : headerCandidates) {
                    String headerValue = headers == null ? null : headers.get(headerName);
                    if (!String.isBlank(headerValue)) {
                        return headerValue.trim();
                    }
                }
            }
        } catch (Exception ignored) {
            // Best-effort only. Some execution contexts do not expose HTTP headers.
        }
        return null;
    }
}