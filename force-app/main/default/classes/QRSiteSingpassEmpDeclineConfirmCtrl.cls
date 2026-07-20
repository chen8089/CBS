/**
 * Decline confirmation page for Singpass Employee consent flow.
 * User confirms decline before status is recorded on the declination complete page.
 */
public without sharing class QRSiteSingpassEmpDeclineConfirmCtrl {
    public String contactId { get; set; }
    public String requestItemId { get; set; }
    public String token { get; set; }
    public Boolean showPage { get; private set; }

    public QRSiteSingpassEmpDeclineConfirmCtrl() {
        parseUrlParameters();
        showPage = String.isBlank(contactId) != true;
    }

    public String getBankName() {
        if (String.isBlank(contactId)) {
            return 'your employer';
        }
        try {
            List<Contact> contacts = [
                SELECT Account.Name
                FROM Contact
                WHERE Id = :((Id) contactId)
                LIMIT 1
            ];
            if (!contacts.isEmpty() && contacts[0].Account != null && !String.isBlank(contacts[0].Account.Name)) {
                return contacts[0].Account.Name;
            }
        } catch (Exception e) {
            // Fall through to default label.
        }
        return 'your employer';
    }

    public String getConfirmationTitle() {
        return 'Decline to Give Consent';
    }

    public List<String> getConfirmationMessageLines() {
        String bankName = getBankName();
        return new List<String>{
            'You have chosen to decline to give consent for CBS to collect, receive, use, release and disclose your personal credit information to '
                + bankName
                + ' for employment-related credit assessment / background screening purposes.',
            'If you confirm, CBS will update your consent status as declined and ' + bankName + ' will be notified.',
            bankName + ' will not be able to submit a new credit report request to CBS under this consent request unless valid consent is provided in future.'
        };
    }

    public PageReference confirmDecline() {
        if (String.isBlank(contactId)) {
            return null;
        }

        PageReference declinationPage = new PageReference('/apex/QRSiteDeclinationComplete');
        declinationPage.getParameters().put('ContactId', contactId);
        declinationPage.getParameters().put('contactId', contactId);
        if (!String.isBlank(requestItemId)) {
            declinationPage.getParameters().put('requestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            declinationPage.getParameters().put('token', token);
        }
        declinationPage.setRedirect(true);
        return declinationPage;
    }

    public PageReference goBackToConsentForm() {
        PageReference consentPage = Page.QRSiteSingpassEmployeeConsentForm;
        copyContextParams(consentPage);
        consentPage.setRedirect(true);
        return consentPage;
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        token = params.get('token');
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }
        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('contactId', contactId);
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }
        targetPage.getParameters().put('action', 'authorize');
        targetPage.getParameters().put('type', 'employee');
        targetPage.getParameters().put('authType', 'singpass');
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        return !String.isBlank(firstValue) ? firstValue : secondValue;
    }
}