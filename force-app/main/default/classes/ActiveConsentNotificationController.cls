/**
 * Shared Active Consent notification page for all Data Subject consent journeys.
 * Display-only: informs the data subject that valid consent already exists.
 */
public without sharing class ActiveConsentNotificationController {
    private static final String ERROR_MISSING_REFERENCE =
        'Invalid or missing request reference.';
    private static final String ERROR_NOT_FOUND =
        'We are unable to locate this consent request.';
    private static final String ERROR_GENERIC =
        'We are unable to process your request at this time. Please contact your HR representative.';

    private static final String PURPOSE_EMPLOYEE =
        'employment-related credit assessment';
    private static final String PURPOSE_PRE_HIRE =
        'pre-employment screening';

    private static final Set<String> ACTIVE_CONTACT_STATUSES = new Set<String>{
        'AUTHORIZED', 'VALID', 'ACTIVE'
    };
    private static final Set<String> ACTIVE_CONSENT_STATUSES = new Set<String>{
        'ACTIVE', 'VALID'
    };
    private static final Set<String> TERMINAL_CONTACT_STATUSES = new Set<String>{
        'DECLINED', 'WITHDRAWN', 'EXPIRED'
    };

    private static final String PAGE_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_NONSINGPASS_PREHIRE_NOTES = '/apex/QRSiteNonSingpassPrehireImportantNotes';
    private static final String PAGE_NONSINGPASS_EMPLOYEE_NOTES = '/apex/QRSiteNonSingpassEmployeeImportantNotes';

    public String contactId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public String referenceId { get; private set; }

    public Boolean showPage { get; private set; }
    public Boolean showError { get; private set; }
    public String errorMessage { get; private set; }

    public String dataSubjectName { get; private set; }
    public String bankName { get; private set; }
    public String consentStatus { get; private set; }
    public String consentExpiryDate { get; private set; }
    public String purposeText { get; private set; }

    private Contact contactRecord;
    private Consent__c activeConsentRecord;

    public ActiveConsentNotificationController() {
        parseUrlParameters();
        showPage = false;
        showError = false;
    }

    public PageReference initPage() {
        try {
            if (!hasAnyLookupParameter()) {
                markError(ERROR_MISSING_REFERENCE);
                return null;
            }

            Id subjectId = resolveContactId();
            if (subjectId == null) {
                markError(ERROR_NOT_FOUND);
                return null;
            }
            contactId = String.valueOf(subjectId);

            contactRecord = queryContact(subjectId);
            if (contactRecord == null) {
                markError(ERROR_NOT_FOUND);
                return null;
            }

            PageReference terminalRedirect = resolveTerminalStatusRedirect();
            if (terminalRedirect != null) {
                terminalRedirect.setRedirect(true);
                return terminalRedirect;
            }

            if (!hasValidActiveConsent(subjectId)) {
                PageReference flowRedirect = resolveNormalConsentFlowRedirect();
                flowRedirect.setRedirect(true);
                return flowRedirect;
            }

            populateDisplayValues();
            showPage = true;
            return null;
        } catch (Exception e) {
            markError(ERROR_GENERIC);
            return null;
        }
    }

    public String getPageTitle() {
        return 'Your consent is currently active.';
    }

    public String getMainBodyText() {
        return 'Our records show that you have already provided consent for Credit Bureau (Singapore) Pte Ltd ("CBS") '
            + 'to disclose your consumer credit report(s) and/or credit information to '
            + getBankNameForDisplay()
            + ' for [EMPLOYMENT-RELATED CREDIT ASSESSMENT / PRE-EMPLOYMENT SCREENING]'
            + ' purposes. No further action is required from you.';
    }

    public String getWithdrawalText() {
        return 'If you wish to withdraw your consent, please refer to the original email sent by '
            + getBankDepartmentForDisplay()
            + ' and click the withdrawal link provided in that email. '
            + 'You may be required to complete the relevant authentication or identity verification steps '
            + 'before your withdrawal is submitted. '
            + 'Alternatively, you may also reach out to '
            + getBankDepartmentForDisplay()
            + ' or CBS at Privacy@creditbureau.com.sg for assistance in processing your withdrawal.';
    }

    public String getWithdrawalTextHtml() {
        return getWithdrawalText().replace(
            'Privacy@creditbureau.com.sg',
            '<a href="mailto:Privacy@creditbureau.com.sg" style="text-decoration: underline;">Privacy@creditbureau.com.sg</a>'
        );
    }

    public Boolean getShowDataSubjectName() {
        return !String.isBlank(dataSubjectName);
    }

    public Boolean getShowBankName() {
        return !String.isBlank(bankName);
    }

    public Boolean getShowConsentStatus() {
        return !String.isBlank(consentStatus);
    }

    public Boolean getShowConsentExpiryDate() {
        return !String.isBlank(consentExpiryDate);
    }

    public Boolean getShowPurpose() {
        return !String.isBlank(purposeText);
    }

    private void populateDisplayValues() {
        bankName = resolveBankName();
        purposeText = resolvePurposeText();

        dataSubjectName = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'Full_Name__c', 'Principal_Name__c', 'Name' }),
            null
        );

        consentStatus = firstNonBlank(
            activeConsentRecord != null ? blankIfNull(activeConsentRecord.Consent_Status__c) : '',
            blankIfNull(contactRecord.Current_Consent_Status__c)
        );
        if (String.isBlank(consentStatus)) {
            consentStatus = null;
        }

        Date expiryDate = activeConsentRecord != null
            ? activeConsentRecord.Consent_Expiry_Date__c
            : contactRecord.Current_Consent_Expiry_Date__c;
        consentExpiryDate = expiryDate == null ? null : formatDate(expiryDate);
    }

    private Boolean hasValidActiveConsent(Id subjectId) {
        activeConsentRecord = queryLatestValidConsent(subjectId);
        if (activeConsentRecord != null) {
            return true;
        }

        String contactStatus = normalizeStatus(contactRecord.Current_Consent_Status__c);
        if (!ACTIVE_CONTACT_STATUSES.contains(contactStatus)) {
            return false;
        }

        Date contactExpiry = contactRecord.Current_Consent_Expiry_Date__c;
        return contactExpiry == null || contactExpiry >= Date.today();
    }

    private Consent__c queryLatestValidConsent(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id',
            'Data_Subject__c',
            'Consent_Status__c',
            'Consent_Expiry_Date__c',
            'Submitted_At__c'
        };
        List<String> optional = new List<String>{ 'Action_Type__c' };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }

        String soql =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Consent__c WHERE Data_Subject__c = :subjectId' +
            ' AND Consent_Status__c IN (\'Active\', \'Valid\')' +
            ' AND (Consent_Expiry_Date__c = NULL OR Consent_Expiry_Date__c >= TODAY)' +
            ' ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC LIMIT 1';

        List<Consent__c> rows = Database.query(soql);
        if (rows.isEmpty()) {
            return null;
        }

        Consent__c candidate = rows[0];
        if (fieldMap.containsKey('Action_Type__c')) {
            String actionType = normalizeStatus(String.valueOf(candidate.get('Action_Type__c')));
            if (!String.isBlank(actionType)
                && actionType != 'AUTHORIZE'
                && actionType != 'CONSENT'
                && actionType != 'CONSENT GIVEN') {
                return null;
            }
        }

        String consentStatusValue = normalizeStatus(candidate.Consent_Status__c);
        return ACTIVE_CONSENT_STATUSES.contains(consentStatusValue) ? candidate : null;
    }

    private PageReference resolveTerminalStatusRedirect() {
        String contactStatus = normalizeStatus(contactRecord.Current_Consent_Status__c);
        if (contactStatus == 'DECLINED' || contactStatus == 'WITHDRAWN') {
            return buildRedirect(PAGE_ALREADY_ACTIONED);
        }
        if (contactStatus == 'EXPIRED') {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        Date contactExpiry = contactRecord.Current_Consent_Expiry_Date__c;
        if (contactExpiry != null && contactExpiry < Date.today()
            && TERMINAL_CONTACT_STATUSES.contains(contactStatus)) {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        return null;
    }

    private PageReference resolveNormalConsentFlowRedirect() {
        String authType = normalizeStatus(getStringFieldValue(contactRecord, new List<String>{ 'Authentication_Type__c' }));
        String employmentStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        String consentType = getStringFieldValue(contactRecord, new List<String>{ 'Consent_Type__c' });
        Boolean preHireScenario = isPreHireScenario(employmentStatus, consentType);

        PageReference nextPage;
        if (isSingpassAuthType(authType)) {
            nextPage = preHireScenario
                ? Page.QRSiteSingpassPrehireImportantNotes
                : Page.QRSiteSingpassEmployeeImportantNotes;
            nextPage.getParameters().put('action', 'authorize');
            nextPage.getParameters().put('authType', 'singpass');
            nextPage.getParameters().put('type', preHireScenario ? 'prehire' : 'employee');
        } else {
            nextPage = new PageReference(
                preHireScenario ? PAGE_NONSINGPASS_PREHIRE_NOTES : PAGE_NONSINGPASS_EMPLOYEE_NOTES
            );
            nextPage.getParameters().put('action', 'authorize');
            nextPage.getParameters().put('authType', 'nonsingpass');
            nextPage.getParameters().put('type', preHireScenario ? 'prehire' : 'employee');
            nextPage.getParameters().put('subjectType', preHireScenario ? 'prehire' : 'employee');
        }

        copyContextParams(nextPage);
        return nextPage;
    }

    private String resolvePurposeText() {
        String employmentStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        String consentType = getStringFieldValue(contactRecord, new List<String>{ 'Consent_Type__c' });
        return isPreHireScenario(employmentStatus, consentType) ? PURPOSE_PRE_HIRE : PURPOSE_EMPLOYEE;
    }

    private Boolean isSingpassAuthType(String authType) {
        String normalizedAuthType = normalizeStatus(authType);
        return normalizedAuthType.contains('SINGPASS') && !normalizedAuthType.contains('NON');
    }

    private Boolean isPreHireScenario(String employmentStatus, String consentType) {
        String normalizedEmployment = normalizeStatus(employmentStatus);
        if (normalizedEmployment == 'PRE-HIRE'
            || normalizedEmployment == 'PRE HIRE'
            || normalizedEmployment == 'PREHIRE'
            || normalizedEmployment == 'NEW HIRE'
            || normalizedEmployment == 'NEWHIRE') {
            return true;
        }

        String normalizedConsentType = normalizeStatus(consentType);
        return normalizedConsentType.contains('PER REPORT') || normalizedConsentType.contains('PERREPORT');
    }

    private String resolveBankName() {
        if (contactRecord != null
            && contactRecord.Account != null
            && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        return null;
    }

    private String getBankNameForDisplay() {
        return String.isBlank(bankName) ? '[NAME OF BANK]' : bankName;
    }

    private String getBankDepartmentForDisplay() {
        return String.isBlank(bankName) ? '[NAME OF BANK AND DEPARTMENT]' : bankName + ' Human Resources';
    }

    private String getPurposeForDisplay() {
        return String.isBlank(purposeText) ? PURPOSE_EMPLOYEE : purposeText;
    }

    private Id resolveContactId() {
        Id parsedContactId = parseId(firstNonBlank(contactId, ApexPages.currentPage().getParameters().get('ContactId')));
        if (parsedContactId != null) {
            return parsedContactId;
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
                requestItemId = parsedReferenceId;
                return requestRows[0].Data_Subject__c;
            }
        }

        if (!String.isBlank(token)) {
            Consent_Request_Item__c byToken = queryRequestItemByToken(token);
            if (byToken != null) {
                requestItemId = byToken.Id;
                return byToken.Data_Subject__c;
            }
        }

        return null;
    }

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(fieldMap, new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
        if (String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT Id, Data_Subject__c FROM Consent_Request_Item__c WHERE '
            + tokenField + ' = :tokenValue LIMIT 1';
        List<Consent_Request_Item__c> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'AccountId',
            'Account.Name',
            'Current_Consent_Status__c',
            'Current_Consent_Expiry_Date__c'
        };
        List<String> optional = new List<String>{
            'Full_Name__c',
            'Principal_Name__c',
            'Employment_Status__c',
            'Authentication_Type__c',
            'Consent_Type__c'
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

    private Boolean hasAnyLookupParameter() {
        return !String.isBlank(contactId)
            || !String.isBlank(requestItemId)
            || !String.isBlank(referenceId)
            || !String.isBlank(token);
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        referenceId = params.get('referenceId');
        token = params.get('token');
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }

        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('contactId', contactId);
            targetPage.getParameters().put('ContactId', contactId);
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
            targetPage.getParameters().put('consentRequestItemId', requestItemId);
        }
        if (!String.isBlank(referenceId)) {
            targetPage.getParameters().put('referenceId', referenceId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }
    }

    private PageReference buildRedirect(String pagePath) {
        PageReference pageRef = new PageReference(pagePath);
        copyContextParams(pageRef);
        return pageRef;
    }

    private void markError(String message) {
        showError = true;
        showPage = false;
        errorMessage = message;
    }

    private String formatDate(Date dateValue) {
        return Datetime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy');
    }

    private static String normalizeStatus(String value) {
        return String.isBlank(value) ? '' : value.trim().toUpperCase();
    }

    private static String getStringFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (hasField(record, fieldApi)) {
                Object rawValue = record.get(fieldApi);
                if (rawValue != null) {
                    return String.valueOf(rawValue);
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