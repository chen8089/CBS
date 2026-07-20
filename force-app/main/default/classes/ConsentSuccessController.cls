/**
 * Shared Consent Success confirmation page for all Data Subject consent journeys.
 * Display-only: does not create or update Consent records on page load.
 */
public without sharing class ConsentSuccessController {
    private static final String ERROR_MESSAGE =
        'We are unable to display this consent confirmation. The link may be invalid or expired.';

    private static final Set<String> SUBMITTED_CONTACT_STATUSES = new Set<String>{
        'Authorized', 'Valid', 'Processing', 'Pending Verification', 'Verification Pending'
    };

    public String contactId { get; private set; }
    public String consentId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public String referenceId { get; private set; }

    public Boolean showSuccess { get; private set; }
    public Boolean showError { get; private set; }
    public String errorMessage { get; private set; }

    public String employerBankName { get; private set; }

    private Contact contactRecord;
    private Consent__c consentRecord;
    private Consent_Request_Item__c requestItemRecord;

    public ConsentSuccessController() {
        parseUrlParameters();
        showSuccess = false;
        showError = false;
    }

    public PageReference initPage() {
        try {
            if (!validateAccess()) {
                return null;
            }
            populateDisplayValues();
            showSuccess = true;
            return null;
        } catch (Exception e) {
            markError(ERROR_MESSAGE);
            return null;
        }
    }

    public String getPageTitle() {
        return 'Consent Submitted Successfully';
    }

    public String getSuccessIntroText() {
        return 'Your consent submission has been well received by Credit Bureau (Singapore) Pte Ltd ("CBS").';
    }

    public String getWhatHappensNextTitle() {
        return 'What happens next';
    }

    public String getSingpassSubmissionText() {
        return 'Your consent has been recorded and will be available for the authorised credit report request process.';
    }

    public String getCreditRequestNotificationText() {
        return 'You will receive notification(s) for any credit information request(s) made by '
            + getBankNameForDisplay()
            + ' to CBS during the consent validity period.';
    }

    public String getManualVerificationSubmissionText() {
        return 'Your consent has been recorded, but it will remain pending until CBS completes and reviews the required identity verification. '
            + getBankNameForDisplay()
            + ' will only be able to submit a credit report request after CBS\' approval.';
    }

    public String getWithdrawalSectionTitle() {
        return 'Withdrawal of consent';
    }

    public String getWithdrawalText() {
        return 'If you wish to withdraw your consent, please refer to the original email sent by '
            + getBankAndDepartmentForDisplay()
            + ' and click the withdrawal link provided in that email. You may be required to complete the relevant authentication or identity verification steps before your withdrawal is submitted. Alternatively, you may also reach out to '
            + getBankAndDepartmentForDisplay()
            + ' or CBS at Privacy@creditbureau.com.sg for assistance in processing your withdrawal.';
    }

    public String getWithdrawalTextHtml() {
        return getWithdrawalText().replace(
            'Privacy@creditbureau.com.sg',
            '<a href="mailto:Privacy@creditbureau.com.sg" style="text-decoration: underline;">Privacy@creditbureau.com.sg</a>'
        );
    }

    private String getBankNameForDisplay() {
        return String.isBlank(employerBankName) ? '[NAME OF BANK]' : employerBankName;
    }

    private String getBankAndDepartmentForDisplay() {
        if (String.isBlank(employerBankName) || employerBankName == '[NAME OF BANK]') {
            return '[NAME OF BANK AND DEPARTMENT]';
        }
        return employerBankName + ' Human Resources';
    }

    private Boolean validateAccess() {
        if (String.isBlank(token)) {
            markError(ERROR_MESSAGE);
            return false;
        }

        Id parsedContactId = resolveContactId();
        if (parsedContactId == null) {
            markError(ERROR_MESSAGE);
            return false;
        }

        contactRecord = queryContact(parsedContactId);
        if (contactRecord == null) {
            markError(ERROR_MESSAGE);
            return false;
        }
        contactId = String.valueOf(parsedContactId);

        requestItemRecord = resolveRequestItem(parsedContactId);
        if (!isTokenValidForRequestItem(requestItemRecord, token)) {
            markError(ERROR_MESSAGE);
            return false;
        }

        if (isRequestItemLinkExpired(requestItemRecord)) {
            markError(ERROR_MESSAGE);
            return false;
        }

        consentRecord = resolveConsentRecord(parsedContactId);
        if (!hasSubmittedConsent(parsedContactId)) {
            markError(ERROR_MESSAGE);
            return false;
        }

        return true;
    }

    private Boolean hasSubmittedConsent(Id subjectId) {
        if (consentRecord != null && consentRecord.Submitted_At__c != null) {
            return true;
        }

        String contactStatus = blankIfNull(contactRecord.Current_Consent_Status__c);
        if (SUBMITTED_CONTACT_STATUSES.contains(contactStatus)) {
            return true;
        }

        Datetime latestSubmission = getDatetimeFieldValue(
            contactRecord,
            new List<String>{ 'Latest_Submission_Datetime__c' }
        );
        if (latestSubmission != null) {
            return true;
        }

        if (requestItemRecord != null) {
            String requestStatus = blankIfNull(requestItemRecord.Current_Status__c);
            if (requestStatus == 'Submitted' || requestStatus == 'Pending Verification'
                || requestStatus == 'Verification Pending' || requestStatus == 'Pending') {
                return true;
            }
        }

        List<Consent__c> latestConsents = [
            SELECT Id, Submitted_At__c
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
                AND Submitted_At__c != NULL
            ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];
        if (!latestConsents.isEmpty()) {
            consentRecord = latestConsents[0];
            return true;
        }

        return false;
    }

    private void populateDisplayValues() {
        employerBankName = resolveBankName();
    }

    private String resolveBankName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        return '[NAME OF BANK]';
    }

    private Id resolveContactId() {
        Id parsedContactId = parseId(firstNonBlank(contactId, ApexPages.currentPage().getParameters().get('ContactId')));
        if (parsedContactId != null) {
            return parsedContactId;
        }

        Id parsedConsentId = parseId(consentId);
        if (parsedConsentId != null) {
            List<Consent__c> rows = [
                SELECT Data_Subject__c
                FROM Consent__c
                WHERE Id = :parsedConsentId
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                consentRecord = rows[0];
                return rows[0].Data_Subject__c;
            }
        }

        Id parsedReferenceId = parseId(firstNonBlank(referenceId, requestItemId));
        if (parsedReferenceId != null) {
            List<Consent_Request_Item__c> requestRows = [
                SELECT Data_Subject__c
                FROM Consent_Request_Item__c
                WHERE Id = :parsedReferenceId
                LIMIT 1
            ];
            if (!requestRows.isEmpty()) {
                return requestRows[0].Data_Subject__c;
            }
        }

        return null;
    }

    private Consent__c resolveConsentRecord(Id subjectId) {
        Id parsedConsentId = parseId(consentId);
        if (parsedConsentId != null) {
            List<Consent__c> byId = queryConsentById(parsedConsentId);
            if (!byId.isEmpty() && byId[0].Data_Subject__c == subjectId) {
                return byId[0];
            }
        }

        List<Consent__c> latestRows = queryLatestConsent(subjectId);
        return latestRows.isEmpty() ? null : latestRows[0];
    }

    private List<Consent__c> queryConsentById(Id safeConsentId) {
        Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id', 'Data_Subject__c', 'Consent_Status__c', 'Submitted_At__c', 'Consent_Expiry_Date__c'
        };
        List<String> optional = new List<String>{ 'Match_Status__c', 'Consent_Request_Item__c' };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Consent__c WHERE Id = :safeConsentId LIMIT 1';
        return Database.query(soql);
    }

    private List<Consent__c> queryLatestConsent(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id', 'Data_Subject__c', 'Consent_Status__c', 'Submitted_At__c', 'Consent_Expiry_Date__c'
        };
        List<String> optional = new List<String>{ 'Match_Status__c', 'Consent_Request_Item__c' };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        String soql =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Consent__c WHERE Data_Subject__c = :subjectId ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC LIMIT 1';
        return Database.query(soql);
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'AccountId', 'Account.Name' };
        List<String> optional = new List<String>{
            'Current_Consent_Status__c',
            'Latest_Submission_Datetime__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Consent_Request_Item__c resolveRequestItem(Id subjectId) {
        String requestItemParam = firstNonBlank(
            firstNonBlank(requestItemId, referenceId),
            ApexPages.currentPage().getParameters().get('consentRequestItemId')
        );

        if (!String.isBlank(requestItemParam)) {
            Consent_Request_Item__c byId = queryRequestItemById(requestItemParam);
            if (byId != null) {
                requestItemId = byId.Id;
                return byId;
            }
        }

        Consent_Request_Item__c byToken = queryRequestItemByToken(token);
        if (byToken != null) {
            requestItemId = byToken.Id;
            return byToken;
        }

        List<Consent_Request_Item__c> latestItems = [
            SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :subjectId
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 1
        ];
        if (!latestItems.isEmpty()) {
            requestItemId = latestItems[0].Id;
            return latestItems[0];
        }

        return null;
    }

    private Consent_Request_Item__c queryRequestItemById(String rawId) {
        try {
            Id safeId = (Id) rawId;
            String soql =
                'SELECT ' + String.join(getRequestItemSelectFields(), ',') +
                ' FROM Consent_Request_Item__c WHERE Id = :safeId LIMIT 1';
            List<Consent_Request_Item__c> items = Database.query(soql);
            return items.isEmpty() ? null : items[0];
        } catch (Exception e) {
            return null;
        }
    }

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(fieldMap, new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
        if (String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT ' + String.join(getRequestItemSelectFields(), ',') +
            ' FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';
        List<Consent_Request_Item__c> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private List<String> getRequestItemSelectFields() {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Data_Subject__c', 'Current_Status__c', 'Consent_Link_Expires_At__c' };
        List<String> optional = new List<String>{
            'Token__c',
            'Secure_Token__c',
            'Access_Token__c',
            'Link_Expires_At__c',
            'Expires_At__c',
            'Expiry_Date_Time__c',
            'Token_Expires_At__c',
            'Link_Expiry_DateTime__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        return fields;
    }

    private Boolean isTokenValidForRequestItem(Consent_Request_Item__c requestItem, String tokenValue) {
        return ConsentGuestAuthService.isTokenValidForRequestItem(
            requestItem,
            tokenValue,
            contactRecord != null ? contactRecord.Id : parseId(contactId)
        );
    }

    private Boolean isRequestItemLinkExpired(Consent_Request_Item__c requestItem) {
        if (requestItem == null) {
            return false;
        }

        List<String> expiryFieldCandidates = new List<String>{
            'Consent_Link_Expires_At__c',
            'Link_Expires_At__c',
            'Expires_At__c',
            'Expiry_Date_Time__c',
            'Token_Expires_At__c',
            'Link_Expiry_DateTime__c'
        };
        for (String fieldApi : expiryFieldCandidates) {
            if (!hasField(requestItem, fieldApi)) {
                continue;
            }
            Object rawValue = requestItem.get(fieldApi);
            if (rawValue instanceof Datetime && ((Datetime) rawValue) < System.now()) {
                return true;
            }
            if (rawValue instanceof Date && ((Date) rawValue) < Date.today()) {
                return true;
            }
        }
        return false;
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        consentId = firstNonBlank(params.get('consentId'), params.get('id'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        referenceId = params.get('referenceId');
        token = params.get('token');
    }

    private void markError(String message) {
        showError = true;
        showSuccess = false;
        errorMessage = message;
    }

    private static Datetime getDatetimeFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (hasField(record, fieldApi)) {
                Object rawValue = record.get(fieldApi);
                if (rawValue instanceof Datetime) {
                    return (Datetime) rawValue;
                }
            }
        }
        return null;
    }

    private static String findFirstExistingField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private static Boolean hasField(SObject record, String fieldApi) {
        return record != null
            && record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApi);
    }

    private static Id parseId(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            return (Id) rawValue;
        } catch (Exception e) {
            return null;
        }
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        return !String.isBlank(firstValue) ? firstValue : secondValue;
    }

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

}