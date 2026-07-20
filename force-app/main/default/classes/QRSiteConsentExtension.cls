public without sharing class QRSiteConsentExtension {
    private ApexPages.StandardController stdController;
    private Id consentId;

    public QRSiteConsentExtension(ApexPages.StandardController stdController) {
        this.stdController = stdController;
        this.consentId = stdController.getId();
    }

    // 点击按钮触发的撤销方法
    public PageReference withdrawConsent() {
        PageReference nextPage;

        if (consentId != null) {
            try {
                List<Consent__c> consentList = [
                    SELECT Id, Data_Subject__c, Consent_Status__c
                    FROM Consent__c
                    WHERE Id = :consentId
                    LIMIT 1
                ];

                Consent__c existingConsent;
                for (Consent__c consent : consentList) {
                    existingConsent = consent;
                }

                if (existingConsent != null) {
                    nextPage = Page.QRSiteWithdrawQrPage;
                    nextPage.getParameters().put('ContactId', existingConsent.Data_Subject__c);
                    nextPage.getParameters().put('id', existingConsent.Id);
                    nextPage.setRedirect(true);
                }
            } catch (Exception e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Withdrawal failed: ' + e.getMessage()));
            }
        }

        return nextPage;
    }
}