public without sharing class ConsentSubmissionService {
    private static final String CURRENT_STATUS_AUTHORIZED = 'Authorized';
    private static final String CURRENT_STATUS_WITHDRAWN = 'Withdrawn';

    public static Id submitAuthorization(
        Consent_Request_Item__c requestItem,
        String inputName,
        String inputNationality,
        String inputNric,
        Date inputDob,
        String inputResidentialAddress
    ) {
        return submitAuthorization(
            requestItem,
            inputName,
            inputNationality,
            inputNric,
            inputDob,
            inputResidentialAddress,
            Date.today().addYears(5),
            System.now(),
            null
        );
    }

    public static Id submitAuthorization(
        Consent_Request_Item__c requestItem,
        String inputName,
        String inputNationality,
        String inputNric,
        Date inputDob,
        String inputResidentialAddress,
        Date consentExpiryDate,
        Datetime submittedAt,
        String authenticationType
    ) {
        if (requestItem == null || requestItem.Data_Subject__c == null) {
            return null;
        }
        Datetime effectiveSubmittedAt = submittedAt == null ? System.now() : submittedAt;
        Consent__c newConsent = new Consent__c();
        newConsent.Data_Subject__c = requestItem.Data_Subject__c;
        newConsent.Consent_Status__c = 'Active';
        newConsent.Submitted_At__c = effectiveSubmittedAt;
        newConsent.Action_Type__c = 'Consent Given';
        newConsent.MyInfo_Name__c = inputName;
        newConsent.MyInfo_Nationality__c = inputNationality;
        newConsent.MyInfo_ID_Number__c = inputNric;
        newConsent.MyInfo_Date_of_Birth__c = inputDob;
        newConsent.MyInfo_Residential_Address__c = inputResidentialAddress;
        if (consentExpiryDate != null) {
            newConsent.Consent_Expiry_Date__c = consentExpiryDate;
        }
        setFieldIfAvailable(newConsent, 'Consent_Request_Item__c', requestItem.Id);
        setFieldIfAvailable(newConsent, 'Latest_Submission_Date_Time__c', effectiveSubmittedAt);
        setFieldIfAvailable(newConsent, 'Authentication_Type__c', authenticationType);
        insert newConsent;

        Consent_Request_Item__c requestItemUpdate = new Consent_Request_Item__c(Id = requestItem.Id);
        requestItemUpdate.Current_Status__c = 'Submitted';
        requestItemUpdate.Withdrawal_QR_Viewed_At__c = null;
        setFieldIfAvailable(requestItemUpdate, 'Latest_Submission_Date_Time__c', effectiveSubmittedAt);
        update requestItemUpdate;

        ConsentProjectionSyncService.syncContactFromConsent(
            requestItem.Data_Subject__c,
            CURRENT_STATUS_AUTHORIZED,
            consentExpiryDate,
            effectiveSubmittedAt
        );
        return newConsent.Id;
    }

    public static void submitWithdrawal(Id subjectId, Consent__c activeConsent, Datetime withdrawnAt) {
        submitWithdrawal(subjectId, null, activeConsent, withdrawnAt);
    }

    public static void submitWithdrawal(
        Id subjectId,
        Id requestItemId,
        Consent__c activeConsent,
        Datetime withdrawnAt
    ) {
        if (activeConsent != null) {
            Consent__c withdrawalConsent = new Consent__c();
            withdrawalConsent.Data_Subject__c = activeConsent.Data_Subject__c;
            withdrawalConsent.Consent_Status__c = CURRENT_STATUS_WITHDRAWN;
            withdrawalConsent.Revoked_At__c = withdrawnAt;
            withdrawalConsent.Action_Type__c = 'Consent Withdrawn';
            withdrawalConsent.Withdrawn_By_Client__c = true;
            withdrawalConsent.MyInfo_Name__c = activeConsent.MyInfo_Name__c;
            withdrawalConsent.MyInfo_Nationality__c = activeConsent.MyInfo_Nationality__c;
            withdrawalConsent.MyInfo_ID_Number__c = activeConsent.MyInfo_ID_Number__c;
            withdrawalConsent.MyInfo_Date_of_Birth__c = activeConsent.MyInfo_Date_of_Birth__c;
            withdrawalConsent.MyInfo_Residential_Address__c = activeConsent.MyInfo_Residential_Address__c;
            Id linkedRequestItemId = requestItemId == null ? activeConsent.Consent_Request_Item__c : requestItemId;
            setFieldIfAvailable(withdrawalConsent, 'Consent_Request_Item__c', linkedRequestItemId);
            setFieldIfAvailable(withdrawalConsent, 'Consent_Withdrawn_Date__c', withdrawnAt);
            setFieldIfAvailable(withdrawalConsent, 'Withdrawal_Channel__c', 'Data Subject Singpass');
            setFieldIfAvailable(withdrawalConsent, 'Withdrawal_By__c', UserInfo.getUserId());
            insert withdrawalConsent;
        }

        updateLatestRequestItemStatus(subjectId, requestItemId, CURRENT_STATUS_WITHDRAWN);
        finalizeWithdrawalQrStatus(subjectId, requestItemId);
        updateContactForWithdrawal(subjectId, withdrawnAt);
    }

    public static Id submitNonSingpassAuthorization(
        Consent_Request_Item__c requestItem,
        String principalName,
        String nationality,
        String idNumber,
        Date dateOfBirth,
        String residentialAddress,
        String passType,
        String passportNumber,
        String gender,
        String maritalStatus,
        Datetime submittedAt
    ) {
        if (requestItem == null || requestItem.Data_Subject__c == null) {
            return null;
        }
        Datetime effectiveSubmittedAt = submittedAt == null ? System.now() : submittedAt;

        Consent__c newConsent = new Consent__c();
        newConsent.Data_Subject__c = requestItem.Data_Subject__c;
        newConsent.Submitted_At__c = effectiveSubmittedAt;
        newConsent.Action_Type__c = 'Consent Given';
        newConsent.MyInfo_Name__c = principalName;
        newConsent.MyInfo_Nationality__c = nationality;
        newConsent.MyInfo_ID_Number__c = idNumber;
        newConsent.MyInfo_Date_of_Birth__c = dateOfBirth;
        newConsent.MyInfo_Residential_Address__c = residentialAddress;
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus(newConsent);
        if (String.isBlank(newConsent.Consent_Status__c)) {
            return null;
        }
        setFieldIfAvailable(newConsent, 'Consent_Request_Item__c', requestItem.Id);
        setFieldIfAvailable(newConsent, 'Authentication_Type__c', 'Non-Singpass');
        setFieldIfAvailable(newConsent, 'Latest_Submission_Date_Time__c', effectiveSubmittedAt);
        insert newConsent;

        Contact contactUpdate = new Contact(Id = requestItem.Data_Subject__c);
        contactUpdate.Principal_Name__c = principalName;
        contactUpdate.Pass_Type__c = passType;
        contactUpdate.Passport_Number__c = passportNumber;
        contactUpdate.DOB__c = dateOfBirth;
        contactUpdate.Date_of_Birth__c = dateOfBirth;
        contactUpdate.Nationality__c = nationality;
        contactUpdate.Gender__c = gender;
        contactUpdate.Marital_Status__c = maritalStatus;
        contactUpdate.Registered_Address__c = residentialAddress;
        setFieldIfAvailable(contactUpdate, 'Authentication_Type__c', 'Non-Singpass');
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus(contactUpdate);
        setFieldIfAvailable(contactUpdate, 'Latest_Submission_Datetime__c', effectiveSubmittedAt);
        String lifecycleStage = choosePicklistValue(
            Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(),
            new List<String>{ 'Pending Verification', 'Verification Pending', 'Active Consent' }
        );
        setFieldIfAvailable(contactUpdate, 'Data_Subject_Lifecycle_Stage__c', lifecycleStage);
        update contactUpdate;

        Consent_Request_Item__c requestUpdate = new Consent_Request_Item__c(Id = requestItem.Id);
        NonSingpassVerificationOrchestrator.applyPendingVerificationStatus(requestUpdate);
        setFieldIfAvailable(requestUpdate, 'Latest_Submission_Date_Time__c', effectiveSubmittedAt);
        requestUpdate.Withdrawal_QR_Viewed_At__c = null;
        update requestUpdate;
        return newConsent.Id;
    }

    private static void updateLatestRequestItemStatus(Id subjectId, Id requestItemId, String status) {
        if (subjectId == null && requestItemId == null) {
            return;
        }
        Id targetRequestItemId = requestItemId;
        if (targetRequestItemId == null) {
            List<Consent_Request_Item__c> requestItems = [
                SELECT Id
                FROM Consent_Request_Item__c
                WHERE Data_Subject__c = :subjectId
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 1
            ];
            if (!requestItems.isEmpty()) {
                targetRequestItemId = requestItems[0].Id;
            }
        }

        if (targetRequestItemId != null) {
            update new Consent_Request_Item__c(
                Id = targetRequestItemId,
                Current_Status__c = status
            );
        }
    }

    private static void finalizeWithdrawalQrStatus(Id subjectId, Id requestItemId) {
        Consent_Request_Item__c requestItem = requestItemId == null
            ? ConsentRequestResolverService.getLatestRequestItem(subjectId)
            : new Consent_Request_Item__c(Id = requestItemId);
        if (requestItem != null) {
            update new Consent_Request_Item__c(
                Id = requestItem.Id,
                Authorization_QR_Viewed_At__c = null,
                Withdrawal_QR_Viewed_At__c = null
            );
        }
    }

    private static void updateContactForWithdrawal(Id subjectId, Datetime withdrawnAt) {
        if (subjectId == null) {
            return;
        }
        Datetime effectiveWithdrawnAt = withdrawnAt == null ? System.now() : withdrawnAt;

        ConsentProjectionSyncService.syncContactFromConsent(
            subjectId,
            CURRENT_STATUS_WITHDRAWN,
            null,
            effectiveWithdrawnAt
        );

        Contact contactUpdate = new Contact(Id = subjectId);
        Boolean hasAdditionalUpdate = false;

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> withdrawalDatetimeFields = new List<String>{
            'Withdrawal_Date__c',
            'Withdrawal_Datetime__c',
            'Consent_Revocation_Date__c',
            'Revoked_At__c',
            'Latest_Status_Datetime__c'
        };
        for (String fieldApi : withdrawalDatetimeFields) {
            if (contactFields.containsKey(fieldApi)) {
                Schema.DisplayType fieldType = contactFields.get(fieldApi).getDescribe().getType();
                if (fieldType == Schema.DisplayType.Date) {
                    contactUpdate.put(fieldApi, effectiveWithdrawnAt.date());
                    hasAdditionalUpdate = true;
                } else if (fieldType == Schema.DisplayType.DateTime) {
                    contactUpdate.put(fieldApi, effectiveWithdrawnAt);
                    hasAdditionalUpdate = true;
                }
            }
        }
        if (hasAdditionalUpdate) {
            update contactUpdate;
        }
    }

    private static void setFieldIfAvailable(SObject targetRecord, String fieldApiName, Object value) {
        if (targetRecord == null || String.isBlank(fieldApiName) || value == null) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, value);
        }
    }

    private static String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
        if (describe == null || preferredValues == null) {
            return null;
        }
        for (String preferred : preferredValues) {
            if (String.isBlank(preferred)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferred) || entry.getLabel().equalsIgnoreCase(preferred)) {
                    return entry.getValue();
                }
            }
        }
        return null;
    }
}