public without sharing class CbsExperienceLoginController {
    private static final String LOGIN_ERROR_MESSAGE = 'Your login attempt has failed. Please check your username and password.';
    private static final String RESET_PASSWORD_SUCCESS_MESSAGE = 'If the username is valid, you will receive an email with password reset instructions.';
    private static final String DEFAULT_START_URL = '/s/';
    @TestVisible
    private static String testLoginResultUrl;
    @TestVisible
    private static Boolean testForceLoginFailure = false;

    @AuraEnabled
    public static String login(String username, String password, Boolean rememberMe, String startUrl) {
        String targetStartUrl = resolveStartUrl(startUrl);

        try {
            if (Test.isRunningTest()) {
                if (testForceLoginFailure) {
                    throw buildLoginFailureException();
                }
                if (!String.isBlank(testLoginResultUrl)) {
                    return testLoginResultUrl;
                }
            }

            PageReference pageRef = Site.login(username, password, targetStartUrl);
            if (pageRef != null) {
                return pageRef.getUrl();
            }
            throw buildLoginFailureException();
        } catch (Exception ex) {
            if (ex instanceof AuraHandledException) {
                throw ex;
            }
            throw buildLoginFailureException();
        }
    }

    @AuraEnabled
    public static String resetPassword(String username) {
        if (String.isBlank(username)) {
            throw new AuraHandledException('Please enter your username.');
        }

        try {
            Site.forgotPassword(username.trim());
        } catch (Exception ex) {
            // Do not expose whether the username exists.
        }

        return RESET_PASSWORD_SUCCESS_MESSAGE;
    }

    @TestVisible
    private static String resolveStartUrl(String startUrl) {
        if (String.isBlank(startUrl)) {
            return DEFAULT_START_URL;
        }

        String normalized = startUrl.trim();
        String lowered = normalized.toLowerCase();

        if (!normalized.startsWith('/')) {
            return DEFAULT_START_URL;
        }

        if (lowered.startsWith('http://') || lowered.startsWith('https://') || lowered.startsWith('//')) {
            return DEFAULT_START_URL;
        }

        return normalized;
    }

    private static AuraHandledException buildLoginFailureException() {
        AuraHandledException loginEx = new AuraHandledException(LOGIN_ERROR_MESSAGE);
        loginEx.setMessage(LOGIN_ERROR_MESSAGE);
        return loginEx;
    }
}