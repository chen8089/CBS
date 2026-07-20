@isTest
private class QRSiteContactConsentEmailTest {
    private static void applyRequiredContactFields(Contact contactRow, String idNumberValue) {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        if (fields.containsKey('Employment_Status__c')) {
            contactRow.put('Employment_Status__c', 'Existing Hire');
        }
        if (fields.containsKey('Full_Name__c')) {
            contactRow.put('Full_Name__c', contactRow.LastName);
        }
        if (fields.containsKey('ID_Type__c')) {
            contactRow.put('ID_Type__c', 'NRIC');
        }
        if (fields.containsKey('ID_Number__c')) {
            contactRow.put('ID_Number__c', idNumberValue);
        }
    }
    @isTest
    static void resolveTemplateDeveloperNameSupportsNonSingpassEmployee() {
        String templateName = QRSiteContactConsentEmail.resolveTemplateDeveloperName('NonSingpass', 'Existing Hire');
        System.assertEquals('NonSingpassEmployeeConsentEmail', templateName);
    }

    @isTest
    static void resolveTemplateDeveloperNameSupportsNonSingpassPrehire() {
        String templateName = QRSiteContactConsentEmail.resolveTemplateDeveloperName('NonSingpass', 'Pre-hire');
        System.assertEquals('NonSingpassPrehireConsentEmail', templateName);
    }

    @isTest
    static void filterContactsByDoNotContact_skipsBlockedContact() {
        if (!Schema.SObjectType.Contact.fields.getMap().containsKey('Do_Not_Contact__c')) {
            return;
        }

        Account acc = new Account(Name = 'QRSiteContactConsentEmailTest Account');
        insert acc;

        Contact eligible = new Contact(LastName = 'Eligible', AccountId = acc.Id, Email = 'eligible.dnc@test.com');
        Contact blocked = new Contact(LastName = 'Blocked', AccountId = acc.Id, Email = 'blocked.dnc@test.com');
        applyRequiredContactFields(eligible, 'S1234567A');
        applyRequiredContactFields(blocked, 'S7654321B');
        blocked.put('Do_Not_Contact__c', true);
        insert new List<Contact>{ eligible, blocked };

        List<Contact> blockedContacts = new List<Contact>();
        List<Contact> eligibleContacts = QRSiteContactConsentEmail.filterContactsByDoNotContact(
            new List<Contact>{ eligible, blocked },
            blockedContacts
        );

        System.assertEquals(1, eligibleContacts.size());
        System.assertEquals(eligible.Id, eligibleContacts[0].Id);
        System.assertEquals(1, blockedContacts.size());
        System.assertEquals(blocked.Id, blockedContacts[0].Id);
    }
}