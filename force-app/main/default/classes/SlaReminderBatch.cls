public without sharing class SlaReminderBatch implements Database.Batchable<SObject> {
    @TestVisible
    private static final Integer WINDOW_START_HOURS = 48;
    @TestVisible
    private static final Integer WINDOW_END_HOURS = 72;
    @TestVisible
    private static final String DELIVERY_STATUS_COMPLETED = 'Completed';
    @TestVisible
    private static final String ELIGIBILITY_STATUS_INELIGIBLE = 'Ineligible';
    @TestVisible
    private static final String REMINDER_STATUS_SENT = 'Sent';
    @TestVisible
    private static final String SLA_STATUS_WITHIN = 'Within SLA';
    @TestVisible
    private static final String SLA_STATUS_NEAR_DUE = 'Near Due';
    @TestVisible
    private static final String SLA_STATUS_OVERDUE = 'Overdue';
    @TestVisible
    private static final String SLA_STATUS_BREACHED = 'Breached';
    @TestVisible
    private static final Integer REMINDER_REVIEW_OFFSET_DAYS = 2;

    private final Datetime windowStart;
    private final Datetime windowEnd;

    public SlaReminderBatch() {
        this(System.now());
    }

    @TestVisible
    SlaReminderBatch(Datetime anchor) {
        Datetime safeAnchor = anchor == null ? System.now() : anchor;
        this.windowStart = safeAnchor.addHours(WINDOW_START_HOURS);
        this.windowEnd = safeAnchor.addHours(WINDOW_END_HOURS);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Name, Data_Subject__c, SLA_Due_Date__c, SLA_Warning_Sent__c,
                Delivery_Status__c, Eligibility_Status__c
            FROM Report_Request_Item__c
            WHERE SLA_Due_Date__c >= :windowStart
                AND SLA_Due_Date__c <= :windowEnd
                AND SLA_Warning_Sent__c = false
                AND Data_Subject__c != null
                AND (Delivery_Status__c = null OR Delivery_Status__c != :DELIVERY_STATUS_COMPLETED)
                AND (Eligibility_Status__c = null OR Eligibility_Status__c != :ELIGIBILITY_STATUS_INELIGIBLE)
        ]);
    }

    public void execute(Database.BatchableContext context, List<Report_Request_Item__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<Id> sentRequestItemIds = SlaReminderService.sendReminders(scope);
        if (sentRequestItemIds.isEmpty()) {
            return;
        }

        List<Report_Request_Item__c> updates = new List<Report_Request_Item__c>();
        for (Id requestItemId : sentRequestItemIds) {
            updates.add(new Report_Request_Item__c(
                Id = requestItemId,
                SLA_Warning_Sent__c = true
            ));
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
        updateContactTracking(sentRequestItemIds, scope);
    }

    public void finish(Database.BatchableContext context) {
    }

    private static void updateContactTracking(Set<Id> sentRequestItemIds, List<Report_Request_Item__c> scope) {
        if (sentRequestItemIds == null || sentRequestItemIds.isEmpty() || scope == null || scope.isEmpty()) {
            return;
        }

        Map<Id, Report_Request_Item__c> requestItemById = new Map<Id, Report_Request_Item__c>();
        for (Report_Request_Item__c row : scope) {
            requestItemById.put(row.Id, row);
        }

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        String reminderStatusValue = resolvePicklistValue(contactFields, 'Reminder_Status__c', REMINDER_STATUS_SENT);
        Map<String, String> slaStatusByToken = new Map<String, String>{
            SLA_STATUS_WITHIN => resolvePicklistValue(contactFields, 'SLA_Status__c', SLA_STATUS_WITHIN),
            SLA_STATUS_NEAR_DUE => resolvePicklistValue(contactFields, 'SLA_Status__c', SLA_STATUS_NEAR_DUE),
            SLA_STATUS_OVERDUE => resolvePicklistValue(contactFields, 'SLA_Status__c', SLA_STATUS_OVERDUE),
            SLA_STATUS_BREACHED => resolvePicklistValue(contactFields, 'SLA_Status__c', SLA_STATUS_BREACHED)
        };

        Map<Id, Contact> updatesByContactId = new Map<Id, Contact>();
        for (Id requestItemId : sentRequestItemIds) {
            Report_Request_Item__c row = requestItemById.get(requestItemId);
            if (row == null || row.Data_Subject__c == null) {
                continue;
            }

            Contact updateRow = updatesByContactId.containsKey(row.Data_Subject__c)
                ? updatesByContactId.get(row.Data_Subject__c)
                : new Contact(Id = row.Data_Subject__c);

            if (contactFields.containsKey('Reminder_Status__c') && !String.isBlank(reminderStatusValue)) {
                updateRow.put('Reminder_Status__c', reminderStatusValue);
            }
            if (contactFields.containsKey('Last_Reminder_Sent_Date__c')) {
                updateRow.put('Last_Reminder_Sent_Date__c', Date.today());
            }
            if (contactFields.containsKey('Reminder_Review_Date__c')) {
                updateRow.put('Reminder_Review_Date__c', Date.today().addDays(REMINDER_REVIEW_OFFSET_DAYS));
            }
            if (contactFields.containsKey('SLA_Due_Date__c') && row.SLA_Due_Date__c != null) {
                updateRow.put('SLA_Due_Date__c', row.SLA_Due_Date__c.date());
            }
            if (contactFields.containsKey('SLA_Status__c')) {
                String token = resolveSlaStatusToken(row.SLA_Due_Date__c);
                String statusValue = slaStatusByToken.get(token);
                if (!String.isBlank(statusValue)) {
                    updateRow.put('SLA_Status__c', statusValue);
                }
            }
            updatesByContactId.put(updateRow.Id, updateRow);
        }

        if (!updatesByContactId.isEmpty()) {
            Database.update(updatesByContactId.values(), false);
        }
    }

    private static String resolveSlaStatusToken(Datetime dueDateTime) {
        if (dueDateTime == null) {
            return SLA_STATUS_WITHIN;
        }
        Long remainingMs = dueDateTime.getTime() - System.now().getTime();
        Decimal remainingHours = remainingMs / (1000.0 * 60.0 * 60.0);
        if (remainingHours <= 0) {
            return SLA_STATUS_BREACHED;
        }
        if (remainingHours <= 48) {
            return SLA_STATUS_OVERDUE;
        }
        if (remainingHours <= 72) {
            return SLA_STATUS_NEAR_DUE;
        }
        return SLA_STATUS_WITHIN;
    }

    private static String resolvePicklistValue(
        Map<String, Schema.SObjectField> fields,
        String fieldApiName,
        String preferredValue
    ) {
        if (fields == null || String.isBlank(fieldApiName) || String.isBlank(preferredValue) || !fields.containsKey(fieldApiName)) {
            return null;
        }
        Schema.DescribeFieldResult describe = fields.get(fieldApiName).getDescribe();
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.getValue().equalsIgnoreCase(preferredValue) || entry.getLabel().equalsIgnoreCase(preferredValue)) {
                return entry.getValue();
            }
        }
        return null;
    }
}