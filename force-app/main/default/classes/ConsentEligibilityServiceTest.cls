@IsTest
private class ConsentEligibilityServiceTest {
    @TestSetup
    static void setupData() {
        Account acct = new Account(Name = 'CBS Test Account');
        insert acct;

        Contact c = new Contact(
            LastName = 'Subject',
            AccountId = acct.Id,
            Full_Name__c = 'Test Subject',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1234567A',
            Employment_Status__c = 'Existing Employee'
        );
        insert c;

        Consent__c consent = new Consent__c(
            Data_Subject__c = c.Id,
            Consent_Status__c = 'Active',
            Consent_Expiry_Date__c = Date.today().addDays(30),
            Match_Status__c = 'Matched'
        );
        insert consent;

        Contact activeContactState = new Contact(Id = c.Id);
        ConsentStatusModelService.applyContactState(activeContactState, ConsentStatusModelService.STATUS_ACTIVE);
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Report_Eligibility_Status__c')) {
            activeContactState.put('Report_Eligibility_Status__c', null);
        }
        update activeContactState;
    }

    @IsTest
    static void testConsentAllowedForReport() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(c.Id, c.AccountId);
        System.assertEquals(true, result.isEligible);
        System.assertEquals('ALLOWED', result.reasonCode);
    }

    @IsTest
    static void testConsentNotFound() {
        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(UserInfo.getUserId(), null);
        System.assertEquals(false, result.isEligible);
        System.assertEquals('CONSENT_NOT_FOUND', result.reasonCode);
    }

    @IsTest
    static void testBlockedByContactDepartureState() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Contact updateContact = new Contact(Id = c.Id);
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        if (fields.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            updateContact.put('Data_Subject_Lifecycle_Stage__c', 'Departure');
        }
        if (fields.containsKey('Current_Consent_Status__c')) {
            updateContact.put('Current_Consent_Status__c', 'Withdrawn');
        }
        update updateContact;

        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(c.Id, c.AccountId);
        System.assertEquals(false, result.isEligible);
        System.assertEquals('CONTACT_STATUS_BLOCKED', result.reasonCode);
    }

    @IsTest
    static void testBlockedByLifecycleConsumedState() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Contact updateContact = new Contact(Id = c.Id);
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        if (fields.containsKey('Current_Consent_Status__c')) {
            updateContact.put('Current_Consent_Status__c', 'Authorized');
        }
        if (fields.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            updateContact.put('Data_Subject_Lifecycle_Stage__c', 'Consumed');
        }
        update updateContact;

        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(c.Id, c.AccountId);
        System.assertEquals(false, result.isEligible);
        System.assertEquals('CONTACT_STATUS_BLOCKED', result.reasonCode);
    }

    @IsTest
    static void testConsentStatusBlocked() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Consent__c latestConsent = [
            SELECT Id, Consent_Status__c
            FROM Consent__c
            WHERE Data_Subject__c = :c.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        latestConsent.Consent_Status__c = 'Declined';
        update latestConsent;

        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(c.Id, c.AccountId);
        System.assertEquals(false, result.isEligible);
        System.assertEquals('CONSENT_STATUS_BLOCKED', result.reasonCode);
    }

    @IsTest
    static void testClientAccountMismatchBlocked() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Account otherAccount = new Account(Name = 'Other Account');
        insert otherAccount;

        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(c.Id, otherAccount.Id);
        System.assertEquals(false, result.isEligible);
        System.assertEquals('CLIENT_ACCOUNT_MISMATCH', result.reasonCode);
    }

    @IsTest
    static void testPrehireAlreadyUsedBlockedBySuccessfulRetrievalCount() {
        Account acct = new Account(Name = 'CBS Prehire Account');
        insert acct;

        Contact prehireContact = new Contact(
            LastName = 'Prehire Subject',
            AccountId = acct.Id,
            Full_Name__c = 'Prehire Subject',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S7654321A',
            Employment_Status__c = 'Pre-hire'
        );
        insert prehireContact;

        Consent__c prehireConsent = new Consent__c(
            Data_Subject__c = prehireContact.Id,
            Consent_Status__c = 'Active',
            Employment_Status__c = 'Pre-hire',
            Consent_Expiry_Date__c = Date.today().addDays(30),
            Match_Status__c = 'Matched',
            Report_Use_Count__c = 0
        );
        insert prehireConsent;

        Contact prehireState = new Contact(Id = prehireContact.Id);
        ConsentStatusModelService.applyContactState(prehireState, ConsentStatusModelService.STATUS_ACTIVE);
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Report_Eligibility_Status__c')) {
            prehireState.put('Report_Eligibility_Status__c', null);
        }
        update prehireState;

        Case reportCase = new Case(
            AccountId = acct.Id,
            ContactId = prehireContact.Id,
            Status = 'New',
            Origin = 'Phone',
            Subject = 'Prehire retrieval test',
            Exception_Type__c = 'File Validation'
        );
        insert reportCase;

        insert new Report_Request_Item__c(
            Data_Subject__c = prehireContact.Id,
            Report_Request_Case__c = reportCase.Id,
            Successful_Retrieval_Count__c = 1
        );

        ConsentEligibilityService.EligibilityResult result =
            ConsentEligibilityService.isConsentEligibleForReport(prehireContact.Id, acct.Id);
        System.assertEquals(false, result.isEligible);
        System.assertEquals('PREHIRE_ALREADY_USED', result.reasonCode);
    }
}