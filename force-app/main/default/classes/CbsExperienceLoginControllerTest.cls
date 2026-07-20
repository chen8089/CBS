@IsTest
private class CbsExperienceLoginControllerTest {
    @IsTest
    static void resolveStartUrlReturnsDefaultForBlank() {
        System.assertEquals('/s/', CbsExperienceLoginController.resolveStartUrl(null));
        System.assertEquals('/s/', CbsExperienceLoginController.resolveStartUrl(''));
        System.assertEquals('/s/', CbsExperienceLoginController.resolveStartUrl('   '));
    }

    @IsTest
    static void resolveStartUrlRejectsUnsafeValues() {
        System.assertEquals('/s/', CbsExperienceLoginController.resolveStartUrl('dashboard'));
        System.assertEquals('/s/', CbsExperienceLoginController.resolveStartUrl('http://evil.example'));
        System.assertEquals('/s/', CbsExperienceLoginController.resolveStartUrl('https://evil.example'));
        System.assertEquals('/s/', CbsExperienceLoginController.resolveStartUrl('//evil.example/path'));
    }

    @IsTest
    static void resolveStartUrlAllowsRelativePath() {
        System.assertEquals('/s/custom/home', CbsExperienceLoginController.resolveStartUrl('/s/custom/home'));
        System.assertEquals('/target?foo=bar', CbsExperienceLoginController.resolveStartUrl(' /target?foo=bar '));
    }

    @IsTest
    static void loginReturnsRedirectUrlWhenTestHookProvided() {
        CbsExperienceLoginController.testForceLoginFailure = false;
        CbsExperienceLoginController.testLoginResultUrl = '/s/welcome';

        Test.startTest();
        String result = CbsExperienceLoginController.login(
            'partner@example.com',
            'Password123!',
            true,
            '/s/start'
        );
        Test.stopTest();

        System.assertEquals('/s/welcome', result);

        CbsExperienceLoginController.testLoginResultUrl = null;
    }

    @IsTest
    static void loginThrowsFriendlyMessageWhenLoginFails() {
        CbsExperienceLoginController.testLoginResultUrl = null;
        CbsExperienceLoginController.testForceLoginFailure = true;

        Boolean threwException = false;
        try {
            Test.startTest();
            CbsExperienceLoginController.login(
                'partner@example.com',
                'WrongPassword',
                false,
                '/s/start'
            );
            Test.stopTest();
        } catch (Exception ex) {
            threwException = true;
            String msg = ex.getMessage();
            System.assert(
                (msg != null && msg.contains('Your login attempt has failed. Please check your username and password.')) ||
                msg == 'Script-thrown exception',
                'Expected login() to throw a friendly login failure message or platform wrapped equivalent.'
            );
        } finally {
            CbsExperienceLoginController.testForceLoginFailure = false;
        }

        System.assertEquals(true, threwException, 'Expected login() to throw when login fails.');
    }

    @IsTest
    static void loginThrowsWhenSiteLoginUnavailable() {
        CbsExperienceLoginController.testLoginResultUrl = null;
        CbsExperienceLoginController.testForceLoginFailure = false;

        Boolean threwException = false;
        try {
            Test.startTest();
            CbsExperienceLoginController.login(
                'partner@example.com',
                'Password123!',
                false,
                '/s/start'
            );
            Test.stopTest();
        } catch (Exception ex) {
            threwException = true;
            String msg = ex.getMessage();
            System.assert(
                (msg != null && msg.contains('Your login attempt has failed. Please check your username and password.')) ||
                msg == 'Script-thrown exception',
                'Expected login() to throw a friendly login failure message or platform wrapped equivalent.'
            );
        }

        System.assertEquals(true, threwException, 'Expected login() to throw when Site.login does not return a redirect.');
    }

    @IsTest
    static void resetPasswordRejectsBlankUsername() {
        Boolean threwException = false;
        try {
            Test.startTest();
            CbsExperienceLoginController.resetPassword('   ');
            Test.stopTest();
            System.assert(false, 'Expected resetPassword() to throw for blank username.');
        } catch (Exception ex) {
            threwException = true;
            String msg = ex.getMessage();
            System.assert(
                (msg != null && msg.contains('Please enter your username.')) ||
                msg == 'Script-thrown exception'
            );
        }
        System.assertEquals(true, threwException, 'Expected resetPassword() to throw for blank username.');
    }

    @IsTest
    static void resetPasswordAlwaysReturnsGenericSuccessMessage() {
        Test.startTest();
        String result = CbsExperienceLoginController.resetPassword('partner@example.com');
        Test.stopTest();

        System.assertEquals(
            'If the username is valid, you will receive an email with password reset instructions.',
            result
        );
    }
}