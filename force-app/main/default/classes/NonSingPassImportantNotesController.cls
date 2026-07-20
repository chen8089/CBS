public without sharing class NonSingPassImportantNotesController {
    public String contactId { get; set; }
    private Consent_Request_Item__c latestRequestItemRecord;
    private Contact contactRecord;
    private String tokenValue;
    private Boolean entryValidated = false;
    private Boolean entryIsValid = false;

    public NonSingPassImportantNotesController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = params.get('ContactId');
        tokenValue = params.get('token');
        validateEntryContext();
    }

    public String getImportantNotesTitle() {
        return entryIsValid ? 'Important Notes' : 'Invalid Link';
    }

    public List<String> getImportantNotesList() {
        if (entryIsValid) {
            return new List<String>{
                'You have received this link from your employer\'s HR team to provide consent for Credit Bureau Singapore ("CBS") to retrieve your MyInfo details for employment-related credit assessment purposes.',
                'To proceed, click the button below to review and submit your details on the consent form.',
                'The information you submit may include your principal name, pass type, passport number, nationality, date of birth, gender, marital status, and registered address.',
                'This information will be used only for the purpose of processing your employer\'s authorised credit report request through CBS.',
                'Please review the consent form carefully before submitting. By submitting the form, you confirm that you authorise CBS to collect, use, and disclose the relevant information for the stated purpose.',
                'If you do not wish to provide consent, please contact your HR representative before proceeding.'
            };
        }

        return new List<String>{
            'This link is missing a valid ContactId and secure token. Please use the latest link from your email.'
        };
    }

    public Boolean getHasValidEntryAction() {
        return entryIsValid;
    }

    public String getImportantNotesButtonMain() {
        return 'Continue to Consent Form';
    }

    public String getImportantNotesButtonSub() {
        return '';
    }

    public PageReference goToNextPage() {
        if (!entryIsValid) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid link or missing parameter (ContactId/token).'));
            return null;
        }

        Contact contact = getContactRecord();
        if (contact == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'The link is invalid or has expired.'));
            return null;
        }

        String lifecycleCanonical = ConsentStatusModelService.normalizeLifecycleStage(contact.Data_Subject_Lifecycle_Stage__c);
        String statusCanonical = ConsentStatusModelService.normalizeContactConsentStatus(contact.Current_Consent_Status__c);
        if (lifecycleCanonical == ConsentStatusModelService.STATUS_ACTIVE
            && statusCanonical == ConsentStatusModelService.STATUS_ACTIVE) {
            return redirectToActiveConsentPage();
        }

        Consent_Request_Item__c requestItem = resolveAuthorizedRequestItem();
        if (requestItem == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Authorization request was not found.'));
            return null;
        }

        String entryType = ApexPages.currentPage().getParameters().get('type');
        String subjectType = ApexPages.currentPage().getParameters().get('subjectType');
        Boolean isPrehireFlow =
            'prehire'.equalsIgnoreCase(String.valueOf(entryType))
            || 'prehire'.equalsIgnoreCase(String.valueOf(subjectType));

        PageReference nextPage = isPrehireFlow
            ? Page.QRSiteNonSingpassOneMonthConsent
            : Page.QRSiteNonSingpassEmployeeImportantNotes;
        nextPage.getParameters().put('ContactId', contactId);
        nextPage.getParameters().put('requestItemId', requestItem.Id);
        nextPage.getParameters().put('token', tokenValue);
        nextPage.getParameters().put('action', 'authorize');
        nextPage.getParameters().put('type', isPrehireFlow ? 'prehire' : 'employee');
        nextPage.getParameters().put('authType', 'nonsingpass');
        nextPage.getParameters().put('subjectType', isPrehireFlow ? 'prehire' : 'employee');
        if (!String.isBlank(subjectType)) {
            nextPage.getParameters().put('subjectType', subjectType);
        }

        nextPage.setRedirect(true);
        return nextPage;
    }

    private void validateEntryContext() {
        if (entryValidated) {
            return;
        }
        entryValidated = true;
        entryIsValid = false;

        Id parsedContactId = parseContactId();
        if (parsedContactId == null || String.isBlank(tokenValue)) {
            return;
        }

        Consent_Request_Item__c requestItem = resolveAuthorizedRequestItem();
        entryIsValid = ConsentGuestAuthService.isTokenValidForRequestItem(
            requestItem,
            tokenValue,
            parsedContactId
        );
    }

    private Consent_Request_Item__c resolveAuthorizedRequestItem() {
        Id parsedContactId = parseContactId();
        if (parsedContactId == null || String.isBlank(tokenValue)) {
            return null;
        }

        String tokenField = ConsentGuestAuthService.resolveTokenFieldApiName();
        String requestItemId = ApexPages.currentPage().getParameters().get('requestItemId');
        if (!String.isBlank(requestItemId)) {
            String byIdSoql;
            if (!String.isBlank(tokenField)) {
                byIdSoql =
                    'SELECT Id, Data_Subject__c, Consent_Link_Expires_At__c, ' + tokenField +
                    ' FROM Consent_Request_Item__c'
                    + ' WHERE Id = :requestItemId'
                    + ' AND Data_Subject__c = :parsedContactId'
                    + ' AND ' + tokenField + ' = :tokenValue'
                    + ' LIMIT 1';
            } else {
                byIdSoql =
                    'SELECT Id, Data_Subject__c, Consent_Link_Expires_At__c'
                    + ' FROM Consent_Request_Item__c'
                    + ' WHERE Id = :requestItemId'
                    + ' AND Data_Subject__c = :parsedContactId'
                    + ' LIMIT 1';
            }
            List<Consent_Request_Item__c> byId = Database.query(byIdSoql);
            if (!byId.isEmpty()) {
                latestRequestItemRecord = byId[0];
                return latestRequestItemRecord;
            }
        }

        if (String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT Id, Data_Subject__c, Consent_Link_Expires_At__c, ' + tokenField +
            ' FROM Consent_Request_Item__c'
            + ' WHERE Data_Subject__c = :parsedContactId AND ' + tokenField + ' = :tokenValue'
            + ' ORDER BY CreatedDate DESC LIMIT 1';
        List<Consent_Request_Item__c> requestItems = Database.query(soql);
        latestRequestItemRecord = requestItems.isEmpty() ? null : requestItems[0];
        return latestRequestItemRecord;
    }

    private Contact getContactRecord() {
        if (contactRecord == null && parseContactId() != null) {
            List<Contact> contacts = [
                SELECT Id, Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c, Latest_Submission_Datetime__c, AccountId, Account.Name
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            contactRecord = contacts.isEmpty() ? null : contacts[0];
        }
        return contactRecord;
    }

    private PageReference redirectToActiveConsentPage() {
        PageReference activeConsentPage = Page.QRSiteConsentForm;
        activeConsentPage.getParameters().put('completed', 'true');
        activeConsentPage.getParameters().put('activeConsent', 'true');
        copyContextParams(activeConsentPage);
        activeConsentPage.setRedirect(true);
        return activeConsentPage;
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }

        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('ContactId', contactId);
        }

        List<String> passthroughParams = new List<String>{ 'recordId', 'token', 'action', 'requestId', 'requestItemId', 'consentId', 'id', 'subjectType' };
        for (String key : passthroughParams) {
            String value = ApexPages.currentPage().getParameters().get(key);
            if (!String.isBlank(value)) {
                targetPage.getParameters().put(key, value);
            }
        }
    }

    private Id parseContactId() {
        if (String.isBlank(contactId)) {
            return null;
        }

        try {
            return (Id) contactId;
        } catch (Exception e) {
            return null;
        }
    }
}