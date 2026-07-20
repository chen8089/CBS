@IsTest
public class ConsentTestSupport {
    public static String applyGuestLinkParams(Id contactId, Consent_Request_Item__c requestItem) {
        Id requestItemId = requestItem.Id;
        String tokenField = ConsentGuestAuthService.resolveTokenFieldApiName();
        String soql = String.isBlank(tokenField)
            ? 'SELECT Id FROM Consent_Request_Item__c WHERE Id = :requestItemId LIMIT 1'
            : 'SELECT Id, ' + tokenField + ' FROM Consent_Request_Item__c WHERE Id = :requestItemId LIMIT 1';
        requestItem = (Consent_Request_Item__c) Database.query(soql)[0];
        String tokenValue = ConsentGuestAuthService.getStoredToken(requestItem);
        if (String.isBlank(tokenValue)) {
            tokenValue = ConsentGuestAuthService.generateSecureToken();
        }

        if (ApexPages.currentPage() == null) {
            Test.setCurrentPage(new PageReference('/apex/TestPage'));
        }

        if (String.isBlank(ApexPages.currentPage().getParameters().get('contactId'))) {
            ApexPages.currentPage().getParameters().put('contactId', String.valueOf(contactId));
        }
        if (String.isBlank(ApexPages.currentPage().getParameters().get('ContactId'))) {
            ApexPages.currentPage().getParameters().put('ContactId', String.valueOf(contactId));
        }
        ApexPages.currentPage().getParameters().put('requestItemId', String.valueOf(requestItem.Id));
        ApexPages.currentPage().getParameters().put('token', tokenValue);
        return tokenValue;
    }

    public static String getStoredTokenForRequestItem(Id requestItemId) {
        String tokenField = ConsentGuestAuthService.resolveTokenFieldApiName();
        if (String.isBlank(tokenField) || requestItemId == null) {
            return null;
        }
        String soql =
            'SELECT Id, ' + tokenField +
            ' FROM Consent_Request_Item__c WHERE Id = :requestItemId LIMIT 1';
        Consent_Request_Item__c requestItem = (Consent_Request_Item__c) Database.query(soql)[0];
        return ConsentGuestAuthService.getStoredToken(requestItem);
    }

    public static Consent_Request_Item__c createRequestItem(Contact contact) {
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent',
            Consent_Purpose__c = String.isBlank(contact.Consent_Type__c)
                ? 'Per-Report Consent'
                : contact.Consent_Type__c,
            Uploaded_Full_Name__c = contact.Full_Name__c,
            Uploaded_ID_Number__c = contact.ID_Number__c,
            Uploaded_Date_of_Birth__c = contact.Date_of_Birth__c
        );
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        return [
            SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c,
                Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c,
                Uploaded_Full_Name__c, Uploaded_ID_Number__c, Uploaded_Date_of_Birth__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
    }
}