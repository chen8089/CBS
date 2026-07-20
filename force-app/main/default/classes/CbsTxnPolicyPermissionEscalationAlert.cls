global without sharing class CbsTxnPolicyPermissionEscalationAlert implements TxnSecurity.EventCondition {
    global boolean evaluate(SObject eventObject) {
        if (eventObject == null) {
            return false;
        }

        String permissionType = normalize(toStringValue(eventObject.get('permissiontype')));
        String permissionList = normalize(toStringValue(eventObject.get('permissionlist')));

        // Alert on any assignment/elevation style permission activity.
        return permissionType.contains('assign')
            || permissionType.contains('permission')
            || permissionList.contains('modifyall')
            || permissionList.contains('manage')
            || permissionList.contains('author');
    }

    private static String toStringValue(Object rawValue) {
        return rawValue == null ? '' : String.valueOf(rawValue);
    }

    private static String normalize(String value) {
        return value == null ? '' : value.trim().toLowerCase();
    }
}