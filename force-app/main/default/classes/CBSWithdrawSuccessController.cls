/**
 * Shared Withdrawal Success confirmation page for all Data Subject withdrawal journeys.
 * Display-only: does not create or update Consent records on page load.
 *
 * without sharing: Guest users must read Contact, Consent__c and Consent_Request_Item__c
 * records referenced by URL parameters without relying on org-wide sharing defaults.
 */
public without sharing class CBSWithdrawSuccessController {
    private static final String ERROR_MESSAGE =
        'We are unable to display the withdrawal confirmation at this time. Please contact your HR representative or CBS for assistance.';

    private static final String STATUS_WITHDRAWN = 'Withdrawn';
    private static final String DISPLAY_PLACEHOLDER = '-';

    public String contactId { get; private set; }
    public String consentId { get; private set; }
    public String requestItemId { get; private set; }
    public String referenceId { get; private set; }

    public Boolean showSuccess { get; private set; }
    public Boolean showError { get; private set; }
    public String errorMessage { get; private set; }

    public String dataSubjectName { get; private set; }
    public String employerBankName { get; private set; }
    public String withdrawalStatus { get; private set; }
    public String withdrawalDateTime { get; private set; }
    public String referenceIdDisplay { get; private set; }

    private Contact contactRecord;
    private Consent__c consentRecord;
    private Consent_Request_Item__c requestItemRecord;

    public CBSWithdrawSuccessController() {
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
        return 'Withdrawal Submitted Successfully';
    }

    public String getSuccessIntroText() {
        return 'Your withdrawal request has been submitted successfully.';
    }

    public String getWhatHappensNextTitle() {
        return 'What happens next';
    }

    public String getSingpassWithdrawalText() {
        return 'For Singpass-verified withdrawals, your consent status will be updated directly.';
    }

    public String getManualVerificationWithdrawalTextBeforeEmail() {
        return 'For withdrawals which require identity verification by CBS (i.e., non-Singpass users), your withdrawal request has been submitted and is pending CBS\' review before your consent status is updated. CBS may contact you if further verification is required. Contact CBS at ';
    }

    public String getManualVerificationWithdrawalTextAfterEmail() {
        return ' to check on your consent withdrawal status.';
    }

    public String getPrivacyEmailAddress() {
        return 'privacy@creditbureau.com.sg';
    }

    public String getClosePageButtonLabel() {
        return 'Close This Page';
    }

    private String getBankNameForDisplay() {
        return String.isBlank(employerBankName) ? '[NAME OF BANK]' : employerBankName;
    }

    private Boolean validateAccess() {
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
        consentRecord = resolveWithdrawnConsent(parsedContactId);
        if (!hasWithdrawnStatus(parsedContactId)) {
            markError(ERROR_MESSAGE);
            return false;
        }

        return true;
    }

    private Boolean hasWithdrawnStatus(Id subjectId) {
        if (consentRecord != null && normalizeStatus(consentRecord.Consent_Status__c) == STATUS_WITHDRAWN) {
            return true;
        }

        String contactStatus = normalizeStatus(contactRecord.Current_Consent_Status__c);
        if (contactStatus == STATUS_WITHDRAWN) {
            return true;
        }

        if (requestItemRecord != null && normalizeStatus(requestItemRecord.Current_Status__c) == STATUS_WITHDRAWN) {
            return true;
        }

        List<Consent__c> withdrawnConsents = [
            SELECT Id, Consent_Status__c, Revoked_At__c
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
                AND Consent_Status__c = :STATUS_WITHDRAWN
            ORDER BY Revoked_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];
        if (!withdrawnConsents.isEmpty()) {
            consentRecord = withdrawnConsents[0];
            return true;
        }

        return false;
    }

    private void populateDisplayValues() {
        dataSubjectName = resolveDataSubjectName();
        employerBankName = resolveBankName();
        withdrawalStatus = STATUS_WITHDRAWN;
        withdrawalDateTime = formatWithdrawalDateTime();
        referenceIdDisplay = resolveReferenceIdDisplay();
    }

    private String resolveDataSubjectName() {
        String resolvedName = getStringFieldValue(
            contactRecord,
            new List<String>{ 'Principal_Name__c', 'Full_Name__c', 'Full_Legal_Name__c', 'Name' }
        );
        return String.isBlank(resolvedName) ? DISPLAY_PLACEHOLDER : resolvedName;
    }

    private String resolveBankName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        return DISPLAY_PLACEHOLDER;
    }

    private String formatWithdrawalDateTime() {
        Datetime withdrawnAt = null;

        if (consentRecord != null && consentRecord.Revoked_At__c != null) {
            withdrawnAt = consentRecord.Revoked_At__c;
        }

        if (withdrawnAt == null) {
            withdrawnAt = getDatetimeFieldValue(
                contactRecord,
                new List<String>{
                    'Withdrawal_Datetime__c',
                    'Consent_Revocation_Date__c',
                    'Revoked_At__c',
                    'Latest_Status_Datetime__c'
                }
            );
        }

        return withdrawnAt == null ? DISPLAY_PLACEHOLDER : withdrawnAt.format('d MMMM yyyy, h:mm a');
    }

    private String resolveReferenceIdDisplay() {
        if (requestItemRecord != null && requestItemRecord.Id != null) {
            return String.valueOf(requestItemRecord.Id);
        }

        if (!String.isBlank(referenceId)) {
            return referenceId;
        }

        if (!String.isBlank(requestItemId)) {
            return requestItemId;
        }

        if (consentRecord != null && consentRecord.Id != null) {
            return String.valueOf(consentRecord.Id);
        }

        return DISPLAY_PLACEHOLDER;
    }

    private Id resolveContactId() {
        Id parsedContactId = parseId(firstNonBlank(contactId, ApexPages.currentPage().getParameters().get('ContactId')));
        if (parsedContactId != null) {
            return parsedContactId;
        }

        Id parsedConsentId = parseId(firstNonBlank(consentId, ApexPages.currentPage().getParameters().get('id')));
        if (parsedConsentId != null) {
            List<Consent__c> rows = [
                SELECT Data_Subject__c
                FROM Consent__c
                WHERE Id = :parsedConsentId
                LIMIT 1
            ];
            if (!rows.isEmpty() && rows[0].Data_Subject__c != null) {
                consentId = String.valueOf(parsedConsentId);
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
                requestItemRecord = requestRows[0];
                requestItemId = String.valueOf(parsedReferenceId);
                return requestRows[0].Data_Subject__c;
            }
        }

        return null;
    }

    private Consent__c resolveWithdrawnConsent(Id subjectId) {
        Id parsedConsentId = parseId(firstNonBlank(consentId, ApexPages.currentPage().getParameters().get('id')));
        if (parsedConsentId != null) {
            List<Consent__c> byId = queryConsentById(parsedConsentId);
            if (!byId.isEmpty() && byId[0].Data_Subject__c == subjectId) {
                if (normalizeStatus(byId[0].Consent_Status__c) == STATUS_WITHDRAWN) {
                    return byId[0];
                }
            }
        }

        List<Consent__c> latestWithdrawn = queryLatestWithdrawnConsent(subjectId);
        return latestWithdrawn.isEmpty() ? null : latestWithdrawn[0];
    }

    private List<Consent__c> queryConsentById(Id safeConsentId) {
        Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id', 'Data_Subject__c', 'Consent_Status__c', 'Revoked_At__c'
        };
        List<String> optional = new List<String>{ 'Consent_Request_Item__c' };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Consent__c WHERE Id = :safeConsentId LIMIT 1';
        return Database.query(soql);
    }

    private List<Consent__c> queryLatestWithdrawnConsent(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id', 'Data_Subject__c', 'Consent_Status__c', 'Revoked_At__c'
        };
        List<String> optional = new List<String>{ 'Consent_Request_Item__c' };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        String soql =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Consent__c WHERE Data_Subject__c = :subjectId AND Consent_Status__c = :STATUS_WITHDRAWN' +
            ' ORDER BY Revoked_At__c DESC NULLS LAST, CreatedDate DESC LIMIT 1';
        return Database.query(soql);
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'AccountId', 'Account.Name', 'Name' };
        List<String> optional = new List<String>{
            'Principal_Name__c',
            'Full_Name__c',
            'Full_Legal_Name__c',
            'Current_Consent_Status__c',
            'Withdrawal_Datetime__c',
            'Consent_Revocation_Date__c',
            'Revoked_At__c',
            'Latest_Status_Datetime__c'
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

        if (consentRecord != null && hasField(consentRecord, 'Consent_Request_Item__c')) {
            Object requestItemLookup = consentRecord.get('Consent_Request_Item__c');
            if (requestItemLookup != null) {
                Consent_Request_Item__c byConsent = queryRequestItemById(String.valueOf(requestItemLookup));
                if (byConsent != null) {
                    requestItemId = byConsent.Id;
                    return byConsent;
                }
            }
        }

        List<Consent_Request_Item__c> latestItems = [
            SELECT Id, Data_Subject__c, Current_Status__c
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
            List<Consent_Request_Item__c> items = [
                SELECT Id, Data_Subject__c, Current_Status__c
                FROM Consent_Request_Item__c
                WHERE Id = :safeId
                LIMIT 1
            ];
            return items.isEmpty() ? null : items[0];
        } catch (Exception e) {
            return null;
        }
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        consentId = firstNonBlank(params.get('consentId'), params.get('id'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        referenceId = params.get('referenceId');
    }

    private void markError(String message) {
        showError = true;
        showSuccess = false;
        errorMessage = message;
    }

    private static String getStringFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (hasField(record, fieldApi)) {
                Object rawValue = record.get(fieldApi);
                if (rawValue != null && !String.isBlank(String.valueOf(rawValue))) {
                    return String.valueOf(rawValue);
                }
            }
        }
        return null;
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

    private static String normalizeStatus(String value) {
        return value == null ? '' : value.trim();
    }
}