trigger caseTrigger on Case (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ReportRequestCaseCreationGuard.beforeInsert(Trigger.new);
    }
}