@IsTest
private class ExperienceClientDataIsolationTest {
    @TestSetup
    static void setupData() {
        Account accountA = new Account(Name = 'Isolation RR Account A');
        Account accountB = new Account(Name = 'Isolation RR Account B');
        insert new List<Account>{ accountA, accountB };

        Contact requesterA = new Contact(
            LastName = 'RR Requester A',
            AccountId = accountA.Id,
            RecordTypeId = contactRecordTypeId('Client_User'),
            Email = 'rr.requester.a@test.com',
            Full_Name__c = 'RR Requester A',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S2234567A',
            Employment_Status__c = 'Existing Employee',
            Portal_Role__c = 'Approver'
        );
        Contact requesterB = new Contact(
            LastName = 'RR Requester B',
            AccountId = accountB.Id,
            RecordTypeId = contactRecordTypeId('Client_User'),
            Email = 'rr.requester.b@test.com',
            Full_Name__c = 'RR Requester B',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S2234568A',
            Employment_Status__c = 'Existing Employee',
            Portal_Role__c = 'Approver'
        );
        Contact subjectA = new Contact(
            LastName = 'RR Subject A',
            AccountId = accountA.Id,
            RecordTypeId = contactRecordTypeId('Data_Subject'),
            Email = 'rr.subject.a@test.com',
            Full_Name__c = 'RR Subject A',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S2234569A',
            Employment_Status__c = 'Existing Employee',
            Consent_Type__c = 'Per-Report Consent'
        );
        Contact subjectB = new Contact(
            LastName = 'RR Subject B',
            AccountId = accountB.Id,
            RecordTypeId = contactRecordTypeId('Data_Subject'),
            Email = 'rr.subject.b@test.com',
            Full_Name__c = 'RR Subject B',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S2234570A',
            Employment_Status__c = 'Existing Employee',
            Consent_Type__c = 'Per-Report Consent'
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        try {
            insert new List<Contact>{ requesterA, requesterB, subjectA, subjectB };
        } finally {
            ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        }

        insert new List<Consent__c>{
            new Consent__c(
                Data_Subject__c = subjectA.Id,
                Consent_Request_Item__c = ensureRequestItem(subjectA),
                Consent_Status__c = 'Active',
                Consent_Expiry_Date__c = Date.today().addDays(30),
                Match_Status__c = 'Matched'
            ),
            new Consent__c(
                Data_Subject__c = subjectB.Id,
                Consent_Request_Item__c = ensureRequestItem(subjectB),
                Consent_Status__c = 'Active',
                Consent_Expiry_Date__c = Date.today().addDays(30),
                Match_Status__c = 'Matched'
            )
        };

        Contact subjectAState = new Contact(Id = subjectA.Id);
        Contact subjectBState = new Contact(Id = subjectB.Id);
        ConsentStatusModelService.applyContactState(subjectAState, ConsentStatusModelService.STATUS_ACTIVE);
        ConsentStatusModelService.applyContactState(subjectBState, ConsentStatusModelService.STATUS_ACTIVE);
        update new List<Contact>{ subjectAState, subjectBState };
    }

    @IsTest
    static void eligibleSubjectsAreScopedToRequesterAccount() {
        Account accountA = [SELECT Id FROM Account WHERE Name = 'Isolation RR Account A' LIMIT 1];
        Contact requesterA = [SELECT Id FROM Contact WHERE Email = 'rr.requester.a@test.com' LIMIT 1];
        Contact subjectA = [SELECT Id FROM Contact WHERE Email = 'rr.subject.a@test.com' LIMIT 1];
        Contact subjectB = [SELECT Id FROM Contact WHERE Email = 'rr.subject.b@test.com' LIMIT 1];

        PortalReportRequestController.overrideContactIdForTests = requesterA.Id;
        PortalReportRequestController.overrideAccountIdForTests = accountA.Id;
        try {
            List<PortalReportRequestController.DataSubjectOption> options =
                PortalReportRequestController.getEligibleDataSubjects(null);

            Set<Id> returnedIds = new Set<Id>();
            for (PortalReportRequestController.DataSubjectOption option : options) {
                returnedIds.add(option.contactId);
            }

            System.assert(returnedIds.contains(subjectA.Id), 'Client A should see subject A.');
            System.assert(!returnedIds.contains(subjectB.Id), 'Client A must not see subject B.');
        } finally {
            PortalReportRequestController.overrideContactIdForTests = null;
            PortalReportRequestController.overrideAccountIdForTests = null;
        }
    }

    @IsTest
    static void createReportRequestRejectsCrossAccountSubjectAndKeepsCaseScoped() {
        Account accountA = [SELECT Id FROM Account WHERE Name = 'Isolation RR Account A' LIMIT 1];
        Contact requesterA = [SELECT Id FROM Contact WHERE Email = 'rr.requester.a@test.com' LIMIT 1];
        Contact subjectA = [SELECT Id FROM Contact WHERE Email = 'rr.subject.a@test.com' LIMIT 1];
        Contact subjectB = [SELECT Id FROM Contact WHERE Email = 'rr.subject.b@test.com' LIMIT 1];

        PortalReportRequestController.overrideContactIdForTests = requesterA.Id;
        PortalReportRequestController.overrideAccountIdForTests = accountA.Id;
        ReportRequestSubmissionService.skipRunningUserContextValidationForTests = true;
        try {
            Boolean crossAccountBlocked = false;
            try {
                PortalReportRequestController.createReportRequestCase(
                    'Cross account should fail',
                    new List<Id>{ subjectA.Id, subjectB.Id },
                    5
                );
            } catch (AuraHandledException e) {
                crossAccountBlocked = true;
                System.assertNotEquals(null, e.getMessage(), 'Expected a validation exception message.');
            }
            System.assertEquals(true, crossAccountBlocked, 'Cross-account submission must be blocked.');

            PortalReportRequestController.CreateRequestResult okResult =
                PortalReportRequestController.createReportRequestCase(
                    'Account A only',
                    new List<Id>{ subjectA.Id },
                    5
                );

            Case createdCase = [
                SELECT Id, AccountId
                FROM Case
                WHERE Id = :okResult.caseId
                LIMIT 1
            ];
            System.assertEquals(accountA.Id, createdCase.AccountId, 'Case must belong to client account A.');

            List<Report_Request_Item__c> createdItems = [
                SELECT Id, Data_Subject__c
                FROM Report_Request_Item__c
                WHERE Report_Request_Case__c = :createdCase.Id
            ];
            System.assertEquals(1, createdItems.size());
            System.assertEquals(subjectA.Id, createdItems[0].Data_Subject__c, 'Only subject A should be created.');
        } finally {
            PortalReportRequestController.overrideContactIdForTests = null;
            PortalReportRequestController.overrideAccountIdForTests = null;
            ReportRequestSubmissionService.skipRunningUserContextValidationForTests = false;
        }
    }

    private static Id contactRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> infos =
            Contact.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        return infos.containsKey(developerName) && infos.get(developerName).isAvailable()
            ? infos.get(developerName).getRecordTypeId()
            : null;
    }

    private static Id ensureRequestItem(Contact subject) {
        List<Consent_Request_Item__c> existing = [
            SELECT Id
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :subject.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        try {
            Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
                Data_Subject__c = subject.Id,
                Current_Status__c = 'Sent',
                Consent_Purpose__c = 'Per-Report Consent'
            );
            insert requestItem;
            return requestItem.Id;
        } finally {
            ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        }
    }
}