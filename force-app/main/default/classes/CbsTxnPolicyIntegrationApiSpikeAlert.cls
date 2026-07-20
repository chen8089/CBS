global without sharing class CbsTxnPolicyIntegrationApiSpikeAlert implements TxnSecurity.EventCondition {
    private static Set<Id> integrationUserIds;

    global boolean evaluate(SObject eventObject) {
        if (eventObject == null) {
            return false;
        }

        Id eventUserId = toIdValue(eventObject.get('userid'));
        if (eventUserId == null || !getIntegrationUserIds().contains(eventUserId)) {
            return false;
        }

        // Fallback baseline alert for Integration User API activity.
        // Platform limits prevent efficient threshold aggregation in this policy context.
        return true;
    }

    private static Set<Id> getIntegrationUserIds() {
        if (integrationUserIds == null) {
            integrationUserIds = new Set<Id>();
            for (PermissionSetAssignment assignment : [
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSet.Name = 'CBS_Integration_User'
            ]) {
                integrationUserIds.add(assignment.AssigneeId);
            }
        }
        return integrationUserIds;
    }

    private static Id toIdValue(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        String value = String.valueOf(rawValue);
        return String.isBlank(value) ? null : (Id) value;
    }
}