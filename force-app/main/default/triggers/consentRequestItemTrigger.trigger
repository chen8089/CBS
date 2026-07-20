trigger consentRequestItemTrigger on Consent_Request_Item__c (before insert, after insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ConsentRequestItemTriggerHandler.beforeInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        ConsentRequestItemTriggerHandler.afterInsert(Trigger.new);
    }
}