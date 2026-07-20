@isTest
private class ConsentSubmissionServiceTest {
    @isTest
    static void submitAuthorizationCreatesConsentAndUpdatesRecords() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);

        ConsentSubmissionService.submitAuthorization(
            requestItem,
            'Edited Name',
            'Singaporean',
            'S7654321A',
            Date.newInstance(1991, 2, 15),
            '456 Edited Address'
        );

        Consent__c createdConsent = [
            SELECT Data_Subject__c, Consent_Status__c, Action_Type__c, MyInfo_Name__c,
                MyInfo_Nationality__c, MyInfo_ID_Number__c, MyInfo_Date_of_Birth__c,
                MyInfo_Residential_Address__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Active', createdConsent.Consent_Status__c);
        System.assertEquals('Consent Given', createdConsent.Action_Type__c);
        System.assertEquals('Edited Name', createdConsent.MyInfo_Name__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c, Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Submitted', updatedRequestItem.Current_Status__c);
        System.assertEquals(null, updatedRequestItem.Withdrawal_QR_Viewed_At__c);

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Authorized', updatedContact.Current_Consent_Status__c);
        System.assertEquals('Active Consent', updatedContact.Data_Subject_Lifecycle_Stage__c);
    }

    @isTest
    static void submitWithdrawalCreatesWithdrawalConsentAndUpdatesRecords() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;

        Consent__c activeConsent = new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given',
            MyInfo_Name__c = 'Consent Name',
            MyInfo_Nationality__c = 'Singaporean',
            MyInfo_ID_Number__c = 'S1111111A',
            MyInfo_Date_of_Birth__c = Date.newInstance(1992, 3, 2),
            MyInfo_Residential_Address__c = '123 Consent Address'
        );
        insert activeConsent;

        ConsentSubmissionService.submitWithdrawal(contact.Id, activeConsent, System.now());

        List<Consent__c> withdrawnConsents = [
            SELECT Consent_Status__c, Action_Type__c, Withdrawn_By_Client__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
            AND Consent_Status__c = 'Withdrawn'
        ];
        System.assertEquals(1, withdrawnConsents.size());
        System.assertEquals('Consent Withdrawn', withdrawnConsents[0].Action_Type__c);
        System.assertEquals(true, withdrawnConsents[0].Withdrawn_By_Client__c);

        List<Consent_Request_Item__c> withdrawnRequestItems = [
            SELECT Id, Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :contact.Id
            AND Current_Status__c = 'Withdrawn'
        ];
        System.assert(!withdrawnRequestItems.isEmpty());

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Withdrawn', updatedContact.Current_Consent_Status__c);
        System.assertEquals('Consent Withdrawn', updatedContact.Data_Subject_Lifecycle_Stage__c);
    }

    @isTest
    static void submitNonSingpassAuthorizationCreatesPendingVerificationChain() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);

        Id consentId = ConsentSubmissionService.submitNonSingpassAuthorization(
            requestItem,
            'NonSingpass User',
            'Malaysian',
            'P1234567',
            Date.newInstance(1992, 3, 15),
            '1 Test Street',
            contact.Pass_Type__c,
            'P1234567',
            'Female',
            contact.Marital_Status__c,
            System.now()
        );

        System.assertNotEquals(null, consentId);
        Consent__c createdConsent = [
            SELECT Consent_Status__c, MyInfo_Name__c
            FROM Consent__c
            WHERE Id = :consentId
            LIMIT 1
        ];
        System.assertNotEquals('Active', createdConsent.Consent_Status__c);
        System.assertEquals('NonSingpass User', createdConsent.MyInfo_Name__c);

        Contact updatedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        String normalizedContactStatus = updatedContact.Current_Consent_Status__c == null
            ? ''
            : updatedContact.Current_Consent_Status__c.toLowerCase();
        System.assert(
            normalizedContactStatus.contains('pending') || normalizedContactStatus.contains('verification'),
            'Expected pending-verification contact status but got: ' + updatedContact.Current_Consent_Status__c
        );
        System.assertNotEquals(null, updatedContact.Data_Subject_Lifecycle_Stage__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertNotEquals('Submitted', updatedRequestItem.Current_Status__c);
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'Submission Service Test',
            Email = 'submission.test+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Submission Service Test',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver',
            Pass_Type__c = getPicklistValue('Contact', 'Pass_Type__c'),
            Marital_Status__c = getPicklistValue('Contact', 'Marital_Status__c')
        );
        insert contact;
        return contact;
    }

    private static String getPicklistValue(String objectApiName, String fieldApiName) {
        Schema.DescribeFieldResult describeField = Schema.getGlobalDescribe()
            .get(objectApiName)
            .getDescribe()
            .fields.getMap()
            .get(fieldApiName)
            .getDescribe();
        List<Schema.PicklistEntry> entries = describeField.getPicklistValues();
        return entries.isEmpty() ? null : entries[0].getValue();
    }
}