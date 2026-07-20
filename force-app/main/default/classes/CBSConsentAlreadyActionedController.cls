/**
 * Display-only page for consent journeys when the request has already been actioned.
 * Does not perform consent submission, decline, withdrawal, or Singpass actions.
 */
public without sharing class CBSConsentAlreadyActionedController {
    private static final String DEFAULT_RETURN_URL = 'https://www.creditbureau.com.sg';

    private static final String TITLE_ALREADY_ACTIONED = 'Consent Request Already Actioned';
    private static final String TITLE_NOT_AVAILABLE = 'Consent Request Not Available';

    private static final String MAIN_MESSAGE_NOT_AVAILABLE =
        'This consent request could not be found or is no longer available. '
        + 'Please contact your employer\'s HR team if you need assistance.';

    private static final String REASON_INTRO_TEXT = 'This may be because:';
    private static final String WHAT_THIS_MEANS_TITLE = 'What this means';
    private static final String HR_EMAIL_PLACEHOLDER = '[BANK HR SUPPORT EMAIL]';
    private static final String BANK_NAME_PLACEHOLDER = '[NAME OF BANK]';
    private static final String BANK_AND_DEPT_PLACEHOLDER = '[NAME OF BANK AND DEPARTMENT]';
    private static final String CBS_PRIVACY_EMAIL = 'Privacy@creditbureau.com.sg';

    private static final Set<String> TERMINAL_STATUSES = new Set<String>{
        'VALID',
        'ACTIVE',
        'AUTHORIZED',
        'DECLINED',
        'WITHDRAWN',
        'REVOKED',
        'EXPIRED',
        'CONSUMED'
    };

  public String pageTitle { get; private set; }
  public String mainMessage { get; private set; }
  public String statusMessage { get; private set; }
  public String currentStatus { get; private set; }
  public String bankName { get; private set; }
  public String referenceId { get; private set; }
  public String lastActionDateTimeText { get; private set; }
  public Boolean hasRecord { get; private set; }
  public Boolean isTokenValid { get; private set; }
  public Boolean showRequestDetails { get; private set; }
  public Boolean showPage { get; private set; }
  public Boolean showActionedContent { get; private set; }
  public String openingMessage { get; private set; }
  public String currentConsentStatusLine { get; private set; }
  public String reasonIntroText { get; private set; }
  public String statusConfirmationText { get; private set; }
  public String whatThisMeansTitle { get; private set; }
  public String contactHrText { get; private set; }
  public String contactHrPrefix { get; private set; }
  public String hrSupportEmail { get; private set; }

  private List<String> reasonBullets = new List<String>();
  private List<String> whatThisMeansItems = new List<String>();

  private String contactIdParam;
  private String requestItemIdParam;
  private String consentIdParam;
  private String tokenParam;
  private String actionParam;
  private String contactIdFromUrl;

  private String configuredReturnUrl;

  private Contact contactRecord;
  private Consent__c consentRecord;
  private Consent_Request_Item__c requestItemRecord;

  public CBSConsentAlreadyActionedController() {
    parseUrlParameters();
    initializeDefaults();
  }

  public PageReference init() {
    try {
      loadContext();

      if (!hasDisplayableContext()) {
        applyNotAvailableState();
        return null;
      }

      hasRecord = true;
      resolveCurrentStatus();
      populateRequestDetails();

      PageReference flowRedirect = resolveFlowRedirectForNonTerminalStatus();
      if (flowRedirect != null) {
        flowRedirect.setRedirect(true);
        return flowRedirect;
      }

      populatePageContent();
      showPage = true;
      showActionedContent = true;
      showRequestDetails = true;
      return null;
    } catch (Exception e) {
      applyNotAvailableState();
      return null;
    }
  }

  public String getReturnUrl() {
    return String.isBlank(configuredReturnUrl) ? DEFAULT_RETURN_URL : configuredReturnUrl;
  }

  public String getCloseButtonLabel() {
    return 'Close This Page';
  }

  public Boolean getShowHrEmailLink() {
    return !String.isBlank(hrSupportEmail) && hrSupportEmail.contains('@');
  }

  public String getHrSupportEmailDisplay() {
    return String.isBlank(hrSupportEmail) ? HR_EMAIL_PLACEHOLDER : hrSupportEmail;
  }

  public List<String> getReasonBullets() {
    return reasonBullets;
  }

  public List<String> getWhatThisMeansItems() {
    return whatThisMeansItems;
  }

  private void initializeDefaults() {
    pageTitle = TITLE_ALREADY_ACTIONED;
    mainMessage = '';
    statusMessage = '';
    currentStatus = '';
    bankName = '';
    referenceId = '';
    lastActionDateTimeText = '';
    hasRecord = false;
    isTokenValid = false;
    showRequestDetails = false;
    showPage = false;
    showActionedContent = false;
    openingMessage = '';
    currentConsentStatusLine = '';
    reasonIntroText = '';
    statusConfirmationText = '';
    whatThisMeansTitle = '';
    contactHrText = '';
    contactHrPrefix = '';
    hrSupportEmail = '';
    reasonBullets = new List<String>();
    whatThisMeansItems = new List<String>();
    configuredReturnUrl = DEFAULT_RETURN_URL;
    contactRecord = null;
    consentRecord = null;
    requestItemRecord = null;
  }

  private void applyNotAvailableState() {
    pageTitle = TITLE_NOT_AVAILABLE;
    mainMessage = MAIN_MESSAGE_NOT_AVAILABLE;
    statusMessage = '';
    currentStatus = '';
    bankName = '';
    referenceId = '';
    lastActionDateTimeText = '';
    hasRecord = false;
    showRequestDetails = false;
    showPage = true;
    showActionedContent = false;
    openingMessage = '';
    currentConsentStatusLine = '';
    reasonIntroText = '';
    statusConfirmationText = '';
    whatThisMeansTitle = '';
    contactHrText = '';
    contactHrPrefix = '';
    hrSupportEmail = '';
    reasonBullets = new List<String>();
    whatThisMeansItems = new List<String>();
  }

  private void populatePageContent() {
    pageTitle = TITLE_ALREADY_ACTIONED;
    mainMessage = '';

    hrSupportEmail = resolveHrSupportEmail();

    openingMessage =
      'We are unable to process this ' + resolveActionRequestLabel()
      + ' request because this consent request has already been actioned.';

    currentConsentStatusLine = 'Current Consent Status: ' + resolveCurrentStatusDisplay();

    reasonIntroText = REASON_INTRO_TEXT;
    reasonBullets = new List<String>{
      'you have already provided consent;',
      'you have already withdrawn your consent; or',
      'you have already declined to provide consent.'
    };
    whatThisMeansTitle = WHAT_THIS_MEANS_TITLE;
    whatThisMeansItems = new List<String>{
      'If your current consent status is Active, you cannot decline the same consent request. '
        + 'If you wish to withdraw your consent, please refer to the original email sent by '
        + getBankDepartmentForDisplay()
        + ' and click the withdrawal link provided in that email. '
        + 'Alternatively, you may also reach out to '
        + getBankDepartmentForDisplay()
        + ' or CBS at '
        + CBS_PRIVACY_EMAIL
        + ' for assistance in processing your withdrawal.',
      'If your current consent status is Withdrawn, no further action is required. '
        + getBankNameForDisplay()
        + ' will not be able to submit any new credit report request to CBS under this consent.',
      'If your current consent status is Declined, no further action is required. '
        + getBankNameForDisplay()
        + ' has already been notified that you declined consent.'
    };

    contactHrPrefix =
      'If you have any questions, please contact '
      + getBankDepartmentForDisplay()
      + ' at ';
    contactHrText = contactHrPrefix + getHrSupportEmailDisplay() + '.';

    statusMessage = resolveLegacyStatusMessage();
  }

  private String getBankDepartmentForDisplay() {
    if (String.isBlank(bankName)) {
      return BANK_AND_DEPT_PLACEHOLDER;
    }
    return bankName + ' Human Resources';
  }

  private String resolveActionRequestLabel() {
    String normalized = String.isBlank(actionParam) ? '' : actionParam.trim().toLowerCase();
    if (normalized == 'decline' || normalized == 'declined') {
      return 'decline';
    }
    if (normalized == 'withdraw' || normalized == 'withdrawal') {
      return 'withdrawal';
    }
    if (normalized == 'consent' || normalized == 'authorize' || normalized == 'authorization') {
      return 'consent';
    }
    return 'decline';
  }

  private String getBankNameForDisplay() {
    return String.isBlank(bankName) ? BANK_NAME_PLACEHOLDER : bankName;
  }

  private String resolveCurrentStatusDisplay() {
    if (!String.isBlank(currentStatus)) {
      return currentStatus;
    }
    return '[CURRENT CONSENT STATUS]';
  }

  private String resolveHrSupportEmail() {
    String fromContactAccount = getNotificationEmailFromContactAccount();
    if (!String.isBlank(fromContactAccount)) {
      return fromContactAccount;
    }

    Id accountId = resolveAccountId();
    if (accountId != null) {
      return queryAccountNotificationEmail(accountId);
    }

    return null;
  }

  private String getNotificationEmailFromContactAccount() {
    if (contactRecord == null || contactRecord.Account == null) {
      return null;
    }

    if (!hasField(contactRecord.Account, 'Notification_Email__c')) {
      return null;
    }

    Object rawValue = contactRecord.Account.get('Notification_Email__c');
    return rawValue == null || String.isBlank(String.valueOf(rawValue))
      ? null
      : String.valueOf(rawValue).trim();
  }

  private Id resolveAccountId() {
    if (contactRecord != null && contactRecord.AccountId != null) {
      return contactRecord.AccountId;
    }
    return null;
  }

  private String queryAccountNotificationEmail(Id accountId) {
    if (accountId == null) {
      return null;
    }

    Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
    if (!accountFields.containsKey('Notification_Email__c')) {
      return null;
    }

    List<Account> rows = [
      SELECT Notification_Email__c
      FROM Account
      WHERE Id = :accountId
      LIMIT 1
    ];
    if (rows.isEmpty() || String.isBlank(rows[0].Notification_Email__c)) {
      return null;
    }
    return rows[0].Notification_Email__c.trim();
  }

  private String resolveLegacyStatusMessage() {
    String normalized = normalizeStatus(currentStatus);
    if (normalized == 'VALID' || normalized == 'ACTIVE' || normalized == 'AUTHORIZED') {
      return 'You have already provided consent for this request.';
    }
    if (normalized == 'DECLINED') {
      return 'You have already declined to give consent for this request.';
    }
    if (normalized == 'WITHDRAWN' || normalized == 'REVOKED') {
      return 'You have already withdrawn your consent.';
    }
    if (normalized == 'EXPIRED') {
      return 'This consent request is no longer active.';
    }
    if (normalized == 'CONSUMED') {
      return 'This consent has already been used for a completed credit report retrieval and cannot be reused.';
    }
    return 'This consent request cannot be actioned at this time.';
  }

  private void loadContext() {
    if (!String.isBlank(consentIdParam)) {
      loadByConsentId(parseId(consentIdParam));
    } else if (!String.isBlank(requestItemIdParam)) {
      loadByRequestItemId(parseId(requestItemIdParam));
    } else if (!String.isBlank(contactIdParam)) {
      loadByContactId(parseId(contactIdParam));
    } else if (!String.isBlank(tokenParam)) {
      Consent_Request_Item__c byToken = queryRequestItemByToken(tokenParam);
      if (byToken != null) {
        requestItemRecord = byToken;
        requestItemIdParam = byToken.Id;
        if (byToken.Data_Subject__c != null) {
          loadByContactId(byToken.Data_Subject__c);
        }
      }
    }

    if (requestItemRecord == null && !String.isBlank(requestItemIdParam)) {
      loadByRequestItemId(parseId(requestItemIdParam));
    }

    if (contactRecord == null && !String.isBlank(contactIdParam)) {
      loadByContactId(parseId(contactIdParam));
    }

    isTokenValid = validateToken();
  }

  private void loadByConsentId(Id consentId) {
    if (consentId == null) {
      return;
    }

    consentRecord = queryConsentById(consentId);
    if (consentRecord == null) {
      return;
    }

    consentIdParam = String.valueOf(consentId);

    if (consentRecord.Data_Subject__c != null) {
      Id subjectId = consentRecord.Data_Subject__c;
      if (contactRecord == null) {
        contactRecord = queryContact(subjectId);
      }
      contactIdParam = String.valueOf(subjectId);
    }

    if (requestItemRecord == null && hasField(consentRecord, 'Consent_Request_Item__c')) {
      Object rawRequestItemId = consentRecord.get('Consent_Request_Item__c');
      if (rawRequestItemId instanceof Id) {
        loadByRequestItemId((Id) rawRequestItemId);
      }
    }
  }

  private void loadByRequestItemId(Id requestItemId) {
    if (requestItemId == null) {
      return;
    }

    Consent_Request_Item__c item = queryRequestItemById(requestItemId);
    if (item == null) {
      return;
    }

    requestItemRecord = item;
    requestItemIdParam = String.valueOf(requestItemId);

    if (item.Data_Subject__c != null) {
      Id subjectId = item.Data_Subject__c;
      if (contactRecord == null) {
        contactRecord = queryContact(subjectId);
      }
      contactIdParam = String.valueOf(subjectId);
    }

    if (consentRecord == null && contactRecord != null) {
      consentRecord = resolveLatestConsent(contactRecord.Id);
      if (consentRecord != null) {
        consentIdParam = consentRecord.Id;
      }
    }
  }

  private void loadByContactId(Id contactId) {
    if (contactId == null) {
      return;
    }

    if (contactRecord == null) {
      contactRecord = queryContact(contactId);
    }
    if (contactRecord == null) {
      return;
    }

    contactIdParam = String.valueOf(contactId);

    if (requestItemRecord == null) {
      requestItemRecord = resolveRequestItem(contactId);
    }

    if (consentRecord == null) {
      consentRecord = resolveLatestConsent(contactId);
      if (consentRecord != null) {
        consentIdParam = consentRecord.Id;
      }
    }
  }

  private void resolveCurrentStatus() {
    String consentStatus = consentRecord == null
      ? ''
      : normalizeStatus(blankIfNull(consentRecord.Consent_Status__c));
    String contactStatus = contactRecord == null
      ? ''
      : normalizeStatus(getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' }));
    String requestStatus = requestItemRecord == null
      ? ''
      : normalizeStatus(blankIfNull(requestItemRecord.Current_Status__c));

    String effectiveStatus = resolveEffectiveStatus(consentStatus, contactStatus, requestStatus);
    if (effectiveStatus == 'CONSUMED' && requestItemRecord != null) {
      currentStatus = requestItemRecord.Current_Status__c;
    } else if (!String.isBlank(consentStatus)) {
      currentStatus = consentRecord.Consent_Status__c;
    } else if (!String.isBlank(contactStatus)) {
      currentStatus = getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' });
    } else if (!String.isBlank(requestStatus)) {
      currentStatus = requestItemRecord.Current_Status__c;
    } else {
      currentStatus = '';
    }

    if (isExpiredByDate()) {
      currentStatus = 'Expired';
    }
  }

  private String resolveEffectiveStatus(String consentStatus, String contactStatus, String requestStatus) {
    if (consentStatus == 'WITHDRAWN' || contactStatus == 'WITHDRAWN' || requestStatus == 'WITHDRAWN') {
      return 'WITHDRAWN';
    }
    if (consentStatus == 'REVOKED' || contactStatus == 'REVOKED' || requestStatus == 'REVOKED') {
      return 'REVOKED';
    }
    if (consentStatus == 'DECLINED' || contactStatus == 'DECLINED' || requestStatus == 'DECLINED') {
      return 'DECLINED';
    }
    if (consentStatus == 'CONSUMED' || requestStatus == 'CONSUMED') {
      return 'CONSUMED';
    }
    if (consentStatus == 'EXPIRED' || contactStatus == 'EXPIRED' || requestStatus == 'EXPIRED' || isExpiredByDate()) {
      return 'EXPIRED';
    }
    if (!String.isBlank(consentStatus)) {
      return consentStatus;
    }
    if (!String.isBlank(contactStatus)) {
      return contactStatus;
    }
    return requestStatus;
  }

  private void populateRequestDetails() {
    bankName = resolveBankName();
    referenceId = resolveReferenceId();
    lastActionDateTimeText = resolveLastActionDateTimeText();
  }

  private String resolveBankName() {
    if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
      return contactRecord.Account.Name;
    }
    return '';
  }

  private String resolveReferenceId() {
    if (requestItemRecord != null && !String.isBlank(requestItemRecord.Name)) {
      return requestItemRecord.Name;
    }

    if (requestItemRecord != null && hasField(requestItemRecord, 'Consent_Request_Case__c')) {
      Object caseId = requestItemRecord.get('Consent_Request_Case__c');
      if (caseId instanceof Id) {
        List<Case> cases = [
          SELECT CaseNumber
          FROM Case
          WHERE Id = :((Id) caseId)
          LIMIT 1
        ];
        if (!cases.isEmpty() && !String.isBlank(cases[0].CaseNumber)) {
          return cases[0].CaseNumber;
        }
      }
    }

    if (!String.isBlank(requestItemIdParam)) {
      return requestItemIdParam;
    }

    if (contactRecord != null) {
      return String.valueOf(contactRecord.Id);
    }

    return '';
  }

  private String resolveLastActionDateTimeText() {
    String normalized = normalizeStatus(currentStatus);

    if (normalized == 'VALID' || normalized == 'ACTIVE' || normalized == 'AUTHORIZED' || normalized == 'DECLINED') {
      return formatDateTime(resolveSubmittedDatetime());
    }
    if (normalized == 'WITHDRAWN' || normalized == 'REVOKED') {
      Datetime revokedAt = consentRecord != null ? consentRecord.Revoked_At__c : null;
      if (revokedAt == null) {
        revokedAt = getDatetimeFieldValue(
          contactRecord,
          new List<String>{
            'Withdrawal_Datetime__c',
            'Consent_Revocation_Date__c',
            'Revoked_At__c',
            'Latest_Status_Datetime__c'
          }
        );
      }
      return formatDateTime(revokedAt);
    }
    if (normalized == 'EXPIRED') {
      Date expiryDate = consentRecord != null ? consentRecord.Consent_Expiry_Date__c : null;
      if (expiryDate == null) {
        expiryDate = getDateFieldValue(
          contactRecord,
          new List<String>{ 'Current_Consent_Expiry_Date__c' }
        );
      }
      return formatDate(expiryDate);
    }
    if (normalized == 'CONSUMED') {
      // TODO: Confirm Last_Report_Retrieval_Date__c API name when field is available in org.
      Datetime consumedAt = getDatetimeFieldValue(
        consentRecord,
        new List<String>{ 'Last_Report_Retrieval_Date__c', 'Last_Report_Retrieval_Datetime__c' }
      );
      if (consumedAt == null) {
        consumedAt = getDatetimeFieldValue(
          requestItemRecord,
          new List<String>{ 'Last_Report_Retrieval_Date__c', 'Last_Report_Retrieval_Datetime__c' }
        );
      }
      return formatDateTime(consumedAt);
    }

    return formatDateTime(resolveSubmittedDatetime());
  }

  private Datetime resolveSubmittedDatetime() {
    if (consentRecord != null && consentRecord.Submitted_At__c != null) {
      return consentRecord.Submitted_At__c;
    }

    Datetime fromContact = getDatetimeFieldValue(
      contactRecord,
      new List<String>{ 'Latest_Submission_Datetime__c', 'Latest_Status_Datetime__c' }
    );
    if (fromContact != null) {
      return fromContact;
    }

    if (consentRecord != null && consentRecord.CreatedDate != null) {
      return consentRecord.CreatedDate;
    }

    return null;
  }

  private Boolean hasDisplayableContext() {
    if (isTokenValid != true) {
      return false;
    }
    if (hasConflictingIdentifiers()) {
      return false;
    }
    return contactRecord != null || requestItemRecord != null || consentRecord != null;
  }

  private Boolean hasConflictingIdentifiers() {
    Id contactIdFromParam = parseId(contactIdFromUrl);

    if (requestItemRecord != null
      && requestItemRecord.Data_Subject__c != null
      && contactIdFromParam != null
      && contactIdFromParam != requestItemRecord.Data_Subject__c) {
      return true;
    }

    if (consentRecord != null
      && consentRecord.Data_Subject__c != null
      && contactIdFromParam != null
      && contactIdFromParam != consentRecord.Data_Subject__c) {
      return true;
    }

    return false;
  }

  private Boolean validateToken() {
    Id expectedContactId = parseId(contactIdFromUrl);
    if (expectedContactId == null) {
      expectedContactId = parseId(contactIdParam);
    }

    if (!String.isBlank(tokenParam)) {
      return isTokenAcceptedForDisplay(requestItemRecord, tokenParam, expectedContactId);
    }

    return hasResolvableContextWithoutToken(expectedContactId);
  }

  private Boolean hasResolvableContextWithoutToken(Id expectedContactId) {
    if (requestItemRecord != null) {
      if (expectedContactId != null
        && requestItemRecord.Data_Subject__c != null
        && expectedContactId != requestItemRecord.Data_Subject__c) {
        return false;
      }
      return true;
    }

    return contactRecord != null || consentRecord != null;
  }

  private Boolean isTokenAcceptedForDisplay(
    Consent_Request_Item__c requestItem,
    String tokenValue,
    Id expectedContactId
  ) {
    if (requestItem == null) {
      return false;
    }

    if (expectedContactId != null
      && requestItem.Data_Subject__c != null
      && expectedContactId != requestItem.Data_Subject__c) {
      return false;
    }

    String tokenField = ConsentGuestAuthService.resolveTokenFieldApiName();
    if (String.isBlank(tokenField)) {
      return true;
    }

    return ConsentGuestAuthService.matchesStoredToken(requestItem, tokenValue);
  }

  private PageReference resolveFlowRedirectForNonTerminalStatus() {
    if (isTerminalStatus(normalizeStatus(currentStatus))) {
      return null;
    }

    // TODO: Redirect non-terminal statuses back to the appropriate consent flow page based on actionParam.
    return null;
  }

  private Consent__c resolveLatestConsent(Id subjectId) {
    String explicitConsentId = consentIdParam;
    if (!String.isBlank(explicitConsentId)) {
      Consent__c byId = queryConsentById(parseId(explicitConsentId));
      if (byId != null && byId.Data_Subject__c == subjectId) {
        return byId;
      }
    }

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
    addFieldIfExists(fieldMap, fields, 'Consent_Request_Item__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Date__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Datetime__c');

    String soql =
      'SELECT ' + String.join(fields, ',') +
      ' FROM Consent__c WHERE Data_Subject__c = :subjectId' +
      ' ORDER BY Submitted_At__c DESC NULLS LAST, CreatedDate DESC LIMIT 1';

    List<Consent__c> rows = Database.query(soql);
    return rows.isEmpty() ? null : rows[0];
  }

  private Consent_Request_Item__c resolveRequestItem(Id subjectId) {
    if (requestItemRecord != null) {
      return requestItemRecord;
    }

    String requestItemParam = requestItemIdParam;
    if (!String.isBlank(requestItemParam)) {
      Consent_Request_Item__c byId = queryRequestItemById(parseId(requestItemParam));
      if (byId != null) {
        return byId;
      }
    }

    if (!String.isBlank(tokenParam)) {
      Consent_Request_Item__c byToken = queryRequestItemByToken(tokenParam);
      if (byToken != null) {
        return byToken;
      }
    }

    if (subjectId == null) {
      return null;
    }

    List<Consent_Request_Item__c> latestItems = [
      SELECT Id, Name, Data_Subject__c, Current_Status__c, Consent_Request_Case__c
      FROM Consent_Request_Item__c
      WHERE Data_Subject__c = :subjectId
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    return latestItems.isEmpty() ? null : latestItems[0];
  }

  private Consent__c queryConsentById(Id consentId) {
    if (consentId == null) {
      return null;
    }

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
    addFieldIfExists(fieldMap, fields, 'Consent_Request_Item__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Date__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Datetime__c');

    String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Consent__c WHERE Id = :consentId LIMIT 1';
    List<Consent__c> rows = Database.query(soql);
    return rows.isEmpty() ? null : rows[0];
  }

  private Consent_Request_Item__c queryRequestItemById(Id requestItemId) {
    if (requestItemId == null) {
      return null;
    }

    Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
    List<String> fields = new List<String>{
      'Id',
      'Name',
      'Data_Subject__c',
      'Current_Status__c'
    };
    addFieldIfExists(fieldMap, fields, 'Consent_Request_Case__c');
    addFieldIfExists(fieldMap, fields, 'Consent_Link_Expires_At__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Date__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Datetime__c');
    addTokenFields(fieldMap, fields);

    String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Consent_Request_Item__c WHERE Id = :requestItemId LIMIT 1';
    List<Consent_Request_Item__c> rows = Database.query(soql);
    return rows.isEmpty() ? null : rows[0];
  }

  private Consent_Request_Item__c queryRequestItemByToken(String tokenValue) {
    Map<String, Schema.SObjectField> fieldMap = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
    String tokenField = findFirstExistingField(fieldMap, new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' });
    if (String.isBlank(tokenField)) {
      return null;
    }

    List<String> fields = new List<String>{
      'Id',
      'Name',
      'Data_Subject__c',
      'Current_Status__c'
    };
    addFieldIfExists(fieldMap, fields, 'Consent_Request_Case__c');
    addFieldIfExists(fieldMap, fields, 'Consent_Link_Expires_At__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Date__c');
    addFieldIfExists(fieldMap, fields, 'Last_Report_Retrieval_Datetime__c');
    addTokenFields(fieldMap, fields);

    String soql =
      'SELECT ' + String.join(fields, ',') +
      ' FROM Consent_Request_Item__c WHERE ' + tokenField + ' = :tokenValue LIMIT 1';
    List<Consent_Request_Item__c> rows = Database.query(soql);
    return rows.isEmpty() ? null : rows[0];
  }

  private Contact queryContact(Id subjectId) {
    if (subjectId == null) {
      return null;
    }

    try {
      Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
      List<String> fields = new List<String>{ 'Id', 'AccountId' };
      List<String> optional = new List<String>{
        'Current_Consent_Status__c',
        'Current_Consent_Expiry_Date__c',
        'Latest_Submission_Datetime__c',
        'Latest_Status_Datetime__c',
        'Withdrawal_Datetime__c',
        'Consent_Revocation_Date__c',
        'Revoked_At__c'
      };
      for (String candidate : optional) {
        if (fieldMap.containsKey(candidate) && fieldMap.get(candidate).getDescribe().isAccessible()) {
          fields.add(candidate);
        }
      }

      Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe().fields.getMap();
      if (accountFields.containsKey('Name')) {
        fields.add('Account.Name');
      }
      if (accountFields.containsKey('Notification_Email__c')) {
        fields.add('Account.Notification_Email__c');
      }

      String soql = 'SELECT ' + String.join(fields, ',') + ' FROM Contact WHERE Id = :subjectId LIMIT 1';
      List<Contact> rows = Database.query(soql);
      return rows.isEmpty() ? null : rows[0];
    } catch (Exception e) {
      return null;
    }
  }

  private Boolean isTokenValidForRequestItem(Consent_Request_Item__c requestItem, String tokenValue) {
    return ConsentGuestAuthService.isTokenValidForRequestItem(
      requestItem,
      tokenValue,
      contactRecord != null ? contactRecord.Id : parseId(contactIdParam)
    );
  }

  private Boolean isTerminalStatus(String normalizedStatus) {
    return TERMINAL_STATUSES.contains(normalizedStatus);
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

  private String formatDateTime(Datetime value) {
    return value == null ? '' : value.format('d MMMM yyyy, h:mm a');
  }

  private String formatDate(Date value) {
    if (value == null) {
      return '';
    }
    return Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy');
  }

  private void parseUrlParameters() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    contactIdFromUrl = firstNonBlank(params.get('contactId'), params.get('ContactId'));
    contactIdParam = contactIdFromUrl;
    requestItemIdParam = firstNonBlank(
      params.get('requestItemId'),
      params.get('requestId'),
      params.get('consentRequestItemId')
    );
    consentIdParam = firstNonBlank(params.get('consentId'), params.get('id'));
    tokenParam = params.get('token');
    actionParam = blankIfNull(params.get('action'));
  }

  private static void addFieldIfExists(Map<String, Schema.SObjectField> fieldMap, List<String> fields, String fieldApi) {
    if (fieldMap.containsKey(fieldApi)) {
      fields.add(fieldApi);
    }
  }

  private static void addTokenFields(Map<String, Schema.SObjectField> fieldMap, List<String> fields) {
    for (String candidate : new List<String>{ 'Token__c', 'Secure_Token__c', 'Access_Token__c' }) {
      addFieldIfExists(fieldMap, fields, candidate);
    }
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
        if (rawValue instanceof Date) {
          Date dateValue = (Date) rawValue;
          return Datetime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
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

  private static String blankIfNull(String value) {
    return value == null ? '' : value;
  }
}