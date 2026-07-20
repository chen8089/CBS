public without sharing class CbsForgotPasswordController {
    private static final String SUCCESS_MESSAGE =
        'If the username is valid, you will receive an email with password reset instructions.';
    private static final String GENERIC_ERROR_MESSAGE =
        'We could not process your request right now. Please try again later.';

    @AuraEnabled
    public static String resetPassword(String username) {
        String normalizedUsername = String.isBlank(username) ? '' : username.trim();
        if (String.isBlank(normalizedUsername)) {
            throw new AuraHandledException('Please enter your username.');
        }

        try {
            Site.forgotPassword(normalizedUsername);
            return SUCCESS_MESSAGE;
        } catch (Exception ex) {
            throw new AuraHandledException(GENERIC_ERROR_MESSAGE);
        }
    }
}