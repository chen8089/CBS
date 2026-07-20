@IsTest
private class ConsentExpirySchedulerTest {
    @IsTest
    static void runExpiredConsentSweepExpiresEligibleConsents() {
        Account accountRecord = new Account(Name = 'Expiry Sweep Account');
        insert accountRecord;

        Contact expiredSubject = new Contact(
            LastName = 'Expired Subject',
            AccountId = accountRecord.Id,
            Full_Name__c = 'Expired Subject',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1000001A',
            Employment_Status__c = 'Existing Hire'
        );
        Contact activeSubject = new Contact(
            LastName = 'Active Subject',
            AccountId = accountRecord.Id,
            Full_Name__c = 'Active Subject',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1000002A',
            Employment_Status__c = 'Existing Hire'
        );
        insert new List<Contact>{ expiredSubject, activeSubject };

        Consent__c expiredConsent = new Consent__c(
            Data_Subject__c = expiredSubject.Id,
            Consent_Status__c = 'Active',
            Consent_Expiry_Date__c = Date.today().addDays(-1)
        );
        Consent__c stillActiveConsent = new Consent__c(
            Data_Subject__c = activeSubject.Id,
            Consent_Status__c = 'Active',
            Consent_Expiry_Date__c = Date.today().addDays(10)
        );
        insert new List<Consent__c>{ expiredConsent, stillActiveConsent };

        Test.startTest();
        Integer updatedCount = ConsentExpiryScheduler.runExpiredConsentSweep();
        Test.stopTest();

        Consent__c refreshedExpired = [
            SELECT Consent_Status__c
            FROM Consent__c
            WHERE Id = :expiredConsent.Id
            LIMIT 1
        ];
        Consent__c refreshedActive = [
            SELECT Consent_Status__c
            FROM Consent__c
            WHERE Id = :stillActiveConsent.Id
            LIMIT 1
        ];
        Contact refreshedSubject = [
            SELECT Data_Subject_Lifecycle_Stage__c, Report_Eligibility_Status__c
            FROM Contact
            WHERE Id = :expiredSubject.Id
            LIMIT 1
        ];

        System.assertEquals(1, updatedCount);
        System.assertEquals('Expired', refreshedExpired.Consent_Status__c);
        System.assertEquals('Active', refreshedActive.Consent_Status__c);
        System.assertEquals('Consent Expired', refreshedSubject.Data_Subject_Lifecycle_Stage__c);
        System.assertEquals('Consent Expired', refreshedSubject.Report_Eligibility_Status__c);
    }
}