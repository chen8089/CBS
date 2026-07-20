public without sharing class QRSiteApprovalController {
    private static final String ACTION_AUTHORIZE = 'authorize';
    private static final String ACTION_WITHDRAW = 'withdraw';
    private static final String CURRENT_STATUS_AUTHORIZED = 'Authorized';
    private static final String CURRENT_STATUS_VALID = 'Valid';
    private static final String CURRENT_STATUS_DECLINED = 'Declined';
    private static final String CURRENT_STATUS_WITHDRAWN = 'Withdrawn';
    private static final String LIFECYCLE_STAGE_ACTIVE_CONSENT = 'Active Consent';
    private static final String LIFECYCLE_STAGE_CONSENT_DECLINED = 'Consent Declined';
    private static final String LIFECYCLE_STAGE_CONSENT_WITHDRAWN = 'Consent Withdrawn';
    public String contactId { get; set; }
    public String requestItemId { get; set; }
    public String entryAction { get; set; }
    public Boolean isFinished { get; set; }
    public Boolean isConsented { get; set; }
    public Boolean isWithdrawConsented { get; set; }
    public Boolean hasConfirmedWithdrawal { get; set; }
    public String inputName { get; set; }
    public String inputNationality { get; set; }
    public String inputNric { get; set; }
    public String inputDobDay { get; set; }
    public String inputDobMonth { get; set; }
    public String inputDobYear { get; set; }
    public String inputResidentialAddress { get; set; }
    public String resultMessage { get; set; }
    private Consent_Request_Item__c requestItemRecord;
    private Contact contactRecord;
    private Consent__c consentRecord;
    private ConsentPageContextService.SuccessContextState successContext = new ConsentPageContextService.SuccessContextState();
    private ConsentPageContextService.WithdrawContextState withdrawContext = new ConsentPageContextService.WithdrawContextState();

    public QRSiteApprovalController() {
        contactId = ApexPages.currentPage().getParameters().get('ContactId');
        requestItemId = ApexPages.currentPage().getParameters().get('requestItemId');
        entryAction = normalizeEntryAction(ApexPages.currentPage().getParameters().get('action'));
        isFinished = false;
        isConsented = false;
        isWithdrawConsented = false;
        hasConfirmedWithdrawal = false;
        initializeFormValues();
    }

    public PageReference goToNextQrPage() {
        PageReference nextPage;

        if (String.isBlank(entryAction)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid link or missing parameter (action).'));
        } else if (entryAction == ACTION_WITHDRAW) {
            nextPage = goToWithdrawQrPage();
        }else {
            nextPage = goToQrPage();
        }

        return nextPage;
    }

    public PageReference goToQrPage() {
        PageReference nextPage;

        if (String.isBlank(contactId)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid link or missing parameter (ContactId).'));
        } else {
            PageReference existingStatusPage = checkAuthorizationEntryStatus();
            if (existingStatusPage != null) {
                nextPage = existingStatusPage;
            } else {
                Consent_Request_Item__c latestRequestItem = getLatestRequestItem();
                if (latestRequestItem == null) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Authorization request was not found.'));
                    return null;
                }
                nextPage = QRSiteApprovalNavigationService.buildAuthorizationQrPage(
                    contactId,
                    String.valueOf(latestRequestItem.Id),
                    ApexPages.currentPage().getParameters().get('token')
                );
            }
        }

        return nextPage;
    }

    public PageReference goToWithdrawQrPage() {
        Consent_Request_Item__c withdrawalRequestItem = getWithdrawalRequestItem();
        PageReference nextPage;

        if (withdrawalRequestItem == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid link or missing parameter (requestItemId/token).'));
            return null;
        }

        Id subjectId = withdrawalRequestItem.Data_Subject__c;
        contactId = String.valueOf(subjectId);
        Consent__c consent = getCurrentActiveConsent(subjectId);

        if (consent == null || consent.Consent_Status__c != 'Active' || !isConsentForCurrentContact(consent)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Authorization record was not found.'));
        } else {
            nextPage = QRSiteApprovalNavigationService.buildWithdrawQrPage(
                String.valueOf(consent.Data_Subject__c),
                String.valueOf(consent.Id),
                String.valueOf(withdrawalRequestItem.Id),
                ApexPages.currentPage().getParameters().get('token')
            );
            prepareWithdrawalEntry(consent.Data_Subject__c);
        }

        return nextPage;
    }

    // PC page polls this method and redirects after the mobile scan records QR authentication.
    public PageReference checkStatusPC() {
        PageReference nextPage;
        Id subjectId = resolveAuthorizationSubjectId();
        if (subjectId != null) {
            contactId = String.valueOf(subjectId);
            Consent__c existing = getLatestConsent(subjectId);

            if (ConsentQrAuthenticationService.hasActiveConsent(existing)) {
                nextPage = QRSiteApprovalNavigationService.buildConsentFormActiveConsentPage(contactId);
            } else {
                Consent_Request_Item__c requestItem = getAuthorizationRequestItem();
                if (ConsentQrAuthenticationService.shouldRedirectToAuthorizationForm(requestItem)) {
                    nextPage = QRSiteApprovalNavigationService.buildConsentFormRequestPage(
                        contactId,
                        String.valueOf(requestItem.Id)
                    );
                }
            }
        }

        return nextPage;
    }

    public PageReference checkWithdrawStatusPC() {
        Consent_Request_Item__c requestItem = getWithdrawalRequestItem();
        PageReference nextPage;

        if (requestItem != null) {
            Id subjectId = requestItem.Data_Subject__c;
            contactId = String.valueOf(subjectId);
            Consent__c consent = getCurrentActiveConsent(subjectId);
            if (ConsentQrAuthenticationService.shouldRedirectToWithdrawalForm(consent, requestItem, isConsentForCurrentContact(consent))) {
                nextPage = QRSiteApprovalNavigationService.buildWithdrawConsentPage(
                    String.valueOf(consent.Data_Subject__c),
                    String.valueOf(consent.Id),
                    String.valueOf(requestItem.Id),
                    ApexPages.currentPage().getParameters().get('token')
                );
            }
        }
        return nextPage;
    }

    public String getBankName() {
        return ConsentPagePresentationService.resolveBankName(
            ApexPages.currentPage().getUrl(),
            getWithdrawEmployerBankName(),
            getSuccessBankName()
        );
    }

    public String getCurrentDateString() {
        return ConsentPagePresentationService.getCurrentDateString();
    }

    public Boolean getShowConsentForm() {
        return isFinished != true && ApexPages.currentPage().getParameters().get('completed') != 'true';
    }

    public Boolean getShowCompletionMessage() {
        return isFinished == true || ApexPages.currentPage().getParameters().get('completed') == 'true';
    }

    public String getCompletionMessageLine1() {
        return ConsentPagePresentationService.getCompletionMessageLine1(getIsActiveConsentPage());
    }

    public String getCompletionMessageLine2() {
        return ConsentPagePresentationService.getCompletionMessageLine2();
    }

    public List<String> getCompletionMessageLines() {
        return ConsentPagePresentationService.getCompletionMessageLines(getIsActiveConsentPage());
    }

    public String getCompletionFooterText() {
        return ConsentPagePresentationService.getCompletionFooterText();
    }

    public Boolean getShowSuccessSummary() {
        ensureSuccessContextLoaded();
        return getShowCompletionMessage() && successContext.valid;
    }

    public String getConsentStatus() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent') && ApexPages.currentPage().getParameters().get('completed') != 'true') {
            return getWithdrawConsentStatus();
        }
        ensureSuccessContextLoaded();
        if (successContext.valid != true) {
            return '';
        }

        String status = ConsentPagePresentationService.getStringFieldValue(successContext.contactRecord, new List<String>{ 'Current_Consent_Status__c' });
        if (!String.isBlank(status)) {
            return status;
        }
        Consent__c latest = getLatestConsent(resolveSuccessContactId());
        return ConsentPagePresentationService.resolveConsentStatus(successContext.contactRecord, latest);
    }

    public String getSubmissionDateTime() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent') && ApexPages.currentPage().getParameters().get('completed') != 'true') {
            return getWithdrawSubmissionDateTime();
        }
        ensureSuccessContextLoaded();
        if (successContext.valid != true) {
            return '';
        }

        Consent__c latest = getLatestConsent(resolveSuccessContactId());
        return ConsentPagePresentationService.resolveSubmissionDateTime(successContext.contactRecord, latest);
    }

    public String getSuccessBankName() {
        ensureSuccessContextLoaded();
        return ConsentPagePresentationService.resolveSuccessBankName(
            ApexPages.currentPage().getParameters(),
            successContext.contactRecord,
            successContext.requestItemRecord
        );
    }

    public String getEmployerBankName() {
        return ConsentPagePresentationService.resolveEmployerBankName(
            ApexPages.currentPage().getUrl(),
            ApexPages.currentPage().getParameters().get('completed'),
            getWithdrawEmployerBankName(),
            getSuccessBankName()
        );
    }

    public String getDataSubjectName() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent') && ApexPages.currentPage().getParameters().get('completed') != 'true') {
            return getWithdrawDataSubjectName();
        }
        ensureSuccessContextLoaded();
        if (successContext.valid != true) {
            return '';
        }
        return ConsentPagePresentationService.resolveDataSubjectName(successContext.contactRecord, inputName);
    }

    public String getConsentExpiryDate() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent') && ApexPages.currentPage().getParameters().get('completed') != 'true') {
            return getWithdrawConsentExpiryDate();
        }
        ensureSuccessContextLoaded();
        return ConsentPagePresentationService.resolveConsentExpiryDate(successContext.contactRecord);
    }

    public Boolean getIsNonSingpass() {
        if (!getIsWithdrawAction()) {
            ensureSuccessContextLoaded();
        }
        return ConsentPagePresentationService.resolveIsNonSingpass(
            successContext.contactRecord,
            ApexPages.currentPage().getParameters(),
            getWithdrawAuthenticationType(),
            getIsWithdrawAction()
        );
    }

    public Boolean getIsSingpass() {
        return ConsentPagePresentationService.resolveIsSingpass(
            ApexPages.currentPage().getParameters(),
            getWithdrawAuthenticationType(),
            getIsWithdrawAction()
        );
    }

    public Boolean getShowNonSingpassManualVerificationNote() {
        return getShowSuccessSummary() && getIsNonSingpass();
    }

    public String getWithdrawalGuidanceText() {
        return ConsentPagePresentationService.getWithdrawalGuidanceText();
    }

    public String getDuplicateSubmissionText() {
        return ConsentPagePresentationService.getDuplicateSubmissionText();
    }

    public Boolean getShowDuplicateSubmissionWarning() {
        return getShowSuccessSummary() && getIsActiveConsentPage();
    }

    public String getConfirmationEmailText() {
        return ConsentPagePresentationService.getConfirmationEmailText();
    }

    public String getHelpText() {
        return ConsentPagePresentationService.getHelpText();
    }

    public Boolean getShowWithdrawalForm() {
        if (ApexPages.currentPage().getParameters().get('completed') == 'true') {
            return false;
        }
        ensureWithdrawContextLoaded();
        return isFinished != true && withdrawContext.valid == true && getHasActiveConsent();
    }

    public Boolean getShowWithdrawalCompletionMessage() {
        if (ApexPages.currentPage().getParameters().get('completed') == 'true' || isFinished == true) {
            return true;
        }
        ensureWithdrawContextLoaded();
        return withdrawContext.valid != true || !getHasActiveConsent() || ApexPages.currentPage().getParameters().get('noActiveConsent') == 'true';
    }

    public Boolean getShowWithdrawQrCode() {
        Consent__c consent = getConsentRecord();
        return isFinished != true && consent != null && consent.Consent_Status__c == 'Active' && isConsentForCurrentContact(consent);
    }

    public String getWithdrawalCompletionMessageLine1() {
        return ConsentPagePresentationService.getWithdrawalCompletionMessageLine1(isWithdrawalFlowCompleted());
    }

    public String getWithdrawalCompletionMessageLine2() {
        return ConsentPagePresentationService.getWithdrawalCompletionMessageLine2(isWithdrawalFlowCompleted());
    }

    public List<String> getWithdrawalCompletionMessageLines() {
        return ConsentPagePresentationService.getWithdrawalCompletionMessageLines(isWithdrawalFlowCompleted());
    }

    public String getWithdrawalCompletionFooterText() {
        return ConsentPagePresentationService.getWithdrawalCompletionFooterText(isWithdrawalFlowCompleted());
    }

    private Boolean isWithdrawalFlowCompleted() {
        return isFinished == true || ApexPages.currentPage().getParameters().get('completed') == 'true';
    }

    public Boolean getHasValidEntryAction() {
        return ConsentPagePresentationService.hasValidEntryAction(entryAction);
    }

    public Boolean getIsAuthorizeAction() {
        return ConsentPagePresentationService.isAuthorizeAction(entryAction);
    }

    public Boolean getIsWithdrawAction() {
        return ConsentPagePresentationService.isWithdrawAction(entryAction);
    }

    public String getImportantNotesTitle() {
        return ConsentPagePresentationService.getImportantNotesTitle(entryAction);
    }

    public List<String> getImportantNotesList() {
        return ConsentPagePresentationService.getImportantNotesList(entryAction);
    }

    public String getImportantNotesButtonMain() {
        return ConsentPagePresentationService.getImportantNotesButtonMain(entryAction);
    }

    public String getImportantNotesButtonSub() {
        return ConsentPagePresentationService.getImportantNotesButtonSub(entryAction);
    }

    public String getWithdrawIntroText() {
        return ConsentPagePresentationService.getWithdrawIntroText();
    }

    public String getWithdrawIntroSubText() {
        return ConsentPagePresentationService.getWithdrawIntroSubText();
    }

    public List<String> getWithdrawImpactNotes() {
        return ConsentPagePresentationService.getWithdrawImpactNotes();
    }

    public String getWithdrawDataSubjectName() {
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return '';
        }
        return ConsentPagePresentationService.resolveWithdrawDataSubjectName(withdrawContext.contactRecord);
    }

    public String getWithdrawEmployerBankName() {
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return '';
        }
        return ConsentPagePresentationService.resolveWithdrawEmployerBankName(withdrawContext.contactRecord);
    }

    public String getWithdrawConsentStatus() {
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return '';
        }
        return ConsentPagePresentationService.resolveWithdrawConsentStatus(withdrawContext.contactRecord);
    }

    public String getWithdrawSubmissionDateTime() {
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return '';
        }
        return ConsentPagePresentationService.resolveWithdrawSubmissionDateTime(withdrawContext.contactRecord);
    }

    public String getWithdrawConsentExpiryDate() {
        ensureWithdrawContextLoaded();
        return ConsentPagePresentationService.resolveWithdrawConsentExpiryDate(withdrawContext.contactRecord);
    }

    public String getWithdrawNextStepNote() {
        return ConsentPagePresentationService.getWithdrawNextStepNote(getIsSingpass(), getIsNonSingpass());
    }

    public String getWithdrawHrReminder() {
        return ConsentPagePresentationService.getWithdrawHrReminder();
    }

    public Boolean getHasActiveConsent() {
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return false;
        }
        String status = ConsentPagePresentationService.getStringFieldValue(
            withdrawContext.contactRecord,
            new List<String>{ 'Current_Consent_Status__c' }
        );
        return ConsentPagePresentationService.isActiveConsentStatus(status);
    }

    // Withdraw important notes must block non-active contacts before users proceed.
    public PageReference handleImportantNotesEntry() {
        if (!getIsWithdrawAction()) {
            return null;
        }

        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return null;
        }

        if (!getHasActiveConsent()) {
            return redirectToNoActiveConsentPage();
        }

        return null;
    }

    public PageReference continueWithdrawal() {
        if (!getHasValidEntryAction()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid link or missing parameter (action).'));
            return null;
        }

        refreshWithdrawContext();
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return null;
        }

        if (!getHasActiveConsent()) {
            return redirectToNoActiveConsentPage();
        }

        if (getIsNonSingpass()) {
            return redirectToWithdrawConsentPage();
        }
        return redirectToWithdrawQrPage();
    }

    public PageReference handleWithdrawFormEntry() {
        if (ApexPages.currentPage().getParameters().get('completed') == 'true' ||
            ApexPages.currentPage().getParameters().get('noActiveConsent') == 'true') {
            return null;
        }

        refreshWithdrawContext();
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return null;
        }

        if (!getHasActiveConsent()) {
            return redirectToNoActiveConsentPage();
        }
        return null;
    }

    public String getDeclinationCompletionTitle() {
        return ConsentPagePresentationService.getDeclinationCompletionTitle(getHasActiveConsentForDeclination());
    }

    public List<String> getDeclinationCompletionMessageLines() {
        return ConsentPagePresentationService.getDeclinationCompletionMessageLines(getHasActiveConsentForDeclination());
    }

    public String getDeclinationCompletionFooterText() {
        return ConsentPagePresentationService.getDeclinationCompletionFooterText();
    }

    public PageReference recordDeclination() {
        if (String.isBlank(contactId)) {
            return null;
        }

        Id subjectId;
        try {
            subjectId = (Id) contactId;
        } catch (Exception e) {
            return null;
        }

        if (getHasActiveConsentForDeclination()) {
            return null;
        }

        ConsentStateTransitionService.applyDeclination(subjectId);

        return null;
    }

    public Boolean getHasActiveConsentForDeclination() {
        if (String.isBlank(contactId)) {
            return false;
        }

        Consent__c existing = getLatestConsent();
        return existing != null && existing.Consent_Status__c == 'Active';
    }

    public String getContactName() {
        return ConsentPagePresentationService.resolveContactName(
            ApexPages.currentPage().getUrl(),
            getWithdrawDataSubjectName(),
            inputName
        );
    }

    public String getNationality() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent')) {
            ensureWithdrawContextLoaded();
            return ConsentPagePresentationService.resolveWithdrawFormNationality(withdrawContext.contactRecord, inputNationality);
        }
        return ConsentPagePresentationService.blankIfNull(inputNationality);
    }

    public String getNricNumber() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent')) {
            ensureWithdrawContextLoaded();
            return ConsentPagePresentationService.resolveWithdrawFormNric(withdrawContext.contactRecord, inputNric);
        }
        return ConsentPagePresentationService.blankIfNull(inputNric);
    }

    public String getDobDay() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent')) {
            ensureWithdrawContextLoaded();
            return ConsentPagePresentationService.resolveWithdrawFormDobDay(withdrawContext.contactRecord, inputDobDay);
        }
        return ConsentPagePresentationService.blankIfNull(inputDobDay);
    }

    public String getDobMonth() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent')) {
            ensureWithdrawContextLoaded();
            return ConsentPagePresentationService.resolveWithdrawFormDobMonth(withdrawContext.contactRecord, inputDobMonth);
        }
        return ConsentPagePresentationService.blankIfNull(inputDobMonth);
    }

    public String getDobYear() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent')) {
            ensureWithdrawContextLoaded();
            return ConsentPagePresentationService.resolveWithdrawFormDobYear(withdrawContext.contactRecord, inputDobYear);
        }
        return ConsentPagePresentationService.blankIfNull(inputDobYear);
    }

    public String getResidentialAddress() {
        if (ApexPages.currentPage().getUrl().contains('/QRSiteWithdrawConsent')) {
            ensureWithdrawContextLoaded();
            return ConsentPagePresentationService.resolveWithdrawFormResidentialAddress(
                withdrawContext.contactRecord,
                inputResidentialAddress
            );
        }
        return ConsentPagePresentationService.blankIfNull(inputResidentialAddress);
    }

    public PageReference submitForm() {
        Consent_Request_Item__c requestItem = getRequestItemRecord();

        if (requestItem == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Authorization request was not found.'));
        } else if (isConsented != true) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please select the consent checkbox before submitting.'));
        } else {
            ConsentSubmissionService.submitAuthorization(
                requestItem,
                inputName,
                inputNationality,
                inputNric,
                parseInputDateOfBirth(),
                inputResidentialAddress
            );

            isFinished = true;
            resultMessage = 'Authorization submitted successfully. The process is complete, and you may close this page.';
        }
        return null;
    }

    public PageReference submitWithdrawal() {
        refreshWithdrawContext();
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return null;
        }

        if (!getHasActiveConsent()) {
            return redirectToNoActiveConsentPage();
        }

        if (hasConfirmedWithdrawal != true && isWithdrawConsented != true) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please confirm your withdrawal before submitting.'));
            return null;
        }

        Id subjectId = parseIdValue(contactId);
        if (subjectId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'The link is invalid or has expired.'));
            return null;
        }

        try {
            Consent__c consent = getCurrentActiveConsent(subjectId);
            Datetime withdrawnAt = System.now();
            ConsentSubmissionService.submitWithdrawal(
                subjectId,
                consent != null && isConsentForCurrentContact(consent) ? consent : null,
                withdrawnAt
            );

            isFinished = true;
            resultMessage = 'Withdrawal submitted successfully. The process is complete, and you may close this page.';

            PageReference successPage = QRSiteApprovalNavigationService.buildWithdrawConsentPage(
                contactId,
                null,
                null,
                ApexPages.currentPage().getParameters().get('token')
            );
            copyWithdrawalContextParams(successPage);
            successPage.getParameters().put('completed', 'true');
            successPage.getParameters().remove('noActiveConsent');
            return successPage;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to submit withdrawal at this time. Please try again later.'));
            return null;
        }
    }

    // Mobile scan entry point: mark authentication complete and keep the success page on mobile.
    public PageReference scanAndApprove() {
        return approve();
    }

    public PageReference scanAndConfirmWithdrawal() {
        Consent_Request_Item__c requestItem = getWithdrawalRequestItem();

        if (requestItem == null) {
            resultMessage = 'Invalid link or missing request parameter. The operation failed.';
            isFinished = true;
        } else {
            Id subjectId = requestItem.Data_Subject__c;
            contactId = String.valueOf(subjectId);
            Consent__c consent = getCurrentActiveConsent(subjectId);
            if (consent == null || consent.Consent_Status__c != 'Active' || !isConsentForCurrentContact(consent)) {
                resultMessage = 'Authorization record was not found.';
                isFinished = true;
                return null;
            }

            try {
                ConsentQrAuthenticationService.markWithdrawalQrViewedByRequestItem(requestItem.Id);
                isFinished = true;
                resultMessage = 'Authentication completed successfully. Please continue the withdrawal form on your computer.';
            } catch (Exception e) {
                resultMessage = 'System error: ' + e.getMessage();
                isFinished = true;
            }
        }

        return null;
    }

    private Consent_Request_Item__c getWithdrawalRequestItem() {
        String requestIdValue = ConsentPagePresentationService.firstNonBlank(requestItemId, ApexPages.currentPage().getParameters().get('requestItemId'));
        String tokenValue = ApexPages.currentPage().getParameters().get('token');
        if (String.isBlank(requestIdValue) || String.isBlank(tokenValue)) {
            return null;
        }

        SObject requestItemRaw = querySuccessRequestItemById(requestIdValue);
        if (requestItemRaw == null || ConsentPageContextService.isRequestItemLinkExpired(requestItemRaw) || !doesTokenMatchRequestItem(requestItemRaw, tokenValue)) {
            return null;
        }

        Object rawSubjectId = requestItemRaw.get('Data_Subject__c');
        if (!(rawSubjectId instanceof Id)) {
            return null;
        }
        Id subjectId = (Id) rawSubjectId;
        if (!String.isBlank(contactId)) {
            Id safeContactId = parseIdValue(contactId);
            if (safeContactId != null && safeContactId != subjectId) {
                return null;
            }
        }

        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Id = (Id) requestItemRaw.get('Id'),
            Data_Subject__c = subjectId
        );
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Current_Status__c')) {
            requestItem.Current_Status__c = (String) requestItemRaw.get('Current_Status__c');
        }
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Withdrawal_QR_Viewed_At__c')) {
            requestItem.Withdrawal_QR_Viewed_At__c = (Datetime) requestItemRaw.get('Withdrawal_QR_Viewed_At__c');
        }
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Authorization_QR_Viewed_At__c')) {
            requestItem.Authorization_QR_Viewed_At__c = (Datetime) requestItemRaw.get('Authorization_QR_Viewed_At__c');
        }
        requestItemId = requestItem.Id;
        return requestItem;
    }

    private Boolean doesTokenMatchRequestItem(SObject requestItemRaw, String tokenValue) {
        return ConsentGuestAuthService.matchesStoredToken(requestItemRaw, tokenValue);
    }

    // Mobile status check retained for compatibility with any old page references.
    public PageReference checkStatusMobile() {
        if (!String.isBlank(contactId)) {
            Consent__c existing = getLatestConsent();

            if (existing != null) {
                if (existing.Consent_Status__c == 'Active') {
                    isFinished = true;
                    resultMessage = 'You have already completed the authorization. No further action is required.';
                }
            }
        }

        return null;
    }

    // Mobile scan confirms that the user authenticated; consent is created only after PC form submit.
    public PageReference approve() {
        Consent_Request_Item__c requestItem = getAuthorizationRequestItem();
        if (requestItem == null) {
            resultMessage = 'Invalid link or missing request parameter. The operation failed.';
            isFinished = true;
        } else {
            try {
                Id subjectId = requestItem.Data_Subject__c;
                contactId = String.valueOf(subjectId);
                Consent__c existing = getLatestConsent(subjectId);
                ConsentQrAuthenticationService.AuthorizationScanOutcome outcome =
                    ConsentQrAuthenticationService.evaluateAuthorizationScan(requestItem, existing);
                if (outcome.shouldMarkAuthorizationQrViewed) {
                    ConsentQrAuthenticationService.markAuthorizationQrViewedByRequestItem(requestItem.Id);
                }
                isFinished = outcome.isFinished;
                resultMessage = outcome.resultMessage;
            } catch (Exception e) {
                resultMessage = 'System error: ' + e.getMessage();
                isFinished = true;
            }
        }

        return null;
    }

    // Retained for compatibility, but the new mobile page no longer exposes decline.
    public PageReference reject() {
        if (String.isBlank(contactId)) {
            resultMessage = 'Missing contact parameter. The operation failed.';
            isFinished = true;
        } else {
            isFinished = true;
            resultMessage = 'You have declined the authorization. The process is complete.';
        }

        return null;
    }

    private Consent__c getLatestConsent() {
        return getLatestConsent(contactId);
    }

    private Consent__c getLatestConsent(Id subjectId) {
        return ConsentRequestResolverService.getLatestConsent(subjectId);
    }

    private Consent__c getCurrentActiveConsent(Id subjectId) {
        return ConsentRequestResolverService.getCurrentActiveConsent(subjectId);
    }

    private Consent_Request_Item__c getLatestRequestItem() {
        return getLatestRequestItem(contactId);
    }

    private Consent_Request_Item__c getLatestRequestItem(Id subjectId) {
        return ConsentRequestResolverService.getLatestRequestItem(subjectId);
    }

    private PageReference checkAuthorizationEntryStatus() {
        PageReference nextPage;
        Consent__c existing = getLatestConsent();

        if (ConsentQrAuthenticationService.hasActiveConsent(existing)) {
            nextPage = QRSiteApprovalNavigationService.buildConsentFormActiveConsentPage(contactId);
        } else {
            Consent_Request_Item__c requestItem = getLatestRequestItem();
            ConsentStateTransitionService.clearAuthorizationQrIfNeeded(requestItem, getCurrentContactConsentStatus());
        }

        return nextPage;
    }

    private void prepareWithdrawalEntry(Id subjectId) {
        Consent_Request_Item__c requestItem = getLatestRequestItem(subjectId);
        ConsentStateTransitionService.clearWithdrawalQrIfNeeded(requestItem, getCurrentContactConsentStatus(subjectId));
    }

    private Consent_Request_Item__c getRequestItemRecord() {
        if (requestItemRecord == null) {
            String resolvedRequestItemId = ConsentPagePresentationService.firstNonBlank(requestItemId, ApexPages.currentPage().getParameters().get('requestItemId'));
            if (!String.isBlank(resolvedRequestItemId)) {
                List<Consent_Request_Item__c> requestItems = [
                    SELECT Id, Current_Status__c, Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c,
                        Data_Subject__c, Uploaded_Full_Name__c,
                        Uploaded_ID_Number__c, Uploaded_Date_of_Birth__c
                    FROM Consent_Request_Item__c
                    WHERE Id = :resolvedRequestItemId
                    LIMIT 1
                ];

                if (requestItems.size() > 0) {
                    requestItemRecord = requestItems[0];
                    requestItemId = requestItemRecord.Id;
                }
            }
        }

        return requestItemRecord;
    }

    private Consent__c getConsentRecord() {
        if (consentRecord == null) {
            String consentId = ApexPages.currentPage().getParameters().get('id');
            if (!String.isBlank(consentId)) {
                List<Consent__c> consents = [
                    SELECT Id, Consent_Status__c, Data_Subject__c, Action_Type__c, Submitted_At__c,
                        Revoked_At__c, Withdrawn_By_Client__c, MyInfo_Name__c, MyInfo_Nationality__c,
                        MyInfo_ID_Number__c, MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c
                    FROM Consent__c
                    WHERE Id = :consentId
                    LIMIT 1
                ];

                if (consents.size() > 0) {
                    Consent__c requestedConsent = consents[0];
                    Consent__c currentActiveConsent = getCurrentActiveConsent(requestedConsent.Data_Subject__c);
                    if (currentActiveConsent != null && currentActiveConsent.Id == requestedConsent.Id) {
                        consentRecord = currentActiveConsent;
                    }
                }
            } else if (!String.isBlank(contactId)) {
                consentRecord = getCurrentActiveConsent((Id) contactId);
            }
        }

        return consentRecord;
    }

    private Boolean isConsentForCurrentContact(Consent__c consent) {
        if (consent == null) {
            return false;
        }

        if (String.isBlank(contactId)) {
            return true;
        }

        try {
            Id contactRecordId = contactId;
            return consent.Data_Subject__c == contactRecordId;
        } catch (Exception e) {
            return false;
        }
    }

    private String normalizeEntryAction(String actionValue) {
        String normalizedAction;

        if (!String.isBlank(actionValue)) {
            String normalized = actionValue.trim().toLowerCase();
            if (normalized == ACTION_AUTHORIZE || normalized == ACTION_WITHDRAW) {
                normalizedAction = normalized;
            }
        }

        return normalizedAction;
    }

    private Contact getContactRecord() {
        if (contactRecord == null && !String.isBlank(contactId)) {
            contactRecord = getContactRecord(contactId);
        }

        return contactRecord;
    }

    private String getCurrentContactConsentStatus() {
        return getCurrentContactConsentStatus(contactId);
    }

    private String getCurrentContactConsentStatus(Id subjectId) {
        Contact contact = getContactRecord(subjectId);
        return contact == null ? null : contact.Current_Consent_Status__c;
    }

    private Contact getContactRecord(Id subjectId) {
        List<Contact> contacts = [
            SELECT Id, Name, Principal_Name__c, Full_Name__c, Nationality__c,
                ID_Number__c, Passport_Number__c, Date_of_Birth__c, DOB__c, Registered_Address__c,
                Current_Consent_Status__c
            FROM Contact
            WHERE Id = :subjectId
            LIMIT 1
        ];

        return contacts.size() > 0 ? contacts[0] : null;
    }

    private void initializeFormValues() {
        Consent__c consent = getConsentRecord();
        if (consent != null) {
            inputName = consent.MyInfo_Name__c;
            inputNationality = consent.MyInfo_Nationality__c;
            inputNric = consent.MyInfo_ID_Number__c;
            inputResidentialAddress = consent.MyInfo_Residential_Address__c;
            setInputDateOfBirth(consent.MyInfo_Date_of_Birth__c);
        } else {
            Contact contact = getContactRecord();
            if (contact != null) {
                inputName = ConsentPagePresentationService.firstNonBlank(contact.Principal_Name__c, contact.Full_Name__c);
                if (String.isBlank(inputName)) {
                    inputName = contact.Name;
                }
                inputNationality = contact.Nationality__c;
                inputNric = ConsentPagePresentationService.firstNonBlank(contact.ID_Number__c, contact.Passport_Number__c);
                Date contactDob = contact.Date_of_Birth__c != null ? contact.Date_of_Birth__c : contact.DOB__c;
                setInputDateOfBirth(contactDob);
                inputResidentialAddress = contact.Registered_Address__c;
            }
        }
    }

    private void ensureSuccessContextLoaded() {
        ConsentPageContextService.ensureSuccessContextLoaded(
            successContext,
            ApexPages.currentPage().getParameters(),
            contactId,
            isFinished
        );
        syncContactIdFromSuccessContext();
        publishSuccessContextErrorIfNeeded();
    }

    private void ensureWithdrawContextLoaded() {
        ConsentPageContextService.ensureWithdrawContextLoaded(
            withdrawContext,
            ApexPages.currentPage().getParameters(),
            contactId
        );
        syncContactIdFromWithdrawContext();
        publishWithdrawContextErrorIfNeeded();
    }

    private void syncContactIdFromSuccessContext() {
        if (successContext.resolvedContactId != null) {
            contactId = String.valueOf(successContext.resolvedContactId);
        }
    }

    private void syncContactIdFromWithdrawContext() {
        if (withdrawContext.resolvedContactId != null) {
            contactId = String.valueOf(withdrawContext.resolvedContactId);
        }
    }

    private void publishSuccessContextErrorIfNeeded() {
        if (successContext.valid != true && !String.isBlank(successContext.errorMessage)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, successContext.errorMessage));
        }
    }

    private void publishWithdrawContextErrorIfNeeded() {
        if (withdrawContext.valid != true && !String.isBlank(withdrawContext.errorMessage)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, withdrawContext.errorMessage));
        }
    }

    private String getWithdrawAuthenticationType() {
        ensureWithdrawContextLoaded();
        if (withdrawContext.valid != true) {
            return null;
        }

        String authType = ConsentPagePresentationService.getStringFieldValue(
            withdrawContext.contactRecord,
            new List<String>{ 'Authentication_Type__c' }
        );
        if (!String.isBlank(authType)) {
            return authType;
        }
        return ConsentPagePresentationService.firstNonBlank(ApexPages.currentPage().getParameters().get('subjectType'), ApexPages.currentPage().getParameters().get('authenticationType'));
    }

    private Consent__c getWithdrawActiveConsent() {
        Id subjectId = parseIdValue(contactId);
        if (subjectId == null) {
            return null;
        }
        return getCurrentActiveConsent(subjectId);
    }

    private PageReference redirectToWithdrawQrPage() {
        PageReference nextPage = QRSiteApprovalNavigationService.buildWithdrawQrPage(contactId, null, null, null);
        copyWithdrawalContextParams(nextPage);
        return nextPage;
    }

    private PageReference redirectToWithdrawConsentPage() {
        PageReference nextPage = QRSiteApprovalNavigationService.buildWithdrawConsentPage(contactId, null, null, null);
        copyWithdrawalContextParams(nextPage);
        return nextPage;
    }

    private PageReference redirectToNoActiveConsentPage() {
        PageReference nextPage = QRSiteApprovalNavigationService.buildWithdrawConsentPage(contactId, null, null, null);
        copyWithdrawalContextParams(nextPage);
        nextPage.getParameters().remove('id');
        nextPage.getParameters().put('noActiveConsent', 'true');
        return nextPage;
    }

    private void copyWithdrawalContextParams(PageReference pageRef) {
        if (pageRef == null) {
            return;
        }

        if (!String.isBlank(contactId)) {
            pageRef.getParameters().put('ContactId', contactId);
        }

        Consent__c activeConsent = getWithdrawActiveConsent();
        if (activeConsent != null) {
            pageRef.getParameters().put('id', activeConsent.Id);
        }

        List<String> passthroughParams = new List<String>{ 'recordId', 'token', 'action', 'requestId', 'requestItemId', 'consentId', 'subjectType', 'authenticationType' };
        for (String key : passthroughParams) {
            String value = ApexPages.currentPage().getParameters().get(key);
            if (!String.isBlank(value)) {
                pageRef.getParameters().put(key, value);
            }
        }
    }

    private void refreshWithdrawContext() {
        ConsentPageContextService.refreshWithdrawContext(withdrawContext);
    }

    private Id resolveSuccessContactId() {
        Id resolvedContactId = ConsentPageContextService.resolveSuccessContactId(
            successContext,
            ApexPages.currentPage().getParameters(),
            contactId
        );
        if (resolvedContactId != null) {
            contactId = String.valueOf(resolvedContactId);
            successContext.resolvedContactId = resolvedContactId;
        }
        return resolvedContactId;
    }

    private Consent_Request_Item__c getAuthorizationRequestItem() {
        String tokenValue = ApexPages.currentPage().getParameters().get('token');
        String requestIdValue = ConsentPagePresentationService.firstNonBlank(
            requestItemId,
            ApexPages.currentPage().getParameters().get('requestItemId')
        );

        if (!String.isBlank(requestIdValue)) {
            SObject requestItemRaw = querySuccessRequestItemById(requestIdValue);
            if (requestItemRaw == null
                || ConsentPageContextService.isRequestItemLinkExpired(requestItemRaw)
                || !doesTokenMatchRequestItem(requestItemRaw, tokenValue)) {
                return null;
            }

            Consent_Request_Item__c fromId = normalizeAuthorizationRequestItem(requestItemRaw);
            if (!String.isBlank(contactId)) {
                Id safeContactId = parseIdValue(contactId);
                if (safeContactId != null && fromId.Data_Subject__c != safeContactId) {
                    return null;
                }
            }
            requestItemId = fromId.Id;
            return fromId;
        }

        if (!String.isBlank(tokenValue)) {
            SObject byToken = querySuccessRequestItemByToken(tokenValue);
            if (byToken == null || ConsentPageContextService.isRequestItemLinkExpired(byToken)) {
                return null;
            }
            Consent_Request_Item__c normalized = normalizeAuthorizationRequestItem(byToken);
            requestItemId = normalized.Id;
            return normalized;
        }

        return null;
    }

    private Consent_Request_Item__c normalizeAuthorizationRequestItem(SObject requestItemRaw) {
        Consent_Request_Item__c normalized = new Consent_Request_Item__c(
            Id = (Id) requestItemRaw.get('Id'),
            Data_Subject__c = (Id) requestItemRaw.get('Data_Subject__c')
        );
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Current_Status__c')) {
            normalized.Current_Status__c = (String) requestItemRaw.get('Current_Status__c');
        }
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Authorization_QR_Viewed_At__c')) {
            normalized.Authorization_QR_Viewed_At__c = (Datetime) requestItemRaw.get('Authorization_QR_Viewed_At__c');
        }
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Withdrawal_QR_Viewed_At__c')) {
            normalized.Withdrawal_QR_Viewed_At__c = (Datetime) requestItemRaw.get('Withdrawal_QR_Viewed_At__c');
        }
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Uploaded_Full_Name__c')) {
            normalized.Uploaded_Full_Name__c = (String) requestItemRaw.get('Uploaded_Full_Name__c');
        }
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Uploaded_ID_Number__c')) {
            normalized.Uploaded_ID_Number__c = (String) requestItemRaw.get('Uploaded_ID_Number__c');
        }
        if (ConsentPagePresentationService.hasField(requestItemRaw, 'Uploaded_Date_of_Birth__c')) {
            normalized.Uploaded_Date_of_Birth__c = (Date) requestItemRaw.get('Uploaded_Date_of_Birth__c');
        }
        return normalized;
    }

    private Id resolveAuthorizationSubjectId() {
        Consent_Request_Item__c requestItem = getAuthorizationRequestItem();
        if (requestItem == null) {
            return null;
        }
        return requestItem.Data_Subject__c;
    }

    private Boolean isRequestItemExpiredBySchema(Consent_Request_Item__c requestItemValue) {
        if (requestItemValue == null) {
            return true;
        }
        SObject wrapped = (SObject) requestItemValue;
        return ConsentPageContextService.isRequestItemLinkExpired(wrapped);
    }

    private SObject querySuccessRequestItemById(String rawId) {
        return ConsentRequestResolverService.querySuccessRequestItemById(rawId);
    }

    private SObject querySuccessRequestItemByToken(String tokenValue) {
        return ConsentRequestResolverService.querySuccessRequestItemByToken(tokenValue);
    }

    private Id resolveContactIdByConsentId(String consentIdParam) {
        return ConsentRequestResolverService.resolveContactIdByConsentId(consentIdParam);
    }

    private Id resolveRecordIdToContactId(String recordIdParam) {
        return ConsentRequestResolverService.resolveRecordIdToContactId(recordIdParam);
    }

    private Id parseIdValue(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        try {
            return (Id) rawValue;
        } catch (Exception e) {
            return null;
        }
    }

    public Boolean getIsActiveConsentPage() {
        ensureSuccessContextLoaded();
        if (isFinished == true) {
            return false;
        }
        if (ApexPages.currentPage().getParameters().get('activeConsent') == 'true') {
            return true;
        }
        if (ApexPages.currentPage().getParameters().get('completedMode') == 'submitted') {
            return false;
        }

        String status = getConsentStatus();
        return status == 'Authorized' || status == 'Valid';
    }

    private void setInputDateOfBirth(Date dateOfBirth) {
        if (dateOfBirth != null) {
            inputDobDay = ConsentPagePresentationService.leftPad(String.valueOf(dateOfBirth.day()), 2);
            inputDobMonth = ConsentPagePresentationService.getMonthName(dateOfBirth.month());
            inputDobYear = String.valueOf(dateOfBirth.year());
        }
    }

    private Date parseInputDateOfBirth() {
        Date dateOfBirth;

        if (!String.isBlank(inputDobDay) && !String.isBlank(inputDobMonth) && !String.isBlank(inputDobYear)) {
            Integer day = Integer.valueOf(inputDobDay);
            Integer month = ConsentPagePresentationService.getMonthNumber(inputDobMonth);
            Integer year = Integer.valueOf(inputDobYear);
            dateOfBirth = Date.newInstance(year, month, day);
        }

        return dateOfBirth;
    }

}