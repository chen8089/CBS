/**
 * Display-only result page for the withdrawal journey when no withdrawable
 * Active / Valid consent exists for the data subject.
 */
public without sharing class NoActiveConsentController {
    private static final String ACTION_WITHDRAW = 'withdraw';

    private static final String DEFAULT_MESSAGE =
        'There is currently no active consent available for withdrawal.';
    private static final String EXPLANATION_TEXT =
        'You may have already withdrawn, declined, or your consent may have expired. '
        + 'If you believe this is incorrect, please contact your employer\'s Human Resources team or CBS for assistance.';

    private static final String MSG_WITHDRAWN = 'Your consent has already been withdrawn.';
    private static final String MSG_DECLINED = 'You have previously declined this consent request.';
    private static final String MSG_EXPIRED = 'Your consent is no longer active because it has expired.';
    private static final String MSG_CONSUMED =
        'This pre-hire consent has already been consumed for a credit report request.';
    private static final String MSG_NO_ACTION = 'No active consent has been submitted yet.';
    private static final String MSG_NOT_FOUND =
        'We could not find an active consent record for this request.';

    private static final String PAGE_WITHDRAWAL_IMPORTANT_NOTES = '/apex/WithdrawalImportantNotesPage';

    public String contactId { get; private set; }
    public String consentId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }

    public Boolean showPage { get; private set; }
    public Boolean showDetailInfo { get; private set; }
    public Boolean showContactUsButton { get; private set; }

    public String displayMessage { get; private set; }
    public String statusMessage { get; private set; }
    public String explanationText { get; private set; }

    public String dataSubjectName { get; private set; }
    public String email { get; private set; }
    public String bankName { get; private set; }
    public String hrSupportEmail { get; private set; }
    public String referenceId { get; private set; }
    public String currentConsentStatus { get; private set; }
    public String lastStatusDate { get; private set; }
    public String employmentStatus { get; private set; }

    @TestVisible
    private Boolean hasActiveConsent { get; set; }
    @TestVisible
    private String redirectUrl { get; set; }

    private Contact contactRecord;
    private Consent__c consentRecord;
    private Consent_Request_Item__c requestItemRecord;
    private Boolean accessValidated = false;
    private Boolean isSingpass = false;
    private Boolean isManualVerification = false;

    public NoActiveConsentController() {
        parseUrlParameters();
        showPage = false;
        showDetailInfo = false;
        showContactUsButton = false;
        hasActiveConsent = false;
        displayMessage = DEFAULT_MESSAGE;
        explanationText = EXPLANATION_TEXT;
    }

    public PageReference initPage() {
        try {
            loadContext();

            if (accessValidated && hasWithdrawableActiveConsent()) {
                hasActiveConsent = true;
                PageReference redirect = buildWithdrawalRedirect();
                redirectUrl = redirect.getUrl();
                redirect.setRedirect(true);
                return redirect;
            }

            hasActiveConsent = false;
            resolveStatusMessages();
            populateDisplayValues();
            showDetailInfo = shouldShowDetailInfo();
            showPage = true;
            return null;
        } catch (Exception e) {
            hasActiveConsent = false;
            displayMessage = DEFAULT_MESSAGE;
            statusMessage = MSG_NOT_FOUND;
            explanationText = EXPLANATION_TEXT;
            showDetailInfo = false;
            showPage = true;
            return null;
        }
    }

    public String getPageTitle() {
        return 'No Active Consent Found';
    }

    public String getIntroText() {
        return 'We are unable to process a withdrawal request because there is no active consent record available for withdrawal under this request.';
    }

    public String getReasonIntroText() {
        return 'This may be because:';
    }

    public String getNextStepsTitle() {
        return 'What you can do next';
    }

    public List<String> getReasonBullets() {
        return new List<String>{
            'you have not previously provided consent;',
            'your consent has already been withdrawn;',
            'your consent was previously declined;',
            'your consent has expired;',
            'the withdrawal link is invalid or no longer active; or',
            'the request details do not match an active consent record.'
        };
    }

    public String getContactHrText() {
        return 'If you believe you have an active consent record and should be able to withdraw it, please contact '
            + getBankDepartmentForDisplay()
            + ' at:';
    }

    public String getHrSupportEmailDisplay() {
        return String.isBlank(hrSupportEmail) ? '[BANK HR SUPPORT EMAIL]' : hrSupportEmail;
    }

    public Boolean getShowHrEmailLink() {
        return !String.isBlank(hrSupportEmail) && hrSupportEmail.contains('@');
    }

    public String getCloseButtonLabel() {
        return 'Close This Page';
    }

    private String getBankDepartmentForDisplay() {
        return String.isBlank(bankName) ? '[NAME OF BANK AND DEPARTMENT]' : bankName + ' Human Resources';
    }

    public Boolean getHasActiveConsent() {
        return hasActiveConsent == true;
    }

    public String getRedirectUrl() {
        return redirectUrl;
    }

    private void loadContext() {
        accessValidated = false;
        contactRecord = null;
        consentRecord = null;
        requestItemRecord = null;

        Id subjectId = resolveContactId();
        if (subjectId == null) {
            return;
        }

        contactRecord = queryContact(subjectId);
        if (contactRecord == null) {
            return;
        }

        requestItemRecord = resolveRequestItem(subjectId);
        if (!String.isBlank(token) && !isTokenValidForRequestItem(requestItemRecord, token)) {
            contactRecord = null;
            requestItemRecord = null;
            return;
        }

        if (hasConflictingIdentifiers(subjectId)) {
            contactRecord = null;
            requestItemRecord = null;
            return;
        }

        contactId = String.valueOf(subjectId);
        consentRecord = resolveLatestConsent(subjectId);
        if (consentRecord != null) {
            consentId = consentRecord.Id;
        }
        accessValidated = true;
        resolveAuthenticationType();
    }

    private Boolean hasWithdrawableActiveConsent() {
        if (contactRecord == null) {
            return false;
        }

        Consent__c withdrawableConsent = resolveWithdrawableConsent(contactRecord.Id);
        if (withdrawableConsent == null) {
            return false;
        }

        String contactStatus = normalizeStatus(
            getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' })
        );
        if (!isActiveContactConsentStatus(contactStatus)) {
            return false;
        }

        Date contactExpiry = getDateFieldValue(
            contactRecord,
            new List<String>{ 'Current_Consent_Expiry_Date__c' }
        );
        if (contactExpiry != null && contactExpiry < Date.today()) {
            return false;
        }

        consentRecord = withdrawableConsent;
        consentId = withdrawableConsent.Id;
        return true;
    }

    private Consent__c resolveWithdrawableConsent(Id subjectId) {
        String consentIdParam = firstNonBlank(
            consentId,
            ApexPages.currentPage().getParameters().get('consentId'),
            ApexPages.currentPage().getParameters().get('id')
        );

        if (!String.isBlank(consentIdParam)) {
            Consent__c byId = queryConsentById(consentIdParam);
            if (byId != null && byId.Data_Subject__c == subjectId && isWithdrawableConsentRecord(byId)) {
                return byId;
            }
        }

        List<Consent__c> candidates = queryLatestWithdrawableConsents(subjectId);
        return candidates.isEmpty() ? null : candidates[0];
    }

    private List<Consent__c> queryLatestWithdrawableConsents(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id',
            'Data_Subject__c',
            'Consent_Status__c',
            'Consent_Expiry_Date__c',
            'Submitted_At__c',
            'Revoked_At__c',
            'CreatedDate'
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
            ' ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC LIMIT 5';

        List<Consent__c> rows = Database.query(soql);
        List<Consent__c> withdrawable = new List<Consent__c>();
        for (Consent__c row : rows) {
            if (isWithdrawableConsentRecord(row)) {
                withdrawable.add(row);
            }
        }
        return withdrawable;
    }

    private Boolean isWithdrawableConsentRecord(Consent__c consent) {
        if (consent == null) {
            return false;
        }

        String status = normalizeStatus(consent.Consent_Status__c);
        if (status != 'ACTIVE' && status != 'VALID') {
            return false;
        }

        if (consent.Consent_Expiry_Date__c != null && consent.Consent_Expiry_Date__c < Date.today()) {
            return false;
        }

        if (hasField(consent, 'Action_Type__c')) {
            String actionType = normalizeStatus(String.valueOf(consent.get('Action_Type__c')));
            if (!String.isBlank(actionType)
                && actionType != 'AUTHORIZE'
                && actionType != 'CONSENT'
                && actionType != 'CONSENT GIVEN') {
                return false;
            }
        }

        return true;
    }

    private Consent__c resolveLatestConsent(Id subjectId) {
        String consentIdParam = firstNonBlank(
            consentId,
            ApexPages.currentPage().getParameters().get('consentId'),
            ApexPages.currentPage().getParameters().get('id')
        );

        if (!String.isBlank(consentIdParam)) {
            Consent__c byId = queryConsentById(consentIdParam);
            if (byId != null && byId.Data_Subject__c == subjectId) {
                return byId;
            }
        }

        List<Consent__c> latestConsents = [
            SELECT Id, Data_Subject__c, Consent_Status__c, Consent_Expiry_Date__c, Submitted_At__c, Revoked_At__c, CreatedDate
            FROM Consent__c
            WHERE Data_Subject__c = :subjectId
            ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];
        return latestConsents.isEmpty() ? null : latestConsents[0];
    }

    private Consent__c queryConsentById(String rawConsentId) {
        try {
            Id safeId = (Id) rawConsentId;
            Map<String, Schema.SObjectField> fieldMap = Consent__c.SObjectType.getDescribe().fields.getMap();
            List<String> fields = new List<String>{
                'Id',
                'Data_Subject__c',
                'Consent_Status__c',
                'Consent_Expiry_Date__c',
                'Submitted_At__c',
                'Revoked_At__c',
                'CreatedDate'
            };
            if (fieldMap.containsKey('Action_Type__c')) {
                fields.add('Action_Type__c');
            }
            String soql =
                'SELECT ' + String.join(fields, ',') +
                ' FROM Consent__c WHERE Id = :safeId LIMIT 1';
            List<Consent__c> rows = Database.query(soql);
            return rows.isEmpty() ? null : rows[0];
        } catch (Exception e) {
            return null;
        }
    }

    private void resolveStatusMessages() {
        displayMessage = DEFAULT_MESSAGE;
        explanationText = EXPLANATION_TEXT;
        statusMessage = resolveSpecificStatusMessage();
    }

    private String resolveSpecificStatusMessage() {
        if (!accessValidated && contactRecord == null) {
            return MSG_NOT_FOUND;
        }

        String effectiveStatus = resolveEffectiveStatus();
        if (effectiveStatus == 'WITHDRAWN') {
            return MSG_WITHDRAWN;
        }
        if (effectiveStatus == 'DECLINED') {
            return MSG_DECLINED;
        }
        if (effectiveStatus == 'EXPIRED') {
            return MSG_EXPIRED;
        }
        if (effectiveStatus == 'CONSUMED') {
            return MSG_CONSUMED;
        }
        if (effectiveStatus == 'PENDING'
            || effectiveStatus == 'REQUESTED'
            || effectiveStatus == 'NO ACTION'
            || effectiveStatus == 'AUTHORIZATION REQUESTED') {
            return MSG_NO_ACTION;
        }
        if (String.isBlank(effectiveStatus)) {
            return MSG_NO_ACTION;
        }
        return MSG_NOT_FOUND;
    }

    private String resolveEffectiveStatus() {
        String consentStatus = consentRecord == null
            ? ''
            : normalizeStatus(consentRecord.Consent_Status__c);
        String contactStatus = contactRecord == null
            ? ''
            : normalizeStatus(getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' }));
        String requestStatus = requestItemRecord == null
            ? ''
            : normalizeStatus(requestItemRecord.Current_Status__c);

        if (consentStatus == 'WITHDRAWN' || contactStatus == 'WITHDRAWN' || requestStatus == 'WITHDRAWN') {
            return 'WITHDRAWN';
        }
        if (consentStatus == 'DECLINED' || contactStatus == 'DECLINED' || requestStatus == 'DECLINED') {
            return 'DECLINED';
        }
        if (consentStatus == 'CONSUMED' || requestStatus == 'CONSUMED') {
            return 'CONSUMED';
        }
        if (consentStatus == 'EXPIRED'
            || contactStatus == 'EXPIRED'
            || requestStatus == 'EXPIRED'
            || isExpiredByDate()) {
            return 'EXPIRED';
        }
        if (contactStatus == 'PENDING'
            || contactStatus == 'REQUESTED'
            || requestStatus == 'PENDING'
            || requestStatus == 'REQUESTED') {
            return 'PENDING';
        }
        if (!String.isBlank(consentStatus)) {
            return consentStatus;
        }
        if (!String.isBlank(contactStatus)) {
            return contactStatus;
        }
        return requestStatus;
    }

    private Boolean isExpiredByDate() {
        if (consentRecord != null
            && consentRecord.Consent_Expiry_Date__c != null
            && consentRecord.Consent_Expiry_Date__c < Date.today()) {
            return true;
        }

        Date contactExpiry = getDateFieldValue(
            contactRecord,
            new List<String>{ 'Current_Consent_Expiry_Date__c' }
        );
        return contactExpiry != null && contactExpiry < Date.today();
    }

    private void populateDisplayValues() {
        if (contactRecord == null) {
            return;
        }

        bankName = resolveBankName();
        hrSupportEmail = resolveHrSupportEmail();
        dataSubjectName = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'Full_Name__c', 'Principal_Name__c', 'Full_Legal_Name__c', 'Name' }),
            ''
        );
        email = blankIfNull(contactRecord.Email);
        employmentStatus = resolveEmploymentStatusLabel();
        currentConsentStatus = resolveCurrentConsentStatusLabel();
        lastStatusDate = resolveLastStatusDate();
        referenceId = resolveReferenceIdDisplay();
    }

    private Boolean shouldShowDetailInfo() {
        return accessValidated
            && contactRecord != null
            && (!String.isBlank(dataSubjectName)
                || !String.isBlank(email)
                || !String.isBlank(bankName)
                || !String.isBlank(referenceId)
                || !String.isBlank(currentConsentStatus)
                || !String.isBlank(lastStatusDate)
                || !String.isBlank(employmentStatus));
    }

    private String resolveCurrentConsentStatusLabel() {
        if (consentRecord != null && !String.isBlank(consentRecord.Consent_Status__c)) {
            return consentRecord.Consent_Status__c;
        }
        return getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' });
    }

    private String resolveLastStatusDate() {
        Datetime statusDatetime = null;

        if (consentRecord != null) {
            if (consentRecord.Revoked_At__c != null) {
                statusDatetime = consentRecord.Revoked_At__c;
            } else if (consentRecord.Submitted_At__c != null) {
                statusDatetime = consentRecord.Submitted_At__c;
            } else if (consentRecord.CreatedDate != null) {
                statusDatetime = consentRecord.CreatedDate;
            }
        }

        if (statusDatetime == null) {
            statusDatetime = getDatetimeFieldValue(
                contactRecord,
                new List<String>{
                    'Latest_Status_Datetime__c',
                    'Withdrawal_Datetime__c',
                    'Consent_Revocation_Date__c',
                    'Revoked_At__c'
                }
            );
        }

        return statusDatetime == null ? '' : statusDatetime.format('d MMMM yyyy, h:mm a');
    }

    private String resolveReferenceIdDisplay() {
        if (requestItemRecord != null && requestItemRecord.Id != null) {
            return String.valueOf(requestItemRecord.Id);
        }
        if (!String.isBlank(requestItemId)) {
            return requestItemId;
        }
        if (consentRecord != null && consentRecord.Id != null) {
            return String.valueOf(consentRecord.Id);
        }
        return '';
    }

    private String resolveBankName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        return '';
    }

    private String resolveHrSupportEmail() {
        if (contactRecord != null
            && contactRecord.Account != null
            && hasField(contactRecord.Account, 'Notification_Email__c')) {
            Object rawValue = contactRecord.Account.get('Notification_Email__c');
            if (rawValue != null && !String.isBlank(String.valueOf(rawValue))) {
                return String.valueOf(rawValue);
            }
        }
        return null;
    }

    private String resolveEmploymentStatusLabel() {
        String rawStatus = getStringFieldValue(contactRecord, new List<String>{ 'Employment_Status__c' });
        if (String.isBlank(rawStatus)) {
            String fromUrl = ApexPages.currentPage().getParameters().get('type');
            if (equalsIgnoreCase(fromUrl, 'prehire') || equalsIgnoreCase(fromUrl, 'pre-hire')) {
                return 'Pre-Hire';
            }
            if (equalsIgnoreCase(fromUrl, 'employee')) {
                return 'Existing Employee';
            }
            return '';
        }

        String normalized = rawStatus.trim().toLowerCase();
        if (normalized.contains('pre') || normalized.contains('hire') && normalized.contains('new')) {
            return 'Pre-Hire';
        }
        return 'Existing Employee';
    }

    private PageReference buildWithdrawalRedirect() {
        PageReference nextPage = new PageReference(PAGE_WITHDRAWAL_IMPORTANT_NOTES);
        copyContextParams(nextPage);
        nextPage.getParameters().put('action', ACTION_WITHDRAW);
        return nextPage;
    }

    private void resolveAuthenticationType() {
        String authenticationType = getStringFieldValue(contactRecord, new List<String>{ 'Authentication_Type__c' });
        if (String.isBlank(authenticationType)) {
            authenticationType = firstNonBlank(
                ApexPages.currentPage().getParameters().get('authType'),
                ApexPages.currentPage().getParameters().get('authenticationType'),
                ApexPages.currentPage().getParameters().get('subjectType')
            );
        }

        isSingpass = equalsIgnoreCase(authenticationType, 'Singpass')
            || (!String.isBlank(authenticationType)
                && authenticationType.toLowerCase().contains('singpass')
                && !authenticationType.toLowerCase().contains('non'));
        isManualVerification = equalsIgnoreCase(authenticationType, 'Non-Singpass')
            || (!String.isBlank(authenticationType) && authenticationType.toLowerCase().contains('non'));
    }

    private Boolean hasConflictingIdentifiers(Id subjectId) {
        Id contactIdFromParam = parseId(firstNonBlank(contactId, ApexPages.currentPage().getParameters().get('ContactId')));
        if (contactIdFromParam != null && contactIdFromParam != subjectId) {
            return true;
        }

        String consentIdParam = firstNonBlank(
            consentId,
            ApexPages.currentPage().getParameters().get('consentId'),
            ApexPages.currentPage().getParameters().get('id')
        );
        if (!String.isBlank(consentIdParam)) {
            Consent__c consent = queryConsentById(consentIdParam);
            if (consent != null && consent.Data_Subject__c != subjectId) {
                return true;
            }
        }

        if (requestItemRecord != null
            && requestItemRecord.Data_Subject__c != null
            && requestItemRecord.Data_Subject__c != subjectId) {
            return true;
        }

        return false;
    }

    private Id resolveContactId() {
        Id contactIdFromParam = parseId(firstNonBlank(contactId, ApexPages.currentPage().getParameters().get('ContactId')));

        Id fromRequest = resolveContactIdFromRequestItem();
        if (fromRequest != null) {
            if (contactIdFromParam != null && contactIdFromParam != fromRequest) {
                return null;
            }
            return fromRequest;
        }

        String consentIdParam = firstNonBlank(
            consentId,
            ApexPages.currentPage().getParameters().get('consentId'),
            ApexPages.currentPage().getParameters().get('id')
        );
        Id fromConsent = resolveContactIdByConsentId(consentIdParam);
        if (fromConsent != null) {
            if (contactIdFromParam != null && contactIdFromParam != fromConsent) {
                return null;
            }
            return fromConsent;
        }

        String recordIdParam = ApexPages.currentPage().getParameters().get('recordId');
        if (!String.isBlank(recordIdParam)) {
            Id fromRecord = resolveRecordIdToContactId(recordIdParam);
            if (fromRecord != null) {
                if (contactIdFromParam != null && contactIdFromParam != fromRecord) {
                    return null;
                }
                return fromRecord;
            }
        }

        return contactIdFromParam;
    }

    private Id resolveContactIdFromRequestItem() {
        Consent_Request_Item__c item = resolveRequestItem(null);
        return item == null || item.Data_Subject__c == null ? null : item.Data_Subject__c;
    }

    private Id resolveContactIdByConsentId(String rawConsentId) {
        Consent__c consent = queryConsentById(rawConsentId);
        return consent == null ? null : consent.Data_Subject__c;
    }

    private Id resolveRecordIdToContactId(String rawRecordId) {
        Id parsedId = parseId(rawRecordId);
        if (parsedId == null) {
            return null;
        }

        String objectName = parsedId.getSObjectType().getDescribe().getName();
        if (objectName == 'Contact') {
            return parsedId;
        }
        if (objectName == 'Consent__c') {
            return resolveContactIdByConsentId(rawRecordId);
        }
        if (objectName == 'Consent_Request_Item__c') {
            List<Consent_Request_Item__c> items = [
                SELECT Data_Subject__c
                FROM Consent_Request_Item__c
                WHERE Id = :parsedId
                LIMIT 1
            ];
            return items.isEmpty() ? null : items[0].Data_Subject__c;
        }
        return null;
    }

    private Consent_Request_Item__c resolveRequestItem(Id subjectId) {
        if (requestItemRecord != null) {
            return requestItemRecord;
        }

        String requestItemParam = firstNonBlank(
            requestItemId,
            ApexPages.currentPage().getParameters().get('requestItemId'),
            ApexPages.currentPage().getParameters().get('requestId'),
            ApexPages.currentPage().getParameters().get('consentRequestItemId')
        );

        if (!String.isBlank(requestItemParam)) {
            Consent_Request_Item__c byId = queryRequestItemById(requestItemParam);
            if (byId != null) {
                requestItemId = byId.Id;
                requestItemRecord = byId;
                return byId;
            }
        }

        if (!String.isBlank(token)) {
            Consent_Request_Item__c byToken = queryRequestItemByToken(token);
            if (byToken != null) {
                requestItemId = byToken.Id;
                requestItemRecord = byToken;
                return byToken;
            }
        }

        if (subjectId != null) {
            List<Consent_Request_Item__c> latestItems = [
                SELECT Id, Data_Subject__c, Current_Status__c
                FROM Consent_Request_Item__c
                WHERE Data_Subject__c = :subjectId
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 1
            ];
            if (!latestItems.isEmpty()) {
                requestItemId = latestItems[0].Id;
                requestItemRecord = latestItems[0];
                return latestItems[0];
            }
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

    private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
        Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
        String tokenField = findFirstExistingField(fieldMap, new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
        if (String.isBlank(tokenField)) {
            return null;
        }

        String soql =
            'SELECT Id, Data_Subject__c, Current_Status__c FROM Consent_Request_Item__c WHERE '
            + tokenField + ' = :tokenValue LIMIT 1';
        List<Consent_Request_Item__c> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{
            'Id', 'Name', 'Email', 'AccountId', 'Account.Name', 'Current_Consent_Status__c', 'Current_Consent_Expiry_Date__c'
        };
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
        if (accountFields.containsKey('Notification_Email__c')) {
            fields.add('Account.Notification_Email__c');
        }
        List<String> optional = new List<String>{
            'Full_Name__c',
            'Principal_Name__c',
            'Full_Legal_Name__c',
            'Employment_Status__c',
            'Authentication_Type__c',
            'Latest_Status_Datetime__c',
            'Withdrawal_Datetime__c',
            'Consent_Revocation_Date__c',
            'Revoked_At__c'
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

    private Boolean isTokenValidForRequestItem(Consent_Request_Item__c requestItem, String tokenValue) {
        return ConsentGuestAuthService.isTokenValidForRequestItem(
            requestItem,
            tokenValue,
            parseId(contactId)
        );
    }

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        consentId = firstNonBlank(params.get('consentId'), params.get('id'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('requestId'), params.get('consentRequestItemId'));
        token = params.get('token');
    }

    private void copyContextParams(PageReference targetPage) {
        if (targetPage == null) {
            return;
        }

        if (!String.isBlank(contactId)) {
            targetPage.getParameters().put('ContactId', contactId);
        }
        if (!String.isBlank(consentId)) {
            targetPage.getParameters().put('id', consentId);
            targetPage.getParameters().put('consentId', consentId);
        }
        if (!String.isBlank(requestItemId)) {
            targetPage.getParameters().put('requestItemId', requestItemId);
        }
        if (!String.isBlank(token)) {
            targetPage.getParameters().put('token', token);
        }

        List<String> passthroughParams = new List<String>{ 'recordId', 'action', 'type', 'authType', 'authenticationType', 'subjectType' };
        for (String key : passthroughParams) {
            String value = ApexPages.currentPage().getParameters().get(key);
            if (!String.isBlank(value)) {
                targetPage.getParameters().put(key, value);
            }
        }
    }

    private static Boolean isActiveContactConsentStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }
        String normalized = statusValue.trim().toLowerCase();
        return normalized == 'authorized' || normalized == 'valid';
    }

    private static String normalizeStatus(String statusValue) {
        return String.isBlank(statusValue) ? '' : statusValue.trim().toUpperCase();
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

    private static Date getDateFieldValue(SObject record, List<String> fieldCandidates) {
        if (record == null) {
            return null;
        }
        for (String fieldApi : fieldCandidates) {
            if (hasField(record, fieldApi)) {
                Object rawValue = record.get(fieldApi);
                if (rawValue instanceof Date) {
                    return (Date) rawValue;
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
        return thirdValue;
    }

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue, String fourthValue) {
        if (!String.isBlank(firstValue)) {
            return firstValue;
        }
        if (!String.isBlank(secondValue)) {
            return secondValue;
        }
        if (!String.isBlank(thirdValue)) {
            return thirdValue;
        }
        return fourthValue;
    }

    private static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.toLowerCase() == right.toLowerCase();
    }
}