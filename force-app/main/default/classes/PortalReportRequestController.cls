public without sharing class PortalReportRequestController {
    private static final Set<String> ALLOWED_CONSENT_STATUSES = new Set<String>{ 'Consent Valid', 'Active' };
    @TestVisible private static Id overrideContactIdForTests;
    @TestVisible private static Id overrideAccountIdForTests;

    public class DataSubjectOption {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String label;
        @AuraEnabled public String email;
        @AuraEnabled public String consentStatus;
    }

    public class CreateRequestResult {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Integer itemCount;
    }

    private class UserContext {
        public Id contactId;
        public Id accountId;
    }

    @AuraEnabled(cacheable=true)
    public static List<DataSubjectOption> getEligibleDataSubjects(String searchKey) {
        UserContext context = resolveUserContext();
        if (context == null) {
            return new List<DataSubjectOption>();
        }

        List<Consent__c> consentRows = queryLatestConsentCandidates();
        Map<Id, Consent__c> latestBySubject = new Map<Id, Consent__c>();
        for (Consent__c consentRow : consentRows) {
            if (consentRow.Data_Subject__c != null && !latestBySubject.containsKey(consentRow.Data_Subject__c)) {
                latestBySubject.put(consentRow.Data_Subject__c, consentRow);
            }
        }

        Map<Id, Contact> eligibleContactsById = queryEligibleContacts(
            latestBySubject.keySet(),
            context.accountId,
            searchKey
        );

        List<DataSubjectOption> options = new List<DataSubjectOption>();
        for (Id contactId : eligibleContactsById.keySet()) {
            Consent__c latestConsent = latestBySubject.get(contactId);
            if (!isEligibleConsent(latestConsent)) {
                continue;
            }
            Contact subjectContact = eligibleContactsById.get(contactId);
            DataSubjectOption option = new DataSubjectOption();
            option.contactId = contactId;
            option.label = String.isBlank(subjectContact.Name) ? String.valueOf(contactId) : subjectContact.Name;
            option.email = subjectContact.Email;
            option.consentStatus = latestConsent.Consent_Status__c;
            options.add(option);
        }
        options.sort(new DataSubjectOptionComparator());
        return options;
    }

    @AuraEnabled
    public static CreateRequestResult createReportRequestCase(String requestSubject, List<Id> dataSubjectIds, Integer slaDays) {
        if (dataSubjectIds == null || dataSubjectIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one authorized Data Subject.');
        }

        UserContext context = resolveUserContext();
        if (context == null) {
            throw new AuraHandledException('Current user is not linked to a Contact/Account.');
        }

        Set<Id> uniqueSubjectIds = new Set<Id>(dataSubjectIds);
        List<ReportRequestConsentValidator.ValidationResult> validationResults =
            ReportRequestConsentValidator.validateForSubmission(new List<Id>(uniqueSubjectIds), context.accountId);
        List<String> invalidMessages = new List<String>();
        for (ReportRequestConsentValidator.ValidationResult validationResult : validationResults) {
            if (validationResult == null || validationResult.isEligible) {
                continue;
            }
            invalidMessages.add(
                String.valueOf(validationResult.dataSubjectId) + ':' + String.valueOf(validationResult.reasonCode)
            );
        }
        if (!invalidMessages.isEmpty()) {
            throw new AuraHandledException(
                'Selected Data Subject includes invalid consent. ' + String.join(invalidMessages, '; ')
            );
        }

        ReportRequestSubmissionService.SubmissionRequest request = new ReportRequestSubmissionService.SubmissionRequest();
        request.clientAccountId = context.accountId;
        request.requestedByContactId = context.contactId;
        request.subject = String.isBlank(requestSubject) ? 'Portal Report Request' : requestSubject.trim();
        request.origin = 'Portal';
        request.slaDays = slaDays == null || slaDays <= 0 ? 5 : slaDays;
        request.dataSubjectIds = new List<Id>(uniqueSubjectIds);

        ReportRequestSubmissionService.SubmissionResult submissionResult = ReportRequestSubmissionService.submit(request);
        if (submissionResult == null || !submissionResult.isSuccess || submissionResult.caseId == null) {
            String errorText = 'Report request submit failed.';
            if (submissionResult != null && submissionResult.errors != null && !submissionResult.errors.isEmpty()) {
                errorText = String.join(submissionResult.errors, '; ');
            }
            throw new AuraHandledException(errorText);
        }

        Case createdCase = [
            SELECT Id, CaseNumber
            FROM Case
            WHERE Id = :submissionResult.caseId
            LIMIT 1
        ];

        CreateRequestResult result = new CreateRequestResult();
        result.caseId = createdCase.Id;
        result.caseNumber = createdCase.CaseNumber;
        result.itemCount = submissionResult.itemIds == null ? 0 : submissionResult.itemIds.size();
        return result;
    }

    private static List<Consent__c> queryLatestConsentCandidates() {
        // Use SYSTEM_MODE for portal runtime consistency.
        return Database.queryWithBinds(
            'SELECT Id, Data_Subject__c, Consent_Status__c, Consent_Expiry_Date__c, CreatedDate ' +
            'FROM Consent__c WHERE Data_Subject__c != null ORDER BY CreatedDate DESC LIMIT 2000',
            new Map<String, Object>(),
            AccessLevel.SYSTEM_MODE
        );
    }

    private static Map<Id, Contact> queryEligibleContacts(Set<Id> contactIds, Id accountId, String searchKey) {
        Map<Id, Contact> result = new Map<Id, Contact>();
        if (contactIds == null || contactIds.isEmpty() || accountId == null) {
            return result;
        }

        String normalizedSearch = String.isBlank(searchKey) ? null : '%' + searchKey.trim() + '%';
        Map<String, Object> binds = new Map<String, Object>{
            'contactIds' => contactIds,
            'accountId' => accountId
        };
        String soql =
            'SELECT Id, Name, Email, AccountId ' +
            'FROM Contact WHERE Id IN :contactIds AND AccountId = :accountId';
        if (normalizedSearch != null) {
            binds.put('searchKey', normalizedSearch);
            soql += ' AND (Name LIKE :searchKey OR Email LIKE :searchKey)';
        }
        soql += ' ORDER BY Name ASC LIMIT 500';

        for (Contact subjectContact : (List<Contact>) Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE)) {
            result.put(subjectContact.Id, subjectContact);
        }
        return result;
    }

    private static List<Id> findIneligibleSubjects(Id accountId, Set<Id> selectedSubjectIds) {
        List<Id> invalidIds = new List<Id>();
        if (selectedSubjectIds.isEmpty()) {
            return invalidIds;
        }

        List<Consent__c> candidateRows = [
            SELECT Id, Data_Subject__c, Data_Subject__r.AccountId, Consent_Status__c, Consent_Expiry_Date__c,
                CreatedDate
            FROM Consent__c
            WHERE Data_Subject__c IN :selectedSubjectIds
            ORDER BY Data_Subject__c ASC, CreatedDate DESC
        ];

        Map<Id, Consent__c> latestBySubject = new Map<Id, Consent__c>();
        for (Consent__c rowItem : candidateRows) {
            if (!latestBySubject.containsKey(rowItem.Data_Subject__c)) {
                latestBySubject.put(rowItem.Data_Subject__c, rowItem);
            }
        }

        for (Id subjectId : selectedSubjectIds) {
            Consent__c latest = latestBySubject.get(subjectId);
            if (!isEligibleConsent(latest)) {
                invalidIds.add(subjectId);
            }
        }
        return invalidIds;
    }

    private static Boolean isEligibleConsent(Consent__c consentRow) {
        if (consentRow == null) {
            return false;
        }
        if (!ALLOWED_CONSENT_STATUSES.contains(consentRow.Consent_Status__c)) {
            return false;
        }
        if (consentRow.Consent_Expiry_Date__c != null && consentRow.Consent_Expiry_Date__c < Date.today()) {
            return false;
        }
        return true;
    }

    private static UserContext resolveUserContext() {
        if (Test.isRunningTest() && overrideContactIdForTests != null && overrideAccountIdForTests != null) {
            UserContext testContext = new UserContext();
            testContext.contactId = overrideContactIdForTests;
            testContext.accountId = overrideAccountIdForTests;
            return testContext;
        }
        User runningUser = [
            SELECT Id, ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (runningUser.ContactId == null || runningUser.Contact.AccountId == null) {
            return null;
        }
        UserContext context = new UserContext();
        context.contactId = runningUser.ContactId;
        context.accountId = runningUser.Contact.AccountId;
        return context;
    }

    private class DataSubjectOptionComparator implements Comparator<DataSubjectOption> {
        public Integer compare(DataSubjectOption left, DataSubjectOption right) {
            String leftName = left == null || left.label == null ? '' : left.label.toLowerCase();
            String rightName = right == null || right.label == null ? '' : right.label.toLowerCase();
            if (leftName == rightName) {
                return 0;
            }
            return leftName < rightName ? -1 : 1;
        }
    }
}