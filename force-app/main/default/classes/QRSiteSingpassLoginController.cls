public with sharing class QRSiteSingpassLoginController {
    private static final String DEFAULT_RETURN_URL = '/apex/QRSiteSingpassEmployeeConsentForm';

    public Boolean isMockApprovalStep { get; private set; }
    public Boolean isLoggedIn { get; private set; }
    public Boolean hasError { get; private set; }
    public String statusMessage { get; private set; }
    public MockUser userInfo { get; private set; }

    private String contactId;
    private String requestItemId;
    private String token;
    private String entryAction;
    private String entryType;
    private String entryAuthType;
    private String returnUrl;
    
    public QRSiteSingpassLoginController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        captureContextParams(params);
        isMockApprovalStep = params.get('step') == 'mock';
        isLoggedIn = params.get('singpass_login') == 'success';
        hasError = String.isNotBlank(params.get('error'));
        
        if (isLoggedIn) {
            userInfo = getMockUser();
            statusMessage = 'Singpass sign-in successful (Mock mode). Account linking can be completed in Salesforce next.';
            return;
        }
        
        if (hasError) {
            statusMessage = params.get('error');
            return;
        }
        
        if (isMockApprovalStep) {
            statusMessage = 'Simulated Singpass scan-and-confirm page. After you confirm, you will return to Visualforce with mock MyInfo profile data.';
            return;
        }
        
        statusMessage = 'Not signed in yet. This page uses Visualforce and Apex to run the development Mock flow directly.';
    }
    
    public PageReference startMockLogin() {
        PageReference nextPage = new PageReference('/apex/QRSiteSingpassLogin');
        copyContextParams(nextPage);
        nextPage.getParameters().put('step', 'mock');
        nextPage.getParameters().put('state', createState());
        nextPage.getParameters().put('nonce', createState());
        nextPage.setRedirect(true);
        return nextPage;
    }
    
    public PageReference approveMockLogin() {
        PageReference nextPage = new PageReference(resolveReturnUrl());
        copyContextParams(nextPage);
        copyMockUserParams(nextPage, getMockUser());
        nextPage.getParameters().put('singpass_login', 'success');
        nextPage.getParameters().put('mock', 'true');
        nextPage.setRedirect(true);
        return nextPage;
    }
    
    public PageReference startRealSingpassLogin() {
        ApexPages.addMessage(
            new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Real Singpass FAPI must be implemented in Apex with PAR, DPoP, private_key_jwt signing, and callback token exchange. This page currently provides the internal Salesforce Mock flow only.'
            )
        );
        hasError = true;
        statusMessage = 'Real Singpass FAPI is not configured yet. Prepare the signing key, kid, callback URL, and Named Credential/certificate setup first.';
        return null;
    }
    
    public PageReference clearStatus() {
        PageReference nextPage = new PageReference('/apex/QRSiteSingpassLogin');
        copyContextParams(nextPage);
        nextPage.setRedirect(true);
        return nextPage;
    }

    private void captureContextParams(Map<String, String> params) {
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        token = params.get('token');
        entryAction = params.get('action');
        entryType = params.get('type');
        entryAuthType = params.get('authType');
        returnUrl = params.get('returnUrl');
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }
        putIfNotBlank(targetPage, 'contactId', contactId);
        putIfNotBlank(targetPage, 'requestItemId', requestItemId);
        putIfNotBlank(targetPage, 'token', token);
        putIfNotBlank(targetPage, 'action', entryAction);
        putIfNotBlank(targetPage, 'type', entryType);
        putIfNotBlank(targetPage, 'authType', entryAuthType);
        putIfNotBlank(targetPage, 'returnUrl', returnUrl);
    }

    private String resolveReturnUrl() {
        String targetUrl = String.isBlank(returnUrl) ? DEFAULT_RETURN_URL : returnUrl;
        try {
            targetUrl = EncodingUtil.urlDecode(targetUrl, 'UTF-8');
        } catch (Exception e) {
            targetUrl = DEFAULT_RETURN_URL;
        }

        if (targetUrl.startsWith('/apex/')) {
            return targetUrl;
        }
        return DEFAULT_RETURN_URL;
    }

    private static void putIfNotBlank(PageReference targetPage, String paramName, String paramValue) {
        if (!String.isBlank(paramValue)) {
            targetPage.getParameters().put(paramName, paramValue);
        }
    }

    private static void copyMockUserParams(PageReference targetPage, MockUser mockUser) {
        if (targetPage == null || mockUser == null) {
            return;
        }
        putIfNotBlank(targetPage, 'mockSub', mockUser.sub);
        putIfNotBlank(targetPage, 'mockName', mockUser.name);
        putIfNotBlank(targetPage, 'mockGivenName', mockUser.givenName);
        putIfNotBlank(targetPage, 'mockFamilyName', mockUser.familyName);
        putIfNotBlank(targetPage, 'mockEmail', mockUser.email);
        putIfNotBlank(targetPage, 'mockUinfin', mockUser.uinfin);
        putIfNotBlank(targetPage, 'mockMobileNo', mockUser.mobileNo);
        putIfNotBlank(targetPage, 'mockDateOfBirth', mockUser.dateOfBirth);
        putIfNotBlank(targetPage, 'mockNationality', mockUser.nationality);
        putIfNotBlank(targetPage, 'mockIdType', mockUser.idType);
        putIfNotBlank(targetPage, 'mockGender', mockUser.gender);
        putIfNotBlank(targetPage, 'mockMaritalStatus', mockUser.maritalStatus);
        putIfNotBlank(targetPage, 'mockPassType', mockUser.passType);
        putIfNotBlank(targetPage, 'mockRegisteredAddress', mockUser.registeredAddress);
        putIfNotBlank(targetPage, 'mockPassportNumber', mockUser.passportNumber);
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        return !String.isBlank(firstValue) ? firstValue : secondValue;
    }
    
    private static String createState() {
        Blob randomBytes = Crypto.generateAesKey(256);
        return EncodingUtil.convertToHex(randomBytes);
    }
    
    private static MockUser getMockUser() {
        MockUser mockUser = new MockUser();
        mockUser.sub = 'mock-singpass-user-001';
        mockUser.name = 'Tan Mei Ling';
        mockUser.givenName = 'Mei Ling';
        mockUser.familyName = 'Tan';
        mockUser.email = 'meiling.tan@example.com';
        mockUser.uinfin = 'S1234567D';
        mockUser.mobileNo = '+6591234567';
        mockUser.dateOfBirth = '1990-05-15';
        mockUser.nationality = 'Singapore Citizen';
        mockUser.idType = 'NRIC';
        mockUser.gender = 'Female';
        mockUser.maritalStatus = 'Single';
        mockUser.passType = 'NRIC';
        mockUser.registeredAddress = '1 North Bridge Road, #01-01, Singapore 179094';
        mockUser.passportNumber = '666666';
        return mockUser;
    }
    
    public class MockUser {
        public String sub { get; set; }
        public String name { get; set; }
        public String givenName { get; set; }
        public String familyName { get; set; }
        public String email { get; set; }
        public String uinfin { get; set; }
        public String mobileNo { get; set; }
        public String dateOfBirth { get; set; }
        public String nationality { get; set; }
        public String idType { get; set; }
        public String gender { get; set; }
        public String maritalStatus { get; set; }
        public String passType { get; set; }
        public String registeredAddress { get; set; }
        public String passportNumber { get; set; }
    }
}