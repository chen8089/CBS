public without sharing class ReportRequestSubmissionService {
    private static final String REPORT_REQUEST_RECORD_TYPE = 'CBS_Report_Request';
    private static final String PROCESSING_QUEUE_NAME = 'CBS_Processing_Queue';
    @TestVisible private static Boolean skipRunningUserContextValidationForTests = false;

    public class SubmissionRequest {
        @AuraEnabled public Id clientAccountId;
        @AuraEnabled public Id requestedByContactId;
        @AuraEnabled public String subject;
        @AuraEnabled public String origin;
        @AuraEnabled public Integer slaDays;
        @AuraEnabled public List<Id> dataSubjectIds;
    }

    public class SubmissionResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public Id caseId;
        @AuraEnabled public List<Id> itemIds;
        @AuraEnabled public List<String> errors;

        public SubmissionResult(Boolean isSuccess, String reasonCode) {
            this.isSuccess = isSuccess;
            this.reasonCode = reasonCode;
            this.itemIds = new List<Id>();
            this.errors = new List<String>();
        }
    }

    @AuraEnabled
    public static SubmissionResult submit(SubmissionRequest request) {
        if (request == null) {
            return new SubmissionResult(false, 'REQUEST_REQUIRED');
        }
        if (request.clientAccountId == null) {
            return new SubmissionResult(false, 'CLIENT_ACCOUNT_REQUIRED');
        }
        if (request.requestedByContactId == null) {
            return new SubmissionResult(false, 'REQUESTED_BY_CONTACT_REQUIRED');
        }
        if (request.dataSubjectIds == null || request.dataSubjectIds.isEmpty()) {
            return new SubmissionResult(false, 'DATA_SUBJECTS_REQUIRED');
        }

        SubmissionResult contextValidationResult = validateSubmissionContext(request);
        if (contextValidationResult != null) {
            return contextValidationResult;
        }

        Set<Id> uniqueSubjectIds = new Set<Id>(request.dataSubjectIds);
        List<ReportRequestConsentValidator.ValidationResult> validationResults =
            ReportRequestConsentValidator.validateForSubmission(new List<Id>(uniqueSubjectIds), request.clientAccountId);
        List<Id> eligibleSubjectIds = new List<Id>();
        SubmissionResult deniedResult = new SubmissionResult(false, 'CONSENT_VALIDATION_FAILED');
        for (ReportRequestConsentValidator.ValidationResult validationResult : validationResults) {
            if (!validationResult.isEligible) {
                deniedResult.errors.add(
                    'DataSubject=' + String.valueOf(validationResult.dataSubjectId) + ', reason=' + validationResult.reasonCode
                );
            } else {
                eligibleSubjectIds.add(validationResult.dataSubjectId);
            }
        }
        if (!deniedResult.errors.isEmpty()) {
            return deniedResult;
        }

        Integer normalizedSlaDays = request.slaDays == null || request.slaDays <= 0 ? 5 : request.slaDays;
        Date dueDate = Date.today().addDays(normalizedSlaDays);
        Date warningDate = dueDate.addDays(-1);

        Case reportRequestCase = new Case(
            AccountId = request.clientAccountId,
            ContactId = request.requestedByContactId,
            Status = 'New',
            Origin = String.isBlank(request.origin) ? 'Portal' : request.origin,
            Subject = String.isBlank(request.subject) ? 'Report Request Submission' : request.subject
        );
        Id recordTypeId = resolveRecordTypeId('Case', REPORT_REQUEST_RECORD_TYPE);
        if (recordTypeId != null) {
            reportRequestCase.RecordTypeId = recordTypeId;
        }
        Id queueOwnerId = resolveQueueOwnerId(PROCESSING_QUEUE_NAME);
        if (queueOwnerId != null) {
            reportRequestCase.OwnerId = queueOwnerId;
        }
        setFieldIfAvailable(reportRequestCase, 'Requested_Count__c', eligibleSubjectIds.size());
        setFieldIfAvailable(reportRequestCase, 'Exception_Type__c', 'File Validation');
        setFieldIfAvailable(reportRequestCase, 'SLA_Days__c', normalizedSlaDays);
        setFieldIfAvailable(reportRequestCase, 'Due_Date__c', dueDate);
        setFieldIfAvailable(reportRequestCase, 'Early_Warning_Date__c', warningDate);
        setFieldIfAvailable(reportRequestCase, 'CBS_Group_Mail_Notified__c', false);
        setFieldIfAvailable(reportRequestCase, 'Data_Subject_Notice_Sent__c', false);
        setFieldIfAvailable(reportRequestCase, 'Offline_Processing_Status__c', 'Pending');
        ReportRequestCaseCreationGuard.allowReportRequestCaseCreation = true;
        try {
            insert reportRequestCase;
        } finally {
            ReportRequestCaseCreationGuard.allowReportRequestCaseCreation = false;
        }

        List<Report_Request_Item__c> itemsToInsert = new List<Report_Request_Item__c>();
        for (Id subjectId : eligibleSubjectIds) {
            Report_Request_Item__c itemRecord = new Report_Request_Item__c(
                Data_Subject__c = subjectId,
                Report_Request_Case__c = reportRequestCase.Id
            );
            setFieldIfAvailable(itemRecord, 'Selected_By__c', UserInfo.getUserId());
            setFieldIfAvailable(itemRecord, 'Selected_At__c', System.now());
            setFieldIfAvailable(itemRecord, 'Consent_Revalidation_Status__c', 'Passed');
            setFieldIfAvailable(itemRecord, 'Eligibility_Status__c', 'Eligible');
            setFieldIfAvailable(itemRecord, 'SLA_Due_Date__c', dueDate);
            setFieldIfAvailable(itemRecord, 'Delivery_Status__c', 'Pending');
            setFieldIfAvailable(itemRecord, 'Notice_Sent_To_Data_Subject__c', false);
            itemsToInsert.add(itemRecord);
        }
        insert itemsToInsert;

        List<Id> createdItemIds = new List<Id>();
        for (Report_Request_Item__c insertedItem : itemsToInsert) {
            createdItemIds.add(insertedItem.Id);
        }

        ReportRequestNotificationService.markSubmitted(reportRequestCase.Id, createdItemIds);

        SubmissionResult successResult = new SubmissionResult(true, 'SUBMITTED');
        successResult.caseId = reportRequestCase.Id;
        successResult.itemIds.addAll(createdItemIds);
        return successResult;
    }

    private static SubmissionResult validateSubmissionContext(SubmissionRequest request) {
        List<Contact> requesterRows = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :request.requestedByContactId
            LIMIT 1
        ];
        if (requesterRows.isEmpty()) {
            return new SubmissionResult(false, 'REQUESTED_BY_CONTACT_NOT_FOUND');
        }
        if (requesterRows[0].AccountId != request.clientAccountId) {
            return new SubmissionResult(false, 'REQUESTER_ACCOUNT_MISMATCH');
        }

        List<User> runningUsers = [
            SELECT Id, ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (Test.isRunningTest() && skipRunningUserContextValidationForTests) {
            return null;
        }
        if (runningUsers.isEmpty() || runningUsers[0].ContactId == null) {
            return new SubmissionResult(false, 'RUNNING_USER_CONTACT_REQUIRED');
        }
        if (
            runningUsers[0].ContactId != request.requestedByContactId ||
            runningUsers[0].Contact.AccountId != request.clientAccountId
        ) {
            return new SubmissionResult(false, 'RUNNING_USER_CONTEXT_MISMATCH');
        }
        return null;
    }

    private static Id resolveRecordTypeId(String objectApiName, String recordTypeDeveloperName) {
        if (String.isBlank(objectApiName) || String.isBlank(recordTypeDeveloperName)) {
            return null;
        }
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :objectApiName
            AND DeveloperName = :recordTypeDeveloperName
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }

    private static Id resolveQueueOwnerId(String queueDeveloperName) {
        if (String.isBlank(queueDeveloperName)) {
            return UserInfo.getUserId();
        }
        List<Group> candidateQueues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = :queueDeveloperName
            LIMIT 1
        ];
        return candidateQueues.isEmpty() ? UserInfo.getUserId() : candidateQueues[0].Id;
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }
}