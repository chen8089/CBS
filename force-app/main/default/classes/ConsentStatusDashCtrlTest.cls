@IsTest
private class ConsentStatusDashCtrlTest {
    private static Account newTestAccount() {
        Account a = new Account(Name = 'Consent Dash Test Acct');
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('Client_Code__c')) {
            a.put(
                'Client_Code__c',
                'CS' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(8, '0')
            );
        }
        if (accountFields.containsKey('Client_Status__c')) {
            a.put('Client_Status__c', firstActivePicklistValue(accountFields.get('Client_Status__c')));
        }
        return a;
    }

    private static String firstActivePicklistValue(Schema.SObjectField fieldToken) {
        if (fieldToken == null) {
            return 'Active';
        }
        Schema.DescribeFieldResult d = fieldToken.getDescribe();
        if (d.getType() == Schema.DisplayType.PICKLIST) {
            for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                if (pe.isActive()) {
                    return pe.getValue();
                }
            }
        }
        return 'Active';
    }

    private static void applyDataSubjectRequiredDefaults(Contact c) {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Date_of_Birth__c') && c.get('Date_of_Birth__c') == null) {
            c.put('Date_of_Birth__c', Date.newInstance(1991, 3, 10));
        }
        if (fm.containsKey('Employment_Status__c') && c.get('Employment_Status__c') == null) {
            c.put('Employment_Status__c', firstActivePicklistValue(fm.get('Employment_Status__c')));
        }
        if (fm.containsKey('ID_Type__c') && c.get('ID_Type__c') == null) {
            c.put('ID_Type__c', firstActivePicklistValue(fm.get('ID_Type__c')));
        }
        if (fm.containsKey('Portal_Role__c') && c.get('Portal_Role__c') == null) {
            c.put('Portal_Role__c', firstActivePicklistValue(fm.get('Portal_Role__c')));
        }
    }

    @IsTest
    static void testSummaryAndList_basic() {
        if (!Schema.SObjectType.Consent__c.isCreateable()) {
            return;
        }
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact' AND DeveloperName = 'Per_Report_Consent'
            LIMIT 1
        ];
        if (rts.isEmpty()) {
            ConsentStatusDashboardController.ConsentSummaryDto s = ConsentStatusDashboardController.getConsentSummary();
            System.assertEquals(0, s.totalConsents);
            return;
        }

        Account a = newTestAccount();
        insert a;

        Contact ds = new Contact(
            LastName = 'ConsentDs',
            AccountId = a.Id,
            RecordTypeId = rts[0].Id,
            Full_Name__c = 'Gamma Data Subject',
            Email = 'gamma@example.com',
            ID_Number__c = 'ID-900'
        );
        applyDataSubjectRequiredDefaults(ds);
        insert ds;

        Consent__c c1 = new Consent__c(
            Data_Subject__c = ds.Id,
            Consent_Status__c = ConsentStatusDashboardController.STATUS_ACTIVE,
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        Consent__c c2 = new Consent__c(
            Data_Subject__c = ds.Id,
            Consent_Status__c = ConsentStatusDashboardController.STATUS_PENDING,
            Submitted_At__c = System.now().addDays(-1),
            Action_Type__c = 'Consent Given'
        );
        insert new List<Consent__c>{ c1, c2 };

        ConsentStatusDashboardController.ConsentSummaryDto sum = ConsentStatusDashboardController.getConsentSummary();
        System.assert(sum.totalConsents >= 2);
        System.assert(sum.active >= 1);
        System.assert(sum.pending >= 1);

        List<ConsentStatusDashboardController.ConsentRowDto> allRows = ConsentStatusDashboardController.getConsents(
            'ALL',
            '',
            'Submitted_At__c',
            'DESC',
            null
        );
        System.assert(allRows.size() >= 2);

        List<ConsentStatusDashboardController.ConsentRowDto> activeRows = ConsentStatusDashboardController.getConsents(
            'ACTIVE',
            'Gamma',
            'Name',
            'ASC',
            null
        );
        System.assert(activeRows.size() >= 1);
    }
}