/**
 * Non-Singpass consent page controller for 1-month consent wording.
 * Reuses existing employee non-singpass flow behaviour and data resolution.
 */
public without sharing class QRSiteNonSingpassOneMonthConsentCtrl {
    private static final String TYPE_PREHIRE = 'prehire';
    private QRSiteNonSingpassEmpImportantNotesCtrl baseCtrl;

    public QRSiteNonSingpassOneMonthConsentCtrl() {
        baseCtrl = new QRSiteNonSingpassEmpImportantNotesCtrl();
        baseCtrl.expectedFlowType = TYPE_PREHIRE;
    }

    public PageReference initPage() {
        if (String.isBlank(baseCtrl.entryType)) {
            baseCtrl.entryType = TYPE_PREHIRE;
        }
        if (String.isBlank(baseCtrl.entrySubjectType)) {
            baseCtrl.entrySubjectType = TYPE_PREHIRE;
        }
        return baseCtrl.initPage();
    }

    public String getContactId() {
        return baseCtrl.contactId;
    }
    public void setContactId(String value) {
        baseCtrl.contactId = value;
    }

    public String getRequestItemId() {
        return baseCtrl.requestItemId;
    }
    public void setRequestItemId(String value) {
        baseCtrl.requestItemId = value;
    }

    public String getToken() {
        return baseCtrl.token;
    }
    public void setToken(String value) {
        baseCtrl.token = value;
    }

    public String getEntryAction() {
        return baseCtrl.entryAction;
    }
    public void setEntryAction(String value) {
        baseCtrl.entryAction = value;
    }

    public String getEntryType() {
        return baseCtrl.entryType;
    }
    public void setEntryType(String value) {
        baseCtrl.entryType = value;
    }

    public String getEntryAuthType() {
        return baseCtrl.entryAuthType;
    }
    public void setEntryAuthType(String value) {
        baseCtrl.entryAuthType = value;
    }

    public String getEntrySubjectType() {
        return baseCtrl.entrySubjectType;
    }
    public void setEntrySubjectType(String value) {
        baseCtrl.entrySubjectType = value;
    }

    public Boolean getShowPage() {
        return baseCtrl.showPage;
    }

    public Boolean getHasAcceptedConsent() {
        return baseCtrl.hasAcceptedConsent;
    }
    public void setHasAcceptedConsent(Boolean value) {
        baseCtrl.hasAcceptedConsent = value;
    }

    public String getSubmissionTitle() {
        return baseCtrl.getSubmissionTitle();
    }
    public String getDisplayDataSubjectName() {
        return baseCtrl.getDisplayDataSubjectName();
    }
    public String getDisplayPrincipalName() {
        return baseCtrl.getDisplayPrincipalName();
    }
    public String getDisplayPassType() {
        return baseCtrl.getDisplayPassType();
    }
    public String getDisplayIdNumber() {
        return baseCtrl.getDisplayIdNumber();
    }
    public String getDisplayPassportNumber() {
        return baseCtrl.getDisplayPassportNumber();
    }
    public String getDisplayDateOfBirth() {
        return baseCtrl.getDisplayDateOfBirth();
    }
    public String getDisplayNationality() {
        return baseCtrl.getDisplayNationality();
    }
    public String getDisplayGender() {
        return baseCtrl.getDisplayGender();
    }
    public String getDisplayMaritalStatus() {
        return baseCtrl.getDisplayMaritalStatus();
    }
    public String getDisplayRegisteredAddress() {
        return baseCtrl.getDisplayRegisteredAddress();
    }
    public String getDisplayEmailSubjectTitle() {
        return baseCtrl.getDisplayEmailSubjectTitle();
    }
    public String getBankName() {
        return baseCtrl.getBankName();
    }
    public String getSupportingDocumentsNote() {
        return baseCtrl.getSupportingDocumentsNote();
    }
    public String getConsentCheckboxIntro() {
        return baseCtrl.getConsentCheckboxIntro();
    }
    public List<String> getConsentAuthorisationParagraphs() {
        return baseCtrl.getConsentAuthorisationParagraphs();
    }
    public String getConsentValidityIntro() {
        return baseCtrl.getConsentValidityIntro();
    }
    public List<String> getDisclaimerParagraphs() {
        return baseCtrl.getDisclaimerParagraphs();
    }
    public String getSubmitButtonLabel() {
        return baseCtrl.getSubmitButtonLabel();
    }

    public String getInputPrincipalName() {
        return baseCtrl.inputPrincipalName;
    }
    public void setInputPrincipalName(String value) {
        baseCtrl.inputPrincipalName = value;
    }

    public String getInputIdType() {
        return baseCtrl.inputIdType;
    }
    public void setInputIdType(String value) {
        baseCtrl.inputIdType = value;
    }

    public String getInputIdNumber() {
        return baseCtrl.inputIdNumber;
    }
    public void setInputIdNumber(String value) {
        baseCtrl.inputIdNumber = value;
    }

    public String getInputPassType() {
        return baseCtrl.inputPassType;
    }
    public void setInputPassType(String value) {
        baseCtrl.inputPassType = value;
    }

    public String getInputPassportNumber() {
        return baseCtrl.inputPassportNumber;
    }
    public void setInputPassportNumber(String value) {
        baseCtrl.inputPassportNumber = value;
    }

    public Date getInputDateOfBirth() {
        return baseCtrl.inputDateOfBirth;
    }
    public void setInputDateOfBirth(Date value) {
        baseCtrl.inputDateOfBirth = value;
    }

    public String getInputNationality() {
        return baseCtrl.inputNationality;
    }
    public void setInputNationality(String value) {
        baseCtrl.inputNationality = value;
    }

    public String getInputGender() {
        return baseCtrl.inputGender;
    }
    public void setInputGender(String value) {
        baseCtrl.inputGender = value;
    }

    public String getInputMaritalStatus() {
        return baseCtrl.inputMaritalStatus;
    }
    public void setInputMaritalStatus(String value) {
        baseCtrl.inputMaritalStatus = value;
    }

    public String getInputRegisteredAddress() {
        return baseCtrl.inputRegisteredAddress;
    }
    public void setInputRegisteredAddress(String value) {
        baseCtrl.inputRegisteredAddress = value;
    }

    public List<String> getConsentValidityItems() {
        return new List<String>{
            'the date falling ten (10) business days after such consent and authorisation is revoked by me or by '
                + getBankName()
                + '; or',
            'the expiry of the applicable period, being one (1) month from the date of this consent, unless withdrawn earlier.'
        };
    }

    public PageReference submitConsent() {
        baseCtrl.hasAcceptedConsent = getHasAcceptedConsent();
        return baseCtrl.submitConsent();
    }
}