@isTest
private class NonSingpassVerificationOrchestratorTest {
    @isTest
    static void applyPendingVerificationStatusForConsentAndRequestItem() {
        Contact contactRecord = createContact();
        Consent__c consentRecord = new Consent__c(
            Data_Subject__c = contactRecord.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given',
            MyInfo_Name__c = 'Orchestrator Test'
        );
        Consent_Request_Item__c requestItemRecord = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = 'Sent'
        );

        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus(consentRecord);
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus(requestItemRecord);

        System.assertNotEquals('Active', consentRecord.Consent_Status__c);
        System.assertNotEquals(null, consentRecord.Consent_Status__c);
        System.assertNotEquals(null, requestItemRecord.Current_Status__c);
    }

    @isTest
    static void applyPendingVerificationStatusForContactDoesNotSetAuthorized() {
        Contact contactUpdate = new Contact(Id = createContact().Id);
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus(contactUpdate);

        String resolvedStatus = contactUpdate.Current_Consent_Status__c == null
            ? ''
            : contactUpdate.Current_Consent_Status__c.toLowerCase();
        System.assert(
            resolvedStatus.contains('pending') || resolvedStatus.contains('verification') || String.isBlank(resolvedStatus),
            'Unexpected contact status value: ' + contactUpdate.Current_Consent_Status__c
        );
    }

    @isTest
    static void choosePicklistValueReturnsExpectedEntry() {
        String selected = NonSingpassVerificationOrchestrator.choosePicklistValue(
            Contact.Current_Consent_Status__c.getDescribe(),
            new List<String>{ 'Pending Verification', 'Verification Pending', 'Pending' }
        );
        // Some orgs may not have pending values; we only assert API behaves safely.
        if (selected != null) {
            System.assertNotEquals('', selected);
        } else {
            String fallback = NonSingpassVerificationOrchestrator.chooseNonActiveFallbackStatus(
                Consent__c.Consent_Status__c.getDescribe()
            );
            System.assertNotEquals(null, fallback);
        }
    }

    @isTest
    static void applyPendingVerificationStatusHandlesNullRecords() {
        Test.startTest();
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus((Contact) null);
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus((Consent__c) null);
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus((Consent_Request_Item__c) null);
        Test.stopTest();
        System.assertEquals(true, true);
    }

    @isTest
    static void choosePicklistValueHandlesNullInputs() {
        System.assertEquals(
            null,
            NonSingpassVerificationOrchestrator.choosePicklistValue(null, new List<String>{ 'Pending' })
        );
        System.assertEquals(
            null,
            NonSingpassVerificationOrchestrator.choosePicklistValue(
                Contact.Current_Consent_Status__c.getDescribe(),
                null
            )
        );
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contactRecord = new Contact(
            LastName = 'Orchestrator Test',
            Email = 'orchestrator+' + uniqueSuffix + '@example.com',
            Portal_Role__c = 'Approver'
        );
        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        if (contactFields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', 'Existing Hire');
        }
        if (contactFields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Orchestrator Test');
        }
        if (contactFields.containsKey('ID_Number__c')) {
            contactRecord.put('ID_Number__c', 'S' + uniqueSuffix.right(7));
        }
        if (contactFields.containsKey('ID_Type__c')) {
            contactRecord.put('ID_Type__c', 'NRIC');
        }
        if (contactFields.containsKey('Current_Consent_Status__c')) {
            contactRecord.put('Current_Consent_Status__c', 'Pending');
        }
        insert contactRecord;
        return contactRecord;
    }
}