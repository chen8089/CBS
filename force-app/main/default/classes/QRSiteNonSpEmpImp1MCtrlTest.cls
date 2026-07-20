@IsTest
private class QRSiteNonSpEmpImp1MCtrlTest {
    @IsTest
    static void testOneMonthConsentValidityText() {
        Test.setCurrentPage(new PageReference('/apex/QRSiteNonSpEmpImp1M'));

        QRSiteNonSpEmpImp1MCtrl ctrl = new QRSiteNonSpEmpImp1MCtrl();
        List<String> validityItems = ctrl.getConsentValidityItems();

        System.assertEquals(2, validityItems.size(), 'Expected exactly two validity clauses.');
        System.assert(validityItems[0].contains('ten (10) business days'), 'First clause should include ten business days.');
        System.assert(
            validityItems[1].contains('one (1) month'),
            'Second clause should use one-month validity wording.'
        );
    }
}