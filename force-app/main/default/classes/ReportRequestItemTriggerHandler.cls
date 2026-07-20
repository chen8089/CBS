public without sharing class ReportRequestItemTriggerHandler {
    private static final String REPORT_REQUEST_TYPE = 'Report Request';

    public static void beforeInsert(List<Report_Request_Item__c> newItems) {
        validateItems(newItems);
    }

    public static void beforeUpdate(List<Report_Request_Item__c> newItems, Map<Id, Report_Request_Item__c> oldMap) {
        validateItems(newItems);
    }

    private static void validateItems(List<Report_Request_Item__c> candidateItems) {
        if (candidateItems == null || candidateItems.isEmpty()) {
            return;
        }

        Map<Id, List<Report_Request_Item__c>> itemsByDataSubjectId = new Map<Id, List<Report_Request_Item__c>>();
        Set<Id> caseIds = new Set<Id>();
        for (Report_Request_Item__c item : candidateItems) {
            if (!isReportRequestItem(item) || item.Data_Subject__c == null) {
                continue;
            }
            if (!itemsByDataSubjectId.containsKey(item.Data_Subject__c)) {
                itemsByDataSubjectId.put(item.Data_Subject__c, new List<Report_Request_Item__c>());
            }
            itemsByDataSubjectId.get(item.Data_Subject__c).add(item);
            if (item.Report_Request_Case__c != null) {
                caseIds.add(item.Report_Request_Case__c);
            }
        }
        if (itemsByDataSubjectId.isEmpty()) {
            return;
        }

        Map<Id, Id> accountByCaseId = new Map<Id, Id>();
        if (!caseIds.isEmpty()) {
            for (Case caseRecord : [
                SELECT Id, AccountId
                FROM Case
                WHERE Id IN :caseIds
            ]) {
                accountByCaseId.put(caseRecord.Id, caseRecord.AccountId);
            }
        }

        Map<Id, Id> expectedClientAccountBySubjectId = new Map<Id, Id>();
        for (Id dataSubjectId : itemsByDataSubjectId.keySet()) {
            for (Report_Request_Item__c item : itemsByDataSubjectId.get(dataSubjectId)) {
                Id expectedAccountId = item.Client_Account__c;
                if (expectedAccountId == null && item.Report_Request_Case__c != null) {
                    expectedAccountId = accountByCaseId.get(item.Report_Request_Case__c);
                }
                if (expectedAccountId != null) {
                    expectedClientAccountBySubjectId.put(dataSubjectId, expectedAccountId);
                    break;
                }
            }
        }

        Map<Id, ConsentEligibilityService.EligibilityResult> eligibilityBySubjectId =
            ConsentEligibilityService.isConsentEligibleForReport(itemsByDataSubjectId.keySet(), expectedClientAccountBySubjectId);
        for (Id dataSubjectId : itemsByDataSubjectId.keySet()) {
            ConsentEligibilityService.EligibilityResult eligibilityResult = eligibilityBySubjectId.get(dataSubjectId);
            for (Report_Request_Item__c item : itemsByDataSubjectId.get(dataSubjectId)) {
                if (eligibilityResult == null || !eligibilityResult.isEligible) {
                    setFieldIfAvailable(item, 'Eligibility_Status__c', 'Ineligible');
                    setFieldIfAvailable(item, 'Consent_Revalidation_Status__c', 'Failed');
                    item.addError(
                        'Report Request Item blocked: Data Subject consent is not valid for report request ('
                        + String.valueOf(eligibilityResult == null ? 'CONSENT_NOT_FOUND' : eligibilityResult.reasonCode)
                        + ').'
                    );
                    continue;
                }
                setFieldIfAvailable(item, 'Eligibility_Status__c', 'Eligible');
                setFieldIfAvailable(item, 'Consent_Revalidation_Status__c', 'Passed');
            }
        }
    }

    private static Boolean isReportRequestItem(Report_Request_Item__c item) {
        if (item == null) {
            return false;
        }
        if (item.Request_Type__c == REPORT_REQUEST_TYPE) {
            return true;
        }
        return item.Report_Request_Case__c != null;
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }
}