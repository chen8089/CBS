@IsTest
public class ReportRequestTestSupport {
    public class SeedData {
        public Account clientAccount;
        public Contact requester;
        public List<Contact> dataSubjects;
    }

    public static SeedData createSeedData(Integer subjectCount) {
        Integer normalizedCount = subjectCount == null || subjectCount <= 0 ? 1 : subjectCount;

        Account clientAccount = new Account(Name = 'CBS RR Account ' + String.valueOf(System.now().getTime()));
        insert clientAccount;

        Contact requester = new Contact(
            LastName = 'HR Requester',
            AccountId = clientAccount.Id,
            Email = 'hr.requester+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
            Full_Name__c = 'HR Requester',
            ID_Type__c = 'NRIC',
            ID_Number__c = buildNricSuffix(),
            Employment_Status__c = 'Existing Employee',
            Portal_Role__c = 'Approver'
        );
        insert requester;

        List<Contact> dataSubjects = new List<Contact>();
        for (Integer i = 0; i < normalizedCount; i++) {
            Contact subject = new Contact(
                LastName = 'Data Subject ' + i,
                AccountId = clientAccount.Id,
                Email = 'subject' + i + '+' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '@example.com',
                Full_Name__c = 'Data Subject ' + i,
                ID_Type__c = 'NRIC',
                ID_Number__c = buildNricSuffix(),
                Employment_Status__c = 'Existing Employee',
                Portal_Role__c = 'Subject'
            );
            dataSubjects.add(subject);
        }
        insert dataSubjects;

        SeedData seedData = new SeedData();
        seedData.clientAccount = clientAccount;
        seedData.requester = requester;
        seedData.dataSubjects = dataSubjects;
        return seedData;
    }

    public static void createActiveConsents(List<Contact> dataSubjects) {
        List<Consent__c> consents = new List<Consent__c>();
        for (Contact dataSubject : dataSubjects) {
            consents.add(new Consent__c(
                Data_Subject__c = dataSubject.Id,
                Consent_Status__c = 'Active',
                Consent_Expiry_Date__c = Date.today().addDays(30)
            ));
        }
        insert consents;

        if (dataSubjects == null || dataSubjects.isEmpty()) {
            return;
        }
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        List<Contact> subjectUpdates = new List<Contact>();
        for (Contact dataSubject : dataSubjects) {
            Contact updateRow = new Contact(Id = dataSubject.Id);
            ConsentStatusModelService.applyContactState(updateRow, ConsentStatusModelService.STATUS_ACTIVE);
            if (contactFields.containsKey('Report_Eligibility_Status__c')) {
                // Keep test records unblocked unless a test explicitly sets a blocked value.
                updateRow.put('Report_Eligibility_Status__c', null);
            }
            subjectUpdates.add(updateRow);
        }
        update subjectUpdates;
    }

    public static void createBlockedConsent(Contact dataSubject) {
        insert new Consent__c(
            Data_Subject__c = dataSubject.Id,
            Consent_Status__c = 'Declined',
            Consent_Expiry_Date__c = Date.today().addDays(30)
        );

        Contact blockedUpdate = new Contact(Id = dataSubject.Id);
        ConsentStatusModelService.applyContactState(blockedUpdate, ConsentStatusModelService.STATUS_DECLINED);
        update blockedUpdate;
    }

    public static ReportRequestSubmissionService.SubmissionRequest buildSubmissionRequest(
        Account clientAccount,
        Contact requester,
        List<Contact> dataSubjects
    ) {
        ReportRequestSubmissionService.SubmissionRequest request = new ReportRequestSubmissionService.SubmissionRequest();
        request.clientAccountId = clientAccount.Id;
        request.requestedByContactId = requester.Id;
        request.subject = 'Customer Report Request';
        request.origin = 'Portal';
        request.slaDays = 7;
        request.dataSubjectIds = new List<Id>();
        for (Contact dataSubject : dataSubjects) {
            request.dataSubjectIds.add(dataSubject.Id);
        }
        return request;
    }

    private static String buildNricSuffix() {
        String randomDigits = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        randomDigits = randomDigits.length() > 7 ? randomDigits.right(7) : randomDigits.leftPad(7, '0');
        return 'S' + randomDigits;
    }
}