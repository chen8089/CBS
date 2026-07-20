@IsTest
private class PortalCaseDetailControllerIsolationTest {
    @TestSetup
    static void setupData() {
        Account accountA = new Account(Name = 'Isolation Account A');
        Account accountB = new Account(Name = 'Isolation Account B');
        insert new List<Account>{ accountA, accountB };

        Contact requesterA = new Contact(
            LastName = 'Requester A',
            AccountId = accountA.Id,
            Email = 'requester.a@test.com',
            Full_Name__c = 'Requester A',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1234567A',
            Employment_Status__c = 'Existing Employee',
            Portal_Role__c = 'Approver'
        );
        Contact requesterB = new Contact(
            LastName = 'Requester B',
            AccountId = accountB.Id,
            Email = 'requester.b@test.com',
            Full_Name__c = 'Requester B',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1234568A',
            Employment_Status__c = 'Existing Employee',
            Portal_Role__c = 'Approver'
        );
        Contact subjectA = new Contact(
            LastName = 'Subject A',
            AccountId = accountA.Id,
            Email = 'subject.a@test.com',
            Full_Name__c = 'Subject A',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1234569A',
            Employment_Status__c = 'Existing Employee',
            Portal_Role__c = 'Subject'
        );
        Contact subjectB = new Contact(
            LastName = 'Subject B',
            AccountId = accountB.Id,
            Email = 'subject.b@test.com',
            Full_Name__c = 'Subject B',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1234570A',
            Employment_Status__c = 'Existing Employee',
            Portal_Role__c = 'Subject'
        );
        insert new List<Contact>{ requesterA, requesterB, subjectA, subjectB };

        Case caseA = new Case(
            AccountId = accountA.Id,
            ContactId = requesterA.Id,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Isolation Case A',
            Exception_Type__c = 'File Validation'
        );
        Case caseB = new Case(
            AccountId = accountB.Id,
            ContactId = requesterB.Id,
            Status = 'New',
            Origin = 'Portal',
            Subject = 'Isolation Case B',
            Exception_Type__c = 'File Validation'
        );
        insert new List<Case>{ caseA, caseB };

        Report_Request_Item__c itemA = new Report_Request_Item__c(
            Report_Request_Case__c = caseA.Id,
            Data_Subject__c = subjectA.Id,
            Eligibility_Status__c = 'Eligible',
            Delivery_Status__c = 'Pending',
            Notice_Sent_To_Data_Subject__c = false
        );
        Report_Request_Item__c itemB = new Report_Request_Item__c(
            Report_Request_Case__c = caseB.Id,
            Data_Subject__c = subjectB.Id,
            Eligibility_Status__c = 'Eligible',
            Delivery_Status__c = 'Pending',
            Notice_Sent_To_Data_Subject__c = false
        );
        insert new List<Report_Request_Item__c>{ itemA, itemB };
    }

    @IsTest
    static void getReportRequestItemsScopesByClientAccount() {
        Account accountA = [SELECT Id FROM Account WHERE Name = 'Isolation Account A' LIMIT 1];
        Case caseA = [SELECT Id FROM Case WHERE Subject = 'Isolation Case A' LIMIT 1];
        Case caseB = [SELECT Id FROM Case WHERE Subject = 'Isolation Case B' LIMIT 1];

        PortalCaseDetailController.overrideScopedAccountIdForTests = accountA.Id;
        try {
            List<PortalCaseDetailController.ReportRequestItemRow> ownRows =
                PortalCaseDetailController.getReportRequestItems(caseA.Id);
            List<PortalCaseDetailController.ReportRequestItemRow> otherRows =
                PortalCaseDetailController.getReportRequestItems(caseB.Id);

            System.assertEquals(1, ownRows.size(), 'Client A should read only Case A items.');
            System.assertEquals(0, otherRows.size(), 'Client A must not read Case B items.');
        } finally {
            PortalCaseDetailController.overrideScopedAccountIdForTests = null;
        }
    }
}