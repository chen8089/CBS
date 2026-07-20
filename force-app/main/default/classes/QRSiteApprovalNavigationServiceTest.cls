@isTest
private class QRSiteApprovalNavigationServiceTest {
    @isTest
    static void buildAuthorizationQrPageSetsExpectedParams() {
        PageReference pageRef = QRSiteApprovalNavigationService.buildAuthorizationQrPage(
            '003000000000001AAA',
            'a02000000000001AAA',
            'token-123'
        );
        System.assertNotEquals(null, pageRef);
        System.assertEquals('003000000000001AAA', pageRef.getParameters().get('ContactId'));
        System.assertEquals('a02000000000001AAA', pageRef.getParameters().get('requestItemId'));
        System.assertEquals('token-123', pageRef.getParameters().get('token'));
        System.assertEquals(true, pageRef.getRedirect());
    }

    @isTest
    static void buildConsentFormActiveConsentPageSetsCompletionFlags() {
        PageReference pageRef = QRSiteApprovalNavigationService.buildConsentFormActiveConsentPage(
            '003000000000001AAA'
        );
        System.assertNotEquals(null, pageRef);
        System.assertEquals('003000000000001AAA', pageRef.getParameters().get('ContactId'));
        System.assertEquals('true', pageRef.getParameters().get('completed'));
        System.assertEquals('true', pageRef.getParameters().get('activeConsent'));
        System.assertEquals(true, pageRef.getRedirect());
    }

    @isTest
    static void buildWithdrawConsentPageSkipsBlankParams() {
        PageReference pageRef = QRSiteApprovalNavigationService.buildWithdrawConsentPage(
            '003000000000001AAA',
            null,
            '',
            'token-123'
        );
        System.assertNotEquals(null, pageRef);
        System.assertEquals('003000000000001AAA', pageRef.getParameters().get('ContactId'));
        System.assertEquals(null, pageRef.getParameters().get('id'));
        System.assertEquals(null, pageRef.getParameters().get('requestItemId'));
        System.assertEquals('token-123', pageRef.getParameters().get('token'));
        System.assertEquals(true, pageRef.getRedirect());
    }
}