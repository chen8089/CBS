@isTest
private class MyInfoMatchServiceTest {
    @isTest
    static void evaluateIdentityMatchReturnsMatchedWhenIdMatchesAndDobMatches() {
        MyInfoMatchService.MatchResult result = MyInfoMatchService.evaluateIdentityMatch(
            's1234567a',
            Date.newInstance(1990, 1, 1),
            new List<String>{ 'S1234567A', 'F7654321N' },
            Date.newInstance(1990, 1, 1)
        );

        System.assertEquals(true, result.matched);
        System.assertEquals(MyInfoMatchService.RESULT_MATCHED, result.resultCode);
    }

    @isTest
    static void evaluateIdentityMatchReturnsMismatchIdWhenIdDoesNotMatch() {
        MyInfoMatchService.MatchResult result = MyInfoMatchService.evaluateIdentityMatch(
            'S0000000A',
            null,
            new List<String>{ 'S1234567A' },
            null
        );

        System.assertEquals(false, result.matched);
        System.assertEquals(MyInfoMatchService.RESULT_MISMATCH_ID, result.resultCode);
    }

    @isTest
    static void evaluateIdentityMatchReturnsMismatchDobWhenDobConflicts() {
        MyInfoMatchService.MatchResult result = MyInfoMatchService.evaluateIdentityMatch(
            'S1234567A',
            Date.newInstance(1990, 1, 1),
            new List<String>{ 'S1234567A' },
            Date.newInstance(1991, 1, 1)
        );

        System.assertEquals(false, result.matched);
        System.assertEquals(MyInfoMatchService.RESULT_MISMATCH_DOB, result.resultCode);
    }

    @isTest
    static void evaluateIdentityMatchReturnsInsufficientDataWhenInputIdMissing() {
        MyInfoMatchService.MatchResult result = MyInfoMatchService.evaluateIdentityMatch(
            null,
            Date.newInstance(1990, 1, 1),
            new List<String>{ 'S1234567A' },
            Date.newInstance(1990, 1, 1)
        );

        System.assertEquals(false, result.matched);
        System.assertEquals(MyInfoMatchService.RESULT_INSUFFICIENT_DATA, result.resultCode);
    }
}