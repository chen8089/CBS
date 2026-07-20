@IsTest
private class SiteTokenServiceTest {
    @IsTest
    static void testHashAndValidate() {
        String hash = SiteTokenService.hashToken('abc-token');
        System.assertNotEquals(null, hash);
        System.assertEquals(64, hash.length());

        SiteTokenService.TokenValidationResult validResult =
            SiteTokenService.validateToken('abc-token', System.now().addMinutes(10), 'Pending');
        System.assertEquals(true, validResult.isValid);
        System.assertEquals('TOKEN_VALID', validResult.reasonCode);
        System.assertEquals(hash, validResult.tokenHash);
    }

    @IsTest
    static void testInvalidStates() {
        SiteTokenService.TokenValidationResult expiredResult =
            SiteTokenService.validateToken('abc-token', System.now().addMinutes(-1), 'Pending');
        System.assertEquals(false, expiredResult.isValid);
        System.assertEquals('TOKEN_EXPIRED', expiredResult.reasonCode);

        SiteTokenService.TokenValidationResult actionedResult =
            SiteTokenService.validateToken('abc-token', System.now().addMinutes(5), 'Already Actioned');
        System.assertEquals(false, actionedResult.isValid);
        System.assertEquals('TOKEN_ALREADY_ACTIONED', actionedResult.reasonCode);
    }
}