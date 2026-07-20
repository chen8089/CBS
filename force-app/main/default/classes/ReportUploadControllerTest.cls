@IsTest
private class ReportUploadControllerTest {
    @TestSetup
    static void setupData() {
        if (!Schema.sObjectType.Account.isCreateable() || !Schema.sObjectType.Contact.isCreateable()) {
            return;
        }

        Account accountRecord = new Account(Name = 'Report Upload Test Account');
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('Client_Code__c')) {
            accountRecord.put(
                'Client_Code__c',
                'RU' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(8, '0')
            );
        }
        if (accountFields.containsKey('Client_Status__c')) {
            accountRecord.put('Client_Status__c', firstActivePicklistValue(accountFields.get('Client_Status__c')));
        }
        insert accountRecord;

        insert buildContact(
            accountRecord.Id,
            'report.unique@test.com',
            'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        insert buildContact(
            accountRecord.Id,
            'existing.report@test.com',
            'R' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );

        if (Schema.sObjectType.Consent__c.isCreateable()) {
            List<Contact> seededContacts = [
                SELECT Id
                FROM Contact
                WHERE Email IN ('report.unique@test.com', 'existing.report@test.com')
            ];
            List<Consent__c> consents = new List<Consent__c>();
            for (Contact contactRecord : seededContacts) {
                consents.add(new Consent__c(
                    Data_Subject__c = contactRecord.Id,
                    Consent_Status__c = 'Active',
                    Consent_Expiry_Date__c = Date.today().addDays(30)
                ));
            }
            insert consents;
        }
    }

    private static Contact buildContact(Id accountId, String email, String idNumberSeed) {
        Contact contactRecord = new Contact(
            LastName = 'Report Test Contact',
            AccountId = accountId,
            Email = email
        );
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Contact.fields.getMap();
        if (fields.containsKey('Full_Name__c')) {
            contactRecord.put('Full_Name__c', 'Report Test Contact');
        }
        if (fields.containsKey('Date_of_Birth__c')) {
            contactRecord.put('Date_of_Birth__c', Date.newInstance(1990, 1, 1));
        }
        if (fields.containsKey('Employment_Status__c')) {
            contactRecord.put('Employment_Status__c', firstActivePicklistValue(fields.get('Employment_Status__c')));
        }
        if (fields.containsKey('ID_Type__c')) {
            contactRecord.put('ID_Type__c', firstActivePicklistValue(fields.get('ID_Type__c')));
        }
        if (fields.containsKey('ID_Number__c')) {
            contactRecord.put('ID_Number__c', idNumberSeed);
        }
        if (fields.containsKey('Portal_Role__c')) {
            contactRecord.put('Portal_Role__c', firstActivePicklistValue(fields.get('Portal_Role__c')));
        }
        return contactRecord;
    }

    private static String firstActivePicklistValue(Schema.SObjectField fieldToken) {
        if (fieldToken == null) {
            return 'Active';
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return 'Active';
    }

    private static void insertExistingReportRecord(String emailValue) {
        Reports__c existing = new Reports__c();
        Map<String, Schema.SObjectField> reportFields = Schema.SObjectType.Reports__c.fields.getMap();
        if (reportFields.containsKey('Email__c')) {
            existing.put('Email__c', emailValue);
        }
        if (reportFields.containsKey('Consent_Status__c')) {
            existing.put('Consent_Status__c', ReportUploadController.STATUS_NO_VALID_CONSENT);
        }
        if (reportFields.containsKey('Updated_Date__c')) {
            existing.put('Updated_Date__c', Date.today());
        }
        if (reportFields.containsKey('Batch_ID__c')) {
            Schema.DisplayType batchFieldType = reportFields.get('Batch_ID__c').getDescribe().getType();
            if (batchFieldType == Schema.DisplayType.STRING || batchFieldType == Schema.DisplayType.TEXTAREA) {
                existing.put('Batch_ID__c', 'LEGACY-BATCH');
            }
        }
        insert existing;
    }

    private static void assertExceptionBatchAndExcelRow(Id exceptionId, Id expectedBatchId, Set<Integer> expectedRows) {
        Map<String, Schema.SObjectField> exceptionFields = Schema.SObjectType.Exception__c.fields.getMap();
        System.assert(exceptionFields.containsKey('Batch__c'));
        System.assert(exceptionFields.containsKey('Excel_Row_Number__c'));

        SObject ex = Database.query(
            'SELECT Batch__c, Excel_Row_Number__c FROM Exception__c WHERE Id = :exceptionId LIMIT 1'
        );
        System.assertEquals(expectedBatchId, (Id) ex.get('Batch__c'));
        Decimal excelRowDecimal = (Decimal) ex.get('Excel_Row_Number__c');
        Integer excelRow = excelRowDecimal == null ? null : excelRowDecimal.intValue();
        System.assert(expectedRows.contains(excelRow), 'Unexpected Excel row number: ' + String.valueOf(excelRow));
    }

    @IsTest
    static void testUploadReports_writesBatchLookupAndExcelRowForDuplicateExceptions() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable()
        ) {
            return;
        }

        insertExistingReportRecord('existing.report@test.com');

        List<ReportUploadController.ReportUploadRow> rows = new List<ReportUploadController.ReportUploadRow>();
        ReportUploadController.ReportUploadRow row1 = new ReportUploadController.ReportUploadRow();
        row1.rowNumber = 2;
        row1.email = 'report.unique@test.com';
        row1.batchId = 'OLD-BATCH-1';
        rows.add(row1);

        ReportUploadController.ReportUploadRow row2 = new ReportUploadController.ReportUploadRow();
        row2.rowNumber = 3;
        row2.email = 'existing.report@test.com';
        row2.batchId = 'OLD-BATCH-2';
        rows.add(row2);

        ReportUploadController.ReportUploadRow row3 = new ReportUploadController.ReportUploadRow();
        row3.rowNumber = 4;
        row3.email = 'report.unique@test.com';
        row3.batchId = 'OLD-BATCH-3';
        rows.add(row3);

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReports(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(3, result.totalRows);
        System.assertEquals(1, result.successCount);
        System.assertEquals(2, result.skippedDuplicateCount);
        System.assertEquals(1, result.duplicateExistingCount);
        System.assertEquals(1, result.duplicateInFileCount);
        System.assertEquals(2, result.exceptionCreatedCount);
        System.assertEquals(1, result.validatedRecords);
        System.assertEquals(2, result.failedValidationRecords);
        System.assertNotEquals(null, result.batchId);
        Id batchId = result.batchId;

        List<Exception__c> exceptions = [
            SELECT Id, Source__c
            FROM Exception__c
            WHERE Source__c = :ReportUploadController.SOURCE_REPORT_UPLOAD
            AND Batch__c = :batchId
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(2, exceptions.size());
        for (Exception__c exceptionRecord : exceptions) {
            System.assertEquals(ReportUploadController.SOURCE_REPORT_UPLOAD, exceptionRecord.Source__c);
            assertExceptionBatchAndExcelRow(exceptionRecord.Id, batchId, new Set<Integer>{ 3, 4 });
        }

        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        String batchQuery = 'SELECT Id';
        if (batchFields.containsKey('Source__c')) batchQuery += ', Source__c';
        if (batchFields.containsKey('Total_Records__c')) batchQuery += ', Total_Records__c';
        if (batchFields.containsKey('Validated_Records__c')) batchQuery += ', Validated_Records__c';
        if (batchFields.containsKey('Failed_Validation_Records__c')) batchQuery += ', Failed_Validation_Records__c';
        batchQuery += ' FROM Batch__c WHERE Id = :batchId LIMIT 1';
        SObject batchRow = Database.query(batchQuery);
        if (batchFields.containsKey('Source__c')) {
            System.assertEquals(ReportUploadController.SOURCE_REPORT_UPLOAD, (String) batchRow.get('Source__c'));
        }
        if (batchFields.containsKey('Total_Records__c')) {
            System.assertEquals(3, ((Decimal) batchRow.get('Total_Records__c')).intValue());
        }
        if (batchFields.containsKey('Validated_Records__c')) {
            System.assertEquals(1, ((Decimal) batchRow.get('Validated_Records__c')).intValue());
        }
        if (batchFields.containsKey('Failed_Validation_Records__c')) {
            System.assertEquals(2, ((Decimal) batchRow.get('Failed_Validation_Records__c')).intValue());
        }
    }

    @IsTest
    static void testUploadReports_writesBatchLookupAndExcelRowForValidationException() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable()
        ) {
            return;
        }

        ReportUploadController.ReportUploadRow invalidRow = new ReportUploadController.ReportUploadRow();
        invalidRow.rowNumber = 5;
        invalidRow.email = 'invalid-email-format';
        invalidRow.batchId = '';

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReports(
            JSON.serialize(new List<ReportUploadController.ReportUploadRow>{ invalidRow })
        );
        Test.stopTest();

        System.assertEquals(1, result.totalRows);
        System.assertEquals(0, result.successCount);
        System.assertEquals(1, result.errorCount);
        System.assertEquals(1, result.exceptionCreatedCount);
        System.assertEquals(0, result.validatedRecords);
        System.assertEquals(1, result.failedValidationRecords);
        System.assertNotEquals(null, result.batchId);

        Exception__c validationException = [
            SELECT Id, Source__c, Exception_Message__c
            FROM Exception__c
            WHERE Source__c = :ReportUploadController.SOURCE_REPORT_UPLOAD
            AND Batch__c = :result.batchId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(validationException.Exception_Message__c.contains('Invalid Email Address format'));
        assertExceptionBatchAndExcelRow(validationException.Id, result.batchId, new Set<Integer>{ 5 });
    }

    @IsTest
    static void testUploadReports_writesBlankForEmptyFieldValue() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable()
        ) {
            return;
        }

        ReportUploadController.ReportUploadRow blankEmailRow = new ReportUploadController.ReportUploadRow();
        blankEmailRow.rowNumber = 6;
        blankEmailRow.email = '   ';
        blankEmailRow.batchId = '';

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReports(
            JSON.serialize(new List<ReportUploadController.ReportUploadRow>{ blankEmailRow })
        );
        Test.stopTest();

        System.assertEquals(1, result.totalRows);
        System.assertEquals(0, result.successCount);
        System.assertEquals(1, result.errorCount);
        System.assertEquals(1, result.exceptionCreatedCount);
        System.assertNotEquals(null, result.batchId);

        Exception__c blankValueException = [
            SELECT Id, Field_Value__c, Exception_Field_Name__c, Exception_Message__c
            FROM Exception__c
            WHERE Source__c = :ReportUploadController.SOURCE_REPORT_UPLOAD
            AND Batch__c = :result.batchId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Blank', blankValueException.Field_Value__c);
        System.assertEquals('Email Address', blankValueException.Exception_Field_Name__c);
        System.assert(blankValueException.Exception_Message__c.contains('Email Address is required'));
        assertExceptionBatchAndExcelRow(blankValueException.Id, result.batchId, new Set<Integer>{ 6 });
    }

    @IsTest
    static void testUploadReportsWithBatch_savesFileToBatchAndImportsReport() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable()
        ) {
            return;
        }

        ReportUploadController.ReportUploadRow validRow = new ReportUploadController.ReportUploadRow();
        validRow.rowNumber = 2;
        validRow.emailAddress = 'report.unique@test.com';

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReportsWithBatch(
            JSON.serialize(new List<ReportUploadController.ReportUploadRow>{ validRow }),
            'report-upload.xlsx',
            EncodingUtil.base64Encode(Blob.valueOf('report upload test file')),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        );
        Test.stopTest();

        System.assertEquals(1, result.totalRows);
        System.assertEquals(1, result.successRows);
        System.assertEquals(0, result.exceptionRows);
        System.assertEquals(1, result.validatedRecords);
        System.assertEquals(0, result.failedValidationRecords);
        System.assertNotEquals(null, result.batchId);

        Integer linkedFiles = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :result.batchId];
        System.assert(linkedFiles > 0, 'Uploaded file must be linked to Batch.');

        List<Reports__c> insertedReports = [
            SELECT Id
            FROM Reports__c
            WHERE Email__c = 'report.unique@test.com'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(1, insertedReports.size());
        Contact insertedReportSubject = [
            SELECT Id
            FROM Contact
            WHERE Email = 'report.unique@test.com'
            LIMIT 1
        ];
        Integer createdCases = [
            SELECT COUNT()
            FROM Case
            WHERE ContactId = :insertedReportSubject.Id
                AND Origin = 'Portal'
                AND Subject LIKE 'Uploaded Report Request%'
        ];
        System.assertEquals(1, createdCases);
        Integer createdItems = [
            SELECT COUNT()
            FROM Report_Request_Item__c
            WHERE Data_Subject__c = :insertedReportSubject.Id
        ];
        System.assertEquals(1, createdItems);
        System.assertEquals(1, result.casesCreated);
        System.assertEquals(0, result.caseBindingErrors);
    }

    @IsTest
    static void testUploadReports_bulkCreatesOneCasePerReport() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable()
        ) {
            return;
        }

        Id accountId = [SELECT Id FROM Account WHERE Name = 'Report Upload Test Account' LIMIT 1].Id;
        Contact bulkOne = buildContact(
            accountId,
            'bulk.new.one@test.com',
            'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        Contact bulkTwo = buildContact(
            accountId,
            'bulk.new.two@test.com',
            'T' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        insert new List<Contact>{ bulkOne, bulkTwo };
        if (Schema.sObjectType.Consent__c.isCreateable()) {
            insert new List<Consent__c>{
                new Consent__c(Data_Subject__c = bulkOne.Id, Consent_Status__c = 'Active', Consent_Expiry_Date__c = Date.today().addDays(30)),
                new Consent__c(Data_Subject__c = bulkTwo.Id, Consent_Status__c = 'Active', Consent_Expiry_Date__c = Date.today().addDays(30))
            };
        }

        List<ReportUploadController.ReportUploadRow> rows = new List<ReportUploadController.ReportUploadRow>();
        ReportUploadController.ReportUploadRow row1 = new ReportUploadController.ReportUploadRow();
        row1.rowNumber = 2;
        row1.emailAddress = 'report.unique@test.com';
        rows.add(row1);

        ReportUploadController.ReportUploadRow row2 = new ReportUploadController.ReportUploadRow();
        row2.rowNumber = 3;
        row2.emailAddress = 'bulk.new.one@test.com';
        rows.add(row2);

        ReportUploadController.ReportUploadRow row3 = new ReportUploadController.ReportUploadRow();
        row3.rowNumber = 4;
        row3.emailAddress = 'bulk.new.two@test.com';
        rows.add(row3);

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReports(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(3, result.successRows);
        System.assertEquals(3, result.casesCreated);
        System.assertEquals(0, result.caseBindingErrors);

        List<Reports__c> insertedReports = [
            SELECT Id
            FROM Reports__c
            WHERE Email__c IN ('report.unique@test.com', 'bulk.new.one@test.com', 'bulk.new.two@test.com')
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(3, insertedReports.size());
        Set<Id> expectedSubjectIds = new Set<Id>();
        for (Contact subjectContact : [
            SELECT Id
            FROM Contact
            WHERE Email IN ('report.unique@test.com', 'bulk.new.one@test.com', 'bulk.new.two@test.com')
        ]) {
            expectedSubjectIds.add(subjectContact.Id);
        }
        Integer linkedCases = [
            SELECT COUNT()
            FROM Case
            WHERE ContactId IN :expectedSubjectIds
                AND Origin = 'Portal'
                AND Subject LIKE 'Uploaded Report Request%'
        ];
        System.assertEquals(3, linkedCases);
        Integer linkedItems = [
            SELECT COUNT()
            FROM Report_Request_Item__c
            WHERE Data_Subject__c IN :expectedSubjectIds
        ];
        System.assertEquals(3, linkedItems);
    }

    @IsTest
    static void testUploadReports_marksPrehireConsentConsumedAfterSuccessfulRetrieval() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable() ||
            !Schema.sObjectType.Consent__c.isUpdateable()
        ) {
            return;
        }

        Contact prehireSubject = [
            SELECT Id, Email
            FROM Contact
            WHERE Email = 'report.unique@test.com'
            LIMIT 1
        ];
        Consent__c latestConsent = [
            SELECT Id, Consent_Status__c, Employment_Status__c, Report_Use_Count__c
            FROM Consent__c
            WHERE Data_Subject__c = :prehireSubject.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        latestConsent.Employment_Status__c = 'Pre-hire';
        latestConsent.Consent_Status__c = 'Active';
        latestConsent.Report_Use_Count__c = 0;
        update latestConsent;

        ReportUploadController.ReportUploadRow row = new ReportUploadController.ReportUploadRow();
        row.rowNumber = 2;
        row.emailAddress = prehireSubject.Email;

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReports(
            JSON.serialize(new List<ReportUploadController.ReportUploadRow>{ row })
        );
        Test.stopTest();

        System.assertEquals(1, result.successRows);
        System.assertEquals(0, result.exceptionRows);
        System.assertEquals(1, result.casesCreated);

        Consent__c consumedConsent = [
            SELECT Consent_Status__c, Report_Use_Count__c
            FROM Consent__c
            WHERE Id = :latestConsent.Id
            LIMIT 1
        ];
        System.assertEquals('Expired', consumedConsent.Consent_Status__c);
        System.assertEquals(1, consumedConsent.Report_Use_Count__c);

        Report_Request_Item__c updatedItem = [
            SELECT Delivery_Status__c, Successful_Retrieval_Count__c, Expiry_Triggered__c
            FROM Report_Request_Item__c
            WHERE Data_Subject__c = :prehireSubject.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Completed', updatedItem.Delivery_Status__c);
        System.assertEquals(1, updatedItem.Successful_Retrieval_Count__c);
        System.assertEquals(true, updatedItem.Expiry_Triggered__c);
    }

    @IsTest
    static void testUploadReports_blocksWhenNoActiveConsent() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable()
        ) {
            return;
        }

        ReportUploadController.ReportUploadRow row = new ReportUploadController.ReportUploadRow();
        row.rowNumber = 2;
        row.emailAddress = 'no.consent@test.com';

        Account accountRecord = [SELECT Id FROM Account WHERE Name = 'Report Upload Test Account' LIMIT 1];
        insert buildContact(
            accountRecord.Id,
            'no.consent@test.com',
            'F' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReports(
            JSON.serialize(new List<ReportUploadController.ReportUploadRow>{ row })
        );
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assertEquals(1, result.exceptionRows);
        System.assertEquals(0, result.casesCreated);
        System.assert(result.errors[0].message.contains(ReportUploadController.EXC_MSG_NO_ACTIVE_CONSENT));
        Integer reportsCount = [SELECT COUNT() FROM Reports__c WHERE Email__c = 'no.consent@test.com'];
        System.assertEquals(0, reportsCount);
    }

    @IsTest
    static void testUploadReports_blocksDeclinedWithdrawnExpiredAndNoAction() {
        if (
            !Schema.sObjectType.Reports__c.isCreateable() ||
            !Schema.sObjectType.Exception__c.isCreateable() ||
            !Schema.sObjectType.Batch__c.isCreateable() ||
            !Schema.sObjectType.Consent__c.isCreateable()
        ) {
            return;
        }

        Id accountId = [SELECT Id FROM Account WHERE Name = 'Report Upload Test Account' LIMIT 1].Id;
        Contact declinedContact = buildContact(
            accountId,
            'status.declined@test.com',
            'D' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        Contact withdrawnContact = buildContact(
            accountId,
            'status.withdrawn@test.com',
            'W' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        Contact expiredContact = buildContact(
            accountId,
            'status.expired@test.com',
            'E' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        Contact noActionContact = buildContact(
            accountId,
            'status.noaction@test.com',
            'N' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        insert new List<Contact>{ declinedContact, withdrawnContact, expiredContact, noActionContact };

        insert new List<Consent__c>{
            new Consent__c(
                Data_Subject__c = declinedContact.Id,
                Consent_Status__c = 'Declined',
                Consent_Expiry_Date__c = Date.today().addDays(30)
            ),
            new Consent__c(
                Data_Subject__c = withdrawnContact.Id,
                Consent_Status__c = 'Withdrawn',
                Consent_Expiry_Date__c = Date.today().addDays(30)
            ),
            new Consent__c(
                Data_Subject__c = expiredContact.Id,
                Consent_Status__c = 'Expired',
                Consent_Expiry_Date__c = Date.today().addDays(-1)
            ),
            new Consent__c(
                Data_Subject__c = noActionContact.Id,
                Consent_Status__c = 'No Action',
                Consent_Expiry_Date__c = Date.today().addDays(30)
            )
        };

        List<ReportUploadController.ReportUploadRow> rows = new List<ReportUploadController.ReportUploadRow>();
        rows.add(new ReportUploadController.ReportUploadRow());
        rows[0].rowNumber = 2;
        rows[0].emailAddress = 'status.declined@test.com';
        rows.add(new ReportUploadController.ReportUploadRow());
        rows[1].rowNumber = 3;
        rows[1].emailAddress = 'status.withdrawn@test.com';
        rows.add(new ReportUploadController.ReportUploadRow());
        rows[2].rowNumber = 4;
        rows[2].emailAddress = 'status.expired@test.com';
        rows.add(new ReportUploadController.ReportUploadRow());
        rows[3].rowNumber = 5;
        rows[3].emailAddress = 'status.noaction@test.com';

        Test.startTest();
        ReportUploadController.UploadResult result = ReportUploadController.uploadReports(JSON.serialize(rows));
        Test.stopTest();

        System.assertEquals(0, result.successRows);
        System.assertEquals(4, result.exceptionRows);
        System.assertEquals(0, result.casesCreated);
        System.assertEquals(4, result.createdExceptions);
        for (ReportUploadController.RowError errorItem : result.errors) {
            System.assert(
                errorItem.message != null && errorItem.message.contains(ReportUploadController.EXC_MSG_NO_ACTIVE_CONSENT),
                'Expected blocked consent error, got: ' + errorItem.message
            );
        }
        Integer createdReports = [
            SELECT COUNT()
            FROM Reports__c
            WHERE Email__c IN (
                'status.declined@test.com',
                'status.withdrawn@test.com',
                'status.expired@test.com',
                'status.noaction@test.com'
            )
        ];
        System.assertEquals(0, createdReports);
    }
}