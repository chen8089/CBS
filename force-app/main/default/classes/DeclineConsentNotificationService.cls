public without sharing class DeclineConsentNotificationService {
    private static final String TEMPLATE_DEVELOPER_NAME = 'CBS_ConsentDeclinedClientNotification';
    private static final String STATUS_SENT = 'Sent';
    private static final String STATUS_FAILED = 'Failed';
    private static final String STATUS_NOT_SENT = 'Not Sent';

    @TestVisible
    private static Boolean skipEmailSendDuringTests = true;
    @TestVisible
    private static Boolean simulateSendFailureForTests = false;
    @TestVisible
    private static Id templateIdOverrideForTests;

    public class NotificationResult {
        public Boolean sent;
        public Integer recipientCount;
        public String message;

        public NotificationResult(Boolean sent, Integer recipientCount, String message) {
            this.sent = sent;
            this.recipientCount = recipientCount;
            this.message = message;
        }
    }

    public static NotificationResult notifyClientOfDecline(Id dataSubjectId, Id requestItemId) {
        if (dataSubjectId == null) {
            return new NotificationResult(false, 0, 'DATA_SUBJECT_REQUIRED');
        }

        Contact dataSubject = loadDataSubject(dataSubjectId);
        if (dataSubject == null || dataSubject.AccountId == null) {
            updateNotificationStatus(dataSubjectId, STATUS_FAILED);
            return new NotificationResult(false, 0, 'DATA_SUBJECT_OR_ACCOUNT_NOT_FOUND');
        }

        List<Contact> recipientContacts = loadClientUserRecipients(dataSubject.AccountId, dataSubject.Id);
        Set<String> toAddressSet = new Set<String>();
        for (Contact recipient : recipientContacts) {
            if (!String.isBlank(recipient.Email)) {
                toAddressSet.add(recipient.Email.trim().toLowerCase());
            }
        }

        String accountNotificationEmail = loadAccountNotificationEmail(dataSubject);
        if (!String.isBlank(accountNotificationEmail)) {
            toAddressSet.add(accountNotificationEmail.trim().toLowerCase());
        }

        if (toAddressSet.isEmpty()) {
            updateNotificationStatus(dataSubjectId, STATUS_FAILED);
            return new NotificationResult(false, 0, 'NO_RECIPIENTS');
        }

        Id templateId = resolveTemplateId();
        List<Messaging.SingleEmailMessage> messages = buildMessages(
            recipientContacts,
            toAddressSet,
            templateId,
            dataSubject,
            requestItemId
        );

        if (messages.isEmpty()) {
            updateNotificationStatus(dataSubjectId, STATUS_FAILED);
            return new NotificationResult(false, 0, 'NO_MESSAGES');
        }

        Boolean sendSuccess = sendMessages(messages);
        updateNotificationStatus(dataSubjectId, sendSuccess ? STATUS_SENT : STATUS_FAILED);
        return new NotificationResult(
            sendSuccess,
            toAddressSet.size(),
            sendSuccess ? 'NOTIFICATION_SENT' : 'NOTIFICATION_FAILED'
        );
    }

    private static Contact loadDataSubject(Id subjectId) {
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Email',
            'AccountId',
            'Account.Name'
        };
        if (accountFields.containsKey('Notification_Email__c')) {
            fields.add('Account.Notification_Email__c');
        }
        if (hasContactField('Full_Name__c')) {
            fields.add('Full_Name__c');
        }
        if (hasContactField('Principal_Name__c')) {
            fields.add('Principal_Name__c');
        }
        if (hasContactField('Declined_Date__c')) {
            fields.add('Declined_Date__c');
        }

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<Contact> loadClientUserRecipients(Id accountId, Id dataSubjectId) {
        if (accountId == null) {
            return new List<Contact>();
        }

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> whereClauses = new List<String>{
            'AccountId = :accountId',
            'Email != null'
        };
        if (dataSubjectId != null) {
            whereClauses.add('Id != :dataSubjectId');
        }

        List<Id> clientUserRecordTypeIds = getContactRecordTypeIdsByDeveloperName(
            new Set<String>{ 'Client_User' }
        );
        if (!clientUserRecordTypeIds.isEmpty()) {
            whereClauses.add('RecordTypeId IN :clientUserRecordTypeIds');
        }

        if (contactFields.containsKey('Is_Active_Client_User__c')) {
            whereClauses.add('Is_Active_Client_User__c = true');
        }

        List<String> selectFields = new List<String>{ 'Id', 'Email', 'Name' };
        if (contactFields.containsKey('Is_Active_Client_User__c')) {
            selectFields.add('Is_Active_Client_User__c');
        }

        String soql =
            'SELECT ' + String.join(selectFields, ',') +
            ' FROM Contact WHERE ' + String.join(whereClauses, ' AND ') +
            ' ORDER BY LastModifiedDate DESC LIMIT 100';
        return Database.query(soql);
    }

    private static String loadAccountNotificationEmail(Contact dataSubject) {
        if (dataSubject == null || dataSubject.Account == null) {
            return null;
        }
        if (!hasField(dataSubject.Account, 'Notification_Email__c')) {
            return null;
        }
        Object rawValue = dataSubject.Account.get('Notification_Email__c');
        if (rawValue == null || String.isBlank(String.valueOf(rawValue))) {
            return null;
        }
        return String.valueOf(rawValue).trim();
    }

    private static Id resolveTemplateId() {
        if (templateIdOverrideForTests != null) {
            return templateIdOverrideForTests;
        }
        List<EmailTemplate> rows = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :TEMPLATE_DEVELOPER_NAME
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }

    private static List<Messaging.SingleEmailMessage> buildMessages(
        List<Contact> recipientContacts,
        Set<String> toAddressSet,
        Id templateId,
        Contact dataSubject,
        Id requestItemId
    ) {
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        Set<String> coveredAddresses = new Set<String>();

        for (Contact recipient : recipientContacts) {
            if (String.isBlank(recipient.Email)) {
                continue;
            }
            coveredAddresses.add(recipient.Email.trim().toLowerCase());
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setTargetObjectId(recipient.Id);
            message.setSaveAsActivity(false);
            if (requestItemId != null) {
                message.setWhatId(requestItemId);
            }
            if (templateId != null) {
                message.setTemplateId(templateId);
            } else {
                message.setSubject(buildSubject(dataSubject, requestItemId));
                message.setPlainTextBody(buildPlainTextBody(dataSubject, requestItemId));
            }
            messages.add(message);
        }

        Set<String> additionalAddresses = new Set<String>(toAddressSet);
        additionalAddresses.removeAll(coveredAddresses);
        if (!additionalAddresses.isEmpty()) {
            Messaging.SingleEmailMessage additionalMessage = new Messaging.SingleEmailMessage();
            additionalMessage.setToAddresses(new List<String>(additionalAddresses));
            additionalMessage.setSaveAsActivity(false);
            additionalMessage.setSubject(buildSubject(dataSubject, requestItemId));
            additionalMessage.setPlainTextBody(buildPlainTextBody(dataSubject, requestItemId));
            messages.add(additionalMessage);
        }

        return messages;
    }

    private static Boolean sendMessages(List<Messaging.SingleEmailMessage> messages) {
        if (messages == null || messages.isEmpty()) {
            return false;
        }

        if (Test.isRunningTest() && skipEmailSendDuringTests) {
            return !simulateSendFailureForTests;
        }

        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messages, false);
            if (results == null || results.isEmpty()) {
                return false;
            }
            for (Messaging.SendEmailResult result : results) {
                if (result == null || !result.isSuccess()) {
                    return false;
                }
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static String buildSubject(Contact dataSubject, Id requestItemId) {
        String subjectName = resolveDataSubjectName(dataSubject);
        String reference = requestItemId == null ? '-' : String.valueOf(requestItemId);
        return 'Failed Consent Collection Notification - ' + subjectName + ' - Ref ' + reference;
    }

    private static String buildPlainTextBody(Contact dataSubject, Id requestItemId) {
        String subjectName = resolveDataSubjectName(dataSubject);
        String bankName = resolveBankName(dataSubject);
        String declinedAt = resolveDeclinedAt(dataSubject);
        String reference = requestItemId == null ? '-' : String.valueOf(requestItemId);

        List<String> lines = new List<String>{
            'Client Notification: Consent Declined',
            '',
            'Data Subject: ' + subjectName,
            'Bank/Client: ' + bankName,
            'Consent Request Reference: ' + reference,
            'Consent Status: Declined',
            'Declined At: ' + declinedAt,
            '',
            'This is an automated failed consent collection notification from CBS.'
        };
        return String.join(lines, '\n');
    }

    private static String resolveDataSubjectName(Contact dataSubject) {
        if (dataSubject == null) {
            return '-';
        }
        String resolved = getStringFieldValue(
            dataSubject,
            new List<String>{ 'Full_Name__c', 'Principal_Name__c', 'Name' }
        );
        return String.isBlank(resolved) ? '-' : resolved;
    }

    private static String resolveBankName(Contact dataSubject) {
        if (dataSubject != null && dataSubject.Account != null && !String.isBlank(dataSubject.Account.Name)) {
            return dataSubject.Account.Name;
        }
        return '[NAME OF BANK]';
    }

    private static String resolveDeclinedAt(Contact dataSubject) {
        if (dataSubject == null || !hasField(dataSubject, 'Declined_Date__c')) {
            return '-';
        }
        Object rawValue = dataSubject.get('Declined_Date__c');
        if (rawValue instanceof Datetime) {
            return ((Datetime) rawValue).format('d MMM yyyy, h:mm a');
        }
        return rawValue == null ? '-' : String.valueOf(rawValue);
    }

    private static void updateNotificationStatus(Id dataSubjectId, String statusValue) {
        if (dataSubjectId == null) {
            return;
        }
        Contact updateRecord = new Contact(Id = dataSubjectId);
        setOptionalFieldSafe(updateRecord, 'Client_Notification_Status__c', statusValue);
        setOptionalFieldSafe(updateRecord, 'Notification_Status__c', statusValue);
        setOptionalFieldSafe(updateRecord, 'Client_Notification_Status__c', choosePicklistValue(
            Contact.Client_Notification_Status__c.getDescribe(),
            new List<String>{ statusValue, STATUS_NOT_SENT }
        ));
        setOptionalFieldSafe(updateRecord, 'Notification_Status__c', choosePicklistValue(
            Contact.Notification_Status__c.getDescribe(),
            new List<String>{ statusValue, STATUS_NOT_SENT }
        ));
        try {
            update updateRecord;
        } catch (Exception e) {
            // Do not fail the primary decline flow when status tracking field updates are unavailable.
        }
    }

    private static List<Id> getContactRecordTypeIdsByDeveloperName(Set<String> developerNames) {
        List<Id> ids = new List<Id>();
        if (developerNames == null || developerNames.isEmpty()) {
            return ids;
        }
        for (Schema.RecordTypeInfo info : Contact.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (info == null || !info.isAvailable()) {
                continue;
            }
            if (developerNames.contains(info.getDeveloperName())) {
                ids.add(info.getRecordTypeId());
            }
        }
        return ids;
    }

    private static Boolean hasContactField(String fieldApi) {
        return Contact.SObjectType.getDescribe().fields.getMap().containsKey(fieldApi);
    }

    private static Boolean hasField(SObject record, String fieldApi) {
        return record != null
            && !String.isBlank(fieldApi)
            && record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApi);
    }

    private static String getStringFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null || fieldCandidates == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (!hasField(record, fieldApi)) {
                continue;
            }
            Object rawValue = record.get(fieldApi);
            if (rawValue != null && !String.isBlank(String.valueOf(rawValue))) {
                return String.valueOf(rawValue);
            }
        }
        return null;
    }

    private static void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || !hasField(record, fieldApiName)) {
            return;
        }
        if (value == null) {
            try {
                record.put(fieldApiName, null);
            } catch (Exception e) {
                // Ignore optional null assignment failures.
            }
            return;
        }
        try {
            Schema.DescribeFieldResult describe =
                record.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
            if ((describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist)
                && !isPicklistValueAllowed(describe, String.valueOf(value))) {
                return;
            }
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Ignore optional field assignment failures.
        }
    }

    private static Boolean isPicklistValueAllowed(Schema.DescribeFieldResult describe, String value) {
        if (describe == null || String.isBlank(value)) {
            return false;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    private static String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
        if (describe == null || preferredValues == null) {
            return null;
        }
        for (String preferred : preferredValues) {
            if (String.isBlank(preferred)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferred) || entry.getLabel().equalsIgnoreCase(preferred)) {
                    return entry.getValue();
                }
            }
        }
        return null;
    }
}