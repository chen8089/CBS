global without sharing class CbsTxnPolicyReportExportAlert implements TxnSecurity.EventCondition {
    global boolean evaluate(SObject eventObject) {
        if (eventObject == null) {
            return false;
        }

        String operation = normalize(toStringValue(eventObject.get('operation')));
        String actionName = normalize(toStringValue(eventObject.get('actionname')));

        // Alert on report/list-view export style operations.
        return operation.contains('export') || actionName.contains('export');
    }

    private static String toStringValue(Object rawValue) {
        return rawValue == null ? '' : String.valueOf(rawValue);
    }

    private static String normalize(String value) {
        return value == null ? '' : value.trim().toLowerCase();
    }
}