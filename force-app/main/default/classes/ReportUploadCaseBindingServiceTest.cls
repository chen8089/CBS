@IsTest
private class ReportUploadCaseBindingServiceTest {
    @TestSetup
    static void setupData() {
        Account accountRecord = new Account(Name = 'Case Binding Account');
        insert accountRecord;

        Contact contactOne = buildContact(accountRecord.Id, 'binding.one@test.com', 'S1000001A');
        Contact contactTwo = buildContact(accountRecord.Id, 'binding.two@test.com', 'S1000002A');
        insert new List<Contact>{ contactOne, contactTwo };

        insert new List<Reports__c>{
            new Reports__c(Email__c = 'binding.one@test.com', Consent_Status__c = 'Updated Consent', Updated_Date__c = Date.today()),
            new Reports__c(Email__c = 'binding.two@test.com', Consent_Status__c = 'Updated Consent', Updated_Date__c = Date.today())
        };
    }

    private static Contact buildContact(Id accountId, String email, String idNumberSeed) {
        Contact contactRecord = new Contact(
            LastName = 'Binding Contact',
            AccountId = accountId,
            Email = email
        );
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        if (fields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Binding Contact');
        }
        if (fields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', firstActivePicklistValue(fields.get('Employment_Status__c')));
        }
        if (fields.containsKey('ID_Type__c')) {
            contactRecord.put('ID_Type__c', firstActivePicklistValue(fields.get('ID_Type__c')));
        }
        if (fields.containsKey('ID_Number__c')) {
            contactRecord.put('ID_Number__c', idNumberSeed);
        }
        return contactRecord;
    }

    private static String firstActivePicklistValue(Schema.SObjectField fieldToken) {
        if (fieldToken == null) {
            return 'Active';
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return 'Active';
    }

    @IsTest
    static void createAndBindCases_positiveAndBulk() {
        Account accountOne = new Account(Name = 'Case Binding Account Bulk One');
        Account accountTwo = new Account(Name = 'Case Binding Account Bulk Two');
        insert new List<Account>{ accountOne, accountTwo };
        String uniqueToken = String.valueOf(DateTime.now().getTime());
        Contact contactOne = buildContact(accountOne.Id, 'binding.bulk.one.' + uniqueToken + '@test.com', 'S2000001A');
        Contact contactTwo = buildContact(accountTwo.Id, 'binding.bulk.two.' + uniqueToken + '@test.com', 'S2000002A');
        insert new List<Contact>{ contactOne, contactTwo };
        List<Reports__c> reportRecordsToInsert = new List<Reports__c>{
            new Reports__c(Email__c = contactOne.Email, Consent_Status__c = 'Updated Consent', Updated_Date__c = Date.today()),
            new Reports__c(Email__c = contactTwo.Email, Consent_Status__c = 'Updated Consent', Updated_Date__c = Date.today())
        };
        insert reportRecordsToInsert;
        List<Reports__c> reportRecords = [
            SELECT Id, Name, Email__c
            FROM Reports__c
            WHERE Id IN :new Map<Id, Reports__c>(reportRecordsToInsert).keySet()
            ORDER BY Email__c ASC
        ];
        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        for (Contact contactRecord : [SELECT Id, AccountId, Email FROM Contact WHERE Id IN :new List<Id>{ contactOne.Id, contactTwo.Id }]) {
            contactsByEmail.put(contactRecord.Email.toLowerCase(), contactRecord);
        }

        Test.startTest();
        ReportUploadCaseBindingService.BindingResult result =
            ReportUploadCaseBindingService.createAndBindCases(reportRecords, contactsByEmail);
        Test.stopTest();

        System.assert(result.createdCaseCount > 0, 'Expected at least one case to be created.');
        System.assertEquals(result.createdCaseCount, result.reportToCaseId.size());
        System.assert(result.createdItemCount >= 0 && result.createdItemCount <= result.createdCaseCount);

        Set<Id> reportIds = new Map<Id, Reports__c>(reportRecords).keySet();
        Integer linkedCases = [
            SELECT COUNT()
            FROM Case
            WHERE Source_Report__c IN :reportIds
        ];
        System.assertEquals(result.createdCaseCount, linkedCases);

        List<Case> createdCases = [
            SELECT Id, Submitted_By__c, ContactId, Source_Report__c
            FROM Case
            WHERE Source_Report__c IN :reportIds
        ];
        Map<String, Contact> expectedContactByEmail = new Map<String, Contact>();
        for (Contact contactRecord : [
            SELECT Id, Email
            FROM Contact
            WHERE Id IN :new List<Id>{ contactOne.Id, contactTwo.Id }
        ]) {
            expectedContactByEmail.put(contactRecord.Email == null ? null : contactRecord.Email.toLowerCase(), contactRecord);
        }
        Map<Id, String> reportEmailById = new Map<Id, String>();
        for (Reports__c reportRecord : reportRecords) {
            reportEmailById.put(reportRecord.Id, reportRecord.Email__c == null ? null : reportRecord.Email__c.toLowerCase());
        }
        for (Case createdCase : createdCases) {
            System.assertEquals(UserInfo.getUserId(), createdCase.Submitted_By__c);
            String reportEmail = reportEmailById.get(createdCase.Source_Report__c);
            Contact expectedContact = expectedContactByEmail.get(reportEmail);
            System.assertNotEquals(null, expectedContact, 'Expected matched contact for report email: ' + reportEmail);
            System.assertEquals(expectedContact.Id, createdCase.ContactId);
        }

        Integer linkedItems = [
            SELECT COUNT()
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c IN (
                SELECT Id FROM Case WHERE Source_Report__c IN :reportIds
            )
        ];
        System.assert(linkedItems >= result.createdItemCount);
    }

    @IsTest
    static void createAndBindCases_negativeHandlesMissingReportIds() {
        Reports__c unsavedReport = new Reports__c(Email__c = 'binding.one@test.com');

        Test.startTest();
        ReportUploadCaseBindingService.BindingResult result =
            ReportUploadCaseBindingService.createAndBindCases(new List<Reports__c>{ unsavedReport }, new Map<String, Contact>());
        Test.stopTest();

        System.assertEquals(0, result.createdCaseCount);
        System.assertEquals(0, result.createdItemCount);
        System.assertEquals(0, result.reportErrorsById.size());
    }

    @IsTest
    static void createAndBindCases_routesCaseToProcessingQueue() {
        Group queueGroup;
        List<Group> existingQueues = [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Type = 'Queue'
            AND (Name = 'CBS_Processing_Queue' OR DeveloperName = 'CBS_Processing_Queue')
            LIMIT 1
        ];
        if (!existingQueues.isEmpty()) {
            queueGroup = existingQueues[0];
        } else {
            try {
                queueGroup = new Group(
                    Name = 'CBS_Processing_Queue',
                    DeveloperName = 'CBS_Processing_Queue',
                    Type = 'Queue'
                );
                insert queueGroup;
            } catch (DmlException ex) {
                queueGroup = new Group(
                    Name = 'CBS_Processing_Queue',
                    DeveloperName = 'CBS_Processing_Queue_' + String.valueOf(DateTime.now().getTime()),
                    Type = 'Queue'
                );
                insert queueGroup;
            }
        }

        List<QueueSobject> queueSobjects = [
            SELECT Id
            FROM QueueSobject
            WHERE QueueId = :queueGroup.Id
            AND SobjectType = 'Case'
            LIMIT 1
        ];
        if (queueSobjects.isEmpty()) {
            insert new QueueSobject(QueueId = queueGroup.Id, SobjectType = 'Case');
        }

        Account accountRecord = [SELECT Id FROM Account WHERE Name = 'Case Binding Account' LIMIT 1];
        String uniqueToken = String.valueOf(DateTime.now().getTime());
        Contact contactRecord = buildContact(accountRecord.Id, 'binding.route.' + uniqueToken + '@test.com', 'S3000001A');
        insert contactRecord;
        Reports__c reportRecord = new Reports__c(
            Email__c = contactRecord.Email,
            Consent_Status__c = 'Updated Consent',
            Updated_Date__c = Date.today()
        );
        insert reportRecord;
        List<Reports__c> reportRecords = [SELECT Id, Name, Email__c FROM Reports__c WHERE Id = :reportRecord.Id];
        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        
        contactRecord = [
            SELECT Id, AccountId, Email
            FROM Contact
            WHERE Id = :contactRecord.Id
            LIMIT 1
        ];
        contactsByEmail.put(contactRecord.Email.toLowerCase(), contactRecord);

        Test.startTest();
        ReportUploadCaseBindingService.BindingResult result =
            ReportUploadCaseBindingService.createAndBindCases(reportRecords, contactsByEmail);
        Test.stopTest();

        System.assertEquals(1, result.createdCaseCount);
        Case createdCase = [
            SELECT Id, OwnerId, Source_Report__c, Submitted_By__c, ContactId
            FROM Case
            WHERE Source_Report__c = :reportRecords[0].Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(queueGroup.Id, createdCase.OwnerId);
        System.assertEquals(UserInfo.getUserId(), createdCase.Submitted_By__c);
        System.assertEquals(contactRecord.Id, createdCase.ContactId);
    }
}