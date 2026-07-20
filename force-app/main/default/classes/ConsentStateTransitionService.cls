public without sharing class ConsentStateTransitionService {
    private static final String CURRENT_STATUS_DECLINED = 'Declined';
    private static final String CURRENT_STATUS_AUTHORIZED = 'Authorized';

    public static void applyDeclination(Id subjectId) {
        if (subjectId == null) {
            return;
        }

        ConsentProjectionSyncService.syncContactFromConsent(
            subjectId,
            CURRENT_STATUS_DECLINED,
            null,
            System.now()
        );

        declineLatestRequestItem(subjectId);
    }

    public static void clearAuthorizationQrIfNeeded(Consent_Request_Item__c requestItem, String currentContactStatus) {
        if (requestItem == null || requestItem.Authorization_QR_Viewed_At__c == null) {
            return;
        }
        if (currentContactStatus != CURRENT_STATUS_AUTHORIZED) {
            clearAuthorizationQrViewed(requestItem.Id);
        }
    }

    public static void clearWithdrawalQrIfNeeded(Consent_Request_Item__c requestItem, String currentContactStatus) {
        if (requestItem == null || requestItem.Withdrawal_QR_Viewed_At__c == null) {
            return;
        }
        if (currentContactStatus == CURRENT_STATUS_AUTHORIZED) {
            clearWithdrawalQrViewed(requestItem.Id);
        }
    }

    private static void declineLatestRequestItem(Id subjectId) {
        Consent_Request_Item__c requestItem = ConsentRequestResolverService.getLatestRequestItem(subjectId);
        if (requestItem != null) {
            update new Consent_Request_Item__c(
                Id = requestItem.Id,
                Current_Status__c = CURRENT_STATUS_DECLINED,
                Authorization_QR_Viewed_At__c = null,
                Withdrawal_QR_Viewed_At__c = null
            );
        }
    }

    private static void clearAuthorizationQrViewed(Id requestItemId) {
        update new Consent_Request_Item__c(
            Id = requestItemId,
            Authorization_QR_Viewed_At__c = null
        );
    }

    private static void clearWithdrawalQrViewed(Id requestItemId) {
        update new Consent_Request_Item__c(
            Id = requestItemId,
            Withdrawal_QR_Viewed_At__c = null
        );
    }
}