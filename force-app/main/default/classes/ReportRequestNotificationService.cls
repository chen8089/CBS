public without sharing class ReportRequestNotificationService {
    @TestVisible
    private static Boolean skipEmailSendDuringTests = true;
    @TestVisible
    private static Integer lastEmailBatchSizeForTest = 0;
    private static final Set<String> ACTIVE_CONSENT_STATUSES = new Set<String>{ 'Active', 'Consent Valid' };
    private static final String CONSENT_STATUS_EXPIRED = 'Expired';
    private static final String EMPLOYMENT_STATUS_PREHIRE = 'pre-hire';
    private static final String LIFECYCLE_STAGE_CONSUMED = 'Consumed';
    private static final String REPORT_ELIGIBILITY_CONSUMED = 'Consent Consumed';

    public class CompletionRequest {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String deliveryChannel;
        @AuraEnabled public String deliveryEvidenceReference;
    }

    @AuraEnabled
    public static void markSubmitted(Id caseId, List<Id> reportRequestItemIds) {
        if (caseId == null) {
            return;
        }

        Case updateCase = new Case(Id = caseId);
        setFieldIfAvailable(updateCase, 'CBS_Group_Mail_Notified__c', true);
        setFieldIfAvailable(updateCase, 'Data_Subject_Notice_Sent__c', true);
        update updateCase;

        if (reportRequestItemIds == null || reportRequestItemIds.isEmpty()) {
            return;
        }
        List<Report_Request_Item__c> itemUpdates = new List<Report_Request_Item__c>();
        for (Id itemId : reportRequestItemIds) {
            Report_Request_Item__c itemUpdate = new Report_Request_Item__c(Id = itemId);
            setFieldIfAvailable(itemUpdate, 'Notice_Sent_To_Data_Subject__c', true);
            itemUpdates.add(itemUpdate);
        }
        if (!itemUpdates.isEmpty()) {
            update itemUpdates;
        }
    }

    @AuraEnabled
    public static void completeAndNotify(CompletionRequest request) {
        if (request == null || request.caseId == null) {
            throw new AuraHandledException('CASE_REQUIRED');
        }

        String normalizedChannel = String.isBlank(request.deliveryChannel) ? '' : request.deliveryChannel.trim().toLowerCase();
        if (
            (normalizedChannel == 'encrypted email' || normalizedChannel == 'sftp') &&
            String.isBlank(request.deliveryEvidenceReference)
        ) {
            throw new AuraHandledException('DELIVERY_EVIDENCE_REQUIRED');
        }

        List<Case> matchingCases = [
            SELECT Id, Status, CaseNumber, ContactId, Contact.Email, Submitted_By__c, Submitted_By__r.Email
            FROM Case
            WHERE Id = :request.caseId
            LIMIT 1
        ];
        if (matchingCases.isEmpty()) {
            throw new AuraHandledException('CASE_NOT_FOUND');
        }
        Case targetCase = matchingCases[0];
        sendCompletionNotification(targetCase, request);

        Case updateCase = new Case(Id = request.caseId, Status = 'Closed');
        setFieldIfAvailable(updateCase, 'Offline_Processing_Status__c', 'Completed');
        setFieldIfAvailable(updateCase, 'Completed_At__c', System.now());
        setFieldIfAvailable(updateCase, 'Completion_Notified__c', true);
        setFieldIfAvailable(updateCase, 'Delivery_Channel__c', request.deliveryChannel);
        setFieldIfAvailable(updateCase, 'Delivery_Evidence_Notes__c', request.deliveryEvidenceReference);
        update updateCase;

        List<Report_Request_Item__c> itemUpdates = [
            SELECT Id, Data_Subject__c, Delivery_Status__c, Successful_Retrieval_Count__c
            FROM Report_Request_Item__c
            WHERE Report_Request_Case__c = :request.caseId
        ];
        Map<Id, Integer> successfulRetrievalCountBySubject = new Map<Id, Integer>();
        for (Report_Request_Item__c itemUpdate : itemUpdates) {
            Boolean transitioningToCompleted = itemUpdate.Delivery_Status__c != 'Completed';
            setFieldIfAvailable(itemUpdate, 'Delivery_Status__c', 'Completed');
            setFieldIfAvailable(itemUpdate, 'Completion_Notification_Sent__c', true);
            setFieldIfAvailable(itemUpdate, 'Delivery_Confirmation__c', true);
            if (transitioningToCompleted) {
                if (itemUpdate.Data_Subject__c != null) {
                    Integer existingCount = successfulRetrievalCountBySubject.containsKey(itemUpdate.Data_Subject__c)
                        ? successfulRetrievalCountBySubject.get(itemUpdate.Data_Subject__c)
                        : 0;
                    successfulRetrievalCountBySubject.put(itemUpdate.Data_Subject__c, existingCount + 1);
                }
                if (hasField(Report_Request_Item__c.SObjectType, 'Successful_Retrieval_Count__c')) {
                    Integer previousCount = itemUpdate.Successful_Retrieval_Count__c == null ? 0 : Integer.valueOf(itemUpdate.Successful_Retrieval_Count__c);
                    itemUpdate.Successful_Retrieval_Count__c = previousCount + 1;
                }
                setFieldIfAvailable(itemUpdate, 'Expiry_Triggered__c', true);
            }
        }
        if (!itemUpdates.isEmpty()) {
            update itemUpdates;
        }
        if (!successfulRetrievalCountBySubject.isEmpty()) {
            recordSuccessfulRetrievals(successfulRetrievalCountBySubject, false);
        }
    }

    public static void recordSuccessfulRetrievals(Map<Id, Integer> successfulRetrievalCountBySubject) {
        recordSuccessfulRetrievals(successfulRetrievalCountBySubject, true);
    }

    private static void sendCompletionNotification(Case targetCase, CompletionRequest request) {
        if (Test.isRunningTest() && skipEmailSendDuringTests) {
            lastEmailBatchSizeForTest = 0;
            return;
        }
        if (targetCase == null) {
            throw new AuraHandledException('CASE_REQUIRED');
        }

        Set<String> uniqueRecipients = new Set<String>();
        List<String> recipientEmails = new List<String>();

        String caseContactEmail = targetCase.Contact == null ? null : targetCase.Contact.Email;
        if (!String.isBlank(caseContactEmail)) {
            String normalized = caseContactEmail.trim().toLowerCase();
            if (!uniqueRecipients.contains(normalized)) {
                uniqueRecipients.add(normalized);
                recipientEmails.add(caseContactEmail.trim());
            }
        }

        String submittedByEmail = targetCase.Submitted_By__r == null ? null : targetCase.Submitted_By__r.Email;
        if (!String.isBlank(submittedByEmail)) {
            String normalized = submittedByEmail.trim().toLowerCase();
            if (!uniqueRecipients.contains(normalized)) {
                uniqueRecipients.add(normalized);
                recipientEmails.add(submittedByEmail.trim());
            }
        }

        if (recipientEmails.isEmpty()) {
            throw new AuraHandledException('NOTIFICATION_EMAIL_REQUIRED');
        }

        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (String recipientEmail : recipientEmails) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ recipientEmail });
            mail.setSaveAsActivity(true);
            mail.setSubject('CBS Report Request Completed - Case ' + targetCase.CaseNumber);
            mail.setPlainTextBody(buildCompletionBody(targetCase, request));
            mails.add(mail);
        }
        lastEmailBatchSizeForTest = mails.size();
        Messaging.SendEmailResult[] results = Messaging.sendEmail(mails);
        if (results == null || results.isEmpty()) {
            throw new AuraHandledException('EMAIL_SEND_FAILED');
        }
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i] != null && results[i].isSuccess()) {
                continue;
            }
            String errorMessage = 'EMAIL_SEND_FAILED';
            if (results[i] != null && results[i].getErrors() != null && !results[i].getErrors().isEmpty()) {
                errorMessage += ':' + results[i].getErrors()[0].getMessage();
            }
            throw new AuraHandledException(errorMessage);
        }
    }

    private static String buildCompletionBody(Case targetCase, CompletionRequest request) {
        List<String> lines = new List<String>();
        lines.add('Dear Customer,');
        lines.add('');
        lines.add('Your CBS report request has been completed.');
        lines.add('Case Number: ' + targetCase.CaseNumber);
        lines.add('Completed At: ' + String.valueOf(System.now()));
        if (!String.isBlank(request.deliveryChannel)) {
            lines.add('Delivery Channel: ' + request.deliveryChannel);
        }
        if (!String.isBlank(request.deliveryEvidenceReference)) {
            lines.add('Delivery Reference: ' + request.deliveryEvidenceReference);
        }
        lines.add('');
        lines.add('Regards,');
        lines.add('CBS Service Team');
        return String.join(lines, '\n');
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }

    private static void recordSuccessfulRetrievals(
        Map<Id, Integer> successfulRetrievalCountBySubject,
        Boolean updateRequestItems
    ) {
        if (successfulRetrievalCountBySubject == null || successfulRetrievalCountBySubject.isEmpty()) {
            return;
        }
        if (updateRequestItems == true) {
            updateLatestRequestItemsForSuccessfulRetrieval(successfulRetrievalCountBySubject);
        }
        expirePrehireConsentsAfterSuccessfulRetrieval(successfulRetrievalCountBySubject);
    }

    private static void updateLatestRequestItemsForSuccessfulRetrieval(Map<Id, Integer> successfulRetrievalCountBySubject) {
        if (successfulRetrievalCountBySubject == null || successfulRetrievalCountBySubject.isEmpty()) {
            return;
        }
        List<Report_Request_Item__c> requestItems = [
            SELECT Id, Data_Subject__c, Delivery_Status__c, Successful_Retrieval_Count__c
            FROM Report_Request_Item__c
            WHERE Data_Subject__c IN :successfulRetrievalCountBySubject.keySet()
            ORDER BY Data_Subject__c ASC, CreatedDate DESC
        ];
        Map<Id, Report_Request_Item__c> latestBySubject = new Map<Id, Report_Request_Item__c>();
        for (Report_Request_Item__c requestItem : requestItems) {
            if (requestItem.Data_Subject__c != null && !latestBySubject.containsKey(requestItem.Data_Subject__c)) {
                latestBySubject.put(requestItem.Data_Subject__c, requestItem);
            }
        }

        List<Report_Request_Item__c> updates = new List<Report_Request_Item__c>();
        for (Id subjectId : successfulRetrievalCountBySubject.keySet()) {
            Report_Request_Item__c latestItem = latestBySubject.get(subjectId);
            if (latestItem == null) {
                continue;
            }
            Integer addedCount = successfulRetrievalCountBySubject.get(subjectId);
            if (addedCount == null || addedCount <= 0) {
                continue;
            }
            if (hasField(Report_Request_Item__c.SObjectType, 'Successful_Retrieval_Count__c')) {
                Integer previousCount = latestItem.Successful_Retrieval_Count__c == null
                    ? 0
                    : Integer.valueOf(latestItem.Successful_Retrieval_Count__c);
                latestItem.Successful_Retrieval_Count__c = previousCount + addedCount;
            }
            setFieldIfAvailable(latestItem, 'Expiry_Triggered__c', true);
            setFieldIfAvailable(latestItem, 'Delivery_Status__c', 'Completed');
            updates.add(latestItem);
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static void expirePrehireConsentsAfterSuccessfulRetrieval(Map<Id, Integer> successfulRetrievalCountBySubject) {
        if (successfulRetrievalCountBySubject == null || successfulRetrievalCountBySubject.isEmpty()) {
            return;
        }

        List<Consent__c> consentRows = [
            SELECT Id, Data_Subject__c, Consent_Status__c, Employment_Status__c, Report_Use_Count__c
            FROM Consent__c
            WHERE Data_Subject__c IN :successfulRetrievalCountBySubject.keySet()
            ORDER BY CreatedDate DESC
        ];

        Map<Id, Consent__c> latestConsentBySubject = new Map<Id, Consent__c>();
        for (Consent__c consentRow : consentRows) {
            if (consentRow.Data_Subject__c != null && !latestConsentBySubject.containsKey(consentRow.Data_Subject__c)) {
                latestConsentBySubject.put(consentRow.Data_Subject__c, consentRow);
            }
        }

        List<Consent__c> consentsToUpdate = new List<Consent__c>();
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Id subjectId : successfulRetrievalCountBySubject.keySet()) {
            Consent__c latestConsent = latestConsentBySubject.get(subjectId);
            if (latestConsent == null || !ACTIVE_CONSENT_STATUSES.contains(latestConsent.Consent_Status__c)) {
                continue;
            }
            if (!isPrehire(latestConsent.Employment_Status__c)) {
                continue;
            }

            Integer addedCount = successfulRetrievalCountBySubject.get(subjectId);
            Consent__c consentUpdate = new Consent__c(Id = latestConsent.Id);
            consentUpdate.Consent_Status__c = CONSENT_STATUS_EXPIRED;
            Integer currentUseCount = latestConsent.Report_Use_Count__c == null ? 0 : Integer.valueOf(latestConsent.Report_Use_Count__c);
            consentUpdate.Report_Use_Count__c = currentUseCount + (addedCount == null ? 0 : addedCount);
            consentsToUpdate.add(consentUpdate);

            Contact contactUpdate = new Contact(Id = subjectId);
            setFieldIfAvailable(contactUpdate, 'Data_Subject_Lifecycle_Stage__c', LIFECYCLE_STAGE_CONSUMED);
            setFieldIfAvailable(contactUpdate, 'Report_Eligibility_Status__c', REPORT_ELIGIBILITY_CONSUMED);
            contactsToUpdate.add(contactUpdate);
        }

        if (!consentsToUpdate.isEmpty()) {
            update consentsToUpdate;
        }
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    private static Boolean isPrehire(String employmentStatus) {
        if (String.isBlank(employmentStatus)) {
            return false;
        }
        String normalized = employmentStatus.trim().toLowerCase();
        return normalized == EMPLOYMENT_STATUS_PREHIRE
            || normalized == 'prehire'
            || normalized == 'new hire'
            || normalized == 'newhire';
    }

    private static Boolean hasField(Schema.SObjectType objectType, String fieldApiName) {
        return objectType != null
            && !String.isBlank(fieldApiName)
            && objectType.getDescribe().fields.getMap().containsKey(fieldApiName);
    }
}