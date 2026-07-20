@IsTest
private class ConsentProjectionSyncServiceTest {
    @IsTest
    static void normalize_maps_core_statuses() {
        System.assertEquals(
            ConsentProjectionSyncService.STATUS_ACTIVE,
            ConsentProjectionSyncService.normalize('Active')
        );
        System.assertEquals(
            ConsentProjectionSyncService.STATUS_PENDING,
            ConsentProjectionSyncService.normalize('Pending Review')
        );
        System.assertEquals(
            ConsentProjectionSyncService.STATUS_DECLINED,
            ConsentProjectionSyncService.normalize('Declined')
        );
        System.assertEquals(
            ConsentProjectionSyncService.STATUS_WITHDRAWN,
            ConsentProjectionSyncService.normalize('Revoked')
        );
        System.assertEquals(
            ConsentProjectionSyncService.STATUS_EXPIRED,
            ConsentProjectionSyncService.normalize('Expired')
        );
        System.assertEquals(
            ConsentProjectionSyncService.STATUS_CONSUMED,
            ConsentProjectionSyncService.normalize('Consumed')
        );
        System.assertEquals(
            ConsentProjectionSyncService.STATUS_UNKNOWN,
            ConsentProjectionSyncService.normalize('Purged')
        );
    }

    @IsTest
    static void choosePicklistValue_returns_first_match() {
        Schema.DescribeFieldResult describeField = Contact.LeadSource.getDescribe();
        List<Schema.PicklistEntry> entries = describeField.getPicklistValues();
        System.assert(!entries.isEmpty(), 'LeadSource picklist should have entries for this test.');

        String expected = entries[0].getValue();
        String resolved = ConsentProjectionSyncService.choosePicklistValue(
            describeField,
            new List<String>{ '___NOT_EXISTS___', expected }
        );

        System.assertEquals(expected, resolved);
        System.assertEquals(
            null,
            ConsentProjectionSyncService.choosePicklistValue(describeField, new List<String>())
        );
    }

    @IsTest
    static void choosePicklistValue_returns_null_when_no_match() {
        Schema.DescribeFieldResult describeField = Contact.LeadSource.getDescribe();
        String resolved = ConsentProjectionSyncService.choosePicklistValue(
            describeField,
            new List<String>{ '___NOT_EXISTS_A___', '___NOT_EXISTS_B___' }
        );
        System.assertEquals(null, resolved);
    }

    @IsTest
    static void syncContactFromConsent_updates_projection_fields_when_available() {
        Contact seed = createRequiredContact('Projection Sync Test');

        Date expiryDate = Date.today().addMonths(1);
        Datetime statusAt = System.now();

        Test.startTest();
        ConsentProjectionSyncService.syncContactFromConsent(
            seed.Id,
            'Active',
            expiryDate,
            statusAt
        );
        // Unknown status should safely no-op.
        ConsentProjectionSyncService.syncContactFromConsent(
            seed.Id,
            'Purged',
            null,
            null
        );
        Test.stopTest();

        Contact updated = queryContactWithOptionalFields(seed.Id);

        assertPicklistIfConfigured(
            updated,
            'Current_Consent_Status__c',
            Contact.SObjectType.getDescribe().fields.getMap().containsKey('Current_Consent_Status__c')
                ? ConsentProjectionSyncService.choosePicklistValue(
                    Contact.Current_Consent_Status__c.getDescribe(),
                    ConsentProjectionSyncService.CONTACT_STATUS_PREF.get(ConsentProjectionSyncService.STATUS_ACTIVE)
                )
                : null
        );

        assertPicklistIfConfigured(
            updated,
            'Data_Subject_Lifecycle_Stage__c',
            Contact.SObjectType.getDescribe().fields.getMap().containsKey('Data_Subject_Lifecycle_Stage__c')
                ? ConsentProjectionSyncService.choosePicklistValue(
                    Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(),
                    ConsentProjectionSyncService.CONTACT_LIFECYCLE_PREF.get(ConsentProjectionSyncService.STATUS_ACTIVE)
                )
                : null
        );

        assertDateIfFieldExists(updated, 'Current_Consent_Expiry_Date__c', expiryDate);
        assertDateIfFieldExists(updated, 'Consent_Expiry_Date__c', expiryDate);
    }

    @IsTest
    static void syncContactFromConsent_null_id_is_safe_noop() {
        Test.startTest();
        ConsentProjectionSyncService.syncContactFromConsent(
            null,
            'Active',
            Date.today().addDays(5),
            System.now()
        );
        Test.stopTest();

        System.assert(true, 'Method should safely return when dataSubjectId is null.');
    }

    @IsTest
    static void syncContactFromConsent_unknown_status_does_not_update_contact() {
        Contact seed = createRequiredContact('Projection Unknown Noop');

        Datetime beforeModified = [
            SELECT LastModifiedDate
            FROM Contact
            WHERE Id = :seed.Id
            LIMIT 1
        ].LastModifiedDate;

        Test.startTest();
        ConsentProjectionSyncService.syncContactFromConsent(
            seed.Id,
            '___NOT_A_REAL_STATUS___',
            Date.today().addDays(10),
            System.now()
        );
        Test.stopTest();

        Datetime afterModified = [
            SELECT LastModifiedDate
            FROM Contact
            WHERE Id = :seed.Id
            LIMIT 1
        ].LastModifiedDate;

        System.assertEquals(
            beforeModified,
            afterModified,
            'Unknown status should not trigger Contact update DML.'
        );
    }

    @IsTest
    static void syncContactFromConsent_known_status_but_no_picklist_match_is_safe_noop() {
        Contact seed = createRequiredContact('Projection Known No Match');

        Datetime beforeModified = [
            SELECT LastModifiedDate
            FROM Contact
            WHERE Id = :seed.Id
            LIMIT 1
        ].LastModifiedDate;

        // Simulate a "known canonical status" (ACTIVE) where org picklists have no matching values.
        ConsentProjectionSyncService.CONTACT_STATUS_PREF.put(
            ConsentProjectionSyncService.STATUS_ACTIVE,
            new List<String>{ '___NO_MATCH_CONTACT_STATUS___' }
        );
        ConsentProjectionSyncService.CONTACT_LIFECYCLE_PREF.put(
            ConsentProjectionSyncService.STATUS_ACTIVE,
            new List<String>{ '___NO_MATCH_LIFECYCLE___' }
        );

        Test.startTest();
        ConsentProjectionSyncService.syncContactFromConsent(
            seed.Id,
            'Active',
            null,
            null
        );
        Test.stopTest();

        Datetime afterModified = [
            SELECT LastModifiedDate
            FROM Contact
            WHERE Id = :seed.Id
            LIMIT 1
        ].LastModifiedDate;

        System.assertEquals(
            beforeModified,
            afterModified,
            'Known status with no picklist match should be no-op and must not update Contact.'
        );
    }

    private static Contact queryContactWithOptionalFields(Id contactId) {
        List<String> fields = new List<String>{ 'Id' };
        Map<String, Schema.SObjectField> fmap = Contact.SObjectType.getDescribe().fields.getMap();
        for (String api : new List<String>{
            'Current_Consent_Status__c',
            'Data_Subject_Lifecycle_Stage__c',
            'Current_Consent_Expiry_Date__c',
            'Consent_Expiry_Date__c',
            'Latest_Status_Datetime__c',
            'Latest_Status_Date__c'
        }) {
            if (fmap.containsKey(api)) {
                fields.add(api);
            }
        }

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :contactId LIMIT 1';
        return Database.query(soql);
    }

    private static Contact createRequiredContact(String lastName) {
        Contact c = new Contact(LastName = lastName);
        setFieldIfExists(c, 'Full_Name__c', lastName);
        setFieldIfExists(c, 'ID_Number__c', 'S1234567A');

        String idType = firstPicklistValue(Contact.SObjectType, 'ID_Type__c');
        if (!String.isBlank(idType)) {
            c.put('ID_Type__c', idType);
        }

        String employmentStatus = firstPicklistValue(Contact.SObjectType, 'Employment_Status__c');
        if (!String.isBlank(employmentStatus)) {
            c.put('Employment_Status__c', employmentStatus);
        }

        insert c;
        return c;
    }

    private static void setFieldIfExists(SObject row, String fieldApi, Object value) {
        Map<String, Schema.SObjectField> fmap = row.getSObjectType().getDescribe().fields.getMap();
        if (!fmap.containsKey(fieldApi) || value == null) {
            return;
        }
        row.put(fieldApi, value);
    }

    private static String firstPicklistValue(Schema.SObjectType sobType, String fieldApi) {
        Map<String, Schema.SObjectField> fmap = sobType.getDescribe().fields.getMap();
        if (!fmap.containsKey(fieldApi)) {
            return null;
        }
        List<Schema.PicklistEntry> entries = fmap.get(fieldApi).getDescribe().getPicklistValues();
        if (entries.isEmpty()) {
            return null;
        }
        return entries[0].getValue();
    }

    private static void assertPicklistIfConfigured(SObject row, String fieldApi, String expected) {
        Map<String, Schema.SObjectField> fmap = row.getSObjectType().getDescribe().fields.getMap();
        if (!fmap.containsKey(fieldApi) || String.isBlank(expected)) {
            return;
        }
        System.assertEquals(expected, (String) row.get(fieldApi), fieldApi + ' should be synchronized');
    }

    private static void assertDateIfFieldExists(SObject row, String fieldApi, Date expected) {
        Map<String, Schema.SObjectField> fmap = row.getSObjectType().getDescribe().fields.getMap();
        if (!fmap.containsKey(fieldApi)) {
            return;
        }
        Object raw = row.get(fieldApi);
        if (raw == null) {
            System.assertEquals(expected, raw, fieldApi + ' should be synchronized');
            return;
        }
        System.assert(raw instanceof Date, fieldApi + ' should be a Date field');
        System.assertEquals(expected, (Date) raw, fieldApi + ' should be synchronized');
    }
}