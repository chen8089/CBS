@IsTest
private class SlaReminderBatchTest {
    @IsTest
    static void batchSendsReminderAndMarksWarningSent() {
        Contact c = createContact('window-a@example.com');
        Report_Request_Item__c inWindow = createRequestItem(
            c.Id,
            System.now().addHours(60),
            'Pending',
            'Pending',
            false
        );

        Test.startTest();
        Database.executeBatch(new SlaReminderBatch(), 50);
        Test.stopTest();

        Report_Request_Item__c actual = [
            SELECT SLA_Warning_Sent__c
            FROM Report_Request_Item__c
            WHERE Id = :inWindow.Id
        ];
        System.assertEquals(true, actual.SLA_Warning_Sent__c);

        Contact afterContact = [
            SELECT SLA_Status__c, Reminder_Status__c, Last_Reminder_Sent_Date__c, Reminder_Review_Date__c, SLA_Due_Date__c
            FROM Contact
            WHERE Id = :c.Id
            LIMIT 1
        ];
        System.assertEquals('Sent', afterContact.Reminder_Status__c);
        System.assertEquals(Date.today(), afterContact.Last_Reminder_Sent_Date__c);
        System.assertEquals(Date.today().addDays(2), afterContact.Reminder_Review_Date__c);
        System.assertEquals(inWindow.SLA_Due_Date__c.date(), afterContact.SLA_Due_Date__c);
        System.assertEquals('Near Due', afterContact.SLA_Status__c);
    }

    @IsTest
    static void batchSkipsNonEligibleRecords() {
        Contact c = createContact('window-b@example.com');
        Report_Request_Item__c outsideWindow = createRequestItem(
            c.Id,
            System.now().addHours(30),
            'Pending',
            'Pending',
            false
        );
        Report_Request_Item__c completedDelivery = createRequestItem(
            c.Id,
            System.now().addHours(60),
            'Completed',
            'Pending',
            false
        );
        Report_Request_Item__c alreadySent = createRequestItem(
            c.Id,
            System.now().addHours(60),
            'Pending',
            'Pending',
            true
        );

        Test.startTest();
        Database.executeBatch(new SlaReminderBatch(), 50);
        Test.stopTest();

        Map<Id, Report_Request_Item__c> rows = new Map<Id, Report_Request_Item__c>([
            SELECT SLA_Warning_Sent__c
            FROM Report_Request_Item__c
            WHERE Id IN :new Set<Id>{
                outsideWindow.Id,
                completedDelivery.Id,
                alreadySent.Id
            }
        ]);
        System.assertEquals(false, rows.get(outsideWindow.Id).SLA_Warning_Sent__c);
        System.assertEquals(false, rows.get(completedDelivery.Id).SLA_Warning_Sent__c);
        System.assertEquals(true, rows.get(alreadySent.Id).SLA_Warning_Sent__c);
    }

    @IsTest
    static void schedulerExecuteRunsBatch() {
        Contact c = createContact('window-c@example.com');
        Report_Request_Item__c inWindow = createRequestItem(
            c.Id,
            System.now().addHours(60),
            'Pending',
            'Pending',
            false
        );

        Test.startTest();
        new SlaReminderScheduler().execute(null);
        Test.stopTest();

        Report_Request_Item__c actual = [
            SELECT SLA_Warning_Sent__c
            FROM Report_Request_Item__c
            WHERE Id = :inWindow.Id
        ];
        System.assertEquals(true, actual.SLA_Warning_Sent__c);
    }

    @IsTest
    static void scheduleDailyJobReturnsCronId() {
        Test.startTest();
        Id jobId = SlaReminderScheduler.scheduleDailyJob();
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void serviceReturnsEmptyWhenNoRecipient() {
        Contact c = createContact(null);
        Report_Request_Item__c inWindow = createRequestItem(
            c.Id,
            System.now().addHours(60),
            'Pending',
            'Pending',
            false
        );

        Test.startTest();
        Set<Id> sentIds = SlaReminderService.sendReminders(
            new List<Report_Request_Item__c>{
                [SELECT Id, Name, Data_Subject__c FROM Report_Request_Item__c WHERE Id = :inWindow.Id]
            }
        );
        Test.stopTest();

        System.assertEquals(0, sentIds.size());
    }

    @IsTest
    static void serviceSupportsForcedRecipientInSandboxMode() {
        Contact c = createContact('original-recipient@example.com');
        Report_Request_Item__c inWindow = createRequestItem(
            c.Id,
            System.now().addHours(60),
            'Pending',
            'Pending',
            false
        );

        Test.startTest();
        SlaReminderService.overrideAllowedForTests = true;
        SlaReminderService.overrideRecipientEmail = 'wxf2048@163.com';
        Set<Id> sentIds = SlaReminderService.sendReminders(
            new List<Report_Request_Item__c>{
                [SELECT Id, Name, Data_Subject__c FROM Report_Request_Item__c WHERE Id = :inWindow.Id]
            }
        );
        Test.stopTest();

        System.assertEquals(1, sentIds.size());
        System.assert(sentIds.contains(inWindow.Id));

        SlaReminderService.overrideRecipientEmail = null;
        SlaReminderService.overrideAllowedForTests = null;
    }

    private static Contact createContact(String email) {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact c = new Contact(
            LastName = 'SLA Test ' + uniqueSuffix,
            Email = email,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Current_Consent_Status__c = 'Authorized'
        );
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Full_Name__c')) {
            c.put('Full_Name__c', 'SLA Test User');
        }
        if (contactFields.containsKey('Employment_Status__c')) {
            c.put('Employment_Status__c', 'Existing Hire');
        }
        if (contactFields.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            c.put('Data_Subject_Lifecycle_Stage__c', 'Active Consent');
        }
        if (contactFields.containsKey('Report_Eligibility_Status__c')) {
            c.put('Report_Eligibility_Status__c', 'Eligible');
        }
        insert c;
        return c;
    }

    private static Report_Request_Item__c createRequestItem(
        Id subjectId,
        Datetime dueDate,
        String deliveryStatus,
        String eligibilityStatus,
        Boolean warningSent
    ) {
        ensureActiveConsent(subjectId);
        Case reportCase = createReportRequestCase(subjectId);
        Report_Request_Item__c row = new Report_Request_Item__c(
            Data_Subject__c = subjectId,
            Report_Request_Case__c = reportCase.Id,
            SLA_Due_Date__c = dueDate,
            Delivery_Status__c = deliveryStatus,
            Eligibility_Status__c = eligibilityStatus,
            SLA_Warning_Sent__c = warningSent
        );
        insert row;
        return row;
    }

    private static Case createReportRequestCase(Id subjectId) {
        Case reportCase = new Case(
            ContactId = subjectId,
            Subject = 'SLA reminder test case',
            Origin = 'Web',
            Status = 'New'
        );
        if (Case.SObjectType.getDescribe().fields.getMap().containsKey('Exception_Type__c')) {
            reportCase.put('Exception_Type__c', 'File Validation');
        }
        insert reportCase;
        return reportCase;
    }

    private static void ensureActiveConsent(Id subjectId) {
        if (subjectId == null) {
            return;
        }
        if (![
            SELECT Id
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
            AND Consent_Status__c = 'Active'
            LIMIT 1
        ].isEmpty()) {
            return;
        }

        Contact c = [
            SELECT Id, Employment_Status__c
            FROM Contact
            WHERE Id = :subjectId
            LIMIT 1
        ];
        String employmentStatus = String.isBlank(c.Employment_Status__c) ? 'Existing Hire' : c.Employment_Status__c;

        Consent__c consent = new Consent__c(
            Data_Subject__c = subjectId,
            Consent_Status__c = 'Active',
            Employment_Status__c = employmentStatus,
            Consent_Expiry_Date__c = Date.today().addDays(30),
            Report_Use_Count__c = 0
        );
        if (Consent__c.SObjectType.getDescribe().fields.getMap().containsKey('Action_Type__c')) {
            consent.put('Action_Type__c', 'Authorize');
        }
        if (Consent__c.SObjectType.getDescribe().fields.getMap().containsKey('Match_Status__c')) {
            consent.put('Match_Status__c', 'Matched');
        }
        insert consent;
    }
}