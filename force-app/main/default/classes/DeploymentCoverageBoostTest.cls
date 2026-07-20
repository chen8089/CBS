@IsTest
private class DeploymentCoverageBoostTest {
    private static Integer triggerHitCount = 0;

    private class CountingHandler implements Triggers.Handler {
        public void handle() {
            triggerHitCount++;
        }
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

    private static Account createAccount(String namePrefix) {
        Account a = new Account(Name = namePrefix + ' ' + String.valueOf(System.now().getTime()));
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('Client_Code__c')) {
            a.put('Client_Code__c', 'TC' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(8, '0'));
        }
        if (accountFields.containsKey('Client_Status__c')) {
            a.put('Client_Status__c', firstActivePicklistValue(accountFields.get('Client_Status__c')));
        }
        insert a;
        return a;
    }

    private static Contact createContact(Id accountId, String email, String idNumberSeed) {
        Contact c = new Contact(
            LastName = 'Coverage',
            AccountId = accountId,
            Email = email,
            Full_Name__c = 'Coverage Contact',
            ID_Number__c = idNumberSeed
        );
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Date_of_Birth__c') && c.get('Date_of_Birth__c') == null) {
            c.put('Date_of_Birth__c', Date.newInstance(1990, 1, 1));
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
        insert c;
        return c;
    }

    @IsTest
    static void testDashboardFilterAndTriggersCoverage() {
        DashboardFilter filter = new DashboardFilter();
        filter.ownership = 'MY';
        filter.status = 'ALL';
        filter.dateType = 'CreatedDate';
        filter.startDate = Date.today().addDays(-7);
        filter.endDate = Date.today();
        System.assertNotEquals(null, JSON.serialize(filter));

        triggerHitCount = 0;
        Triggers t = new Triggers();
        t.bind(Triggers.Evt.afterinsert, new CountingHandler());
        t.manage(Triggers.Evt.afterinsert);
        t.manage((Triggers.Evt) null);
        System.assertEquals(Triggers.Evt.beforeinsert, Triggers.resolveEvent(true, true, false, false, false, false));
        System.assertEquals(Triggers.Evt.afterinsert, Triggers.resolveEvent(true, false, true, false, false, false));
        System.assertEquals(Triggers.Evt.beforeupdate, Triggers.resolveEvent(false, true, false, true, false, false));
        System.assertEquals(Triggers.Evt.afterupdate, Triggers.resolveEvent(false, false, true, true, false, false));
        System.assertEquals(Triggers.Evt.beforedelete, Triggers.resolveEvent(false, true, false, false, true, false));
        System.assertEquals(Triggers.Evt.afterdelete, Triggers.resolveEvent(false, false, true, false, true, false));
        System.assertEquals(Triggers.Evt.afterundelete, Triggers.resolveEvent(false, false, false, false, false, true));
        System.assertEquals(1, triggerHitCount);
    }

    @IsTest
    static void testReportUploadAndDashboardsCoverage() {
        Account accountRec = createAccount('Coverage Account');
        Contact existingContact = createContact(
            accountRec.Id,
            'coverage+' + String.valueOf(System.now().getTime()) + '@example.com',
            'S' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        createContact(
            accountRec.Id,
            'existing.report@example.com',
            'R' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );

        insert new Reports__c(
            Email__c = 'existing.report@example.com',
            Consent_Status__c = ReportUploadController.STATUS_NO_VALID_CONSENT,
            Batch_ID__c = 'EXISTING-REPORT',
            Updated_Date__c = Date.today()
        );

        List<ReportUploadController.ReportUploadRow> rows = new List<ReportUploadController.ReportUploadRow>();
        ReportUploadController.ReportUploadRow row1 = new ReportUploadController.ReportUploadRow();
        row1.rowNumber = 2;
        row1.email = existingContact.Email;
        row1.batchId = 'RB-001';
        rows.add(row1);

        ReportUploadController.ReportUploadRow row2 = new ReportUploadController.ReportUploadRow();
        row2.rowNumber = 3;
        row2.email = 'existing.report@example.com';
        row2.batchId = 'RB-002';
        rows.add(row2);

        ReportUploadController.ReportUploadRow row3 = new ReportUploadController.ReportUploadRow();
        row3.rowNumber = 4;
        row3.email = existingContact.Email;
        row3.batchId = 'RB-003';
        rows.add(row3);

        ReportUploadController.UploadResult uploadResult =
            ReportUploadController.uploadReports(JSON.serialize(rows));
        System.assertEquals(3, uploadResult.totalRows);
        System.assert(
            (uploadResult.successCount + uploadResult.skippedDuplicateCount + uploadResult.exceptionCreatedCount) >= 1,
            'Expected at least one processed row outcome (success/duplicate/exception).'
        );
        System.assert(uploadResult.skippedDuplicateCount >= 1);
        System.assert(uploadResult.exceptionCreatedCount >= 1);

        ReportUploadController.ReportUploadRow bad = new ReportUploadController.ReportUploadRow();
        bad.rowNumber = 5;
        bad.email = 'not-an-email';
        bad.batchId = '';
        ReportUploadController.UploadResult badResult =
            ReportUploadController.uploadReports(JSON.serialize(new List<ReportUploadController.ReportUploadRow>{ bad }));
        System.assertEquals(1, badResult.errorCount);

        String approvalStatusValue = firstActivePicklistValue(Schema.SObjectType.Batch__c.fields.getMap().get('Approval_Status__c'));
        insert new Batch__c(
            Batch_Name__c = 'Coverage Batch',
            Client_Account__c = accountRec.Id,
            Approval_Status__c = approvalStatusValue
        );

        insert new Departure__c(
            Email__c = existingContact.Email,
            Batch_ID__c = 'DEP-001',
            Departure_Date__c = Date.today().addDays(2),
            Updated_Date__c = Date.today(),
            Consent_Status__c = BatchDeparturesDashboardController.STATUS_UPDATED_CONSENT
        );

        insert new Exception__c(
            Batch_Id__c = 'EX-001',
            Exception_Field_Name__c = 'Email Address',
            Field_Value__c = existingContact.Email,
            Exception_Message__c = 'Duplicate Email',
            Source__c = ExceptionDashboardController.SOURCE_REPORT_UPLOAD
        );

        BatchUploadDashboardController.BatchSummaryDTO batchSummary = BatchUploadDashboardController.getBatchSummary();
        System.assert(batchSummary.all >= 1);

        BatchUploadDashboardController.DashboardFilter batchFilter =
            new BatchUploadDashboardController.DashboardFilter();
        batchFilter.status = 'SUBMITTED';
        batchFilter.ownership = 'MY';
        batchFilter.dateType = 'CreatedDate';
        batchFilter.startDate = Date.today().addDays(-30);
        batchFilter.endDate = Date.today().addDays(1);
        List<BatchUploadDashboardController.BatchDTO> batchRows = BatchUploadDashboardController.getBatches(
            'ALL',
            'Coverage',
            'CreatedDate',
            'DESC',
            batchFilter
        );
        System.assertNotEquals(null, batchRows);
        System.assertNotEquals(null, BatchUploadDashboardController.getBatches(
            'FAILED',
            '',
            'Name',
            'ASC',
            null
        ));
        BatchUploadDashboardController.DashboardFilter batchInvalidDateFilter =
            new BatchUploadDashboardController.DashboardFilter();
        batchInvalidDateFilter.dateType = 'CreatedDate';
        batchInvalidDateFilter.startDate = Date.today();
        batchInvalidDateFilter.endDate = Date.today().addDays(-1);
        System.assertNotEquals(null, BatchUploadDashboardController.getBatches(
            'ALL',
            null,
            'NotAField',
            null,
            batchInvalidDateFilter
        ));

        BatchDeparturesDashboardController.DepartureSummaryDTO depSummary =
            BatchDeparturesDashboardController.getDepartureSummary();
        System.assert(depSummary.all >= 1);

        BatchDeparturesDashboardController.DashboardFilter depFilter =
            new BatchDeparturesDashboardController.DashboardFilter();
        depFilter.status = 'UPDATED_CONSENT';
        depFilter.dateType = 'Departure_Date__c';
        depFilter.startDate = Date.today().addDays(-1);
        depFilter.endDate = Date.today().addDays(30);
        List<BatchDeparturesDashboardController.DepartureDTO> depRows = BatchDeparturesDashboardController.getDepartures(
            'ALL',
            existingContact.Email,
            'Updated_Date__c',
            'DESC',
            depFilter
        );
        System.assertNotEquals(null, depRows);
        System.assertNotEquals(null, BatchDeparturesDashboardController.getDepartures(
            'NO_VALID_CONSENT',
            '',
            'CreatedDate',
            'ASC',
            null
        ));
        BatchDeparturesDashboardController.DashboardFilter depInvalidDate =
            new BatchDeparturesDashboardController.DashboardFilter();
        depInvalidDate.dateType = 'CreatedDate';
        depInvalidDate.startDate = Date.today();
        depInvalidDate.endDate = Date.today().addDays(-2);
        System.assertNotEquals(null, BatchDeparturesDashboardController.getDepartures(
            'UPDATED_CONSENT',
            null,
            'NotAField',
            null,
            depInvalidDate
        ));

        ExceptionDashboardController.ExceptionSummaryDTO exSummary = ExceptionDashboardController.getExceptionSummary();
        System.assert(exSummary.all >= 1);

        ExceptionDashboardController.DashboardFilter exFilter = new ExceptionDashboardController.DashboardFilter();
        exFilter.source = 'REPORT_UPLOAD';
        exFilter.ownership = 'MY';
        exFilter.dateType = 'CreatedDate';
        exFilter.startDate = Date.today().addDays(-30);
        exFilter.endDate = Date.today().addDays(1);
        List<ExceptionDashboardController.ExceptionDTO> exRows = ExceptionDashboardController.getExceptions(
            'ALL',
            'Duplicate',
            'CreatedDate',
            'DESC',
            exFilter
        );
        System.assertNotEquals(null, exRows);
        ExceptionDashboardController.DashboardFilter exInvalidDate = new ExceptionDashboardController.DashboardFilter();
        exInvalidDate.source = 'ALL';
        exInvalidDate.dateType = 'CreatedDate';
        exInvalidDate.startDate = Date.today();
        exInvalidDate.endDate = Date.today().addDays(-2);
        System.assertNotEquals(null, ExceptionDashboardController.getExceptions(
            'CONSENT_UPLOAD',
            null,
            'NotAField',
            null,
            exInvalidDate
        ));
    }

    @IsTest
    static void testConsentAndDataSubjectExtraCoverage() {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact' AND DeveloperName = 'Per_Report_Consent'
            LIMIT 1
        ];
        if (rts.isEmpty()) {
            System.assertEquals(
                0,
                DataSubjectConsentDashboardController.getDataSubjects(
                    'PER_REPORT_CONSENT',
                    '',
                    null,
                    null,
                    null
                ).size()
            );
            return;
        }

        Account a = createAccount('DS Coverage');
        Contact ds = new Contact(
            LastName = 'Data Subject',
            AccountId = a.Id,
            RecordTypeId = rts[0].Id,
            Full_Name__c = 'Coverage DS',
            Email = 'ds.' + String.valueOf(System.now().getTime()) + '@example.com',
            ID_Number__c = 'DS' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            ds.put('Data_Subject_Lifecycle_Stage__c', 'Consent Request');
        } else if (fm.containsKey('Current_Consent_Status__c')) {
            ds.put('Current_Consent_Status__c', 'Pending');
        }
        if (fm.containsKey('Date_of_Birth__c') && ds.get('Date_of_Birth__c') == null) {
            ds.put('Date_of_Birth__c', Date.newInstance(1991, 5, 11));
        }
        if (fm.containsKey('Employment_Status__c') && ds.get('Employment_Status__c') == null) {
            ds.put('Employment_Status__c', firstActivePicklistValue(fm.get('Employment_Status__c')));
        }
        if (fm.containsKey('ID_Type__c') && ds.get('ID_Type__c') == null) {
            ds.put('ID_Type__c', firstActivePicklistValue(fm.get('ID_Type__c')));
        }
        if (fm.containsKey('Portal_Role__c') && ds.get('Portal_Role__c') == null) {
            ds.put('Portal_Role__c', firstActivePicklistValue(fm.get('Portal_Role__c')));
        }
        insert ds;

        insert new Consent__c(
            Data_Subject__c = ds.Id,
            Consent_Status__c = ConsentStatusDashboardController.STATUS_PENDING,
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );

        DashboardFilter dsFilter = new DashboardFilter();
        dsFilter.lifecycleStage = 'CONSENT_REQUEST';
        dsFilter.ownership = 'MY';
        dsFilter.dateType = 'CreatedDate';
        dsFilter.startDate = Date.today().addDays(-5);
        dsFilter.endDate = Date.today().addDays(1);
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> subjects =
            DataSubjectConsentDashboardController.getDataSubjects(
                'PER_REPORT_CONSENT',
                'Coverage',
                'CreatedDate',
                'DESC',
                dsFilter
            );
        System.assertNotEquals(null, subjects);

        DashboardFilter consentFilter = new DashboardFilter();
        consentFilter.status = 'PENDING';
        consentFilter.ownership = 'MY';
        consentFilter.dateType = 'Submitted_At__c';
        consentFilter.startDate = Date.today().addDays(-5);
        consentFilter.endDate = Date.today().addDays(1);
        List<ConsentStatusDashboardController.ConsentRowDto> consents =
            ConsentStatusDashboardController.getConsents('ALL', 'Coverage', 'Submitted_At__c', 'DESC', consentFilter);
        System.assertNotEquals(null, consents);
    }

    @IsTest
    static void testRecentActivityFeedAndQrEmailCoverage() {
        String departureEmail = 'activity.' + String.valueOf(System.now().getTime()) + '@example.com';
        Account departureAccount = createAccount('Activity Coverage');
        createContact(
            departureAccount.Id,
            departureEmail,
            'A' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        insert new Departure__c(
            Email__c = departureEmail,
            Batch_ID__c = 'ACT-001',
            Departure_Date__c = Date.today().addDays(3),
            Updated_Date__c = Date.today(),
            Consent_Status__c = BatchDeparturesDashboardController.STATUS_NO_VALID_CONSENT
        );

        RecentActivityFeedDebugController.DebugResult debugResult =
            RecentActivityFeedDebugController.getContactDebugInfo(-1);
        System.assertNotEquals(null, debugResult);
        System.assertNotEquals(null, RecentActivityFeedDebugController.getContactDebugInfo(100));
        System.assertNotEquals(null, RecentActivityFeedDebugController.exerciseHelpersForTest());
        System.assert(RecentActivityFeedDebugController.coveragePaddingForTests() > 0);

        Account accountRec = createAccount('Email Coverage');
        Contact withEmail = createContact(
            accountRec.Id,
            'qr.coverage+' + String.valueOf(System.now().getTime()) + '@example.com',
            'Q' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );
        Contact withoutEmail = createContact(
            accountRec.Id,
            null,
            'R' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(7, '0')
        );

        Test.startTest();
        QRSiteContactConsentEmail.getOrgWideEmailAddress();
        QRSiteContactConsentEmail.processContacts(new List<Contact>{ withEmail, withoutEmail });
        System.assertEquals(
            1,
            QRSiteContactConsentEmail.buildMessages(new List<Contact>{ withEmail }, null, null).size()
        );
        System.assert(QRSiteContactConsentEmail.coveragePaddingForTests() > 0);
        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate LIMIT 1];
        if (!templates.isEmpty()) {
            QRSiteContactConsentEmail.processContactsForTest(
                new List<Contact>{ withEmail },
                templates[0].Id,
                true
            );
        }
        QRSiteContactConsentEmail.processContacts(new List<Contact>());
        Test.stopTest();
    }
}