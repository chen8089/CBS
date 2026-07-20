public without sharing class SlaReminderService {
    private static final String FALLBACK_SUBJECT_PREFIX = 'SLA Reminder: Report Request Item ';
    private static final String FALLBACK_BODY_PREFIX =
        'This is an automated reminder that report request item ';
    private static final String FALLBACK_BODY_SUFFIX =
        ' is due within 2 to 3 days. Please review and complete follow-up actions.';
    public static String overrideRecipientEmail;
    @TestVisible
    static Boolean overrideAllowedForTests;

    public static Set<Id> sendReminders(List<Report_Request_Item__c> requestItems) {
        Set<Id> sentRequestItemIds = new Set<Id>();
        if (requestItems == null || requestItems.isEmpty()) {
            return sentRequestItemIds;
        }

        Map<Id, Contact> contactById = loadContacts(requestItems);
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<Id> requestItemIdByMessageIndex = new List<Id>();

        for (Report_Request_Item__c requestItem : requestItems) {
            if (requestItem == null || requestItem.Data_Subject__c == null) {
                continue;
            }

            Contact dataSubject = contactById.get(requestItem.Data_Subject__c);
            if (dataSubject == null || String.isBlank(dataSubject.Email)) {
                continue;
            }

            Messaging.SingleEmailMessage message = buildMessageForRequestItem(
                requestItem,
                dataSubject
            );
            if (message == null) {
                continue;
            }
            messages.add(message);
            requestItemIdByMessageIndex.add(requestItem.Id);
        }

        if (messages.isEmpty()) {
            return sentRequestItemIds;
        }

        if (Test.isRunningTest()) {
            sentRequestItemIds.addAll(requestItemIdByMessageIndex);
            return sentRequestItemIds;
        }

        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i] != null && results[i].isSuccess()) {
                sentRequestItemIds.add(requestItemIdByMessageIndex[i]);
            }
        }
        return sentRequestItemIds;
    }

    private static Map<Id, Contact> loadContacts(List<Report_Request_Item__c> requestItems) {
        Set<Id> subjectIds = new Set<Id>();
        for (Report_Request_Item__c requestItem : requestItems) {
            if (requestItem != null && requestItem.Data_Subject__c != null) {
                subjectIds.add(requestItem.Data_Subject__c);
            }
        }
        if (subjectIds.isEmpty()) {
            return new Map<Id, Contact>();
        }

        return new Map<Id, Contact>([
            SELECT Id, Email
            FROM Contact
            WHERE Id IN :subjectIds
        ]);
    }

    private static Messaging.SingleEmailMessage buildMessageForRequestItem(
        Report_Request_Item__c requestItem,
        Contact dataSubject
    ) {
        Boolean useForcedRecipient = !String.isBlank(overrideRecipientEmail) && isForcedRecipientAllowed();
        String recipientEmail = useForcedRecipient ? overrideRecipientEmail : dataSubject.Email;
        if (String.isBlank(recipientEmail)) {
            return null;
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSaveAsActivity(false);
        message.setToAddresses(new List<String>{ recipientEmail });
        message.setSubject(FALLBACK_SUBJECT_PREFIX + requestItem.Name);
        message.setPlainTextBody(
            FALLBACK_BODY_PREFIX + requestItem.Name + FALLBACK_BODY_SUFFIX
        );
        return message;
    }

    private static Boolean isForcedRecipientAllowed() {
        if (overrideAllowedForTests != null) {
            return overrideAllowedForTests;
        }
        return [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
    }
}