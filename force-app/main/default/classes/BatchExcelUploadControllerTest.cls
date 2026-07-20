@IsTest
private class BatchExcelUploadControllerTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Upload Test Account');
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('Client_Code__c')) {
            acc.put(
                'Client_Code__c',
                'UP' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(8, '0')
            );
        }
        if (accountFields.containsKey('Client_Status__c')) {
            acc.put('Client_Status__c', firstActivePicklistValue(accountFields.get('Client_Status__c')));
        }
        insert acc;
    }

    private static Id testAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Upload Test Account' LIMIT 1].Id;
    }

    private static void useTestAccount() {
        BatchExcelUploadController.testAccountOverride = testAccountId();
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

    private static BatchExcelUploadController.BatchUploadRow validRow(
        Integer rowNum,
        String email,
        String idNum
    ) {
        BatchExcelUploadController.BatchUploadRow r = new BatchExcelUploadController.BatchUploadRow();
        r.rowNumber = rowNum;
        r.email = email;
        r.fullName = 'Test User';
        r.idType = 'NRIC';
        r.idNumber = idNum;
        r.dateOfBirth = '1990-06-15';
        r.employmentStatus = 'Existing Hire';
        return r;
    }

    private static void applyContactDefaults(Contact c) {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Full_Name__c') && c.get('Full_Name__c') == null) {
            c.put('Full_Name__c', 'Existing Contact');
        }
        if (fm.containsKey('Date_of_Birth__c') && c.get('Date_of_Birth__c') == null) {
            c.put('Date_of_Birth__c', Date.newInstance(1990, 6, 15));
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

    private static Boolean consentRecordTypesExistInOrg() {
        Integer count = [
            SELECT COUNT()
            FROM RecordType
            WHERE SObjectType = 'Contact'
            AND DeveloperName IN ('Singpass', 'Non_Singpass')
            AND IsActive = TRUE
        ];
        return count == 2;
    }

    @IsTest
    static void testSuccessfulUpload_twoRows() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        List<BatchExcelUploadController.BatchUploadRow> rows = new List<BatchExcelUploadController.BatchUploadRow>{
            validRow(2, 'alpha.upload@test.com', 'S1111111A'),
            validRow(3, 'beta.upload@test.com', 'S2222222B')
        };

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Test Batch Upload',
            'test-upload.xlsx',
            JSON.serialize(rows)
        );
        Test.stopTest();

        System.assertNotEquals(null, result.batchId);
        System.assertEquals(2, result.successRows);
        System.assertEquals(2, result.totalRows);

        Batch__c b = [
            SELECT Id, Client_Account__c, Approval_Status__c, Batch_Name__c, Total_Records__c, Validated_Records__c
            FROM Batch__c
            WHERE Id = :result.batchId
        ];
        System.assertEquals(testAccountId(), b.Client_Account__c);
        System.assertEquals(2, b.Total_Records__c);
        if (Schema.SObjectType.Batch__c.fields.getMap().containsKey('Validated_Records__c')) {
            System.assertEquals(2, b.Validated_Records__c);
        }

        List<Contact> contacts = [
            SELECT Id, AccountId, Batch_Id__c, Email, RecordType.DeveloperName,
                Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Batch_Id__c = :result.batchId
        ];
        System.assertEquals(2, contacts.size());
        for (Contact c : contacts) {
            System.assertEquals(testAccountId(), c.AccountId);
            System.assertEquals(result.batchId, c.Batch_Id__c);
            System.assertEquals('Singpass', c.RecordType.DeveloperName);
            String canonicalConsentStatus = ConsentStatusModelService.normalizeContactConsentStatus(c.Current_Consent_Status__c);
            String canonicalLifecycle = ConsentStatusModelService.normalizeLifecycleStage(c.Data_Subject_Lifecycle_Stage__c);
            System.assert(
                canonicalConsentStatus == ConsentStatusModelService.STATUS_PENDING
                    || canonicalLifecycle == ConsentStatusModelService.STATUS_PENDING,
                'Consent upload should keep contact in pending verification state.'
            );
        }
    }

    @IsTest
    static void testInvalidEmail_writesException() {
        useTestAccount();
        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'kelvin.ong.example', 'S3333333C');

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Invalid Email Batch',
            'invalid-email.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertNotEquals(null, result.batchId);
        System.assertEquals(0, result.successRows);
        System.assert(result.validationExceptionCount > 0);
        System.assert(result.exceptionCreatedCount > 0);

        if (Schema.SObjectType.Batch__c.fields.getMap().containsKey('Validated_Records__c')) {
            Batch__c batch = [
                SELECT Validated_Records__c
                FROM Batch__c
                WHERE Id = :result.batchId
            ];
            System.assertEquals(0, batch.Validated_Records__c);
        }

        Exception__c ex = [
            SELECT Exception_Field_Name__c, Exception_Message__c, Source__c, Batch_Id__c
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Email Address', ex.Exception_Field_Name__c);
        System.assert(ex.Exception_Message__c.contains('Invalid Email Format'));
        System.assertEquals('Consent Upload', ex.Source__c);
        System.assertNotEquals(null, ex.Batch_Id__c);
        assertExceptionBatchAndExcelRow(ex.Id, result.batchId, 2);
    }

    @IsTest
    static void testInvalidEmploymentStatus_writesException() {
        useTestAccount();
        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'bad.emp@test.com', 'S5555555E');
        r.employmentStatus = 'Invalid Status';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Invalid Employment Batch',
            'invalid-employment.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assertEquals(1, result.validationExceptionCount);
        System.assertEquals(1, result.exceptionCreatedCount);

        Exception__c ex = [
            SELECT Exception_Field_Name__c, Exception_Message__c
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Employment Status', ex.Exception_Field_Name__c);
        System.assert(ex.Exception_Message__c.contains('Invalid Employment Status'));
    }

    @IsTest
    static void testDuplicateEmailInFile_writesException() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        List<BatchExcelUploadController.BatchUploadRow> rows = new List<BatchExcelUploadController.BatchUploadRow>{
            validRow(2, 'dup@test.com', 'S6666666F'),
            validRow(3, 'dup@test.com', 'S7777777G')
        };

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Duplicate File Batch',
            'duplicate-file.xlsx',
            JSON.serialize(rows)
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assertEquals(2, result.duplicateInFileCount);
        System.assertEquals(2, result.exceptionRows);
    }

    @IsTest
    static void testNoPartnerAccount_throwsError() {
        Id saved = BatchExcelUploadController.testAccountOverride;
        BatchExcelUploadController.testAccountOverride = null;
        Boolean thrown = false;
        try {
            BatchExcelUploadController.getCurrentClientAccountId();
        } catch (AuraHandledException e) {
            thrown = true;
        } finally {
            BatchExcelUploadController.testAccountOverride = saved;
        }
        System.assert(thrown, 'Expected AuraHandledException when no partner account');
    }

    @IsTest
    static void testOrgDuplicateEmail_writesException() {
        useTestAccount();
        Id accId = testAccountId();
        Contact existing = new Contact(
            LastName = 'Existing',
            AccountId = accId,
            Email = 'existing.dup@test.com'
        );
        applyContactDefaults(existing);
        insert existing;

        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'existing.dup@test.com', 'S9999999I');

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Dup Test',
            'duplicate-existing.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertNotEquals(null, result.batchId);
        System.assertEquals(0, result.successRows);
        System.assertEquals(1, result.duplicateExistingCount);
        System.assert(result.exceptionCreatedCount >= 1);
    }

    @IsTest
    static void testPassportSkipsNricValidation() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'passport.user@test.com', 'P9988776');
        r.idType = 'Passport';
        r.employmentStatus = 'Pre-hire';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Passport Batch',
            'passport.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertEquals(1, result.successRows);
        Contact c = [
            SELECT RecordType.DeveloperName, Authentication_Type__c, ID_Type__c
            FROM Contact
            WHERE Email = 'passport.user@test.com'
            LIMIT 1
        ];
        System.assertEquals('Non_Singpass', c.RecordType.DeveloperName);
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        if (contactFields.containsKey('Authentication_Type__c')) {
            System.assertEquals('Non-Singpass', (String) c.get('Authentication_Type__c'));
        }
        System.assertEquals('Passport', (String) c.get('ID_Type__c'));
    }

    @IsTest
    static void testGetCurrentClientAccountId_success() {
        useTestAccount();
        Test.startTest();
        Id accId = BatchExcelUploadController.getCurrentClientAccountId();
        Test.stopTest();
        System.assertEquals(testAccountId(), accId);
    }

    @IsTest
    static void testNoRows_throws() {
        useTestAccount();
        Boolean thrown = false;
        try {
            BatchExcelUploadController.createBatchAndContacts('Empty', 'empty.xlsx', '[]');
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown, 'Expected exception when no importable rows.');
    }

    @IsTest
    static void testValidateAndUpload_invalidFileFormat_rejectsWithoutDml() {
        Integer batchCountBefore = [SELECT COUNT() FROM Batch__c];
        Integer contactCountBefore = [SELECT COUNT() FROM Contact];
        Integer exceptionCountBefore = [
            SELECT COUNT()
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
        ];

        BatchExcelUploadController.UploadValidationResult result = BatchExcelUploadController.validateAndUpload(
            'Invalid Format Batch',
            'bad-format.pdf',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ validRow(2, 'bad.format@test.com', 'S1234567A') }),
            JSON.serialize(new List<String>{ 'Full Name', 'Email Address', 'ID Type', 'ID Number', 'Date of Birth', 'Employment Status' }),
            1024,
            null,
            null
        );

        System.assertEquals(false, result.success);
        System.assertEquals('Invalid File Format', result.errorReason);
        System.assertEquals(batchCountBefore, [SELECT COUNT() FROM Batch__c]);
        System.assertEquals(contactCountBefore, [SELECT COUNT() FROM Contact]);
        System.assertEquals(
            exceptionCountBefore,
            [
                SELECT COUNT()
                FROM Exception__c
                WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ]
        );
    }

    @IsTest
    static void testValidateAndUpload_missingRequiredColumn_rejectsWithoutDml() {
        Integer batchCountBefore = [SELECT COUNT() FROM Batch__c];
        Integer exceptionCountBefore = [
            SELECT COUNT()
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
        ];

        BatchExcelUploadController.UploadValidationResult result = BatchExcelUploadController.validateAndUpload(
            'Missing Header Batch',
            'missing-id-number.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ validRow(2, 'missing.header@test.com', 'S1234567A') }),
            JSON.serialize(new List<String>{ 'Full Name', 'Email Address', 'ID Type', 'Date of Birth', 'Employment Status' }),
            1024,
            null,
            null
        );

        System.assertEquals(false, result.success);
        System.assertEquals('Missing Required Column', result.errorReason);
        System.assert(result.errorMessage.contains('ID Number'));
        System.assertEquals(batchCountBefore, [SELECT COUNT() FROM Batch__c]);
        System.assertEquals(
            exceptionCountBefore,
            [
                SELECT COUNT()
                FROM Exception__c
                WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ]
        );
    }

    @IsTest
    static void testValidateAndUpload_duplicateHeader_rejectsWithoutDml() {
        Integer batchCountBefore = [SELECT COUNT() FROM Batch__c];
        Integer exceptionCountBefore = [
            SELECT COUNT()
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
        ];

        BatchExcelUploadController.UploadValidationResult result = BatchExcelUploadController.validateAndUpload(
            'Duplicate Header Batch',
            'duplicate-header.csv',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ validRow(2, 'duplicate.header@test.com', 'S1234567A') }),
            JSON.serialize(
                new List<String>{
                    'Full Name',
                    'Email Address',
                    'Email Address',
                    'ID Type',
                    'ID Number',
                    'Date of Birth',
                    'Employment Status'
                }
            ),
            1024,
            null,
            null
        );

        System.assertEquals(false, result.success);
        System.assertEquals('Duplicate Column Header', result.errorReason);
        System.assertEquals(batchCountBefore, [SELECT COUNT() FROM Batch__c]);
        System.assertEquals(
            exceptionCountBefore,
            [
                SELECT COUNT()
                FROM Exception__c
                WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ]
        );
    }

    @IsTest
    static void testInvalidNric_writesException() {
        useTestAccount();
        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'bad.nric@test.com', '1234567A');

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Bad NRIC',
            'bad-nric.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assertEquals(1, result.validationExceptionCount);
    }

    @IsTest
    static void testFullNameSpaces_writesException() {
        useTestAccount();
        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'spaces.name@test.com', 'S4444444D');
        r.fullName = 'Too   Many   Spaces';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Name Spaces',
            'spaces.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assertEquals(1, result.validationExceptionCount);
    }

    @IsTest
    static void testInvalidIdType_writesException() {
        useTestAccount();
        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'bad.idtype@test.com', 'DL-999');
        r.idType = 'Work Permit';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Bad IdType',
            'bad-idtype.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assertEquals(1, result.validationExceptionCount);
    }

    @IsTest
    static void testUploadBatchContacts_directList() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        List<BatchExcelUploadController.BatchUploadRow> rows = new List<BatchExcelUploadController.BatchUploadRow>{
            validRow(2, 'direct.list@test.com', 'S8888888H')
        };

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.uploadBatchContacts(
            rows,
            'Direct List Batch',
            'direct.xlsx'
        );
        Test.stopTest();

        System.assertEquals(1, result.successRows);
        System.assertNotEquals(null, result.batchId);
    }

    @IsTest
    static void testPerReportFinClassification() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'fin.per@test.com', 'F1234567B');
        r.idType = 'FIN';
        r.employmentStatus = 'Pre-hire';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'FIN Per Report',
            'fin.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertEquals(1, result.successRows);
        Contact c = [
            SELECT RecordType.DeveloperName
            FROM Contact
            WHERE Email = 'fin.per@test.com'
            LIMIT 1
        ];
        System.assertEquals('Singpass', c.RecordType.DeveloperName);
    }

    @IsTest
    static void testOtherIdType_termBased() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        BatchExcelUploadController.BatchUploadRow r = validRow(2, 'other.id@test.com', 'OTH-001');
        r.idType = 'Other';
        r.employmentStatus = 'Pre-hire';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Other Id',
            'other.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ r })
        );
        Test.stopTest();

        System.assertEquals(1, result.successRows);
    }

    @IsTest
    static void testBlankRow_skipped() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        BatchExcelUploadController.BatchUploadRow blank = new BatchExcelUploadController.BatchUploadRow();
        blank.rowNumber = 2;
        List<BatchExcelUploadController.BatchUploadRow> rows = new List<BatchExcelUploadController.BatchUploadRow>{
            blank,
            validRow(3, 'nonblank@test.com', 'S1010101J')
        };

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Blank Skip',
            'blank.xlsx',
            JSON.serialize(rows)
        );
        Test.stopTest();

        System.assertEquals(1, result.successRows);
        System.assertEquals(1, result.totalRows);
    }

    @IsTest
    static void testShouldRetryWithoutOwner_helpers() {
        System.assertEquals(false, BatchExcelUploadController.shouldRetryWithoutOwner(null, null));
        Contact c = new Contact(LastName = 'Retry');
        System.assertEquals(false, BatchExcelUploadController.shouldRetryWithoutOwner(null, c));
    }

    @IsTest
    static void testMissingFullNameAndInvalidDob_writeExceptions() {
        useTestAccount();
        BatchExcelUploadController.BatchUploadRow noName = validRow(2, 'noname@test.com', 'S1313131L');
        noName.fullName = '';

        BatchExcelUploadController.BatchUploadRow badDob = validRow(3, 'baddob@test.com', 'S1414141M');
        badDob.dateOfBirth = '31-12-1990';

        Test.startTest();
        BatchExcelUploadController.UploadResult noNameResult = BatchExcelUploadController.createBatchAndContacts(
            'No Name',
            'noname.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ noName })
        );
        BatchExcelUploadController.UploadResult badDobResult = BatchExcelUploadController.createBatchAndContacts(
            'Bad DOB',
            'baddob.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ badDob })
        );
        Test.stopTest();

        System.assertEquals(0, noNameResult.successRows);
        System.assertEquals(1, noNameResult.validationExceptionCount);
        System.assertEquals(0, badDobResult.successRows);
        System.assertEquals(1, badDobResult.validationExceptionCount);
    }

    @IsTest
    static void testNullRowInList_skipped() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }

        List<BatchExcelUploadController.BatchUploadRow> rows = new List<BatchExcelUploadController.BatchUploadRow>();
        rows.add(null);
        rows.add(validRow(2, 'null.row@test.com', 'S1515151N'));

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.uploadBatchContacts(
            rows,
            'Null Row',
            'null-row.xlsx'
        );
        Test.stopTest();

        System.assertEquals(1, result.successRows);
    }

    @IsTest
    static void testInvalidPassportFormat_writesException() {
        useTestAccount();
        BatchExcelUploadController.BatchUploadRow row = validRow(2, 'passport.invalid@test.com', 'AB@12');
        row.idType = 'Passport';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Invalid Passport',
            'invalid-passport.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ row })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assert(result.exceptionRows > 0);
        Exception__c ex = [
            SELECT Exception_Message__c
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(ex.Exception_Message__c.contains('Invalid Passport Number Format'));
    }

    @IsTest
    static void testDuplicateIdNumberAndExistingDataSubject_writesException() {
        useTestAccount();
        if (!Schema.SObjectType.Contact.fields.getMap().containsKey('ID_Number__c')) {
            return;
        }
        Id accId = testAccountId();
        Contact existing = new Contact(
            LastName = 'Existing Duplicate Id',
            AccountId = accId,
            Email = 'existing.id.dup@test.com'
        );
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('ID_Number__c')) {
            existing.put('ID_Number__c', 'S9090909Z');
        }
        applyContactDefaults(existing);
        insert existing;

        BatchExcelUploadController.BatchUploadRow row = validRow(2, 'new.email@test.com', 'S9090909Z');

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Duplicate Id',
            'duplicate-id.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ row })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assert(result.exceptionRows > 0);
        List<Exception__c> exceptions = [
            SELECT Exception_Message__c
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        Boolean hasDuplicateIdError = false;
        Boolean hasExistingMatchError = false;
        for (Exception__c ex : exceptions) {
            if (ex.Exception_Message__c != null && ex.Exception_Message__c.contains('Duplicate ID Number')) {
                hasDuplicateIdError = true;
            }
            if (ex.Exception_Message__c != null && ex.Exception_Message__c.contains('Existing Data Subject Match Found')) {
                hasExistingMatchError = true;
            }
        }
        System.assert(hasDuplicateIdError, 'Expected at least one Duplicate ID Number exception message.');
        System.assert(hasExistingMatchError, 'Expected at least one Existing Data Subject Match Found exception message.');
    }

    @IsTest
    static void testExistingActiveConsentFound_writesException() {
        useTestAccount();
        Id accId = testAccountId();
        Contact existing = new Contact(
            LastName = 'Has Active Consent',
            AccountId = accId,
            Email = 'active.consent@test.com'
        );
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('ID_Number__c')) {
            existing.put('ID_Number__c', 'S8181818X');
        }
        applyContactDefaults(existing);
        insert existing;
        insert new Consent__c(
            Data_Subject__c = existing.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );

        BatchExcelUploadController.BatchUploadRow row = validRow(2, 'active.consent@test.com', 'S8181818X');

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Active Consent',
            'active-consent.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ row })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assert(result.exceptionRows > 0);
        Boolean foundActiveConsentReason = false;
        for (BatchExcelUploadController.RowValidationError rowError : result.rowErrors) {
            if (rowError != null && rowError.errorReason == 'Existing Active Consent Found') {
                foundActiveConsentReason = true;
                break;
            }
        }
        System.assert(foundActiveConsentReason, 'Expected Existing Active Consent Found row error.');
    }

    @IsTest
    static void testDoNotContactMatchedRecord_blocksUploadAndUpdatesBatchCount() {
        useTestAccount();
        if (!Schema.SObjectType.Contact.fields.getMap().containsKey('Do_Not_Contact__c')) {
            return;
        }

        Id accId = testAccountId();
        Contact existing = new Contact(
            LastName = 'Do Not Contact User',
            AccountId = accId,
            Email = 'dnc.blocked@test.com'
        );
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('ID_Number__c')) {
            existing.put('ID_Number__c', 'S5656565Q');
        }
        existing.put('Do_Not_Contact__c', true);
        applyContactDefaults(existing);
        insert existing;

        BatchExcelUploadController.BatchUploadRow row = validRow(2, 'dnc.blocked@test.com', 'S5656565Q');

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'DNC Block Batch',
            'dnc-block.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ row })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        Boolean foundDoNotContactReason = false;
        for (BatchExcelUploadController.RowValidationError rowError : result.rowErrors) {
            if (rowError != null && rowError.errorReason == BatchExcelUploadController.EXC_MSG_DO_NOT_CONTACT) {
                foundDoNotContactReason = true;
                break;
            }
        }
        System.assert(foundDoNotContactReason, 'Expected Do Not Contact row error.');

        if (Schema.SObjectType.Batch__c.fields.getMap().containsKey('Do_Not_Contact_Records__c')) {
            Batch__c batchRow = [
                SELECT Do_Not_Contact_Records__c
                FROM Batch__c
                WHERE Id = :result.batchId
                LIMIT 1
            ];
            System.assertEquals(1, batchRow.Do_Not_Contact_Records__c);
        }
    }

    @IsTest
    static void testExistingHireEmailDomainMismatch_writesExceptionWhenDomainConfigured() {
        useTestAccount();
        Id accId = testAccountId();
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        String domainField;
        for (String candidate : new List<String>{ 'Email_Domain__c', 'Allowed_Email_Domains__c', 'Company_Email_Domain__c' }) {
            if (accountFields.containsKey(candidate)) {
                domainField = candidate;
                break;
            }
        }
        if (String.isBlank(domainField)) {
            return;
        }

        Account accUpdate = new Account(Id = accId);
        accUpdate.put(domainField, 'bank.com');
        update accUpdate;

        BatchExcelUploadController.BatchUploadRow row = validRow(2, 'user@gmail.com', 'S7070707W');
        row.employmentStatus = 'Existing Hire';

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Domain Mismatch',
            'domain-mismatch.xlsx',
            JSON.serialize(new List<BatchExcelUploadController.BatchUploadRow>{ row })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assert(result.exceptionRows > 0);
        Exception__c ex = [
            SELECT Exception_Message__c
            FROM Exception__c
            WHERE Source__c = :BatchExcelUploadController.SOURCE_CONSENT_UPLOAD
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(ex.Exception_Message__c.contains('Existing Hire Email Domain Mismatch'));
    }

    @IsTest
    static void testMixedRows_summaryCounts() {
        useTestAccount();
        if (!consentRecordTypesExistInOrg()) {
            return;
        }
        Id accId = testAccountId();
        Contact existing = new Contact(
            LastName = 'Existing Mixed',
            AccountId = accId,
            Email = 'existing.mixed@test.com'
        );
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('ID_Number__c')) {
            existing.put('ID_Number__c', 'S1212121V');
        }
        applyContactDefaults(existing);
        insert existing;

        List<BatchExcelUploadController.BatchUploadRow> rows = new List<BatchExcelUploadController.BatchUploadRow>{
            validRow(2, 'ok1@test.com', 'S2000001A'),
            validRow(3, 'ok2@test.com', 'S2000002B'),
            validRow(4, 'ok3@test.com', 'S2000003C'),
            validRow(5, 'ok4@test.com', 'S2000004D'),
            validRow(6, 'ok5@test.com', 'S2000005E'),
            validRow(7, 'ok6@test.com', 'S2000006F'),
            validRow(8, 'bad-email', 'S2000007G'),
            validRow(9, 'dup-row@test.com', 'S2000008H'),
            validRow(10, 'dup-row@test.com', 'S2000009I'),
            validRow(11, 'existing.mixed@test.com', 'S1212121V')
        };

        Test.startTest();
        BatchExcelUploadController.UploadResult result = BatchExcelUploadController.createBatchAndContacts(
            'Mixed Rows',
            'mixed-rows.xlsx',
            JSON.serialize(rows)
        );
        Test.stopTest();

        System.assertEquals(10, result.totalRows);
        System.assertEquals(6, result.successRows);
        System.assertEquals(4, result.exceptionRows);
        System.assertEquals(6, result.createdContacts);
        System.assert(result.createdExceptions > 0);
        System.assert(result.createdExceptions >= result.exceptionRows);
        System.assertEquals(
            'Upload completed with exceptions. Please review the Exceptions list.',
            result.message
        );
    }
}