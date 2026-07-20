public without sharing class CbsConsentWithdrawalNotificationService {
    public static void notifyWithdrawal(Id subjectId, Id consentId, Id requestItemId, Datetime withdrawnAt) {
        if (subjectId == null) {
            return;
        }

        try {
            Contact subject = [
                SELECT Id, Name, Email, AccountId, Account.Name
                FROM Contact
                WHERE Id = :subjectId
                LIMIT 1
            ];

            List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
            if (!String.isBlank(subject.Email)) {
                messages.add(buildSubjectConfirmationEmail(subject, consentId, withdrawnAt));
            }

            List<String> clientRecipients = resolveClientRecipients(subject);
            if (!clientRecipients.isEmpty()) {
                messages.add(buildClientNotificationEmail(subject, consentId, requestItemId, withdrawnAt, clientRecipients));
            }

            if (!messages.isEmpty()) {
                Messaging.sendEmail(messages, false);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Consent withdrawal notification failed: ' + e.getMessage());
        }
    }

    private static Messaging.SingleEmailMessage buildSubjectConfirmationEmail(
        Contact subject,
        Id consentId,
        Datetime withdrawnAt
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ subject.Email });
        mail.setSaveAsActivity(false);
        mail.setSubject('CBS Consent Withdrawal Confirmation');
        mail.setPlainTextBody(
            'Dear ' + resolveSubjectName(subject) + ',\n\n'
            + 'CBS confirms that your consent withdrawal has been recorded'
            + formatWithdrawnAt(withdrawnAt)
            + '.\n\n'
            + 'Consent Reference: ' + String.valueOf(consentId) + '\n'
            + 'Client: ' + resolveClientName(subject) + '\n\n'
            + 'No new report request may be submitted under this withdrawn consent. '
            + 'This withdrawal does not affect report requests already submitted before the withdrawal time.\n\n'
            + 'Regards,\nCredit Bureau (Singapore) Pte Ltd'
        );
        return mail;
    }

    private static Messaging.SingleEmailMessage buildClientNotificationEmail(
        Contact subject,
        Id consentId,
        Id requestItemId,
        Datetime withdrawnAt,
        List<String> recipients
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(recipients);
        mail.setSaveAsActivity(false);
        mail.setSubject('CBS Consent Withdrawn - ' + resolveSubjectName(subject));
        mail.setPlainTextBody(
            'Dear Client,\n\n'
            + 'CBS has recorded a data subject consent withdrawal'
            + formatWithdrawnAt(withdrawnAt)
            + '.\n\n'
            + 'Data Subject: ' + resolveSubjectName(subject) + '\n'
            + 'Consent Reference: ' + String.valueOf(consentId) + '\n'
            + 'Request Item Reference: ' + String.valueOf(requestItemId) + '\n\n'
            + 'Please do not submit new report requests for this data subject under the withdrawn consent.\n\n'
            + 'Regards,\nCredit Bureau (Singapore) Pte Ltd'
        );
        return mail;
    }

    private static List<String> resolveClientRecipients(Contact subject) {
        List<String> recipients = new List<String>();
        if (subject == null || subject.AccountId == null) {
            return recipients;
        }

        for (Contact clientContact : [
            SELECT Email
            FROM Contact
            WHERE AccountId = :subject.AccountId
                AND Id != :subject.Id
                AND Email != null
            ORDER BY CreatedDate ASC
            LIMIT 10
        ]) {
            if (!String.isBlank(clientContact.Email) && !recipients.contains(clientContact.Email)) {
                recipients.add(clientContact.Email);
            }
        }
        return recipients;
    }

    private static String resolveSubjectName(Contact subject) {
        return subject == null || String.isBlank(subject.Name) ? 'Data Subject' : subject.Name;
    }

    private static String resolveClientName(Contact subject) {
        return subject != null && subject.Account != null && !String.isBlank(subject.Account.Name)
            ? subject.Account.Name
            : 'Client';
    }

    private static String formatWithdrawnAt(Datetime withdrawnAt) {
        return withdrawnAt == null ? '' : ' on ' + withdrawnAt.format('d MMMM yyyy, h:mm a');
    }
}