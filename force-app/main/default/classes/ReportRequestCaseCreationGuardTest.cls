@IsTest
private class ReportRequestCaseCreationGuardTest {
    @IsTest
    static void beforeInsertBlocksDirectReportRequestCaseDml() {
        Id reportRequestRecordTypeId = resolveReportRequestRecordTypeId();
        if (reportRequestRecordTypeId == null) {
            return;
        }

        Case directCase = new Case(
            RecordTypeId = reportRequestRecordTypeId,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Direct CBS report request should be blocked'
        );

        try {
            insert directCase;
            System.assert(false, 'Expected direct CBS Report Request Case insert to be blocked.');
        } catch (DmlException ex) {
            System.assert(
                ex.getMessage().contains('must be created through the report request submission service'),
                'Expected Case guardrail message but got: ' + ex.getMessage()
            );
        }
    }

    private static Id resolveReportRequestRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> infosByDeveloperName =
            Case.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        if (!infosByDeveloperName.containsKey('CBS_Report_Request')) {
            return null;
        }
        Schema.RecordTypeInfo info = infosByDeveloperName.get('CBS_Report_Request');
        return info.isAvailable() ? info.getRecordTypeId() : null;
    }
}