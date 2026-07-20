/**
 * Wrapper controller for Non-Singpass employee one-month consent page.
 * Reuses QRSiteNonSingpassEmpImportantNotesCtrl behavior and swaps only
 * the consent validity text to match the one-month template.
 */
public without sharing class QRSiteNonSpEmpImp1MCtrl {
    private QRSiteNonSingpassEmpImportantNotesCtrl baseCtrl;

    public QRSiteNonSpEmpImp1MCtrl() {
        baseCtrl = new QRSiteNonSingpassEmpImportantNotesCtrl();
    }

    public PageReference initPage() { return baseCtrl.initPage(); }
    public PageReference submitConsent() { return baseCtrl.submitConsent(); }

    public String getContactId() { return baseCtrl.contactId; }
    public void setContactId(String value) { baseCtrl.contactId = value; }
    public String getRequestItemId() { return baseCtrl.requestItemId; }
    public void setRequestItemId(String value) { baseCtrl.requestItemId = value; }
    public String getToken() { return baseCtrl.token; }
    public void setToken(String value) { baseCtrl.token = value; }
    public String getEntryAction() { return baseCtrl.entryAction; }
    public void setEntryAction(String value) { baseCtrl.entryAction = value; }
    public String getEntryType() { return baseCtrl.entryType; }
    public void setEntryType(String value) { baseCtrl.entryType = value; }
    public String getEntryAuthType() { return baseCtrl.entryAuthType; }
    public void setEntryAuthType(String value) { baseCtrl.entryAuthType = value; }
    public String getEntrySubjectType() { return baseCtrl.entrySubjectType; }
    public void setEntrySubjectType(String value) { baseCtrl.entrySubjectType = value; }

    public Boolean getShowPage() { return baseCtrl.showPage; }
    public Boolean getHasAcceptedConsent() { return baseCtrl.hasAcceptedConsent; }
    public void setHasAcceptedConsent(Boolean value) { baseCtrl.hasAcceptedConsent = value; }

    public String getSubmissionTitle() { return baseCtrl.getSubmissionTitle(); }
    public String getDisplayDataSubjectName() { return baseCtrl.getDisplayDataSubjectName(); }
    public String getDisplayPrincipalName() { return baseCtrl.getDisplayPrincipalName(); }
    public String getDisplayPassType() { return baseCtrl.getDisplayPassType(); }
    public String getDisplayIdNumber() { return baseCtrl.getDisplayIdNumber(); }
    public String getDisplayPassportNumber() { return baseCtrl.getDisplayPassportNumber(); }
    public String getDisplayDateOfBirth() { return baseCtrl.getDisplayDateOfBirth(); }
    public String getDisplayNationality() { return baseCtrl.getDisplayNationality(); }
    public String getDisplayGender() { return baseCtrl.getDisplayGender(); }
    public String getDisplayMaritalStatus() { return baseCtrl.getDisplayMaritalStatus(); }
    public String getDisplayRegisteredAddress() { return baseCtrl.getDisplayRegisteredAddress(); }
    public String getBankName() { return baseCtrl.getBankName(); }
    public String getDisplayEmailSubjectTitle() { return baseCtrl.getDisplayEmailSubjectTitle(); }
    public String getSupportingDocumentsNote() { return baseCtrl.getSupportingDocumentsNote(); }
    public String getConsentCheckboxIntro() { return baseCtrl.getConsentCheckboxIntro(); }
    public List<String> getConsentAuthorisationParagraphs() { return baseCtrl.getConsentAuthorisationParagraphs(); }
    public String getConsentValidityIntro() { return baseCtrl.getConsentValidityIntro(); }
    public List<String> getDisclaimerParagraphs() { return baseCtrl.getDisclaimerParagraphs(); }
    public String getSubmitButtonLabel() { return baseCtrl.getSubmitButtonLabel(); }

    public List<String> getConsentValidityItems() {
        return new List<String>{
            'the date falling ten (10) business days after such consent and authorisation is revoked by me or by '
                + getBankName()
                + '; or',
            'the expiry of the applicable period, being one (1) month from the date of this consent, unless withdrawn earlier.'
        };
    }
}