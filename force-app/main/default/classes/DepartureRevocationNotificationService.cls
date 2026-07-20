public without sharing class DepartureRevocationNotificationService {
    @TestVisible
    private static Boolean skipEmailSendDuringTests = true;

    public static void notifyClientAndCbs(Set<Id> dataSubjectIds, Id batchId) {
        if (dataSubjectIds == null || dataSubjectIds.isEmpty()) {
            return;
        }
        if (Test.isRunningTest() && skipEmailSendDuringTests) {
            return;
        }

        List<Contact> subjects = [
            SELECT Id, Name, Email, AccountId, Account.Name, Account.Owner.Email
            FROM Contact
            WHERE Id IN :dataSubjectIds
        ];
        if (subjects.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Contact subject : subjects) {
            if (subject.AccountId != null) {
                accountIds.add(subject.AccountId);
            }
        }

        Set<String> cbsRecipients = collectCbsRecipients();
        if (!cbsRecipients.isEmpty()) {
            sendEmail(
                new List<String>(cbsRecipients),
                'CBS Notification - Departure-triggered consent revocation',
                buildCbsBody(subjects, batchId)
            );
        }

        Map<Id, Set<String>> clientRecipientsByAccount = collectClientRecipientsByAccount(accountIds, subjects);
        for (Id accountId : clientRecipientsByAccount.keySet()) {
            Set<String> recipientSet = clientRecipientsByAccount.get(accountId);
            if (recipientSet == null || recipientSet.isEmpty()) {
                continue;
            }
            List<Contact> accountSubjects = new List<Contact>();
            for (Contact subject : subjects) {
                if (subject.AccountId == accountId) {
                    accountSubjects.add(subject);
                }
            }
            sendEmail(
                new List<String>(recipientSet),
                'Client Notification - Consent withdrawn for departed employees',
                buildClientBody(accountSubjects, batchId)
            );
        }
    }

    private static Set<String> collectCbsRecipients() {
        Set<String> recipients = new Set<String>();
        for (User u : [SELECT Email FROM User WHERE IsActive = true AND UserRole.Name LIKE '%CBS%' LIMIT 30]) {
            if (String.isNotBlank(u.Email)) {
                recipients.add(u.Email.trim());
            }
        }
        if (recipients.isEmpty() && String.isNotBlank(UserInfo.getUserEmail())) {
            recipients.add(UserInfo.getUserEmail().trim());
        }
        return recipients;
    }

    private static Map<Id, Set<String>> collectClientRecipientsByAccount(Set<Id> accountIds, List<Contact> subjects) {
        Map<Id, Set<String>> recipientsByAccount = new Map<Id, Set<String>>();
        if (accountIds == null || accountIds.isEmpty()) {
            return recipientsByAccount;
        }

        Set<Id> subjectIds = new Set<Id>();
        for (Contact subject : subjects) {
            subjectIds.add(subject.Id);
            if (subject.AccountId != null && subject.Account != null && subject.Account.Owner != null && String.isNotBlank(subject.Account.Owner.Email)) {
                if (!recipientsByAccount.containsKey(subject.AccountId)) {
                    recipientsByAccount.put(subject.AccountId, new Set<String>());
                }
                recipientsByAccount.get(subject.AccountId).add(subject.Account.Owner.Email.trim());
            }
        }

        for (Contact c : [
            SELECT Id, AccountId, Email, RecordType.DeveloperName
            FROM Contact
            WHERE AccountId IN :accountIds AND Email != null
        ]) {
            if (subjectIds.contains(c.Id)) {
                continue;
            }
            if (!recipientsByAccount.containsKey(c.AccountId)) {
                recipientsByAccount.put(c.AccountId, new Set<String>());
            }
            if (
                c.RecordType == null ||
                String.isBlank(c.RecordType.DeveloperName) ||
                c.RecordType.DeveloperName == 'Client_User' ||
                c.RecordType.DeveloperName == 'Portal_User'
            ) {
                recipientsByAccount.get(c.AccountId).add(c.Email.trim());
            }
        }
        return recipientsByAccount;
    }

    private static void sendEmail(List<String> recipients, String subject, String body) {
        if (recipients == null || recipients.isEmpty()) {
            return;
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(recipients);
        mail.setSaveAsActivity(true);
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    private static String buildCbsBody(List<Contact> subjects, Id batchId) {
        List<String> lines = new List<String>();
        lines.add('Departure upload has triggered consent revocation.');
        lines.add('Batch Id: ' + String.valueOf(batchId));
        lines.add('Processed At: ' + String.valueOf(System.now()));
        lines.add('');
        lines.add('Impacted Data Subjects:');
        for (Contact subject : subjects) {
            lines.add('- ' + subject.Name + ' (' + subject.Email + ')');
        }
        lines.add('');
        lines.add('Source: Departure Upload');
        lines.add('Action: Client Authorized Withdrawal');
        return String.join(lines, '\n');
    }

    private static String buildClientBody(List<Contact> subjects, Id batchId) {
        String accountName = subjects.isEmpty() || subjects[0].Account == null ? 'Client' : subjects[0].Account.Name;
        List<String> lines = new List<String>();
        lines.add('Dear ' + accountName + ',');
        lines.add('');
        lines.add('Consent records were withdrawn for departed employees based on your departure upload.');
        lines.add('Batch Id: ' + String.valueOf(batchId));
        lines.add('Processed At: ' + String.valueOf(System.now()));
        lines.add('');
        lines.add('Impacted employees:');
        for (Contact subject : subjects) {
            lines.add('- ' + subject.Name + ' (' + subject.Email + ')');
        }
        lines.add('');
        lines.add('Source: Departure Upload');
        lines.add('If this is unexpected, contact CBS support.');
        return String.join(lines, '\n');
    }
}