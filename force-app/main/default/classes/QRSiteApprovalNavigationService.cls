public with sharing class QRSiteApprovalNavigationService {
    public static PageReference buildAuthorizationQrPage(String contactId, String requestItemId, String token) {
        PageReference pageRef = Page.QRSiteShowQrPage;
        putIfNotBlank(pageRef, 'ContactId', contactId);
        putIfNotBlank(pageRef, 'requestItemId', requestItemId);
        putIfNotBlank(pageRef, 'token', token);
        pageRef.setRedirect(true);
        return pageRef;
    }

    public static PageReference buildWithdrawQrPage(String contactId, String consentId, String requestItemId, String token) {
        PageReference pageRef = Page.QRSiteWithdrawQrPage;
        putIfNotBlank(pageRef, 'ContactId', contactId);
        putIfNotBlank(pageRef, 'id', consentId);
        putIfNotBlank(pageRef, 'requestItemId', requestItemId);
        putIfNotBlank(pageRef, 'token', token);
        pageRef.setRedirect(true);
        return pageRef;
    }

    public static PageReference buildConsentFormActiveConsentPage(String contactId) {
        PageReference pageRef = Page.QRSiteConsentForm;
        putIfNotBlank(pageRef, 'ContactId', contactId);
        pageRef.getParameters().put('completed', 'true');
        pageRef.getParameters().put('activeConsent', 'true');
        pageRef.setRedirect(true);
        return pageRef;
    }

    public static PageReference buildConsentFormRequestPage(String contactId, String requestItemId) {
        PageReference pageRef = Page.QRSiteConsentForm;
        putIfNotBlank(pageRef, 'ContactId', contactId);
        putIfNotBlank(pageRef, 'requestItemId', requestItemId);
        pageRef.setRedirect(true);
        return pageRef;
    }

    public static PageReference buildWithdrawConsentPage(String contactId, String consentId, String requestItemId, String token) {
        PageReference pageRef = Page.QRSiteWithdrawConsent;
        putIfNotBlank(pageRef, 'ContactId', contactId);
        putIfNotBlank(pageRef, 'id', consentId);
        putIfNotBlank(pageRef, 'requestItemId', requestItemId);
        putIfNotBlank(pageRef, 'token', token);
        pageRef.setRedirect(true);
        return pageRef;
    }

    private static void putIfNotBlank(PageReference pageRef, String key, String value) {
        if (pageRef == null || String.isBlank(key) || String.isBlank(value)) {
            return;
        }
        pageRef.getParameters().put(key, value);
    }
}