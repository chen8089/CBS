public with sharing class ReportUploadCaseBindingService {
    private static final String REPORT_REQUEST_RECORD_TYPE = 'CBS_Report_Request';
    private static final String PROCESSING_QUEUE_NAME = 'CBS_Processing_Queue';

    public class BindingResult {
        public Integer createdCaseCount = 0;
        public Integer createdItemCount = 0;
        public Map<Id, String> reportErrorsById = new Map<Id, String>();
        public Map<Id, Id> reportToCaseId = new Map<Id, Id>();
    }

    public static BindingResult createAndBindCases(List<Reports__c> reports, Map<String, Contact> contactByEmail) {
        BindingResult result = new BindingResult();
        if (reports == null || reports.isEmpty()) {
            return result;
        }

        Id reportRequestRecordTypeId = resolveRecordTypeId('Case', REPORT_REQUEST_RECORD_TYPE);
        Id processingQueueOwnerId = resolveQueueOwnerId(PROCESSING_QUEUE_NAME);

        List<Case> casesToInsert = new List<Case>();
        List<Id> caseToReportIds = new List<Id>();
        List<Id> caseToContactIds = new List<Id>();

        for (Reports__c reportRecord : reports) {
            if (reportRecord == null || reportRecord.Id == null) {
                continue;
            }

            String reportName = reportRecord.Name;
            String reportEmail = resolveReportEmail(reportRecord);
            Contact matchedContact = null;
            if (!String.isBlank(reportEmail) && contactByEmail != null) {
                matchedContact = contactByEmail.get(normalizeEmail(reportEmail));
            }

            Case requestCase = new Case(
                Status = 'New',
                Origin = 'Portal',
                Subject = String.isBlank(reportName) ? 'Uploaded Report Request' : 'Uploaded Report Request - ' + reportName
            );
            if (matchedContact != null) {
                requestCase.AccountId = matchedContact.AccountId;
                requestCase.ContactId = matchedContact.Id;
            }
            if (reportRequestRecordTypeId != null) {
                requestCase.RecordTypeId = reportRequestRecordTypeId;
            }
            if (processingQueueOwnerId != null) {
                requestCase.OwnerId = processingQueueOwnerId;
            }
            setFieldIfAvailable(requestCase, 'Exception_Type__c', 'File Validation');
            setFieldIfAvailable(requestCase, 'Requested_Count__c', 1);
            setFieldIfAvailable(requestCase, 'CBS_Group_Mail_Notified__c', false);
            setFieldIfAvailable(requestCase, 'Data_Subject_Notice_Sent__c', false);
            setFieldIfAvailable(requestCase, 'Offline_Processing_Status__c', 'Pending');
            setFieldIfAvailable(requestCase, 'Submitted_By__c', UserInfo.getUserId());
            setFieldIfAvailable(requestCase, 'Source_Report__c', reportRecord.Id);
            setFieldIfAvailable(requestCase, 'Consent_Batch_Reference__c', String.valueOf(reportRecord.Id));

            casesToInsert.add(requestCase);
            caseToReportIds.add(reportRecord.Id);
            caseToContactIds.add(matchedContact == null ? null : matchedContact.Id);
        }

        if (casesToInsert.isEmpty()) {
            return result;
        }

        SObjectAccessDecision creatableCases = Security.stripInaccessible(AccessType.CREATABLE, casesToInsert);
        List<Case> sanitizedCases = (List<Case>) creatableCases.getRecords();
        Database.SaveResult[] caseSaveResults = Database.insert(sanitizedCases, false);

        for (Integer i = 0; i < caseSaveResults.size(); i++) {
            Id reportId = i < caseToReportIds.size() ? caseToReportIds[i] : null;
            Database.SaveResult saveResult = caseSaveResults[i];
            if (!saveResult.isSuccess()) {
                if (reportId != null) {
                    String errorMessage = saveResult.getErrors().isEmpty()
                        ? 'Case creation failed.'
                        : saveResult.getErrors()[0].getMessage();
                    result.reportErrorsById.put(reportId, errorMessage);
                }
                continue;
            }

            Id caseId = saveResult.getId();
            result.createdCaseCount++;
            if (reportId != null) {
                result.reportToCaseId.put(reportId, caseId);
            }
        }

        enforceMatchedContactOnCreatedCases(caseSaveResults, caseToContactIds);
        createChildItemsForCases(caseSaveResults, caseToReportIds, caseToContactIds, result);
        return result;
    }

    private static void enforceMatchedContactOnCreatedCases(
        Database.SaveResult[] caseSaveResults,
        List<Id> caseToContactIds
    ) {
        if (caseSaveResults == null || caseSaveResults.isEmpty() || caseToContactIds == null || caseToContactIds.isEmpty()) {
            return;
        }
        List<Case> caseUpdates = new List<Case>();
        for (Integer i = 0; i < caseSaveResults.size(); i++) {
            if (!caseSaveResults[i].isSuccess()) {
                continue;
            }
            Id caseId = caseSaveResults[i].getId();
            Id matchedContactId = i < caseToContactIds.size() ? caseToContactIds[i] : null;
            if (caseId == null || matchedContactId == null) {
                continue;
            }
            caseUpdates.add(new Case(Id = caseId, ContactId = matchedContactId));
        }
        if (caseUpdates.isEmpty()) {
            return;
        }
        SObjectAccessDecision updatableCases = Security.stripInaccessible(AccessType.UPDATABLE, caseUpdates);
        List<Case> sanitizedUpdates = (List<Case>) updatableCases.getRecords();
        if (!sanitizedUpdates.isEmpty()) {
            Database.update(sanitizedUpdates, false);
        }
    }

    private static void createChildItemsForCases(
        Database.SaveResult[] caseSaveResults,
        List<Id> caseToReportIds,
        List<Id> caseToContactIds,
        BindingResult result
    ) {
        if (caseSaveResults == null || caseSaveResults.isEmpty()) {
            return;
        }
        List<Report_Request_Item__c> itemsToInsert = new List<Report_Request_Item__c>();
        List<Id> itemReportIds = new List<Id>();
        for (Integer i = 0; i < caseSaveResults.size(); i++) {
            if (!caseSaveResults[i].isSuccess()) {
                continue;
            }
            Id reportId = i < caseToReportIds.size() ? caseToReportIds[i] : null;
            Id contactId = i < caseToContactIds.size() ? caseToContactIds[i] : null;
            Id caseId = caseSaveResults[i].getId();
            if (caseId == null || reportId == null || contactId == null) {
                if (reportId != null) {
                    result.reportErrorsById.put(reportId, 'Failed to create Report Request Item: Data Subject is missing.');
                }
                continue;
            }
            Report_Request_Item__c itemRecord = new Report_Request_Item__c(
                Report_Request_Case__c = caseId,
                Data_Subject__c = contactId
            );
            setFieldIfAvailable(itemRecord, 'Selected_By__c', UserInfo.getUserId());
            setFieldIfAvailable(itemRecord, 'Selected_At__c', System.now());
            setFieldIfAvailable(itemRecord, 'Consent_Revalidation_Status__c', 'Passed');
            setFieldIfAvailable(itemRecord, 'Eligibility_Status__c', 'Eligible');
            setFieldIfAvailable(itemRecord, 'Delivery_Status__c', 'Pending');
            setFieldIfAvailable(itemRecord, 'Notice_Sent_To_Data_Subject__c', false);
            itemsToInsert.add(itemRecord);
            itemReportIds.add(reportId);
        }
        if (itemsToInsert.isEmpty()) {
            return;
        }
        SObjectAccessDecision creatableItems = Security.stripInaccessible(AccessType.CREATABLE, itemsToInsert);
        List<Report_Request_Item__c> sanitizedItems = (List<Report_Request_Item__c>) creatableItems.getRecords();
        Database.SaveResult[] itemSaveResults = Database.insert(sanitizedItems, false);
        for (Integer i = 0; i < itemSaveResults.size(); i++) {
            if (itemSaveResults[i].isSuccess()) {
                result.createdItemCount++;
                continue;
            }
            Id reportId = i < itemReportIds.size() ? itemReportIds[i] : null;
            if (reportId != null) {
                String errorMessage = itemSaveResults[i].getErrors().isEmpty()
                    ? 'Report Request Item creation failed.'
                    : itemSaveResults[i].getErrors()[0].getMessage();
                result.reportErrorsById.put(reportId, errorMessage);
            }
        }
    }

    private static Id resolveRecordTypeId(String objectApiName, String recordTypeDeveloperName) {
        if (String.isBlank(objectApiName) || String.isBlank(recordTypeDeveloperName)) {
            return null;
        }
        if (objectApiName == 'Case') {
            Schema.DescribeSObjectResult caseDescribe = Case.SObjectType.getDescribe();
            Map<String, Schema.RecordTypeInfo> infosByDeveloperName =
                caseDescribe.getRecordTypeInfosByDeveloperName();
            if (!infosByDeveloperName.containsKey(recordTypeDeveloperName)) {
                return null;
            }
            Schema.RecordTypeInfo info = infosByDeveloperName.get(recordTypeDeveloperName);
            return info.isAvailable() ? info.getRecordTypeId() : null;
        }
        return null;
    }

    private static Id resolveQueueOwnerId(String queueDeveloperName) {
        if (String.isBlank(queueDeveloperName)) {
            return null;
        }
        List<Group> candidateQueues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND (DeveloperName = :queueDeveloperName OR Name = :queueDeveloperName)
            LIMIT 1
        ];
        if (candidateQueues.isEmpty()) {
            return null;
        }
        Id queueId = candidateQueues[0].Id;
        List<QueueSobject> queueSupport = [
            SELECT Id
            FROM QueueSobject
            WHERE QueueId = :queueId
            AND SobjectType = 'Case'
            LIMIT 1
        ];
        return queueSupport.isEmpty() ? null : queueId;
    }

    private static String resolveReportEmail(Reports__c reportRecord) {
        if (reportRecord == null) {
            return null;
        }
        Map<String, Schema.SObjectField> reportFields = Schema.SObjectType.Reports__c.fields.getMap();
        if (reportFields.containsKey('Email_Address__c')) {
            return String.valueOf(reportRecord.get('Email_Address__c'));
        }
        if (reportFields.containsKey('Email__c')) {
            return String.valueOf(reportRecord.get('Email__c'));
        }
        return null;
    }

    private static String normalizeEmail(String value) {
        return String.isBlank(value) ? null : value.trim().toLowerCase();
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }
}