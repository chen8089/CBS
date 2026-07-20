public without sharing class ConsentEligibilityService {
    private static final String MATCH_STATUS_MATCHED = 'MATCHED';
    private static final String MATCH_STATUS_PENDING = 'PENDING';
    private static final String MATCH_STATUS_FAILED = 'FAILED';
    private static final String MATCH_STATUS_UNKNOWN = 'UNKNOWN';

    public class EligibilityResult {
        @AuraEnabled public Boolean isEligible;
        @AuraEnabled public String reasonCode;

        public EligibilityResult(Boolean isEligible, String reasonCode) {
            this.isEligible = isEligible;
            this.reasonCode = reasonCode;
        }
    }

    public static EligibilityResult isConsentEligibleForReport(Id dataSubjectId, Id clientAccountId) {
        Set<Id> subjectIds = new Set<Id>();
        if (dataSubjectId != null) {
            subjectIds.add(dataSubjectId);
        }
        Map<Id, Id> expectedAccountBySubjectId = new Map<Id, Id>();
        if (dataSubjectId != null && clientAccountId != null) {
            expectedAccountBySubjectId.put(dataSubjectId, clientAccountId);
        }
        Map<Id, EligibilityResult> results = isConsentEligibleForReport(subjectIds, expectedAccountBySubjectId);
        return results.containsKey(dataSubjectId)
            ? results.get(dataSubjectId)
            : new EligibilityResult(false, 'CONSENT_NOT_FOUND');
    }

    public static Map<Id, EligibilityResult> isConsentEligibleForReport(
        Set<Id> dataSubjectIds,
        Map<Id, Id> expectedClientAccountBySubjectId
    ) {
        Map<Id, EligibilityResult> resultsBySubjectId = new Map<Id, EligibilityResult>();
        if (dataSubjectIds == null || dataSubjectIds.isEmpty()) {
            return resultsBySubjectId;
        }

        Map<Id, Consent__c> latestConsentBySubjectId = getLatestConsents(dataSubjectIds);
        Map<Id, Integer> successfulRetrievalCountBySubjectId = querySuccessfulRetrievalCountBySubject(dataSubjectIds);
        for (Id dataSubjectId : dataSubjectIds) {
            Consent__c consent = latestConsentBySubjectId.get(dataSubjectId);
            Id expectedClientAccountId = expectedClientAccountBySubjectId == null
                ? null
                : expectedClientAccountBySubjectId.get(dataSubjectId);
            Integer successfulRetrievalCount = successfulRetrievalCountBySubjectId.containsKey(dataSubjectId)
                ? successfulRetrievalCountBySubjectId.get(dataSubjectId)
                : 0;
            resultsBySubjectId.put(
                dataSubjectId,
                evaluateConsent(consent, expectedClientAccountId, successfulRetrievalCount)
            );
        }
        return resultsBySubjectId;
    }

    public static EligibilityResult isConsentEligibleForExport(Id dataSubjectId, Id reportRequestId) {
        return isConsentEligibleForReport(dataSubjectId, null);
    }

    public static EligibilityResult revalidateConsentsBeforeSubmit(Id reportRequestId) {
        if (reportRequestId == null) {
            return new EligibilityResult(false, 'REPORT_REQUEST_REQUIRED');
        }
        Report_Request_Item__c requestRecord = [
            SELECT Id, Data_Subject__c
            FROM Report_Request_Item__c
            WHERE Id = :reportRequestId
            LIMIT 1
        ];
        if (requestRecord.Data_Subject__c == null) {
            return new EligibilityResult(false, 'DATA_SUBJECT_REQUIRED');
        }
        return isConsentEligibleForReport(requestRecord.Data_Subject__c, null);
    }

    public static EligibilityResult revalidateConsentsBeforeExport(Id reportRequestId) {
        return revalidateConsentsBeforeSubmit(reportRequestId);
    }

    private static Consent__c getLatestConsent(Id dataSubjectId) {
        Set<Id> subjectIds = new Set<Id>();
        if (dataSubjectId != null) {
            subjectIds.add(dataSubjectId);
        }
        Map<Id, Consent__c> latestBySubject = getLatestConsents(subjectIds);
        return latestBySubject.get(dataSubjectId);
    }

    private static Map<Id, Consent__c> getLatestConsents(Set<Id> dataSubjectIds) {
        Map<Id, Consent__c> latestBySubjectId = new Map<Id, Consent__c>();
        if (dataSubjectIds == null || dataSubjectIds.isEmpty()) {
            return latestBySubjectId;
        }
        for (Consent__c consentRecord : [
            SELECT
                Id,
                Data_Subject__c,
                Consent_Status__c,
                Consent_Expiry_Date__c,
                Match_Status__c,
                Data_Subject__r.AccountId,
                Data_Subject__r.Current_Consent_Status__c,
                Data_Subject__r.Data_Subject_Lifecycle_Stage__c,
                Data_Subject__r.Report_Eligibility_Status__c,
                Report_Use_Count__c,
                Employment_Status__c
            FROM Consent__c
            WHERE Data_Subject__c IN :dataSubjectIds
            ORDER BY Data_Subject__c ASC, CreatedDate DESC
        ]) {
            if (!latestBySubjectId.containsKey(consentRecord.Data_Subject__c)) {
                latestBySubjectId.put(consentRecord.Data_Subject__c, consentRecord);
            }
        }
        return latestBySubjectId;
    }

    private static EligibilityResult evaluateConsent(
        Consent__c consent,
        Id expectedClientAccountId,
        Integer successfulRetrievalCount
    ) {
        if (consent == null) {
            return new EligibilityResult(false, 'CONSENT_NOT_FOUND');
        }

        String canonicalConsentStatus = ConsentStatusModelService.normalizeConsentStatus(consent.Consent_Status__c);
        if (ConsentStatusModelService.isBlockedForReport(canonicalConsentStatus)) {
            return new EligibilityResult(false, 'CONSENT_STATUS_BLOCKED');
        }
        if (canonicalConsentStatus != ConsentStatusModelService.STATUS_ACTIVE) {
            return new EligibilityResult(false, 'CONSENT_STATUS_UNSUPPORTED');
        }
        if (consent.Consent_Expiry_Date__c != null && consent.Consent_Expiry_Date__c < Date.today()) {
            return new EligibilityResult(false, 'CONSENT_EXPIRED');
        }
        if (
            expectedClientAccountId != null &&
            consent.Data_Subject__r != null &&
            consent.Data_Subject__r.AccountId != expectedClientAccountId
        ) {
            return new EligibilityResult(false, 'CLIENT_ACCOUNT_MISMATCH');
        }
        if (isBlockedByContactState(consent)) {
            return new EligibilityResult(false, 'CONTACT_STATUS_BLOCKED');
        }
        String myInfoMatchStatus = normalizeMyInfoMatchStatus(consent.Match_Status__c);
        if (myInfoMatchStatus == MATCH_STATUS_PENDING) {
            return new EligibilityResult(false, 'MYINFO_MATCH_PENDING');
        }
        if (myInfoMatchStatus == MATCH_STATUS_FAILED) {
            return new EligibilityResult(false, 'MYINFO_MATCH_FAILED');
        }
        if (myInfoMatchStatus != MATCH_STATUS_MATCHED) {
            return new EligibilityResult(false, 'MYINFO_MATCH_UNSUPPORTED');
        }
        if (isPrehireConsumed(consent, successfulRetrievalCount)) {
            return new EligibilityResult(false, 'PREHIRE_ALREADY_USED');
        }
        return new EligibilityResult(true, 'ALLOWED');
    }

    private static Boolean isPrehireConsumed(Consent__c consent, Integer successfulRetrievalCount) {
        if (consent == null || !isPrehireEmploymentStatus(consent.Employment_Status__c)) {
            return false;
        }

        Integer reportUseCount = consent.Report_Use_Count__c == null ? 0 : Integer.valueOf(consent.Report_Use_Count__c);
        Integer successfulCount = successfulRetrievalCount == null ? 0 : successfulRetrievalCount;
        return reportUseCount >= 1 || successfulCount >= 1;
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

    private static Map<Id, Integer> querySuccessfulRetrievalCountBySubject(Set<Id> dataSubjectIds) {
        Map<Id, Integer> countBySubjectId = new Map<Id, Integer>();
        if (dataSubjectIds == null || dataSubjectIds.isEmpty()) {
            return countBySubjectId;
        }

        AggregateResult[] aggregated = [
            SELECT Data_Subject__c dataSubjectId, SUM(Successful_Retrieval_Count__c) total
            FROM Report_Request_Item__c
            WHERE Data_Subject__c IN :dataSubjectIds
            GROUP BY Data_Subject__c
        ];
        for (AggregateResult row : aggregated) {
            Id dataSubjectId = (Id) row.get('dataSubjectId');
            Decimal total = (Decimal) row.get('total');
            countBySubjectId.put(dataSubjectId, total == null ? 0 : Integer.valueOf(total));
        }
        return countBySubjectId;
    }

    private static Boolean isBlockedByContactState(Consent__c consent) {
        if (consent == null || consent.Data_Subject__r == null) {
            return false;
        }

        String contactConsentCanonical =
            ConsentStatusModelService.normalizeContactConsentStatus(consent.Data_Subject__r.Current_Consent_Status__c);
        if (ConsentStatusModelService.isBlockedForReport(contactConsentCanonical)) {
            return true;
        }

        String lifecycleCanonical =
            ConsentStatusModelService.normalizeLifecycleStage(consent.Data_Subject__r.Data_Subject_Lifecycle_Stage__c);
        if (ConsentStatusModelService.isBlockedForReport(lifecycleCanonical)) {
            return true;
        }

        String reportEligibilityCanonical =
            ConsentStatusModelService.normalizeReportEligibility(consent.Data_Subject__r.Report_Eligibility_Status__c);
        if (ConsentStatusModelService.isBlockedForReport(reportEligibilityCanonical)) {
            return true;
        }
        return false;
    }

    private static String normalizeMyInfoMatchStatus(String rawMatchStatus) {
        String token = toToken(rawMatchStatus);
        if (token == null) {
            return MATCH_STATUS_UNKNOWN;
        }
        if (token == 'matched' || token == 'success' || token == 'passed') {
            return MATCH_STATUS_MATCHED;
        }
        if (token == 'pending' || token == 'pendingreview' || token == 'inprogress') {
            return MATCH_STATUS_PENDING;
        }
        if (token == 'failed' || token == 'unmatched' || token == 'exception') {
            return MATCH_STATUS_FAILED;
        }
        return MATCH_STATUS_UNKNOWN;
    }

    private static String toToken(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String lowered = rawValue.trim().toLowerCase();
        lowered = lowered.replace(' ', '');
        lowered = lowered.replace('_', '');
        lowered = lowered.replace('-', '');
        lowered = lowered.replace('/', '');
        return lowered;
    }
}