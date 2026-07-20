@IsTest
private class BatchDeparturesUploadControllerTest {
    private static final String CURRENT_ACCOUNT_NAME = 'Departure Test Current Account';
    private static final String OTHER_ACCOUNT_NAME = 'Departure Test Other Account';

    @TestSetup
    static void setupData() {
        Account currentAccount = new Account(Name = CURRENT_ACCOUNT_NAME);
        Account otherAccount = new Account(Name = OTHER_ACCOUNT_NAME);
        insert new List<Account>{ currentAccount, otherAccount };

        List<Contact> contacts = new List<Contact>{
            buildContact(
                'Matched Existing',
                'matched.departure@test.com',
                currentAccount.Id,
                'S0000001A',
                'Existing Hire'
            ),
            buildContact(
                'Second Existing',
                'second.departure@test.com',
                currentAccount.Id,
                'S0000002B',
                'Existing Hire'
            ),
            buildContact(
                'Prehire User',
                'prehire.departure@test.com',
                currentAccount.Id,
                'S0000003C',
                'Pre-hire'
            ),
            buildContact(
                'Other Account Existing',
                'other.account.departure@test.com',
                otherAccount.Id,
                'S0000004D',
                'Existing Hire'
            ),
            buildContact(
                'Duplicate Email',
                'dup@test.com',
                currentAccount.Id,
                'S0000005E',
                'Existing Hire'
            ),
            buildContact(
                'Case Duplicate',
                'test@abc.com',
                currentAccount.Id,
                'S0000006F',
                'Existing Hire'
            ),
            buildContact(
                'Existing Departure Contact',
                'existing.departure@test.com',
                currentAccount.Id,
                'S0000008H',
                'Existing Hire'
            )
        };

        Contact departed = buildContact(
            'Departed User',
            'departed.departure@test.com',
            currentAccount.Id,
            'S0000007G',
            'Existing Hire'
        );
        if (markAsDeparted(departed)) {
            contacts.add(departed);
        }

        insert contacts;
        createActiveConsent('matched.departure@test.com');
        createActiveConsent('second.departure@test.com');
    }

    private static BatchDeparturesUploadController.DepartureUploadRow validRow(
        Integer rowNum,
        String email,
        String departureDate
    ) {
        BatchDeparturesUploadController.DepartureUploadRow r = new BatchDeparturesUploadController.DepartureUploadRow();
        r.rowNumber = rowNum;
        r.emailAddress = email;
        r.departureDate = departureDate;
        return r;
    }

    private static Contact buildContact(
        String lastName,
        String email,
        Id accountId,
        String idNumber,
        String employmentStatus
    ) {
        Contact c = new Contact(
            LastName = lastName,
            Email = email,
            AccountId = accountId
        );
        applyContactDefaults(c);
        setIfFieldExists(c, 'ID_Number__c', idNumber);
        setIfFieldExists(c, 'Employment_Status__c', employmentStatus);
        return c;
    }

    private static void applyContactDefaults(Contact c) {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Full_Name__c') && c.get('Full_Name__c') == null) {
            c.put('Full_Name__c', 'Test Contact');
        }
        if (fm.containsKey('Date_of_Birth__c') && c.Date_of_Birth__c == null) {
            c.Date_of_Birth__c = Date.newInstance(1990, 6, 15);
        }
        if (fm.containsKey('Employment_Status__c') && c.get('Employment_Status__c') == null) {
            c.put('Employment_Status__c', 'Existing Hire');
        }
        if (fm.containsKey('ID_Type__c') && c.get('ID_Type__c') == null) {
            c.put('ID_Type__c', 'NRIC');
        }
        if (fm.containsKey('ID_Number__c') && c.get('ID_Number__c') == null) {
            c.put('ID_Number__c', 'S0000000X');
        }
        if (fm.containsKey('Portal_Role__c') && c.get('Portal_Role__c') == null) {
            c.put('Portal_Role__c', firstActivePicklistValue(fm.get('Portal_Role__c')));
        }
    }

    private static void setIfFieldExists(Contact c, String fieldApiName, Object value) {
        if (Schema.SObjectType.Contact.fields.getMap().containsKey(fieldApiName)) {
            c.put(fieldApiName, value);
        }
    }

    private static Boolean markAsDeparted(Contact c) {
        if (setPicklistOrTextValue(c, 'Data_Subject_Lifecycle_Stage__c', new List<String>{ 'Departure', 'Departed', 'Inactive' })) {
            return true;
        }
        if (setPicklistOrTextValue(c, 'Current_Consent_Status__c', new List<String>{ 'Departure', 'Departed', 'Inactive' })) {
            return true;
        }
        if (setPicklistOrTextValue(c, 'Employment_Status__c', new List<String>{ 'Departed', 'Departure', 'Inactive' })) {
            return true;
        }
        return false;
    }

    private static Boolean setPicklistOrTextValue(Contact c, String fieldApiName, List<String> preferredValues) {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        if (!fields.containsKey(fieldApiName)) {
            return false;
        }
        Schema.DescribeFieldResult d = fields.get(fieldApiName).getDescribe();
        if (d.getType() == Schema.DisplayType.PICKLIST) {
            for (String preferred : preferredValues) {
                for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                    if (pe.isActive() && pe.getValue().toLowerCase() == preferred.toLowerCase()) {
                        c.put(fieldApiName, pe.getValue());
                        return true;
                    }
                }
            }
            return false;
        }
        c.put(fieldApiName, preferredValues[0]);
        return true;
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

    private static void assertExceptionBatchAndExcelRow(Id exceptionId, Id expectedBatchId, Integer expectedExcelRow) {
        Map<String, Schema.SObjectField> exceptionFields = Schema.SObjectType.Exception__c.fields.getMap();
        System.assert(
            exceptionFields.containsKey('Batch__c'),
            'Exception__c.Batch__c must exist for lookup-based batch association.'
        );
        System.assert(
            exceptionFields.containsKey('Excel_Row_Number__c'),
            'Exception__c.Excel_Row_Number__c must exist for Excel row tracing.'
        );

        SObject exceptionRow = Database.query(
            'SELECT Batch__c, Excel_Row_Number__c FROM Exception__c WHERE Id = :exceptionId LIMIT 1'
        );
        System.assertEquals(expectedBatchId, (Id) exceptionRow.get('Batch__c'));

        Decimal excelRowDecimal = (Decimal) exceptionRow.get('Excel_Row_Number__c');
        Integer actualExcelRow = excelRowDecimal == null ? null : excelRowDecimal.intValue();
        System.assertEquals(expectedExcelRow, actualExcelRow);
    }

    private static Integer departureCount() {
        return [SELECT COUNT() FROM Departure__c];
    }

    private static Id currentAccountId() {
        return [SELECT Id FROM Account WHERE Name = :CURRENT_ACCOUNT_NAME LIMIT 1].Id;
    }

    private static void createActiveConsent(String email) {
        List<Contact> matchedContacts = [
            SELECT Id
            FROM Contact
            WHERE Email = :email
            LIMIT 1
        ];
        if (matchedContacts.isEmpty()) {
            return;
        }
        insert new Consent__c(
            Data_Subject__c = matchedContacts[0].Id,
            Consent_Status__c = 'Active',
            Consent_Expiry_Date__c = Date.today().addDays(30)
        );
    }

    private static Id otherAccountId() {
        return [SELECT Id FROM Account WHERE Name = :OTHER_ACCOUNT_NAME LIMIT 1].Id;
    }

    @IsTest
    static void testSuccessfulImport_twoRows() {
        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'matched.departure@test.com', '2025-01-15'),
            validRow(3, 'second.departure@test.com', '2025-02-20')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(2, result.totalRows);
        System.assertEquals(2, result.insertedRows);
        System.assertEquals(2, result.updatedConsentRows);
        System.assertEquals(0, result.exceptionRows);
        System.assertEquals(2, result.successRows);
        System.assertEquals(true, result.success);

        List<Departure__c> deps = [
            SELECT Email__c, Consent_Status__c, Updated_Date__c, Departure_Date__c
            FROM Departure__c
            ORDER BY Email__c
        ];
        System.assertEquals(2, deps.size());

        Departure__c matched = null;
        Departure__c second = null;
        for (Departure__c d : deps) {
            if (d.Email__c == 'matched.departure@test.com') {
                matched = d;
            } else if (d.Email__c == 'second.departure@test.com') {
                second = d;
            }
        }
        System.assertNotEquals(null, matched);
        System.assertEquals(BatchDeparturesUploadController.STATUS_UPDATED_CONSENT, matched.Consent_Status__c);
        System.assertEquals(Date.today(), matched.Updated_Date__c);
        System.assertEquals(Date.newInstance(2025, 1, 15), matched.Departure_Date__c);

        System.assertNotEquals(null, second);
        System.assertEquals(BatchDeparturesUploadController.STATUS_UPDATED_CONSENT, second.Consent_Status__c);
    }

    @IsTest
    static void testImportRevokesActiveConsentAndCapturesAuditFields() {
        List<Contact> subjects = [
            SELECT Id, Email
            FROM Contact
            WHERE Email = 'matched.departure@test.com'
            LIMIT 1
        ];
        System.assertEquals(1, subjects.size(), 'Expected setup subject to exist.');

        Consent__c activeConsent = [
            SELECT Id, Consent_Status__c
            FROM Consent__c
            WHERE Data_Subject__c = :subjects[0].Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Active', activeConsent.Consent_Status__c);

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'matched.departure@test.com', '2025-07-01')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(1, result.insertedRows);
        System.assertEquals(1, result.updatedConsentRows);
        System.assertEquals(0, result.noValidConsentRows);

        Map<String, Schema.SObjectField> consentFields = Schema.SObjectType.Consent__c.fields.getMap();
        String soql = 'SELECT Consent_Status__c';
        if (consentFields.containsKey('Revoked_At__c')) soql += ', Revoked_At__c';
        if (consentFields.containsKey('Withdrawal_By__c')) soql += ', Withdrawal_By__c';
        if (consentFields.containsKey('Departure_Reason__c')) soql += ', Departure_Reason__c';
        Id consentId = activeConsent.Id;
        soql += ' FROM Consent__c WHERE Id = :consentId LIMIT 1';
        SObject updatedConsent = Database.query(soql);

        String updatedStatus = (String) updatedConsent.get('Consent_Status__c');
        System.assert(
            updatedStatus == 'Revoked' || updatedStatus == 'Withdrawn',
            'Consent status should be changed to Revoked/Withdrawn.'
        );
        if (consentFields.containsKey('Revoked_At__c')) {
            System.assertNotEquals(null, updatedConsent.get('Revoked_At__c'));
        }
        if (consentFields.containsKey('Withdrawal_By__c')) {
            System.assertEquals(UserInfo.getUserId(), (Id) updatedConsent.get('Withdrawal_By__c'));
        }
        if (consentFields.containsKey('Departure_Reason__c')) {
            System.assertEquals('Departure Upload', (String) updatedConsent.get('Departure_Reason__c'));
        }

        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        String contactQuery = 'SELECT Id';
        if (contactFields.containsKey('Current_Consent_Status__c')) contactQuery += ', Current_Consent_Status__c';
        if (contactFields.containsKey('Data_Subject_Lifecycle_Stage__c')) contactQuery += ', Data_Subject_Lifecycle_Stage__c';
        if (contactFields.containsKey('Report_Eligibility_Status__c')) contactQuery += ', Report_Eligibility_Status__c';
        if (contactFields.containsKey('Withdrawal_Source__c')) contactQuery += ', Withdrawal_Source__c';
        if (contactFields.containsKey('Departure_Reason__c')) contactQuery += ', Departure_Reason__c';
        Id subjectId = subjects[0].Id;
        contactQuery += ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        SObject updatedContact = Database.query(contactQuery);

        if (contactFields.containsKey('Current_Consent_Status__c')) {
            System.assertNotEquals(null, updatedContact.get('Current_Consent_Status__c'));
        }
        if (contactFields.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            String lifecycleStage = (String) updatedContact.get('Data_Subject_Lifecycle_Stage__c');
            System.assert(
                lifecycleStage == 'Departure' || lifecycleStage == 'Consent Withdrawn',
                'Lifecycle stage should be departure-aligned.'
            );
        }
        if (contactFields.containsKey('Report_Eligibility_Status__c')) {
            String eligibilityStatus = (String) updatedContact.get('Report_Eligibility_Status__c');
            System.assertNotEquals(null, eligibilityStatus, 'Report eligibility should be updated.');
        }
        if (contactFields.containsKey('Departure_Reason__c')) {
            System.assertEquals('Departure Upload', (String) updatedContact.get('Departure_Reason__c'));
        }
    }

    @IsTest
    static void testInvalidEmail() {
        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'kelvin.ong.example', '2025-01-15')
        };

        Test.startTest();
        BatchDeparturesUploadController.ValidationResult vr = BatchDeparturesUploadController.validateRows(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(1, vr.errorRows);
        System.assertEquals(1, vr.errors.size());
        System.assertEquals('Email Address', vr.errors[0].fieldName);
        System.assertEquals('Invalid email format.', vr.errors[0].message);
    }

    @IsTest
    static void testInvalidDate() {
        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'valid@test.com', 'not-a-date')
        };

        Test.startTest();
        BatchDeparturesUploadController.ValidationResult vr = BatchDeparturesUploadController.validateRows(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(1, vr.errorRows);
        System.assertEquals('Departure Date', vr.errors[0].fieldName);
    }

    @IsTest
    static void testEmptyEmail() {
        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, '', '2025-01-15')
        };

        Test.startTest();
        BatchDeparturesUploadController.ValidationResult vr = BatchDeparturesUploadController.validateRows(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(1, vr.errorRows);
        System.assertEquals('Email Address', vr.errors[0].fieldName);
    }

    @IsTest
    static void testDuplicateEmail_importsFirstAndCreatesException() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'dup@test.com', '2025-01-15'),
            validRow(3, 'dup@test.com', '2025-02-15')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.ValidationResult vr = BatchDeparturesUploadController.validateRows(JSON.serialize(rows));
        System.assertEquals(0, vr.errorRows, 'Duplicate emails should pass validation');

        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(2, result.totalRows);
        System.assertEquals(1, result.insertedRows);
        System.assertEquals(1, result.skippedDuplicateCount);
        System.assertEquals(1, result.exceptionCreatedCount);

        System.assertEquals(1, [SELECT COUNT() FROM Departure__c WHERE Email__c = 'dup@test.com']);
        List<Exception__c> excs = [
            SELECT Exception_Field_Name__c, Field_Value__c, Exception_Message__c, Source__c
            FROM Exception__c
            WHERE Field_Value__c = 'dup@test.com'
        ];
        System.assertEquals(1, excs.size());
        System.assertEquals('Email Address', excs[0].Exception_Field_Name__c);
        System.assertEquals('Duplicate Email', excs[0].Exception_Message__c);
        System.assertEquals('Departure Upload', excs[0].Source__c);
    }

    @IsTest
    static void testDuplicateEmailCaseInsensitive() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'Test@abc.com', '2025-01-15'),
            validRow(3, 'test@abc.com', '2025-02-15')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.ValidationResult vr = BatchDeparturesUploadController.validateRows(JSON.serialize(rows));
        System.assertEquals(0, vr.errorRows);

        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(1, result.insertedRows);
        System.assertEquals(1, result.skippedDuplicateCount);
        System.assertEquals(1, result.exceptionCreatedCount);
    }

    @IsTest
    static void testDuplicateEmail_existingInDeparture() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }

        Departure__c existing = new Departure__c(
            Email__c = 'existing.departure@test.com',
            Departure_Date__c = Date.today(),
            Consent_Status__c = BatchDeparturesUploadController.STATUS_NO_VALID_CONSENT
        );
        insert existing;

        Integer before = departureCount();
        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'existing.departure@test.com', '2025-03-01')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result =
            BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(before, departureCount(), 'Should not insert duplicate email in Departure__c');
        System.assertEquals(0, result.insertedRows);
        System.assertEquals(1, result.skippedDuplicateCount);
        System.assertEquals(1, result.duplicateExistingCount);
        System.assertEquals(1, result.exceptionCreatedCount);
    }

    @IsTest
    static void testImportWithErrors_NoInsert() {
        Integer before = departureCount();
        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'bad-email', '2025-01-15')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        try {
            BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(before, departureCount());
    }

    @IsTest
    static void testDepartureRecordNotFound_createsExceptionOnly() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }
        Integer beforeDeparture = departureCount();
        Integer beforeExceptions = [SELECT COUNT() FROM Exception__c];

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'not.found@test.com', '2025-04-01')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(0, result.insertedRows);
        System.assertEquals(1, result.exceptionRows);
        System.assertEquals(1, result.createdExceptions);
        System.assertEquals(beforeDeparture, departureCount());
        System.assertEquals(beforeExceptions + 1, [SELECT COUNT() FROM Exception__c]);

        Exception__c ex = [
            SELECT Exception_Field_Name__c, Field_Value__c, Exception_Message__c, Source__c
            FROM Exception__c
            WHERE Field_Value__c = 'not.found@test.com'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Departure Record', ex.Exception_Field_Name__c);
        System.assertEquals('Departure Upload', ex.Source__c);
        System.assert(ex.Exception_Message__c.contains('Departure Record Not Found'));
    }

    @IsTest
    static void testDataSubjectAccountMismatch_createsExceptionOnly() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'other.account.departure@test.com', '2025-04-02')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(0, result.insertedRows);
        System.assertEquals(1, result.exceptionRows);

        Exception__c ex = [
            SELECT Exception_Field_Name__c, Field_Value__c, Exception_Message__c, Source__c
            FROM Exception__c
            WHERE Field_Value__c = 'other.account.departure@test.com'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Account', ex.Exception_Field_Name__c);
        System.assert(ex.Exception_Message__c.contains('does not belong to the current client account'));
        System.assert(!ex.Exception_Message__c.contains(OTHER_ACCOUNT_NAME), 'Message must not leak account detail');
    }

    @IsTest
    static void testDepartureNotApplicableToPreHire_createsExceptionOnly() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'prehire.departure@test.com', '2025-04-03')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(0, result.insertedRows);
        System.assertEquals(1, result.exceptionRows);

        Exception__c ex = [
            SELECT Exception_Field_Name__c, Field_Value__c, Exception_Message__c, Source__c
            FROM Exception__c
            WHERE Field_Value__c = 'Pre-hire'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Employment Status', ex.Exception_Field_Name__c);
        System.assertEquals('Pre-hire', ex.Field_Value__c);
        System.assert(ex.Exception_Message__c.contains('Departure Not Applicable to Pre-hire'));
    }

    @IsTest
    static void testDataSubjectAlreadyDeparted_createsExceptionOnly() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }
        List<Contact> departedContacts = [
            SELECT Id, Email
            FROM Contact
            WHERE Email = 'departed.departure@test.com'
            LIMIT 1
        ];
        if (departedContacts.isEmpty()) {
            return;
        }

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'departed.departure@test.com', '2025-04-04')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(0, result.insertedRows);
        System.assertEquals(1, result.exceptionRows);

        Exception__c ex = [
            SELECT Exception_Field_Name__c, Field_Value__c, Exception_Message__c, Source__c
            FROM Exception__c
            WHERE Field_Value__c != null AND Source__c = 'Departure Upload'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Departure Status', ex.Exception_Field_Name__c);
        System.assert(ex.Exception_Message__c.contains('Data Subject Already Departed'));
    }

    @IsTest
    static void testMixedRows_successAndExceptionsSummary() {
        if (!Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }
        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>{
            validRow(2, 'matched.departure@test.com', '2025-05-01'),
            validRow(3, 'second.departure@test.com', '2025-05-01'),
            validRow(4, 'dup@test.com', '2025-05-01'),
            validRow(5, 'test@abc.com', '2025-05-01'),
            validRow(6, 'dup@test.com', '2025-05-02'),
            validRow(7, 'prehire.departure@test.com', '2025-05-02'),
            validRow(8, 'other.account.departure@test.com', '2025-05-02'),
            validRow(9, 'missing.departure@test.com', '2025-05-02')
        };

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.importDepartures(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(8, result.totalRows);
        System.assertEquals(4, result.successRows);
        System.assertEquals(4, result.exceptionRows);
        System.assertEquals(4, result.createdExceptions);
        System.assertEquals('Departure upload completed with exceptions. Please review the Exceptions list.', result.message);
    }

    @IsTest
    static void testUploadDepartureDataWithBatch_createsBatchAndFile() {
        if (!Schema.sObjectType.Batch__c.isCreateable() || !Schema.sObjectType.Exception__c.isCreateable()) {
            return;
        }

        List<BatchDeparturesUploadController.DepartureUploadRow> rows = new List<BatchDeparturesUploadController.DepartureUploadRow>();
        rows.add(validRow(2, 'dup@test.com', '2025-06-01'));
        rows.add(validRow(3, 'dup@test.com', '2025-06-02'));

        Test.startTest();
        BatchDeparturesUploadController.testAccountOverride = currentAccountId();
        BatchDeparturesUploadController.UploadResult result = BatchDeparturesUploadController.uploadDepartureDataWithBatch(
            JSON.serialize(rows),
            2,
            2,
            0,
            'departure-upload.xlsx',
            EncodingUtil.base64Encode(Blob.valueOf('departure upload test file')),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        );
        Test.stopTest();

        System.assertNotEquals(null, result.batchId, 'Batch should be created before import.');
        System.assertEquals(1, result.insertedRows);
        System.assertEquals(1, result.exceptionRows);
        System.assertEquals(1, result.validatedRecords);
        System.assertEquals(1, result.failedValidationRecords);
        Id batchId = result.batchId;

        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        String batchQuery = 'SELECT Id';
        if (batchFields.containsKey('Source__c')) batchQuery += ', Source__c';
        if (batchFields.containsKey('Total_Records__c')) batchQuery += ', Total_Records__c';
        if (batchFields.containsKey('Validated_Records__c')) batchQuery += ', Validated_Records__c';
        if (batchFields.containsKey('Failed_Validation_Records__c')) batchQuery += ', Failed_Validation_Records__c';
        batchQuery += ' FROM Batch__c WHERE Id = :batchId LIMIT 1';
        SObject batchRow = Database.query(batchQuery);

        if (batchFields.containsKey('Source__c')) {
            System.assertEquals('Departure Upload', (String) batchRow.get('Source__c'));
        }
        if (batchFields.containsKey('Total_Records__c')) {
            System.assertEquals(2, ((Decimal) batchRow.get('Total_Records__c')).intValue());
        }
        if (batchFields.containsKey('Validated_Records__c')) {
            System.assertEquals(1, ((Decimal) batchRow.get('Validated_Records__c')).intValue());
        }
        if (batchFields.containsKey('Failed_Validation_Records__c')) {
            System.assertEquals(1, ((Decimal) batchRow.get('Failed_Validation_Records__c')).intValue());
        }

        Integer linkedFiles = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :result.batchId];
        System.assert(linkedFiles > 0, 'Uploaded file must be linked to Batch.');

        Map<String, Schema.SObjectField> depFields = Schema.SObjectType.Departure__c.fields.getMap();
        if (depFields.containsKey('Batch__c') && depFields.get('Batch__c').getDescribe().isCreateable()) {
            Departure__c dep = [
                SELECT Batch__c, Email__c
                FROM Departure__c
                WHERE Email__c = 'dup@test.com'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            System.assertEquals(result.batchId, dep.Batch__c);
        } else if (depFields.containsKey('Batch_ID__c') && depFields.get('Batch_ID__c').getDescribe().isCreateable()) {
            SObject dep = Database.query(
                'SELECT Batch_ID__c, Email__c FROM Departure__c WHERE Email__c = \'dup@test.com\' ORDER BY CreatedDate DESC LIMIT 1'
            );
            Object batchIdTextOrId = dep.get('Batch_ID__c');
            System.assertNotEquals(null, batchIdTextOrId, 'Expected batch reference fallback field to be populated.');
            System.assertEquals(String.valueOf(result.batchId), String.valueOf(batchIdTextOrId));
        }

        Exception__c ex = [
            SELECT Id, Source__c, Field_Value__c
            FROM Exception__c
            WHERE Field_Value__c = 'dup@test.com'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Departure Upload', ex.Source__c);
        assertExceptionBatchAndExcelRow(ex.Id, result.batchId, 3);
    }
}