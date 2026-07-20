@IsTest
private class ExportAuthorizationServiceTest {
    @TestSetup
    static void setupData() {
        Account acct = new Account(Name = 'CBS Export Account');
        insert acct;

        Contact c = new Contact(
            LastName = 'Export Subject',
            AccountId = acct.Id,
            Full_Name__c = 'Export Subject',
            ID_Type__c = 'NRIC',
            ID_Number__c = 'S1234567B',
            Employment_Status__c = 'Existing Employee'
        );
        insert c;

        Consent__c consent = new Consent__c(
            Data_Subject__c = c.Id,
            Consent_Status__c = 'Active',
            Consent_Expiry_Date__c = Date.today().addDays(30)
        );
        insert consent;
    }

    @IsTest
    static void testCanExportDeniedWithoutPermissionSet() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Profile nonAdminProfile = [
            SELECT Id
            FROM Profile
            WHERE PermissionsModifyAllData = false
            LIMIT 1
        ];
        User nonAdminUser = new User(
            Alias = 'nadmin',
            Email = 'nadmin-export@test.local',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NonAdmin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Singapore',
            ProfileId = nonAdminProfile.Id,
            UserName = 'nadmin-export+' + System.currentTimeMillis() + '@test.local'
        );
        insert nonAdminUser;

        System.runAs(nonAdminUser) {
            ExportAuthorizationService.ExportAuthorizationResult result =
                ExportAuthorizationService.canExport(null, c.Id, c.AccountId);
            System.assertEquals(false, result.isAuthorized);
            System.assertEquals('USER_NOT_PROCESSING_OFFICER', result.reasonCode);
        }
    }
}