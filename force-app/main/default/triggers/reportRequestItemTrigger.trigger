trigger reportRequestItemTrigger on Report_Request_Item__c (before insert, before update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ReportRequestItemTriggerHandler.beforeInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        ReportRequestItemTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
}