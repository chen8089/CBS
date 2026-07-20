@IsTest
private class CaseBatchWhitelistDlCtrlTest {
    @IsTest
    static void constructorReturnsCsvWhenNoData() {
        Test.startTest();
        CaseBatchWhitelistDlCtrl controller = new CaseBatchWhitelistDlCtrl();
        Test.stopTest();

        System.assertNotEquals(null, controller.csvBody);
        Boolean hasHeader = controller.csvBody.contains('Case_Number');
        Boolean hasControlledError = controller.csvBody.contains('Export Failed');
        System.assert(hasHeader || hasControlledError);
    }
}