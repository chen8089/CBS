public without sharing class ReportRequestCaseCreationGuard {
    private static final String REPORT_REQUEST_RECORD_TYPE = 'CBS_Report_Request';
    @TestVisible public static Boolean allowReportRequestCaseCreation = false;

    public static void beforeInsert(List<Case> newCases) {
        if (newCases == null || newCases.isEmpty() || allowReportRequestCaseCreation) {
            return;
        }

        Set<Id> reportRequestRecordTypeIds = resolveReportRequestRecordTypeIds();
        if (reportRequestRecordTypeIds.isEmpty()) {
            return;
        }

        for (Case caseRecord : newCases) {
            if (caseRecord.RecordTypeId != null && reportRequestRecordTypeIds.contains(caseRecord.RecordTypeId)) {
                caseRecord.addError(
                    'CBS Report Request Case must be created through the report request submission service.'
                );
            }
        }
    }

    private static Set<Id> resolveReportRequestRecordTypeIds() {
        Set<Id> recordTypeIds = new Set<Id>();
        for (RecordType recordType : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = :REPORT_REQUEST_RECORD_TYPE
        ]) {
            recordTypeIds.add(recordType.Id);
        }
        return recordTypeIds;
    }
}