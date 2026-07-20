@IsTest
private class ConsentUploadControllerTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Consent Upload Test Account');
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('Client_Code__c')) {
            acc.put(
                'Client_Code__c',
                'CU' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(8, '0')
            );
        }
        if (accountFields.containsKey('Client_Status__c')) {
            acc.put('Client_Status__c', firstActivePicklistValue(accountFields.get('Client_Status__c')));
        }
        insert acc;
    }

    private static Id testAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Consent Upload Test Account' LIMIT 1].Id;
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

    private static ConsentUploadController.ConsentUploadRow makeRow(Integer rowNumber, String email, String idNumber) {
        ConsentUploadController.ConsentUploadRow row = new ConsentUploadController.ConsentUploadRow();
        row.rowNumber = rowNumber;
        row.email = email;
        row.fullName = 'Consent User';
        row.idType = 'NRIC';
        row.idNumber = idNumber;
        row.dateOfBirth = '1990-01-01';
        row.employmentStatus = 'Existing Hire';
        return row;
    }

    @IsTest
    static void validateAndUploadConsents_success_createsBatchAndContact() {
        if (!consentRecordTypesExistInOrg()) {
            return;
        }
        BatchExcelUploadController.testAccountOverride = testAccountId();
        List<ConsentUploadController.ConsentUploadRow> rows = new List<ConsentUploadController.ConsentUploadRow>{
            makeRow(2, 'consent.success.one@test.com', 'S1100000A'),
            makeRow(3, 'consent.success.two@test.com', 'S2200000B')
        };
        List<String> headers = new List<String>{
            'Full Name',
            'Email Address',
            'ID Type',
            'ID Number',
            'Date of Birth',
            'Employment Status'
        };

        Test.startTest();
        ConsentUploadController.UploadValidationResult result = ConsentUploadController.validateAndUploadConsents(
            'Consent Upload Batch',
            'consent-upload.xlsx',
            1024,
            JSON.serialize(rows),
            JSON.serialize(headers),
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertNotEquals(null, result.uploadResult);
        System.assertNotEquals(null, result.uploadResult.batchId);
        System.assertEquals(2, result.uploadResult.successCount);
        System.assertEquals(0, result.uploadResult.exceptionRows);

        Batch__c batch = [
            SELECT Id, Total_Records__c, Validated_Records__c
            FROM Batch__c
            WHERE Id = :result.uploadResult.batchId
            LIMIT 1
        ];
        System.assertEquals(2, batch.Total_Records__c);
        if (Schema.SObjectType.Batch__c.fields.getMap().containsKey('Validated_Records__c')) {
            System.assertEquals(2, batch.Validated_Records__c);
        }
    }

    @IsTest
    static void validateAndUploadConsents_invalidHeader_rejectsWithoutDml() {
        Integer batchCountBefore = [SELECT COUNT() FROM Batch__c];
        Integer contactCountBefore = [SELECT COUNT() FROM Contact];

        ConsentUploadController.UploadValidationResult result = ConsentUploadController.validateAndUploadConsents(
            'Invalid Header Batch',
            'consent.csv',
            1024,
            JSON.serialize(new List<ConsentUploadController.ConsentUploadRow>{ makeRow(2, 'header.fail@test.com', 'S3300000C') }),
            JSON.serialize(new List<String>{ 'Email Address' }),
            null,
            null
        );

        System.assertEquals(false, result.success);
        System.assertEquals('Missing Required Column', result.errorReason);
        System.assertEquals(batchCountBefore, [SELECT COUNT() FROM Batch__c]);
        System.assertEquals(contactCountBefore, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void uploadConsents_invalidEmail_writesExceptionWithConsentSource() {
        if (!consentRecordTypesExistInOrg()) {
            return;
        }
        BatchExcelUploadController.testAccountOverride = testAccountId();
        List<ConsentUploadController.ConsentUploadRow> rows = new List<ConsentUploadController.ConsentUploadRow>{
            makeRow(2, 'invalid..email@test.com', 'S4400000D')
        };

        Test.startTest();
        ConsentUploadController.UploadResult result = ConsentUploadController.uploadConsents(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(0, result.successCount);
        System.assert(result.exceptionCreatedCount > 0);
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE Email = 'invalid..email@test.com']);

        Exception__c latest = [
            SELECT Source__c, Exception_Field_Name__c, Exception_Message__c
            FROM Exception__c
            WHERE Source__c = :ConsentUploadController.SOURCE_CONSENT_UPLOAD
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Consent Upload', latest.Source__c);
        System.assertEquals('Email Address', latest.Exception_Field_Name__c);
        System.assert(latest.Exception_Message__c.contains('Invalid Email'));
    }
}