@IsTest
private class HmacMatchServiceTest {
    private class FakeSecretProvider implements HmacMatchService.SecretProvider {
        public Blob getSecret() {
            return Blob.valueOf('TEST_ONLY_SECRET');
        }
    }

    @IsTest
    static void testNormalizeFunctions() {
        System.assertEquals('S1234567A', HmacMatchService.normalizeIdNumber(' s1234567a '));
        System.assertEquals('2026-01-02', HmacMatchService.normalizeDob(Date.newInstance(2026, 1, 2)));
    }

    @IsTest
    static void testComputeCompositeHmac() {
        HmacMatchService.setSecretProvider(new FakeSecretProvider());
        String value1 = HmacMatchService.computeCompositeMatchHmac('s1234567a', Date.newInstance(2000, 1, 1), UserInfo.getUserId());
        String value2 = HmacMatchService.computeCompositeMatchHmac('S1234567A', Date.newInstance(2000, 1, 1), UserInfo.getUserId());
        System.assertNotEquals(null, value1);
        System.assertEquals(value1, value2);
        HmacMatchService.setSecretProvider(null);
    }

    @IsTest
    static void testMissingSecret() {
        HmacMatchService.setSecretProvider(null);
        Boolean gotException = false;
        try {
            HmacMatchService.computeHmacHex('abc');
        } catch (HmacMatchService.MissingSecretException ex) {
            gotException = true;
        }
        System.assertEquals(true, gotException);
    }
}