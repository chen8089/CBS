@isTest
private class CbsConsentWithdrawalNotifyTest {
    @isTest
    static void notifyWithdrawalSendsSubjectAndClientEmails() {
        Account employer = new Account(Name = 'Notification Bank');
        insert employer;

        Contact subject = new Contact(
            LastName = 'Withdrawal Subject',
            Email = 'withdrawal.subject@example.com',
            AccountId = employer.Id,
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Withdrawal Subject',
            ID_Number__c = 'S7654321A',
            ID_Type__c = 'NRIC'
        );
        Contact clientRecipient = new Contact(
            LastName = 'Client Recipient',
            Email = 'client.recipient@example.com',
            AccountId = employer.Id,
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Client Recipient',
            ID_Number__c = 'S1234567A',
            ID_Type__c = 'NRIC'
        );
        insert new List<Contact>{ subject, clientRecipient };

        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = subject.Id,
            Current_Status__c = 'Submitted',
            Consent_Link_Expires_At__c = System.now().addDays(7),
            Secure_Token__c = 'notify-token-001'
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;

        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = subject.Id,
            Consent_Status__c = 'Withdrawn',
            Revoked_At__c = System.now(),
            Action_Type__c = 'Consent Withdrawn'
        );
        insert consentRecord;

        Test.startTest();
        CbsConsentWithdrawalNotificationService.notifyWithdrawal(
            subject.Id,
            consentRecord.Id,
            requestItem.Id,
            System.now()
        );
        Test.stopTest();

        System.assertEquals(1, Limits.getEmailInvocations());
    }

    @isTest
    static void notifyWithdrawalNoopsWhenSubjectMissing() {
        Test.startTest();
        CbsConsentWithdrawalNotificationService.notifyWithdrawal(null, null, null, System.now());
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations());
    }
}