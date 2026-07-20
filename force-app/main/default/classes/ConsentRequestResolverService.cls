public with sharing class ConsentRequestResolverService {
    public static Consent__c getLatestConsent(Id subjectId) {
        if (subjectId == null) {
            return null;
        }

        List<Consent__c> existingConsents = [
            SELECT Id, Consent_Status__c, Data_Subject__c, Action_Type__c, Submitted_At__c,
                Revoked_At__c, Withdrawn_By_Client__c, MyInfo_Name__c, MyInfo_Nationality__c,
                MyInfo_ID_Number__c, MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 1
        ];

        return existingConsents.isEmpty() ? null : existingConsents[0];
    }

    public static Consent__c getCurrentActiveConsent(Id subjectId) {
        Consent__c latestConsent = getLatestConsent(subjectId);
        return latestConsent != null && latestConsent.Consent_Status__c == 'Active' ? latestConsent : null;
    }

    public static Consent_Request_Item__c getLatestRequestItem(Id subjectId) {
        if (subjectId == null) {
            return null;
        }

        List<Consent_Request_Item__c> requestItems = [
            SELECT Id, Current_Status__c, Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c,
                Data_Subject__c, Uploaded_Full_Name__c,
                Uploaded_ID_Number__c, Uploaded_Date_of_Birth__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :subjectId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return requestItems.isEmpty() ? null : requestItems[0];
    }

    public static SObject querySuccessRequestItemById(String rawId) {
        try {
            Id safeId = (Id) rawId;
            String soql = 'SELECT ' + String.join(getSuccessRequestItemSelectFields(), ',') +
                ' FROM Consent_Request_Item__c WHERE Id = :safeId LIMIT 1';
            List<SObject> rows = Database.query(soql);
            return rows.isEmpty() ? null : rows[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static SObject querySuccessRequestItemByToken(String tokenValue) {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(fieldMap, new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
        if (String.isBlank(tokenField)) {
            return null;
        }
        String soql =
            'SELECT ' + String.join(getSuccessRequestItemSelectFields(), ',') +
            ' FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<String> getSuccessRequestItemSelectFields() {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Data_Subject__c', 'Current_Status__c', 'Authorization_QR_Viewed_At__c', 'Withdrawal_QR_Viewed_At__c' };
        List<String> optional = new List<String>{
            'Token__c',
            'Secure_Token__c',
            'Access_Token__c',
            'Client_Name__c',
            'Employer_Name__c',
            'Bank_Name__c',
            'Uploaded_Employer_Name__c',
            'Link_Expires_At__c',
            'Expires_At__c',
            'Expiry_Date_Time__c',
            'Token_Expires_At__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        return fields;
    }

    public static SObject querySuccessContact(Id subjectId) {
        if (subjectId == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Name', 'AccountId', 'Account.Name' };
        List<String> optional = new List<String>{
            'Principal_Name__c',
            'Full_Legal_Name__c',
            'Full_Name__c',
            'Nationality__c',
            'ID_Number__c',
            'Passport_Number__c',
            'NRIC__c',
            'FIN__c',
            'Date_of_Birth__c',
            'DOB__c',
            'Registered_Address__c',
            'Residential_Address__c',
            'MailingStreet',
            'Current_Consent_Status__c',
            'Latest_Submission_Datetime__c',
            'Authentication_Type__c',
            'Current_Consent_Expiry_Date__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    public static Id resolveContactIdByConsentId(String consentIdParam) {
        try {
            Id consentId = (Id) consentIdParam;
            List<Consent__c> rows = [
                SELECT Id, Data_Subject__c
                FROM Consent__c
                WHERE Id = :consentId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].Data_Subject__c;
        } catch (Exception e) {
            return null;
        }
    }

    public static Id resolveRecordIdToContactId(String recordIdParam) {
        try {
            Id genericId = (Id) recordIdParam;
            if (String.valueOf(genericId).startsWith(Contact.SObjectType.getDescribe().getKeyPrefix())) {
                return genericId;
            }

            List<Consent_Request_Item__c> requestRows = [
                SELECT Id, Data_Subject__c
                FROM Consent_Request_Item__c
                WHERE Id = :genericId
                LIMIT 1
            ];
            if (!requestRows.isEmpty()) {
                return requestRows[0].Data_Subject__c;
            }

            List<Consent__c> consentRows = [
                SELECT Id, Data_Subject__c
                FROM Consent__c
                WHERE Id = :genericId
                LIMIT 1
            ];
            return consentRows.isEmpty() ? null : consentRows[0].Data_Subject__c;
        } catch (Exception e) {
            return null;
        }
    }

    private static String findFirstExistingField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        if (fieldMap == null || candidates == null) {
            return null;
        }
        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }
}