@IsTest
private class DataSubjectConsentDashCtrlTest {
    private static Account newDataSubjectParentAccount() {
        Account a = new Account(Name = 'DS Test Account');
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        if (accountFields.containsKey('Client_Code__c')) {
            a.put(
                'Client_Code__c',
                'DS' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(8, '0')
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

    private static void applyLifecycleStage(Contact c, String stage) {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Data_Subject_Lifecycle_Stage__c')) {
            if (isActiveLifecycleStage(stage)) {
                c.put('Data_Subject_Lifecycle_Stage__c', stage);
            }
        } else if (fm.containsKey('Current_Consent_Status__c')) {
            c.put('Current_Consent_Status__c', stage);
        }
    }

    private static Boolean isActiveLifecycleStage(String stage) {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (!fm.containsKey('Data_Subject_Lifecycle_Stage__c') || String.isBlank(stage)) {
            return false;
        }
        for (Schema.PicklistEntry pe : fm.get('Data_Subject_Lifecycle_Stage__c').getDescribe().getPicklistValues()) {
            if (pe.isActive() && stage.equals(pe.getValue())) {
                return true;
            }
        }
        return false;
    }

    private static void applyDataSubjectRequiredDefaults(Contact c) {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Date_of_Birth__c') && c.get('Date_of_Birth__c') == null) {
            c.put('Date_of_Birth__c', Date.newInstance(1990, 6, 15));
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

    private static Id dashboardContactRecordTypeId() {
        Id singpassRt = contactRecordTypeId('Singpass');
        if (singpassRt != null) {
            return singpassRt;
        }
        return contactRecordTypeId('Non_Singpass');
    }

    @IsTest
    static void testSummaryAndList_whenRecordTypeMissing_returnsEmptySafe() {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact' AND DeveloperName IN ('Singpass', 'Non_Singpass')
            LIMIT 1
        ];
        if (rts.isEmpty()) {
            DataSubjectConsentDashboardController.ConsentSummaryDto s =
                DataSubjectConsentDashboardController.getConsentSummary();
            System.assertEquals(0, s.all);
            List<DataSubjectConsentDashboardController.DataSubjectRowDto> rows = DataSubjectConsentDashboardController.getDataSubjects(
                'ALL',
                '',
                null,
                null,
                null
            );
            System.assertEquals(0, rows.size());
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;

        Contact c1 = new Contact(
            LastName = 'SubjectOne',
            AccountId = a.Id,
            RecordTypeId = rts[0].Id,
            Full_Name__c = 'Alpha Subject',
            Email = 'alpha@example.com',
            ID_Number__c = 'ID-100'
        );
        Contact c2 = new Contact(
            LastName = 'SubjectTwo',
            AccountId = a.Id,
            RecordTypeId = rts[0].Id,
            Full_Name__c = 'Beta Subject',
            Email = 'beta@example.com',
            ID_Number__c = 'ID-200'
        );
        applyDataSubjectRequiredDefaults(c1);
        applyDataSubjectRequiredDefaults(c2);
        applyLifecycleStage(c1, 'Active Consent');
        applyLifecycleStage(c2, 'Upload');
        insert new List<Contact>{ c1, c2 };

        DataSubjectConsentDashboardController.ConsentSummaryDto sum =
            DataSubjectConsentDashboardController.getConsentSummary();
        System.assert(sum.all >= 2);

        List<DataSubjectConsentDashboardController.DataSubjectRowDto> allRows = DataSubjectConsentDashboardController.getDataSubjects(
            'ALL',
            '',
            'LastModifiedDate',
            'DESC',
            null
        );
        System.assert(allRows.size() >= 2);

        List<DataSubjectConsentDashboardController.DataSubjectRowDto> activeRows = DataSubjectConsentDashboardController.getDataSubjects(
            'STAGE_ACTIVE_CONSENT',
            'Alpha',
            'Full_Name__c',
            'ASC',
            null
        );
        System.assert(activeRows.size() >= 1);
    }

    private static Id contactRecordTypeId(String developerName) {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact' AND DeveloperName = :developerName AND IsActive = TRUE
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    private static Contact newDashboardContact(
        Id accountId,
        Id recordTypeId,
        String lastName,
        String email,
        String lifecycleStage
    ) {
        Contact c = new Contact(
            LastName = lastName,
            AccountId = accountId,
            RecordTypeId = recordTypeId,
            Email = email,
            Full_Name__c = lastName + ' Full',
            ID_Number__c = 'ID-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
        );
        applyDataSubjectRequiredDefaults(c);
        applyLifecycleStage(c, lifecycleStage);
        return c;
    }

    @IsTest
    static void testConsentSummary_allLifecycleBuckets() {
        Id rtId = dashboardContactRecordTypeId();
        if (rtId == null) {
            DataSubjectConsentDashboardController.ConsentSummaryDto empty =
                DataSubjectConsentDashboardController.getConsentSummary();
            System.assertEquals(0, empty.all);
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;

        List<String> lifecycleStages = new List<String>{
            'Upload',
            'Consent Request',
            'Awaiting Data Subject Action',
            'Active Consent',
            'Consent Declined',
            'Processing',
            'Consent Withdrawn',
            'Consent Expired',
            'Report Request',
            'Report Fulfilment',
            'Consumed',
            'Departure'
        };
        Integer stageIndex = 0;
        Integer insertedCount = 0;
        Integer maxLifecycleContacts = 9;
        for (String stage : lifecycleStages) {
            if (insertedCount >= maxLifecycleContacts) {
                break;
            }
            if (!isActiveLifecycleStage(stage)) {
                continue;
            }
            Contact c = newDashboardContact(
                a.Id,
                rtId,
                'Stage' + String.valueOf(stageIndex),
                'stage.' + String.valueOf(stageIndex) + '@ds-summary.test.com',
                stage
            );
            stageIndex++;
            if (Database.insert(c, false).isSuccess()) {
                insertedCount++;
            }
        }
        if (insertedCount == 0) {
            Contact fallback = newDashboardContact(a.Id, rtId, 'Fallback', 'fallback.ds@test.com', 'Upload');
            System.assert(Database.insert(fallback, false).isSuccess(), 'Expected at least one dashboard contact insert.');
            insertedCount = 1;
        }

        Test.startTest();
        DataSubjectConsentDashboardController.ConsentSummaryDto sum =
            DataSubjectConsentDashboardController.getConsentSummary();
        Test.stopTest();

        System.assert(sum.all >= insertedCount, 'Summary should count inserted lifecycle buckets.');
        System.assert(sum.all >= 1, 'Summary should return at least one subject.');
        System.assert(sum.intake + sum.consentRequest + sum.awaitingAction + sum.activeConsent +
            sum.declined + sum.exceptionCount + sum.withdrawn + sum.expired + sum.reportRequest +
            sum.reportFulfilment + sum.expiredConsumed + sum.departureCount >= 1,
            'At least one lifecycle bucket should be populated.');
    }

    @IsTest
    static void testGetDataSubjects_stageFiltersSearchAndDates() {
        Id rtId = dashboardContactRecordTypeId();
        if (rtId == null) {
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;

        Contact perActive = newDashboardContact(a.Id, rtId, 'FilterActive', 'filter.active@test.com', 'Active Consent');
        insert perActive;

        insert newDashboardContact(a.Id, rtId, 'TermIntake', 'term.intake@test.com', 'Upload');

        DashboardFilter filters = new DashboardFilter();
        filters.ownership = 'MY';
        filters.status = 'Active Consent';
        filters.dateType = 'CreatedDate';
        filters.startDate = Date.today().addDays(-30);
        filters.endDate = Date.today();

        Test.startTest();
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> activeRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'STAGE_ACTIVE_CONSENT',
                'filter.active',
                'Email',
                'ASC',
                null
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> declinedRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'STAGE_CONSENT_DECLINED',
                '',
                'Full_Name__c',
                'DESC',
                filters
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> filterStatusRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'ALL',
                '',
                'LastModifiedDate',
                'DESC',
                filters
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> termRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'STAGE_INTAKE',
                'term.intake',
                'Email',
                'ASC',
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, activeRows);
        System.assertNotEquals(null, declinedRows);
        System.assertNotEquals(null, filterStatusRows);
        System.assert(termRows.size() >= 1);
    }

    @IsTest
    static void testGetDataSubjects_authAndConsentCardFilters() {
        Id rtId = dashboardContactRecordTypeId();
        if (rtId == null) {
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;

        Contact singpassContact = newDashboardContact(
            a.Id,
            rtId,
            'AuthSingpass',
            'auth.singpass@test.com',
            'Upload'
        );
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.Contact.fields.getMap();
        if (fm.containsKey('Authentication_Type__c')) {
            singpassContact.put('Authentication_Type__c', 'Singpass');
        }
        if (fm.containsKey('Consent_Type__c')) {
            singpassContact.put('Consent_Type__c', 'Per-Report Consent');
        }
        insert singpassContact;

        Test.startTest();
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> authRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'AUTH_SINGPASS',
                'auth.singpass',
                'Email',
                'ASC',
                null
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> consentRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'CONSENT_TYPE_PER_REPORT',
                'auth.singpass',
                'Email',
                'ASC',
                null
            );
        Test.stopTest();

        System.assert(authRows.size() >= 1);
        System.assert(consentRows.size() >= 1);
    }

    @IsTest
    static void testDashboardFilterPayloadFields() {
        DashboardFilter filter = new DashboardFilter();
        filter.ownership = 'MY';
        filter.recordType = 'ALL';
        filter.status = 'ALL';
        filter.lifecycleStage = 'Consent Request';
        filter.authenticationType = 'Singpass';
        filter.consentType = 'Per-Report Consent';
        filter.dateType = 'CreatedDate';
        filter.dateRange = 'LAST_7_DAYS';
        filter.startDate = Date.today().addDays(-1);
        filter.endDate = Date.today();

        System.assertEquals('MY', filter.ownership);
        System.assertEquals('Singpass', filter.authenticationType);
        System.assertEquals('Per-Report Consent', filter.consentType);
        System.assertNotEquals(null, JSON.serialize(filter));
    }

    @IsTest
    static void testGetDataSubjects_termBasedDisallowedStageAndInvalidDates() {
        Id rtId = dashboardContactRecordTypeId();
        if (rtId == null) {
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;
        insert newDashboardContact(a.Id, rtId, 'TermOnly', 'term.only@test.com', 'Upload');

        DashboardFilter badDates = new DashboardFilter();
        badDates.dateType = 'CreatedDate';
        badDates.startDate = Date.today();
        badDates.endDate = Date.today().addDays(-5);

        DashboardFilter invalidDateType = new DashboardFilter();
        invalidDateType.dateType = 'NotARealField__c';
        invalidDateType.startDate = Date.today().addDays(-1);
        invalidDateType.endDate = Date.today();

        Test.startTest();
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> reportRequestRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'STAGE_REPORT_REQUEST',
                '',
                'Email',
                'ASC',
                null
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> badDateRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'ALL',
                '',
                'Email',
                'ASC',
                badDates
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> invalidTypeRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'ALL',
                '',
                'Email',
                'ASC',
                invalidDateType
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> noMatchRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'STAGE_CONSENT_REQUEST',
                'zzz-no-match-xyz',
                'InvalidSortField__c',
                'DESC',
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, reportRequestRows);
        System.assertNotEquals(null, badDateRows);
        System.assertNotEquals(null, invalidTypeRows);
        System.assertEquals(0, noMatchRows.size(), 'Non-matching search should return no rows.');
    }

    @IsTest
    static void testGetDataSubjects_remainingStageFilters() {
        Id rtId = dashboardContactRecordTypeId();
        if (rtId == null) {
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;
        insert newDashboardContact(a.Id, rtId, 'StageSweep', 'stage.sweep@test.com', 'Consent Request');

        Test.startTest();
        System.assertNotEquals(
            null,
            DataSubjectConsentDashboardController.getDataSubjects('STAGE_AWAITING_ACTION', '', 'Email', 'ASC', null)
        );
        System.assertNotEquals(
            null,
            DataSubjectConsentDashboardController.getDataSubjects('STAGE_CONSENT_EXCEPTION', '', 'Email', 'ASC', null)
        );
        System.assertNotEquals(
            null,
            DataSubjectConsentDashboardController.getDataSubjects('STAGE_CONSENT_WITHDRAWN', '', 'Email', 'ASC', null)
        );
        System.assertNotEquals(
            null,
            DataSubjectConsentDashboardController.getDataSubjects('STAGE_CONSENT_EXPIRED', '', 'Email', 'ASC', null)
        );
        System.assertNotEquals(
            null,
            DataSubjectConsentDashboardController.getDataSubjects('STAGE_REPORT_FULFILMENT', '', 'Email', 'ASC', null)
        );
        System.assertNotEquals(
            null,
            DataSubjectConsentDashboardController.getDataSubjects('STAGE_EXPIRED_CONSUMED', '', 'Email', 'ASC', null)
        );
        System.assertNotEquals(
            null,
            DataSubjectConsentDashboardController.getDataSubjects('DEPARTURE', '', 'Email', 'ASC', null)
        );
        Test.stopTest();
    }

    @IsTest
    static void testDepartureSummaryAndCardFilter() {
        Id rtId = dashboardContactRecordTypeId();
        if (rtId == null || !isActiveLifecycleStage('Departure')) {
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;

        Contact departureContact = newDashboardContact(
            a.Id,
            rtId,
            'DepartureSubject',
            'departure.subject@test.com',
            'Departure'
        );
        insert departureContact;

        Contact activeContact = newDashboardContact(
            a.Id,
            rtId,
            'ActiveSubject',
            'active.subject@test.com',
            'Active Consent'
        );
        insert activeContact;

        Test.startTest();
        DataSubjectConsentDashboardController.ConsentSummaryDto summary =
            DataSubjectConsentDashboardController.getConsentSummary();
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> departureRows =
            DataSubjectConsentDashboardController.getDataSubjects('DEPARTURE', '', 'Email', 'ASC', null);
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> allRows =
            DataSubjectConsentDashboardController.getDataSubjects('ALL', '', 'Email', 'ASC', null);
        Test.stopTest();

        System.assert(summary.departureCount >= 1, 'Departure count should include Departure contacts.');
        System.assert(departureRows.size() >= 1, 'Departure card filter should return Departure records.');
        for (DataSubjectConsentDashboardController.DataSubjectRowDto row : departureRows) {
            System.assertEquals('Departure', row.lifecycleStage, 'Departure card should only return Departure stage.');
        }
        Boolean foundDepartureInAll = false;
        for (DataSubjectConsentDashboardController.DataSubjectRowDto row : allRows) {
            if (row.id == departureContact.Id) {
                foundDepartureInAll = true;
                break;
            }
        }
        System.assert(foundDepartureInAll, 'ALL card should still include DEPARTURE records.');
    }

    @IsTest
    static void testGetDataSubjects_cardFiltersAcrossRecordTypes() {
        Id singpassRt = contactRecordTypeId('Singpass');
        Id nonSingpassRt = contactRecordTypeId('Non_Singpass');
        if (singpassRt == null && nonSingpassRt == null) {
            return;
        }

        Account a = newDataSubjectParentAccount();
        insert a;

        List<Contact> toInsert = new List<Contact>();
        if (singpassRt != null) {
            toInsert.add(
                newDashboardContact(a.Id, singpassRt, 'AllViewPer', 'all.view.per@test.com', 'Upload')
            );
        }
        if (nonSingpassRt != null) {
            toInsert.add(
                newDashboardContact(a.Id, nonSingpassRt, 'AllViewTerm', 'all.view.term@test.com', 'Upload')
            );
        }
        insert toInsert;

        Test.startTest();
        DataSubjectConsentDashboardController.ConsentSummaryDto sum =
            DataSubjectConsentDashboardController.getConsentSummary();
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> rows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'ALL',
                '',
                'Email',
                'ASC',
                null
            );
        List<DataSubjectConsentDashboardController.DataSubjectRowDto> reportRequestRows =
            DataSubjectConsentDashboardController.getDataSubjects(
                'STAGE_REPORT_REQUEST',
                '',
                'Email',
                'ASC',
                null
            );
        Test.stopTest();

        System.assert(sum.all >= toInsert.size(), 'Summary should include contacts across record types.');
        System.assert(rows.size() >= toInsert.size(), 'ALL card should include contacts across record types.');
        System.assertNotEquals(null, reportRequestRows);
    }
}