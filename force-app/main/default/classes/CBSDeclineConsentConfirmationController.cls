/**
 * Decline Consent Confirmation page for Data Subjects accessing via Salesforce Sites / Experience Cloud.
 */
public without sharing class CBSDeclineConsentConfirmationController {
    private static final String STATUS_DECLINED = 'Declined';
    private static final String LIFECYCLE_STAGE_CONSENT_DECLINED = 'Consent Declined';
    private static final String STATUS_WITHDRAWN = 'Withdrawn';
    private static final String STATUS_EXPIRED = 'Expired';
    private static final String STATUS_AUTHORIZED = 'Authorized';
    private static final String STATUS_VALID = 'Valid';
    private static final String STATUS_SUBMITTED = 'Submitted';

    private static final String PAGE_INVALID_LINK = '/apex/QRSiteInvalidLink';
    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/CBSConsentAlreadyActionedPage';
    private static final String PAGE_ACTIVE_CONSENT = '/apex/ActiveConsentNotificationPage';
    private static final String PAGE_DECLINE_SUCCESS = '/apex/CBSDeclineSuccessPage';

    private static final String BANK_NAME_FALLBACK = '[NAME OF BANK]';
    private static final String CONSENT_PURPOSE_TEXT =
        'EMPLOYMENT-RELATED CREDIT ASSESSMENT / PRE-EMPLOYMENT SCREENING';
    private static final String CBS_ENTITY_LABEL = 'Credit Bureau (Singapore) Pte Ltd (\u201cCBS\u201d)';
    private static final String ERROR_INVALID_LINK = 'Invalid or expired request link.';
    private static final String ERROR_CONTACT_NOT_FOUND = 'We are unable to locate your consent request.';
    private static final String ERROR_LINK_EXPIRED = 'This consent request link has expired.';
    private static final String ERROR_DML_FAILURE =
        'We are unable to process your declination at this time. Please contact support.';

    @TestVisible
    private static Boolean simulateDmlFailureForTest = false;

    public String contactId { get; set; }
    public String requestId { get; set; }
    public String token { get; set; }
    public Contact dataSubject { get; private set; }
    public String bankName { get; private set; }
    public String errorMessage { get; private set; }
    public Boolean hasError { get; private set; }
    public Boolean isProcessing { get; private set; }
    public Boolean showPage { get; private set; }

    private Consent_Request_Item__c requestItemRecord;
    private String entryAction;
    private String entryType;
    private String entryAuthType;
    private String entrySubjectType;
    private Boolean contextInitialized = false;

    public CBSDeclineConsentConfirmationController() {
        isProcessing = false;
        showPage = false;
        init();
    }

    public PageReference initPage() {
        try {
            clearError();
            init();

            PageReference statusRedirect = isAlreadyActioned();
            if (statusRedirect != null) {
                statusRedirect.setRedirect(true);
                return statusRedirect;
            }

            if (!validateRequest()) {
                return null;
            }

            showPage = true;
            return null;
        } catch (Exception e) {
            setError(ERROR_INVALID_LINK);
            return null;
        }
    }

    public String getPageTitle() {
        return 'Decline to Give Consent';
    }

    public String getOpeningStatement() {
        return 'You have selected the option to decline consent for '
            + CBS_ENTITY_LABEL
            + ' to disclose your consumer credit report(s) and/or credit information to '
            + getDisplayBankName()
            + ' for '
            + CONSENT_PURPOSE_TEXT
            + ' purposes.';
    }

    public String getConsequencesIntro() {
        return 'If you confirm that you do not wish to provide your consent:';
    }

    public String getConsequenceBullet2() {
        return getDisplayBankName() + ' will be notified that you have declined consent.';
    }

    public String getConsequenceBullet3() {
        return getDisplayBankName()
            + ' will not be able to submit a credit report request to CBS under this consent request.';
    }

    public String getConsequenceBullet4() {
        return 'If you wish to provide consent in future, you may be required to use a new consent link provided by '
            + getDisplayBankAndDepartment()
            + '.';
    }

    public String getProceedInstructionText() {
        return 'To proceed, click the Confirm Decline below.';
    }

    public String getProceedInstructionHtml() {
        return 'To proceed, click the <strong>Confirm Decline</strong> below.';
    }

    public String getConfirmDeclineButtonLabel() {
        return 'Confirm Decline';
    }

    public PageReference submitDeclination() {
        if (isProcessing == true) {
            return null;
        }

        isProcessing = true;
        try {
            clearError();
            init();

            PageReference statusRedirect = isAlreadyActioned();
            if (statusRedirect != null) {
                statusRedirect.setRedirect(true);
                return statusRedirect;
            }

            if (!validateRequest()) {
                showPage = true;
                return null;
            }

            Savepoint savepointBeforeSubmit = Database.setSavepoint();
            try {
                if (simulateDmlFailureForTest) {
                    throw new DmlException('Simulated DML failure for test coverage.');
                }

                updateContactDeclined();
                updateConsentRequestItemDeclined();
                createOrUpdateConsentDeclineRecord();
                notifyClientOfDecline();

                PageReference successPage = buildRedirect(PAGE_DECLINE_SUCCESS, true);
                return successPage;
            } catch (DmlException e) {
                Database.rollback(savepointBeforeSubmit);
                setError(ERROR_DML_FAILURE);
                showPage = true;
                return null;
            } catch (Exception e) {
                Database.rollback(savepointBeforeSubmit);
                setError(ERROR_DML_FAILURE);
                showPage = true;
                return null;
            }
        } catch (Exception e) {
            setError(ERROR_DML_FAILURE);
            showPage = true;
            return null;
        } finally {
            isProcessing = false;
        }
    }

    public PageReference cancel() {
        return null;
    }

    private void init() {
        if (contextInitialized) {
            return;
        }

        parseUrlParameters();
        resolveDataContext();
        bankName = resolveBankName();
        contextInitialized = true;
    }

    private Boolean validateRequest() {
        if (!hasResolvableIdentifier()) {
            setError(ERROR_INVALID_LINK);
            return false;
        }

        if (dataSubject == null) {
            setError(ERROR_CONTACT_NOT_FOUND);
            return false;
        }

        if (isLinkExpired()) {
            setError(ERROR_LINK_EXPIRED);
            return false;
        }

        if (!isTokenValid()) {
            setError(ERROR_INVALID_LINK);
            return false;
        }

        return true;
    }

    private PageReference isAlreadyActioned() {
        if (dataSubject == null) {
            return null;
        }

        String contactStatus = blankIfNull(getStringFieldValue(
            dataSubject,
            new List<String>{ 'Current_Consent_Status__c' }
        ));
        String lifecycleStage = blankIfNull(getStringFieldValue(
            dataSubject,
            new List<String>{ 'Data_Subject_Lifecycle_Stage__c' }
        ));

        if (contactStatus == STATUS_DECLINED && lifecycleStage == LIFECYCLE_STAGE_CONSENT_DECLINED) {
            return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
        }
        if (isActiveConsentStatus(contactStatus)) {
            return buildRedirect(PAGE_ACTIVE_CONSENT, false);
        }
        if (contactStatus == STATUS_WITHDRAWN) {
            return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
        }
        if (contactStatus == STATUS_EXPIRED) {
            return buildRedirect(PAGE_LINK_EXPIRED, false);
        }

        if (requestItemRecord != null) {
            String requestStatus = blankIfNull(requestItemRecord.Current_Status__c);
            if (requestStatus == STATUS_SUBMITTED) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
            }
            if (requestStatus == STATUS_DECLINED || requestStatus == STATUS_WITHDRAWN) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED, false);
            }
            if (requestStatus == STATUS_EXPIRED) {
                return buildRedirect(PAGE_LINK_EXPIRED, false);
            }
        }

        return null;
    }

    private void updateContactDeclined() {
        String declinedContactStatus = choosePicklistValue(
            Contact.Current_Consent_Status__c.getDescribe(),
            new List<String>{ STATUS_DECLINED }
        );
        if (String.isBlank(declinedContactStatus)) {
            throw new CBSDeclineException('Current_Consent_Status__c picklist value "Declined" is not configured.');
        }

        String declinedLifecycleStage = choosePicklistValue(
            Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(),
            new List<String>{ LIFECYCLE_STAGE_CONSENT_DECLINED }
        );
        if (String.isBlank(declinedLifecycleStage)) {
            throw new CBSDeclineException('Data_Subject_Lifecycle_Stage__c picklist value "Consent Declined" is not configured.');
        }

        Contact contactUpdate = new Contact(Id = dataSubject.Id);
        contactUpdate.Current_Consent_Status__c = declinedContactStatus;
        contactUpdate.Data_Subject_Lifecycle_Stage__c = declinedLifecycleStage;

        Datetime submittedAt = System.now();
        setOptionalFieldSafe(contactUpdate, 'Declined_Date__c', submittedAt);
        setOptionalFieldSafe(contactUpdate, 'Latest_Submission_Datetime__c', submittedAt);
        setOptionalFieldSafe(contactUpdate, 'Latest_Status_Datetime__c', submittedAt);
        setOptionalFieldSafe(contactUpdate, 'Latest_Status_Date__c', submittedAt.date());

        update contactUpdate;
    }

    private void updateConsentRequestItemDeclined() {
        if (requestItemRecord == null || requestItemRecord.Id == null) {
            return;
        }

        Consent_Request_Item__c requestItemUpdate = new Consent_Request_Item__c(Id = requestItemRecord.Id);
        setOptionalFieldSafe(
            requestItemUpdate,
            'Current_Status__c',
            choosePicklistValue(
                Consent_Request_Item__c.Current_Status__c.getDescribe(),
                new List<String>{ STATUS_DECLINED }
            )
        );

        Datetime submittedAt = System.now();
        setOptionalFieldSafe(requestItemUpdate, 'Latest_Submission_Date_Time__c', submittedAt);
        setOptionalFieldSafe(requestItemUpdate, 'Submitted_At__c', submittedAt);
        setOptionalFieldSafe(requestItemUpdate, 'Latest_Status_Date__c', submittedAt.date());
        setOptionalFieldSafe(requestItemUpdate, 'Latest_Status_Datetime__c', submittedAt);
        setOptionalFieldSafe(requestItemUpdate, 'Authorization_QR_Viewed_At__c', null);
        setOptionalFieldSafe(requestItemUpdate, 'Withdrawal_QR_Viewed_At__c', null);

        update requestItemUpdate;
    }

    private void createOrUpdateConsentDeclineRecord() {
        Map<String, Schema.SObjectField> consentFields = Consent__c.SObjectType.getDescribe().fields.getMap();
        if (!consentFields.containsKey('Data_Subject__c')
            || !consentFields.containsKey('Consent_Status__c')
            || !consentFields.containsKey('Submitted_At__c')) {
            return;
        }

        String consentStatus = choosePicklistValue(
            Consent__c.Consent_Status__c.getDescribe(),
            new List<String>{ STATUS_DECLINED }
        );
        if (String.isBlank(consentStatus)) {
            return;
        }

        Datetime submittedAt = System.now();
        Consent__c declineConsent = new Consent__c();
        declineConsent.Data_Subject__c = dataSubject.Id;
        declineConsent.Consent_Status__c = consentStatus;
        declineConsent.Submitted_At__c = submittedAt;

        setOptionalFieldSafe(
            declineConsent,
            'Action_Type__c',
            choosePicklistValue(
                Consent__c.Action_Type__c.getDescribe(),
                new List<String>{ 'Consent Declined', 'Decline' }
            )
        );
        setOptionalFieldSafe(
            declineConsent,
            'Consent_Request_Item__c',
            requestItemRecord == null ? null : requestItemRecord.Id
        );
        setOptionalFieldSafe(declineConsent, 'Latest_Submission_Date_Time__c', submittedAt);

        insert declineConsent;
    }

    private void notifyClientOfDecline() {
        Id requestItemLookupId = requestItemRecord == null ? null : requestItemRecord.Id;
        DeclineConsentNotificationService.notifyClientOfDecline(dataSubject == null ? null : dataSubject.Id, requestItemLookupId);
    }

    private void resolveDataContext() {
        dataSubject = null;
        requestItemRecord = null;

        requestItemRecord = resolveRequestItem();
        if (requestItemRecord != null && requestItemRecord.Data_Subject__c != null) {
            if (String.isBlank(contactId)) {
                contactId = String.valueOf(requestItemRecord.Data_Subject__c);
            }
            requestId = String.valueOf(requestItemRecord.Id);
        }

        Id parsedContactId = parseId(contactId);
        if (parsedContactId != null) {
            dataSubject = queryContact(parsedContactId);
        }

        if (requestItemRecord != null
            && dataSubject != null
            && requestItemRecord.Data_Subject__c != null
            && requestItemRecord.Data_Subject__c != dataSubject.Id) {
            dataSubject = null;
        }
    }

    private Consent_Request_Item__c resolveRequestItem() {
        String requestItemParam = firstNonBlank(
            requestId,
            ApexPages.currentPage().getParameters().get('requestItemId'),
            ApexPages.currentPage().getParameters().get('consentRequestItemId')
        );

        if (!String.isBlank(requestItemParam)) {
            Consent_Request_Item__c byId = queryRequestItemById(requestItemParam);
            if (byId != null) {
                return byId;
            }
        }

        Consent_Request_Item__c byToken = queryRequestItemByToken(token);
        if (byToken != null) {
            return byToken;
        }

        Id parsedContactId = parseId(contactId);
        if (parsedContactId != null) {
            List<Consent_Request_Item__c> latestItems = [
                SELECT Id, Data_Subject__c, Current_Status__c, Consent_Link_Expires_At__c
                FROM Consent_Request_Item__c
                WHERE Data_Subject__c = :parsedContactId
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 1
            ];
            if (!latestItems.isEmpty()) {
                return latestItems[0];
            }
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
        if (String.isBlank(tokenValue)) {
            return null;
        }

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
            'Link_Expiry_DateTime__c',
            'Latest_Submission_Date_Time__c',
            'Submitted_At__c',
            'Latest_Status_Date__c',
            'Latest_Status_Datetime__c',
            'Authorization_QR_Viewed_At__c',
            'Withdrawal_QR_Viewed_At__c'
        };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        return fields;
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Name', 'Email', 'AccountId', 'Account.Name' };
        List<String> optional = new List<String>{
            'Full_Name__c',
            'Principal_Name__c',
            'Current_Consent_Status__c',
            'Data_Subject_Lifecycle_Stage__c',
            'Latest_Submission_Datetime__c',
            'Latest_Status_Datetime__c',
            'Latest_Status_Date__c',
            'Authentication_Type__c'
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

    private String resolveBankName() {
        if (dataSubject != null && dataSubject.Account != null && !String.isBlank(dataSubject.Account.Name)) {
            return dataSubject.Account.Name;
        }
        return BANK_NAME_FALLBACK;
    }

    private String getDisplayBankName() {
        return String.isBlank(bankName) || bankName == BANK_NAME_FALLBACK
            ? BANK_NAME_FALLBACK
            : bankName;
    }

    private String getDisplayBankAndDepartment() {
        if (String.isBlank(bankName) || bankName == BANK_NAME_FALLBACK) {
            return '[NAME OF BANK AND DEPARTMENT]';
        }
        return bankName + ' Human Resources';
    }

    private Boolean hasResolvableIdentifier() {
        return parseId(contactId) != null
            || parseId(requestId) != null
            || !String.isBlank(token);
    }

    private Boolean isLinkExpired() {
        if (requestItemRecord == null) {
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
            if (!hasField(requestItemRecord, fieldApi)) {
                continue;
            }
            Object rawValue = requestItemRecord.get(fieldApi);
            if (rawValue instanceof Datetime && ((Datetime) rawValue) < System.now()) {
                return true;
            }
            if (rawValue instanceof Date && ((Date) rawValue) < Date.today()) {
                return true;
            }
        }
        return false;
    }

    private Boolean isTokenValid() {
        if (String.isBlank(token)) {
            return false;
        }
        if (requestItemRecord == null) {
            return false;
        }

        return ConsentGuestAuthService.isTokenValidForRequestItem(
            requestItemRecord,
            token,
            parseId(contactId)
        );
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        requestId = firstNonBlank(
            params.get('requestId'),
            params.get('requestItemId'),
            params.get('consentRequestItemId')
        );
        token = params.get('token');
        entryAction = blankIfNull(params.get('action'));
        entryType = blankIfNull(params.get('type'));
        entryAuthType = blankIfNull(params.get('authType'));
        entrySubjectType = blankIfNull(params.get('subjectType'));
    }

    private PageReference buildRedirect(String pagePath, Boolean setRedirect) {
        PageReference pageRef = new PageReference(pagePath);
        copyContextParams(pageRef);
        if (setRedirect == true) {
            pageRef.setRedirect(true);
        }
        return pageRef;
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }
        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('contactId', contactId);
            targetPage.getParameters().put('ContactId', contactId);
        }
        if (!String.isBlank(requestId)) {
            targetPage.getParameters().put('requestId', requestId);
            targetPage.getParameters().put('requestItemId', requestId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }
        if (!String.isBlank(entryAction)) {
            targetPage.getParameters().put('action', entryAction);
        }
        if (!String.isBlank(entryType)) {
            targetPage.getParameters().put('type', entryType);
        }
        if (!String.isBlank(entryAuthType)) {
            targetPage.getParameters().put('authType', entryAuthType);
        }
        if (!String.isBlank(entrySubjectType)) {
            targetPage.getParameters().put('subjectType', entrySubjectType);
        }
    }

    private void setError(String message) {
        hasError = true;
        errorMessage = message;
        showPage = false;
    }

    private void clearError() {
        hasError = false;
        errorMessage = null;
    }

    private static Boolean isActiveConsentStatus(String statusValue) {
        return statusValue == STATUS_AUTHORIZED || statusValue == STATUS_VALID;
    }

    private static void setOptionalFieldSafe(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || !hasField(record, fieldApiName)) {
            return;
        }
        if (value == null) {
            try {
                record.put(fieldApiName, null);
            } catch (Exception e) {
                // Ignore optional null assignment failures.
            }
            return;
        }
        try {
            Schema.DescribeFieldResult describe = record.getSObjectType().getDescribe().fields.getMap().get(fieldApiName).getDescribe();
            if ((describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist)
                && !isPicklistValueAllowed(describe, String.valueOf(value))) {
                return;
            }
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Ignore optional field update failures.
        }
    }

    private static Boolean isPicklistValueAllowed(Schema.DescribeFieldResult describe, String value) {
        if (describe == null || String.isBlank(value)) {
            return false;
        }
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    private static String choosePicklistValue(Schema.DescribeFieldResult describe, List<String> preferredValues) {
        if (describe == null || preferredValues == null) {
            return null;
        }
        for (String preferred : preferredValues) {
            if (String.isBlank(preferred)) {
                continue;
            }
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.getValue().equalsIgnoreCase(preferred) || entry.getLabel().equalsIgnoreCase(preferred)) {
                    return entry.getValue();
                }
            }
        }
        return null;
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

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        return String.isBlank(thirdValue) ? '' : thirdValue;
    }

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    public class CBSDeclineException extends Exception {}
}