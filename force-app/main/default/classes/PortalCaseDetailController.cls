public with sharing class PortalCaseDetailController {
    @TestVisible private static Id overrideScopedAccountIdForTests;

    public class ReportRequestItemRow {
        @AuraEnabled public Id itemId;
        @AuraEnabled public String itemName;
        @AuraEnabled public String dataSubjectName;
        @AuraEnabled public String eligibilityStatus;
        @AuraEnabled public String deliveryStatus;
        @AuraEnabled public Boolean noticeSent;
        @AuraEnabled public Datetime createdDate;
    }

    @AuraEnabled(cacheable=true)
    public static List<ReportRequestItemRow> getReportRequestItems(Id caseId) {
        List<ReportRequestItemRow> rows = new List<ReportRequestItemRow>();
        if (caseId == null) {
            return rows;
        }

        Map<String, Object> binds = new Map<String, Object>{ 'caseId' => caseId };
        String soql =
            'SELECT Id, Name, Data_Subject__r.Name, Eligibility_Status__c, Delivery_Status__c, ' +
            'Notice_Sent_To_Data_Subject__c, CreatedDate ' +
            'FROM Report_Request_Item__c WHERE Report_Request_Case__c = :caseId';

        if (shouldApplyAccountScope()) {
            Id scopedAccountId = resolveScopedAccountId();
            if (scopedAccountId == null) {
                return rows;
            }
            binds.put('scopedAccountId', scopedAccountId);
            soql += ' AND Report_Request_Case__r.AccountId = :scopedAccountId';
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT 200';

        List<Report_Request_Item__c> rawItems = (List<Report_Request_Item__c>) Database.queryWithBinds(
            soql,
            binds,
            AccessLevel.SYSTEM_MODE
        );
        SObjectAccessDecision accessDecision = Security.stripInaccessible(AccessType.READABLE, rawItems);
        List<Report_Request_Item__c> readableItems = (List<Report_Request_Item__c>) accessDecision.getRecords();

        for (Report_Request_Item__c itemRecord : readableItems) {
            ReportRequestItemRow row = new ReportRequestItemRow();
            row.itemId = itemRecord.Id;
            row.itemName = itemRecord.Name;
            row.dataSubjectName = itemRecord.Data_Subject__r == null ? null : itemRecord.Data_Subject__r.Name;
            row.eligibilityStatus = itemRecord.Eligibility_Status__c;
            row.deliveryStatus = itemRecord.Delivery_Status__c;
            row.noticeSent = itemRecord.Notice_Sent_To_Data_Subject__c;
            row.createdDate = itemRecord.CreatedDate;
            rows.add(row);
        }
        return rows;
    }

    private static Boolean shouldApplyAccountScope() {
        if (Test.isRunningTest() && overrideScopedAccountIdForTests != null) {
            return true;
        }
        if (Network.getNetworkId() == null) {
            return false;
        }
        String userType = UserInfo.getUserType();
        return userType != 'Standard' && userType != 'Guest' && userType != 'AutomatedProcess';
    }

    private static Id resolveScopedAccountId() {
        if (Test.isRunningTest() && overrideScopedAccountIdForTests != null) {
            return overrideScopedAccountIdForTests;
        }
        User scopedUser = [
            SELECT AccountId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (scopedUser.AccountId != null) {
            return scopedUser.AccountId;
        }
        if (scopedUser.Contact != null && scopedUser.Contact.AccountId != null) {
            return scopedUser.Contact.AccountId;
        }
        return null;
    }
}