@isTest
private class QRSiteSingpassNdiAuthCtrlTest {
    @isTest
    static void initPageRedirectsToInvalidWhenRequiredParamsMissing() {
        Test.setCurrentPage(Page.ndi_auth);

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteInvalidLink'));
    }

    @isTest
    static void initPageLaunchesAuthorizationUrlOnFirstVisit() {
        Test.setCurrentPage(Page.ndi_auth);
        ApexPages.currentPage().getParameters().put('contactId', '003000000000001AAA');
        ApexPages.currentPage().getParameters().put('requestItemId', 'a02000000000001AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-001');
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');

        Test.setMock(HttpCalloutMock.class, new NdiAuthMock(true));

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('https://singpass.example/authorize?state=ok'));
    }

    @isTest
    static void initPageReturnsConsentFormWithMyInfoMockDataOnCallback() {
        Test.setCurrentPage(Page.ndi_auth);
        ApexPages.currentPage().getParameters().put('contactId', '003000000000001AAA');
        ApexPages.currentPage().getParameters().put('requestItemId', 'a02000000000001AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-002');
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('refId', 'cbs-ref-001');

        Test.setMock(HttpCalloutMock.class, new NdiAuthMock(false));

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteSingpassEmployeeConsentForm'));
        System.assertEquals('true', result.getParameters().get('returnFromAuth'));
        System.assertEquals('WATTNA TIWARAT', result.getParameters().get('mockName'));
        System.assertEquals('G4440433N', result.getParameters().get('mockUinfin'));
        System.assertEquals('ARMENIAN', result.getParameters().get('mockNationality'));
        System.assertEquals('FEMALE', result.getParameters().get('mockGender'));
        System.assertEquals('Employment Pass', result.getParameters().get('mockPassType'));
        System.assertEquals('123 LORONG 1 TOA PAYOH #13-220 SINGAPORE 310123', result.getParameters().get('mockRegisteredAddress'));
    }

    @isTest
    static void initPageReturnsPrehireConsentFormWhenSafeReturnUrlProvided() {
        Test.setCurrentPage(Page.ndi_auth);
        ApexPages.currentPage().getParameters().put('contactId', '003000000000001AAA');
        ApexPages.currentPage().getParameters().put('requestItemId', 'a02000000000001AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-003');
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('returnUrl', '/apex/QRSiteSingpassPrehireConsentForm');
        ApexPages.currentPage().getParameters().put('refId', 'cbs-ref-003');

        Test.setMock(HttpCalloutMock.class, new NdiAuthMock(false));

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteSingpassPrehireConsentForm'));
        System.assertEquals('true', result.getParameters().get('returnFromAuth'));
    }

    @isTest
    static void initPageFallsBackToPrehireByTypeWhenReturnUrlUnsafe() {
        Test.setCurrentPage(Page.ndi_auth);
        ApexPages.currentPage().getParameters().put('contactId', '003000000000001AAA');
        ApexPages.currentPage().getParameters().put('requestItemId', 'a02000000000001AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-004');
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        ApexPages.currentPage().getParameters().put('type', 'prehire');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('returnUrl', '/apex/NotAllowedPage');
        ApexPages.currentPage().getParameters().put('refId', 'cbs-ref-004');

        Test.setMock(HttpCalloutMock.class, new NdiAuthMock(false));

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('/apex/QRSiteSingpassPrehireConsentForm'));
        System.assertEquals('true', result.getParameters().get('returnFromAuth'));
    }

    @isTest
    static void withdrawalCallbackRecordsBackendSingpassAuthentication() {
        Contact contactRecord = new Contact(
            LastName = 'NDI Withdrawal Subject',
            Email = 'ndi.withdrawal@example.com',
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'NDI Withdrawal Subject',
            ID_Number__c = 'S1234567A',
            ID_Type__c = 'NRIC'
        );
        insert contactRecord;

        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contactRecord.Id,
            Current_Status__c = 'Submitted',
            Consent_Link_Expires_At__c = System.now().addDays(7),
            Secure_Token__c = 'token-withdrawal-001'
        );
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        insert requestItem;
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
        requestItem = [
            SELECT Id, Secure_Token__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];

        Test.setCurrentPage(Page.ndi_auth);
        ApexPages.currentPage().getParameters().put('contactId', String.valueOf(contactRecord.Id));
        ApexPages.currentPage().getParameters().put('requestItemId', String.valueOf(requestItem.Id));
        ApexPages.currentPage().getParameters().put('token', requestItem.Secure_Token__c);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ApexPages.currentPage().getParameters().put('type', 'employee');
        ApexPages.currentPage().getParameters().put('authType', 'singpass');
        ApexPages.currentPage().getParameters().put('returnUrl', '/apex/SingpassWithdrawalConsentPage');
        ApexPages.currentPage().getParameters().put('refId', 'cbs-ref-withdrawal-001');

        Test.setMock(HttpCalloutMock.class, new NdiAuthMock(false));

        QRSiteSingpassNdiAuthCtrl controller = new QRSiteSingpassNdiAuthCtrl();
        PageReference result = controller.initPage();

        System.assertNotEquals(null, result);
    }

    private class NdiAuthMock implements HttpCalloutMock {
        private final Boolean isAuthorizationFlow;

        NdiAuthMock(Boolean isAuthorizationFlow) {
            this.isAuthorizationFlow = isAuthorizationFlow;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (isAuthorizationFlow == true) {
                System.assertEquals('POST', req.getMethod());
                System.assert(req.getEndpoint().contains('/api/v1/myinfo/authorization-url'));
                res.setBody('{"authorization_url":"https://singpass.example/authorize?state=ok"}');
                return res;
            }

            System.assertEquals('GET', req.getMethod());
            System.assert(req.getEndpoint().contains('/api/v1/myinfo/profile/'));
            res.setBody(
                '{"ref_id":"cbs-ref-001","myinfo_profile":{"person_info":{'
                + '"name":{"value":"WATTNA TIWARAT"},'
                + '"uinfin":{"value":"G4440433N"},'
                + '"dob":{"value":"1960-05-17"},'
                + '"sex":{"desc":"FEMALE"},'
                + '"nationality":{"desc":"ARMENIAN"},'
                + '"passtype":{"desc":"Employment Pass"},'
                + '"regadd":{"block":{"value":"123"},"street":{"value":"LORONG 1 TOA PAYOH"},"floor":{"value":"13"},"unit":{"value":"220"},"country":{"desc":"SINGAPORE"},"postal":{"value":"310123"}}'
                + '}}}'
            );
            return res;
        }
    }
}