@IsTest
private class DeclineConsentNotificationServiceTest {
    @IsTest
    static void notifyClientOfDecline_marksSentWhenRecipientsExist() {
        Account accountRecord = createAccount(true);
        Contact dataSubject = createDataSubject(accountRecord.Id, 'notify.sent');
        Consent_Request_Item__c requestItem = createRequestItem(dataSubject.Id);
        createClientUserRecipient(accountRecord.Id, 'client.user.sent');

        DeclineConsentNotificationService.skipEmailSendDuringTests = true;
        DeclineConsentNotificationService.simulateSendFailureForTests = false;
        DeclineConsentNotificationService.templateIdOverrideForTests = null;

        Test.startTest();
        DeclineConsentNotificationService.NotificationResult result =
            DeclineConsentNotificationService.notifyClientOfDecline(dataSubject.Id, requestItem.Id);
        Test.stopTest();

        System.assertEquals(true, result.sent);
        System.assert(result.recipientCount > 0);
        assertNotificationStatus(dataSubject.Id, 'Sent');
    }

    @IsTest
    static void notifyClientOfDecline_marksFailedWhenNoRecipients() {
        Account accountRecord = createAccount(false);
        Contact dataSubject = createDataSubject(accountRecord.Id, 'notify.none');
        Consent_Request_Item__c requestItem = createRequestItem(dataSubject.Id);

        DeclineConsentNotificationService.skipEmailSendDuringTests = true;
        DeclineConsentNotificationService.simulateSendFailureForTests = false;
        DeclineConsentNotificationService.templateIdOverrideForTests = null;

        Test.startTest();
        DeclineConsentNotificationService.NotificationResult result =
            DeclineConsentNotificationService.notifyClientOfDecline(dataSubject.Id, requestItem.Id);
        Test.stopTest();

        System.assertEquals(false, result.sent);
        System.assertEquals('NO_RECIPIENTS', result.message);
        assertNotificationStatus(dataSubject.Id, 'Failed');
    }

    @IsTest
    static void notifyClientOfDecline_marksFailedWhenSendFails() {
        Account accountRecord = createAccount(true);
        Contact dataSubject = createDataSubject(accountRecord.Id, 'notify.fail');
        Consent_Request_Item__c requestItem = createRequestItem(dataSubject.Id);

        DeclineConsentNotificationService.skipEmailSendDuringTests = true;
        DeclineConsentNotificationService.simulateSendFailureForTests = true;
        DeclineConsentNotificationService.templateIdOverrideForTests = null;

        Test.startTest();
        DeclineConsentNotificationService.NotificationResult result =
            DeclineConsentNotificationService.notifyClientOfDecline(dataSubject.Id, requestItem.Id);
        Test.stopTest();

        System.assertEquals(false, result.sent);
        System.assertEquals('NOTIFICATION_FAILED', result.message);
        assertNotificationStatus(dataSubject.Id, 'Failed');
    }

    private static Account createAccount(Boolean includeNotificationEmail) {
        Account accountRecord = new Account(Name = 'Decline Notify Account ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (includeNotificationEmail && accountFields.containsKey('Notification_Email__c')) {
            accountRecord.put('Notification_Email__c', 'hr.notify+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com');
        }
        insert accountRecord;
        return accountRecord;
    }

    private static Contact createDataSubject(Id accountId, String aliasSeed) {
        String uniqueSuffix = aliasSeed + '.' + String.valueOf(DateTime.now().getTime());
        Contact contactRecord = new Contact(
            LastName = 'Data Subject ' + uniqueSuffix,
            AccountId = accountId,
            Email = uniqueSuffix + '@example.com',
            Current_Consent_Status__c = 'Pending',
            Employment_Status__c = 'Existing Hire',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).right(7)
        );
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Data Subject ' + uniqueSuffix);
        }
        if (contactFields.containsKey('Declined_Date__c')) {
            contactRecord.put('Declined_Date__c', System.now());
        }
        insert contactRecord;
        return contactRecord;
    }

    private static Contact createClientUserRecipient(Id accountId, String aliasSeed) {
        String uniqueSuffix = aliasSeed + '.' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact recipient = new Contact(
            LastName = 'Client User ' + uniqueSuffix,
            AccountId = accountId,
            Email = uniqueSuffix + '@example.com',
            Employment_Status__c = 'Existing Hire',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).right(7),
            Full_Name__c = 'Client User ' + uniqueSuffix
        );

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        Id clientUserRecordTypeId = resolveContactRecordTypeId('Client_User');
        if (clientUserRecordTypeId != null) {
            recipient.RecordTypeId = clientUserRecordTypeId;
        }
        if (contactFields.containsKey('Is_Active_Client_User__c')) {
            recipient.put('Is_Active_Client_User__c', true);
        }
        insert recipient;
        return recipient;
    }

    private static Id resolveContactRecordTypeId(String developerName) {
        for (Schema.RecordTypeInfo info : Contact.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (info != null && info.isAvailable() && info.getDeveloperName() == developerName) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }

    private static Consent_Request_Item__c createRequestItem(Id dataSubjectId) {
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = dataSubjectId,
            Current_Status__c = 'Sent',
            Consent_Link_Expires_At__c = System.now().addDays(3)
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return requestItem;
    }

    private static void assertNotificationStatus(Id contactId, String expectedStatus) {
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        String selectFields = 'Id';
        if (contactFields.containsKey('Client_Notification_Status__c')) {
            selectFields += ', Client_Notification_Status__c';
        }
        if (contactFields.containsKey('Notification_Status__c')) {
            selectFields += ', Notification_Status__c';
        }
        Contact refreshed = Database.query('SELECT ' + selectFields + ' FROM Contact WHERE Id = :contactId LIMIT 1');

        if (contactFields.containsKey('Client_Notification_Status__c')) {
            System.assertEquals(expectedStatus, (String) refreshed.get('Client_Notification_Status__c'));
        }
        if (contactFields.containsKey('Notification_Status__c')) {
            System.assertEquals(expectedStatus, (String) refreshed.get('Notification_Status__c'));
        }
    }
}