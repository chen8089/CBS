public class ConsentRequestItemTriggerHandler {
    @TestVisible
    private static Boolean suppressConsentEmail = false;

    public static void beforeInsert(List<Consent_Request_Item__c> newItems) {
        for (Consent_Request_Item__c requestItem : newItems) {
            ConsentGuestAuthService.assignTokenIfMissing(requestItem);
        }
    }

    public static void afterInsert(List<Consent_Request_Item__c> newItems) {
        if (suppressConsentEmail || newItems == null || newItems.isEmpty()) {
            return;
        }

        QRSiteContactConsentEmail.sendForNewRequestItems(newItems);
    }
}