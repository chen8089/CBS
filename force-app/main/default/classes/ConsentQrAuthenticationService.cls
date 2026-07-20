public without sharing class ConsentQrAuthenticationService {
    private static final String CONSENT_STATUS_ACTIVE = 'Active';
    private static final String REQUEST_STATUS_SUBMITTED = 'Submitted';
    private static final String MESSAGE_AUTHORIZATION_ALREADY_COMPLETE =
        'Authorization submitted successfully. The process is complete, and you may close this page.';
    private static final String MESSAGE_AUTHENTICATION_COMPLETE =
        'Authentication completed successfully. Please continue the authorization form on your computer.';

    public class AuthorizationScanOutcome {
        public Boolean isFinished { get; set; }
        public String resultMessage { get; set; }
        public Boolean shouldMarkAuthorizationQrViewed { get; set; }

        public AuthorizationScanOutcome() {
            isFinished = false;
            shouldMarkAuthorizationQrViewed = false;
        }
    }

    public static AuthorizationScanOutcome evaluateAuthorizationScan(
        Consent_Request_Item__c requestItem,
        Consent__c latestConsent
    ) {
        AuthorizationScanOutcome outcome = new AuthorizationScanOutcome();

        if (hasActiveConsent(latestConsent)) {
            outcome.isFinished = true;
            outcome.resultMessage = MESSAGE_AUTHORIZATION_ALREADY_COMPLETE;
            return outcome;
        }

        if (requestItem != null && requestItem.Current_Status__c == REQUEST_STATUS_SUBMITTED) {
            outcome.isFinished = true;
            outcome.resultMessage = MESSAGE_AUTHORIZATION_ALREADY_COMPLETE;
            return outcome;
        }

        outcome.isFinished = true;
        outcome.shouldMarkAuthorizationQrViewed = true;
        outcome.resultMessage = MESSAGE_AUTHENTICATION_COMPLETE;
        return outcome;
    }

    public static Boolean hasActiveConsent(Consent__c consent) {
        return consent != null && consent.Consent_Status__c == CONSENT_STATUS_ACTIVE;
    }

    public static Boolean shouldRedirectToAuthorizationForm(Consent_Request_Item__c requestItem) {
        return requestItem != null
            && requestItem.Authorization_QR_Viewed_At__c != null
            && requestItem.Current_Status__c != REQUEST_STATUS_SUBMITTED;
    }

    public static Boolean shouldRedirectToWithdrawalForm(
        Consent__c consent,
        Consent_Request_Item__c requestItem,
        Boolean consentBelongsToSubject
    ) {
        return hasActiveConsent(consent)
            && consentBelongsToSubject
            && requestItem != null
            && requestItem.Withdrawal_QR_Viewed_At__c != null;
    }

    public static void markAuthorizationQrViewedByRequestItem(Id requestItemId) {
        if (requestItemId == null) {
            throw new ConsentQrAuthenticationException('Authorization request was not found. Please contact your HR representative.');
        }
        update new Consent_Request_Item__c(
            Id = requestItemId,
            Authorization_QR_Viewed_At__c = System.now(),
            Withdrawal_QR_Viewed_At__c = null
        );
    }

    public static void markAuthorizationQrViewedForSubject(Id subjectId) {
        Consent_Request_Item__c requestItem = ConsentRequestResolverService.getLatestRequestItem(subjectId);
        if (requestItem == null) {
            throw new ConsentQrAuthenticationException('Authorization request was not found. Please contact your HR representative.');
        }
        markAuthorizationQrViewedByRequestItem(requestItem.Id);
    }

    public static void markWithdrawalQrViewedByRequestItem(Id requestItemId) {
        if (requestItemId == null) {
            throw new ConsentQrAuthenticationException('Authorization request was not found. Please contact your HR representative.');
        }
        update new Consent_Request_Item__c(
            Id = requestItemId,
            Withdrawal_QR_Viewed_At__c = System.now()
        );
    }

    public static void markWithdrawalQrViewedForSubject(Id subjectId) {
        Consent_Request_Item__c requestItem = ConsentRequestResolverService.getLatestRequestItem(subjectId);
        if (requestItem == null) {
            throw new ConsentQrAuthenticationException('Authorization request was not found. Please contact your HR representative.');
        }
        markWithdrawalQrViewedByRequestItem(requestItem.Id);
    }

    public class ConsentQrAuthenticationException extends Exception {}
}