@IsTest
private class AImp02ContactSeparationTest {
    private static final String PURPOSE = 'Per-Report Consent';

    @IsTest
    static void clientUserCreate_doesNotCreateConsentRequestItem() {
        Account account = createAccount('Client User Gate');
        Contact clientUser = buildContact(account.Id, 'Client_User', 'client.user@test.example', PURPOSE);

        Test.startTest();
        insert clientUser;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Consent_Request_Item__c WHERE Data_Subject__c = :clientUser.Id],
            'Client Users must exit the consent-request Flow without creating a request.'
        );
    }

    @IsTest
    static void dataSubjectFamilyCreate_preservesConsentRequestContinuity() {
        Account account = createAccount('Data Subject Continuity');
        List<Contact> contacts = new List<Contact>{
            buildContact(account.Id, 'Data_Subject', 'data.subject@test.example', PURPOSE),
            buildContact(account.Id, 'Singpass', 'singpass@test.example', PURPOSE),
            buildContact(account.Id, 'Non_Singpass', 'non.singpass@test.example', PURPOSE)
        };

        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        try {
            Test.startTest();
            insert contacts;
            Test.stopTest();
        } finally {
            ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        }

        Map<Id, Consent_Request_Item__c> requestsByContact = new Map<Id, Consent_Request_Item__c>();
        for (Contact contact : contacts) {
            List<Consent_Request_Item__c> requests = [
                SELECT Id, Data_Subject__c, Current_Status__c, Consent_Purpose__c,
                    Uploaded_Email__c, Uploaded_ID_Number__c
                FROM Consent_Request_Item__c
                WHERE Data_Subject__c = :contact.Id
            ];
            System.assertEquals(1, requests.size(), 'Each Contact must have one request.');
            requestsByContact.put(contact.Id, requests[0]);
        }

        System.assertEquals(3, requestsByContact.size());
        for (Contact contact : contacts) {
            Consent_Request_Item__c request = requestsByContact.get(contact.Id);
            System.assertNotEquals(null, request);
            System.assertEquals('Pending', request.Current_Status__c);
            System.assertEquals(PURPOSE, request.Consent_Purpose__c);
            System.assertEquals(contact.Email, request.Uploaded_Email__c);
            System.assertEquals(contact.ID_Number__c, request.Uploaded_ID_Number__c);
        }
    }

    @IsTest
    static void resolver_reusesPendingSentAndViewedRequests() {
        Account account = createAccount('Active Request Reuse');
        Integer index = 0;
        Test.startTest();
        for (String status : new List<String>{ 'Pending', 'Sent', 'Viewed' }) {
            Contact contact = buildContact(account.Id, 'Data_Subject', null, PURPOSE);
            contact.Email = null;
            insert contact;

            Consent_Request_Item__c existing = insertRequest(contact.Id, status, PURPOSE);
            Contact inputRecord = [
                SELECT Id, AccountId, Email, Full_Name__c, ID_Type__c, ID_Number__c,
                    Date_of_Birth__c, Employment_Status__c, Consent_Type__c
                FROM Contact
                WHERE Id = :contact.Id
            ];

            Id resolvedId = runResolver(inputRecord);

            System.assertEquals(existing.Id, resolvedId, status + ' request must be reused.');
            System.assertEquals(
                1,
                [SELECT COUNT() FROM Consent_Request_Item__c WHERE Data_Subject__c = :contact.Id],
                status + ' reuse must not create a second request.'
            );
            index++;
        }
        Test.stopTest();
        System.assertEquals(3, index);
    }

    @IsTest
    static void terminalRequest_remainsUnchangedAndNewCycleIsCreated() {
        Account account = createAccount('Terminal New Cycle');
        Contact contact = buildContact(account.Id, 'Data_Subject', null, PURPOSE);
        contact.Email = null;
        insert contact;
        Consent_Request_Item__c terminalRequest = insertRequest(contact.Id, 'Submitted', PURPOSE);

        Contact inputRecord = [
            SELECT Id, AccountId, Email, Full_Name__c, ID_Type__c, ID_Number__c,
                Date_of_Birth__c, Employment_Status__c, Consent_Type__c
            FROM Contact
            WHERE Id = :contact.Id
        ];

        Test.startTest();
        Id newRequestId = runResolver(inputRecord);
        Test.stopTest();

        Consent_Request_Item__c unchangedTerminal = [
            SELECT Current_Status__c, Consent_Purpose__c, Active_Request_Key__c
            FROM Consent_Request_Item__c
            WHERE Id = :terminalRequest.Id
        ];
        Consent_Request_Item__c newRequest = [
            SELECT Current_Status__c, Consent_Purpose__c, Active_Request_Key__c
            FROM Consent_Request_Item__c
            WHERE Id = :newRequestId
        ];
        System.assertEquals('Submitted', unchangedTerminal.Current_Status__c);
        System.assertEquals(null, unchangedTerminal.Active_Request_Key__c);
        System.assertEquals('Pending', newRequest.Current_Status__c);
        System.assertEquals(PURPOSE, newRequest.Consent_Purpose__c);
        System.assertNotEquals(null, newRequest.Active_Request_Key__c);
    }

    @IsTest
    static void activeRequestKey_rejectsSecondActiveRequest() {
        Account account = createAccount('Unique Active Request');
        Contact contact = buildContact(account.Id, 'Data_Subject', null, PURPOSE);
        contact.Email = null;
        insert contact;
        insertRequest(contact.Id, 'Pending', PURPOSE);

        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        try {
            Database.SaveResult result = Database.insert(
                new Consent_Request_Item__c(
                    Data_Subject__c = contact.Id,
                    Current_Status__c = 'Sent',
                    Consent_Purpose__c = PURPOSE
                ),
                false
            );
            System.assertEquals(false, result.isSuccess(), 'A second active request must violate the unique key.');
            System.assert(!result.getErrors().isEmpty());
        } finally {
            ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        }
    }

    @IsTest
    static void resolverFault_createsSanitisedCaseOwnedByProcessingQueue() {
        Account account = createAccount('Fault Case');
        Contact contact = buildContact(account.Id, 'Data_Subject', null, PURPOSE);
        contact.Email = null;
        insert contact;
        Contact invalidInput = [
            SELECT Id, AccountId, Email, Full_Name__c, ID_Type__c, ID_Number__c,
                Date_of_Birth__c, Employment_Status__c, Consent_Type__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        invalidInput.put('Consent_Type__c', 'INVALID_TEST_PURPOSE');

        Test.startTest();
        runResolver(invalidInput);
        Test.stopTest();

        Case faultCase = [
            SELECT OwnerId, Status, Priority, Type, Exception_Type__c, AccountId,
                ContactId, Subject, Description
            FROM Case
            WHERE ContactId = :contact.Id
            AND Subject = 'A-IMP-02 consent request creation failure'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Group processingQueue = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = 'CBS_Processing_Queue'
            AND Type = 'Queue'
            LIMIT 1
        ];
        System.assertEquals(processingQueue.Id, faultCase.OwnerId);
        System.assertEquals('New', faultCase.Status);
        System.assertEquals('High', faultCase.Priority);
        System.assertEquals('Problem', faultCase.Type);
        System.assertEquals('Other', faultCase.Exception_Type__c);
        System.assertEquals(account.Id, faultCase.AccountId);
        System.assertEquals(contact.Id, faultCase.ContactId);
        System.assert(!faultCase.Description.contains(contact.ID_Number__c), 'Fault description must not contain ID number.');
        System.assert(!faultCase.Description.contains('1990-01-01'), 'Fault description must not contain DOB.');
    }

    private static Account createAccount(String suffix) {
        Account account = new Account(Name = 'A-IMP-02 ' + suffix);
        insert account;
        return account;
    }

    private static Contact buildContact(
        Id accountId,
        String recordTypeDeveloperName,
        String email,
        String purpose
    ) {
        Id recordTypeId = recordTypeId(recordTypeDeveloperName);
        System.assertNotEquals(null, recordTypeId, 'Missing Contact Record Type ' + recordTypeDeveloperName);
        Contact contact = new Contact(
            AccountId = accountId,
            RecordTypeId = recordTypeId,
            FirstName = 'AImp02',
            LastName = recordTypeDeveloperName,
            Email = email,
            Full_Name__c = 'AImp02 ' + recordTypeDeveloperName,
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0').right(7),
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Consent_Type__c = purpose
        );
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        if (fields.containsKey('Authentication_Type__c')) {
            if (recordTypeDeveloperName == 'Singpass') {
                contact.put('Authentication_Type__c', 'Singpass');
            } else if (recordTypeDeveloperName == 'Non_Singpass') {
                contact.put('Authentication_Type__c', 'Non-Singpass');
            }
        }
        return contact;
    }

    private static Id recordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> infos =
            Contact.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        return infos.containsKey(developerName) && infos.get(developerName).isAvailable()
            ? infos.get(developerName).getRecordTypeId()
            : null;
    }

    private static Consent_Request_Item__c insertRequest(Id contactId, String status, String purpose) {
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        try {
            Consent_Request_Item__c request = new Consent_Request_Item__c(
                Data_Subject__c = contactId,
                Current_Status__c = status,
                Consent_Purpose__c = purpose
            );
            Database.SaveResult result = Database.insert(request, false);
            if (!result.isSuccess()) {
                List<String> messages = new List<String>();
                for (Database.Error error : result.getErrors()) {
                    messages.add(error.getStatusCode() + ': ' + error.getMessage());
                }
                System.assert(false, 'Consent request insert failed: ' + String.join(messages, ' | '));
            }
            return request;
        } finally {
            ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        }
    }

    private static Id runResolver(Contact contactRecord) {
        Flow.Interview interview = Flow.Interview.createInterview(
            'ConsentRequestResolveActiveRequest',
            new Map<String, Object>{ 'contactRecord' => contactRecord }
        );
        interview.start();
        Object resolved = interview.getVariableValue('resolvedRequestItemId');
        return resolved == null ? null : Id.valueOf(String.valueOf(resolved));
    }
}
