public without sharing class ReportRequestConsentValidator {
    public class ValidationResult {
        @AuraEnabled public Id dataSubjectId;
        @AuraEnabled public Boolean isEligible;
        @AuraEnabled public String reasonCode;

        public ValidationResult(Id dataSubjectId, Boolean isEligible, String reasonCode) {
            this.dataSubjectId = dataSubjectId;
            this.isEligible = isEligible;
            this.reasonCode = reasonCode;
        }
    }

    @AuraEnabled
    public static ValidationResult validateForSubmission(Id dataSubjectId, Id clientAccountId) {
        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(dataSubjectId, clientAccountId);
        return new ValidationResult(dataSubjectId, result.isEligible, result.reasonCode);
    }

    public static List<ValidationResult> validateForSubmission(List<Id> dataSubjectIds, Id clientAccountId) {
        List<ValidationResult> validationResults = new List<ValidationResult>();
        if (dataSubjectIds == null || dataSubjectIds.isEmpty()) {
            return validationResults;
        }

        Set<Id> uniqueSubjectIds = new Set<Id>(dataSubjectIds);
        for (Id subjectId : uniqueSubjectIds) {
            validationResults.add(validateForSubmission(subjectId, clientAccountId));
        }
        return validationResults;
    }
}