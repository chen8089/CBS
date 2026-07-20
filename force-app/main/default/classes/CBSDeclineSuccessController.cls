/**
 * Decline Success confirmation page for Data Subjects accessing via Salesforce Sites / Experience Cloud.
 * Display-only on page load: decline status updates are performed by CBSDeclineConsentConfirmationController
 * before redirecting here. Supports fallback decline processing when the request is still pending.
 */
public without sharing class CBSDeclineSuccessController {
    private static final String STATUS_DECLINED = 'Declined';
    private static final String STATUS_WITHDRAWN = 'Withdrawn';
    private static final String STATUS_EXPIRED = 'Expired';
    private static final String STATUS_AUTHORIZED = 'Authorized';
    private static final String STATUS_VALID = 'Valid';
    private static final String STATUS_SUBMITTED = 'Submitted';

    private static final String PAGE_LINK_EXPIRED = '/apex/QRSiteLinkExpired';
    private static final String PAGE_CONSENT_ALREADY_ACTIONED = '/apex/QRSiteConsentAlreadyActioned';
    private static final String PAGE_ACTIVE_CONSENT = '/apex/ActiveConsentNotificationPage';

    private static final String BANK_NAME_FALLBACK = '[NAME OF BANK]';
    private static final String DISPLAY_PLACEHOLDER = '-';
    private static final String CBS_ENTITY_LABEL = 'Credit Bureau (Singapore) Pte Ltd (\u201cCBS\u201d)';
    private static final String ERROR_INVALID_LINK =
        'We are unable to display your declination confirmation. The link may be invalid or expired.';
    private static final String ERROR_NOT_DECLINED =
        'We are unable to display your declination confirmation at this time. Please return to the decline confirmation page and try again.';
    private static final String ERROR_DML_FAILURE =
        'We are unable to process your declination at this time. Please contact support.';

    @TestVisible
    private static Boolean simulateDmlFailureForTest = false;

    public String contactId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public String referenceId { get; private set; }

    public String bankName { get; private set; }
    public String dataSubjectName { get; private set; }
    public String email { get; private set; }
    public String submittedDateTime { get; private set; }
    public String hrSupportEmail { get; private set; }
    public Boolean isSuccess { get; private set; }
    public String errorMessage { get; private set; }

    public Boolean showError { get; private set; }

    private Contact dataSubject;
    private Consent_Request_Item__c requestItemRecord;
    private Consent__c declineConsentRecord;
    private Boolean contextInitialized = false;

    public CBSDeclineSuccessController() {
        parseUrlParameters();
        isSuccess = false;
        showError = false;
    }

    public PageReference initPage() {
        try {
            clearError();
            initContext();

            PageReference statusRedirect = resolveStatusRedirect();
            if (statusRedirect != null) {
                statusRedirect.setRedirect(true);
                return statusRedirect;
            }

            if (isLinkExpired()) {
                PageReference expiredPage = buildRedirect(PAGE_LINK_EXPIRED);
                expiredPage.setRedirect(true);
                return expiredPage;
            }

            if (!validateRequest()) {
                return null;
            }

            if (!hasDeclinedStatus()) {
                if (canProcessPendingDecline()) {
                    Savepoint savepointBeforeSubmit = Database.setSavepoint();
                    try {
                        processPendingDecline();
                    } catch (DmlException e) {
                        Database.rollback(savepointBeforeSubmit);
                        markError(ERROR_DML_FAILURE);
                        return null;
                    } catch (Exception e) {
                        Database.rollback(savepointBeforeSubmit);
                        markError(ERROR_DML_FAILURE);
                        return null;
                    }
                    refreshContextAfterDecline();
                } else {
                    markError(ERROR_NOT_DECLINED);
                    return null;
                }
            }

            populateDisplayValues();
            isSuccess = true;
            return null;
        } catch (Exception e) {
            markError(ERROR_INVALID_LINK);
            return null;
        }
    }

    public String getPageTitle() {
        return 'Consent Declined';
    }

    public String getStatusMessage() {
        return 'Your decision to decline consent has been recorded.';
    }

    public String getWhatThisMeansTitle() {
        return 'What this means';
    }

    public List<String> getWhatThisMeansBulletPoints() {
        String displayBankName = getDisplayBankName();
        return new List<String>{
            displayBankName + ' will be notified that you have declined consent.',
            displayBankName + ' will not be able to submit a credit report request to CBS under this consent request.',
            'If you wish to provide consent in future, you may be required to use a new consent link provided by '
                + getDisplayBankAndDepartment()
                + '.'
        };
    }

    public String getContactParagraphPrefix() {
        return 'If you have any questions about this request, please contact '
            + getDisplayBankAndDepartment()
            + ' at ';
    }

    public String getHrSupportEmailDisplay() {
        return String.isBlank(hrSupportEmail) ? '[BANK HR SUPPORT EMAIL]' : hrSupportEmail;
    }

    public Boolean getShowHrEmailLink() {
        return !String.isBlank(hrSupportEmail) && hrSupportEmail.contains('@');
    }

    public String getClosePageButtonLabel() {
        return 'Close This Page';
    }

    private void initContext() {
        if (contextInitialized) {
            return;
        }
        resolveDataContext();
        contextInitialized = true;
    }

    private void refreshContextAfterDecline() {
        contextInitialized = false;
        declineConsentRecord = null;
        initContext();
    }

    private Boolean validateRequest() {
        if (!hasResolvableIdentifier()) {
            markError(ERROR_INVALID_LINK);
            return false;
        }

        if (dataSubject == null) {
            markError(ERROR_INVALID_LINK);
            return false;
        }

        if (!isTokenValid()) {
            markError(ERROR_INVALID_LINK);
            return false;
        }

        return true;
    }

    private PageReference resolveStatusRedirect() {
        if (dataSubject == null) {
            return null;
        }

        String contactStatus = blankIfNull(getStringFieldValue(
            dataSubject,
            new List<String>{ 'Current_Consent_Status__c' }
        ));

        if (isActiveConsentStatus(contactStatus)) {
            return buildRedirect(PAGE_ACTIVE_CONSENT);
        }
        if (contactStatus == STATUS_WITHDRAWN) {
            return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
        }
        if (contactStatus == STATUS_EXPIRED) {
            return buildRedirect(PAGE_LINK_EXPIRED);
        }

        if (requestItemRecord != null) {
            String requestStatus = blankIfNull(requestItemRecord.Current_Status__c);
            if (requestStatus == STATUS_SUBMITTED) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (requestStatus == STATUS_WITHDRAWN) {
                return buildRedirect(PAGE_CONSENT_ALREADY_ACTIONED);
            }
            if (requestStatus == STATUS_EXPIRED) {
                return buildRedirect(PAGE_LINK_EXPIRED);
            }
        }

        return null;
    }

    private Boolean hasDeclinedStatus() {
        if (normalizeStatus(getStringFieldValue(
            dataSubject,
            new List<String>{ 'Current_Consent_Status__c' }
        )) == STATUS_DECLINED) {
            return true;
        }

        if (requestItemRecord != null
            && normalizeStatus(requestItemRecord.Current_Status__c) == STATUS_DECLINED) {
            return true;
        }

        declineConsentRecord = resolveLatestDeclinedConsent();
        return declineConsentRecord != null;
    }

    private Boolean canProcessPendingDecline() {
        String contactStatus = normalizeStatus(getStringFieldValue(
            dataSubject,
            new List<String>{ 'Current_Consent_Status__c' }
        ));
        if (!String.isBlank(contactStatus) && contactStatus != 'Pending' && contactStatus != 'Sent') {
            return false;
        }

        if (requestItemRecord != null) {
            String requestStatus = normalizeStatus(requestItemRecord.Current_Status__c);
            if (requestStatus == STATUS_DECLINED || requestStatus == STATUS_SUBMITTED
                || requestStatus == STATUS_WITHDRAWN) {
                return false;
            }
        }

        return true;
    }

    private void processPendingDecline() {
        if (simulateDmlFailureForTest) {
            throw new DmlException('Simulated DML failure for test coverage.');
        }

        updateContactDeclined();
        updateConsentRequestItemDeclined();
        createDeclineConsentRecord();
        notifyClientOfDecline();
    }

    private void updateContactDeclined() {
        String declinedContactStatus = choosePicklistValue(
            Contact.Current_Consent_Status__c.getDescribe(),
            new List<String>{ STATUS_DECLINED }
        );
        if (String.isBlank(declinedContactStatus)) {
            throw new CBSDeclineSuccessException('Current_Consent_Status__c picklist value "Declined" is not configured.');
        }

        String declinedLifecycleStage = choosePicklistValue(
            Contact.Data_Subject_Lifecycle_Stage__c.getDescribe(),
            new List<String>{ 'Consent Declined' }
        );
        if (String.isBlank(declinedLifecycleStage)) {
            throw new CBSDeclineSuccessException('Data_Subject_Lifecycle_Stage__c picklist value "Consent Declined" is not configured.');
        }

        Contact contactUpdate = new Contact(Id = dataSubject.Id);
        contactUpdate.Current_Consent_Status__c = declinedContactStatus;
        contactUpdate.Data_Subject_Lifecycle_Stage__c = declinedLifecycleStage;

        Datetime submittedAt = System.now();
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

        update requestItemUpdate;
    }

    private void createDeclineConsentRecord() {
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
        declineConsentRecord = declineConsent;
    }

    private void notifyClientOfDecline() {
        Id requestItemLookupId = requestItemRecord == null ? null : requestItemRecord.Id;
        DeclineConsentNotificationService.notifyClientOfDecline(dataSubject == null ? null : dataSubject.Id, requestItemLookupId);
    }

    private void populateDisplayValues() {
        bankName = resolveBankName();
        dataSubjectName = resolveDataSubjectName();
        email = resolveEmail();
        submittedDateTime = formatSubmittedDateTime();
        referenceId = resolveReferenceIdDisplay();
        hrSupportEmail = resolveHrSupportEmail();
    }

    private String resolveDataSubjectName() {
        String resolvedName = getStringFieldValue(
            dataSubject,
            new List<String>{ 'Principal_Name__c', 'Full_Name__c', 'Full_Legal_Name__c', 'Name' }
        );
        return String.isBlank(resolvedName) ? DISPLAY_PLACEHOLDER : resolvedName;
    }

    private String resolveEmail() {
        String resolvedEmail = getStringFieldValue(dataSubject, new List<String>{ 'Email' });
        return String.isBlank(resolvedEmail) ? DISPLAY_PLACEHOLDER : resolvedEmail;
    }

    private String resolveBankName() {
        if (dataSubject != null && dataSubject.Account != null && !String.isBlank(dataSubject.Account.Name)) {
            return dataSubject.Account.Name;
        }
        return BANK_NAME_FALLBACK;
    }

    private String resolveHrSupportEmail() {
        if (dataSubject == null || dataSubject.Account == null) {
            return null;
        }

        if (!hasField(dataSubject.Account, 'Notification_Email__c')) {
            return null;
        }

        Object rawValue = dataSubject.Account.get('Notification_Email__c');
        if (rawValue != null && !String.isBlank(String.valueOf(rawValue))) {
            return String.valueOf(rawValue);
        }
        return null;
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

    private String formatSubmittedDateTime() {
        Datetime submittedAt = null;

        if (declineConsentRecord == null) {
            declineConsentRecord = resolveLatestDeclinedConsent();
        }
        if (declineConsentRecord != null && declineConsentRecord.Submitted_At__c != null) {
            submittedAt = declineConsentRecord.Submitted_At__c;
        }

        if (submittedAt == null) {
            submittedAt = getDatetimeFieldValue(
                dataSubject,
                new List<String>{ 'Latest_Submission_Datetime__c', 'Latest_Status_Datetime__c' }
            );
        }

        if (submittedAt == null && requestItemRecord != null) {
            submittedAt = getDatetimeFieldValue(
                requestItemRecord,
                new List<String>{ 'Submitted_At__c', 'Latest_Submission_Date_Time__c', 'Latest_Status_Datetime__c' }
            );
        }

        return submittedAt == null ? DISPLAY_PLACEHOLDER : submittedAt.format('d MMMM yyyy, h:mm a');
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
        if (declineConsentRecord != null && declineConsentRecord.Id != null) {
            return String.valueOf(declineConsentRecord.Id);
        }
        return DISPLAY_PLACEHOLDER;
    }

    private Consent__c resolveLatestDeclinedConsent() {
        if (dataSubject == null || dataSubject.Id == null) {
            return null;
        }

        Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id', 'Data_Subject__c', 'Consent_Status__c', 'Submitted_At__c'
        };
        List<String> optional = new List<String>{ 'Consent_Request_Item__c', 'Action_Type__c' };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }

        Id subjectId = dataSubject.Id;
        Id requestItemLookupId = requestItemRecord == null ? null : requestItemRecord.Id;
        String soql =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Consent__c WHERE Data_Subject__c = :subjectId AND Consent_Status__c = :STATUS_DECLINED';
        if (requestItemLookupId != null && fieldMap.containsKey('Consent_Request_Item__c')) {
            soql += ' AND Consent_Request_Item__c = :requestItemLookupId';
        }
        soql += ' ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC LIMIT 1';

        List<Consent__c> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private void resolveDataContext() {
        dataSubject = null;
        requestItemRecord = null;

        requestItemRecord = resolveRequestItem();
        if (requestItemRecord != null && requestItemRecord.Data_Subject__c != null) {
            if (String.isBlank(contactId)) {
                contactId = String.valueOf(requestItemRecord.Data_Subject__c);
            }
            requestItemId = String.valueOf(requestItemRecord.Id);
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
            requestItemId,
            referenceId,
            ApexPages.currentPage().getParameters().get('requestId'),
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
            'Latest_Status_Datetime__c'
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
            'Full_Legal_Name__c',
            'Current_Consent_Status__c',
            'Latest_Submission_Datetime__c',
            'Latest_Status_Datetime__c'
        };
        Map<String, Schema.SObjectField> accountFieldMap = Schema.SObjectType.Account.fields.getMap();
        List<String> accountOptional = new List<String>{ 'Notification_Email__c' };
        for (String candidate : optional) {
            if (fieldMap.containsKey(candidate)) {
                fields.add(candidate);
            }
        }
        for (String candidate : accountOptional) {
            if (accountFieldMap.containsKey(candidate)) {
                fields.add('Account.' + candidate);
            }
        }

        String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Boolean hasResolvableIdentifier() {
        return parseId(contactId) != null
            || parseId(requestItemId) != null
            || parseId(referenceId) != null
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
        requestItemId = firstNonBlank(
            params.get('requestItemId'),
            params.get('consentRequestItemId'),
            params.get('requestId')
        );
        referenceId = params.get('referenceId');
        token = params.get('token');
    }

    private PageReference buildRedirect(String pagePath) {
        PageReference pageRef = new PageReference(pagePath);
        copyContextParams(pageRef);
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
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestId', requestItemId);
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

    private void markError(String message) {
        showError = true;
        isSuccess = false;
        errorMessage = message;
    }

    private void clearError() {
        showError = false;
        errorMessage = null;
        isSuccess = false;
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

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        return String.isBlank(thirdValue) ? '' : thirdValue;
    }

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue, String fourthValue) {
        String resolved = firstNonBlank(firstValue, secondValue, thirdValue);
        return !String.isBlank(resolved) ? resolved : (String.isBlank(fourthValue) ? '' : fourthValue);
    }

    private static String firstNonBlank(
        String firstValue,
        String secondValue,
        String thirdValue,
        String fourthValue,
        String fifthValue
    ) {
        String resolved = firstNonBlank(firstValue, secondValue, thirdValue, fourthValue);
        return !String.isBlank(resolved) ? resolved : (String.isBlank(fifthValue) ? '' : fifthValue);
    }

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private static String normalizeStatus(String value) {
        return value == null ? '' : value.trim();
    }

    public class CBSDeclineSuccessException extends Exception {}

}