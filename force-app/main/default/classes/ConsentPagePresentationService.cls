public without sharing class ConsentPagePresentationService {
    public static final String ACTION_AUTHORIZE = 'authorize';
    public static final String ACTION_WITHDRAW = 'withdraw';
    private static final String EMPLOYER_BANK_FALLBACK = 'your employer or the relevant bank';

    public static String getCurrentDateString() {
        return Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy, EEEE');
    }

    public static String getEmployerBankFallbackText() {
        return EMPLOYER_BANK_FALLBACK;
    }

    public static Boolean hasValidEntryAction(String entryAction) {
        return entryAction == ACTION_AUTHORIZE || entryAction == ACTION_WITHDRAW;
    }

    public static Boolean isAuthorizeAction(String entryAction) {
        return entryAction == ACTION_AUTHORIZE;
    }

    public static Boolean isWithdrawAction(String entryAction) {
        return entryAction == ACTION_WITHDRAW;
    }

    public static String getCompletionMessageLine1(Boolean isActiveConsentPage) {
        return isActiveConsentPage ? 'Active Consent Found' : 'Consent Submitted Successfully';
    }

    public static String getCompletionMessageLine2() {
        return 'The process is complete, and you may close this page.';
    }

    public static List<String> getCompletionMessageLines(Boolean isActiveConsentPage) {
        if (isActiveConsentPage) {
            return new List<String>{
                'You already have an active consent record with Credit Bureau (Singapore) Pte Ltd ("CBS").',
                'No further consent submission is required at this time.',
                'Your employer or the relevant bank may proceed based on your current consent status.'
            };
        }
        return new List<String>{
            'Your authorization and consent have been successfully submitted to Credit Bureau (Singapore) Pte Ltd ("CBS").',
            'CBS has recorded your consent submission. Your employer or the relevant bank may proceed with the next steps based on your consent status.'
        };
    }

    public static String getCompletionFooterText() {
        return '';
    }

    public static String getWithdrawalGuidanceText() {
        return 'You may withdraw your consent in the future by using the withdrawal link provided in your email, where applicable.';
    }

    public static String getDuplicateSubmissionText() {
        return 'Please do not submit another consent form using this link.';
    }

    public static String getConfirmationEmailText() {
        return 'A confirmation email will be sent to you for your records.';
    }

    public static String getHelpText() {
        return 'If you have any questions, please contact your HR representative or CBS support.';
    }

    public static String getWithdrawalCompletionMessageLine1(Boolean isFinishedOrCompleted) {
        return isFinishedOrCompleted
            ? 'Withdrawal submitted successfully.'
            : 'No Active Consent Record Found';
    }

    public static String getWithdrawalCompletionMessageLine2(Boolean isFinishedOrCompleted) {
        return isFinishedOrCompleted
            ? 'The process is complete, and you may close this page.'
            : 'We are unable to find an active consent record associated with this request.';
    }

    public static List<String> getWithdrawalCompletionMessageLines(Boolean isFinishedOrCompleted) {
        if (isFinishedOrCompleted) {
            return new List<String>{
                'The process is complete, and you may close this page.'
            };
        }
        return new List<String>{
            'We are unable to find an active consent record associated with this request.',
            'This may be because consent has not been submitted, the consent has already been declined, withdrawn, expired, or the link is no longer valid.',
            'No withdrawal action is required at this time.'
        };
    }

    public static String getWithdrawalCompletionFooterText(Boolean isFinishedOrCompleted) {
        return isFinishedOrCompleted ? '' : 'You may now close this page.';
    }

    public static String getImportantNotesTitle(String entryAction) {
        if (!hasValidEntryAction(entryAction)) {
            return 'Invalid Link';
        }
        if (isWithdrawAction(entryAction)) {
            return 'Important Notes Before Withdrawing Consent';
        }
        return 'Important Notes';
    }

    public static List<String> getImportantNotesList(String entryAction) {
        if (hasValidEntryAction(entryAction)) {
            if (isWithdrawAction(entryAction)) {
                return getWithdrawImpactNotes();
            }
            return new List<String>{
                'You have received this link from your employer\'s HR team to provide consent for Credit Bureau Singapore ("CBS") to retrieve your MyInfo details via Singpass for employment-related credit assessment purposes.',
                'To proceed, please click the button below and authenticate using Singpass. Upon successful authentication, selected personal information from MyInfo will be retrieved and used to populate the consent form.',
                'The information retrieved may include your name, identification number, nationality, date of birth, and residential address. This information will be used only for the purpose of processing your employer\'s authorised credit report request through CBS.',
                'Please review the consent form carefully before submitting. By submitting the form, you confirm that you authorise CBS to collect, use, and disclose the relevant information for the stated purpose.',
                'After submission, you will receive an email confirmation. The same link may be used in future to authenticate via Singpass and withdraw your consent, where applicable.',
                'If you do not wish to provide consent, you may decline through the form. Your HR team will be notified of the consent status.',
                'Please do not proceed if you are unsure why you received this link. Contact your HR representative before authenticating with Singpass.'
            };
        }
        return new List<String>{
            'This link is missing a valid action parameter. Please use the latest authorization or withdrawal link from your email.'
        };
    }

    public static String getImportantNotesButtonMain(String entryAction) {
        return isWithdrawAction(entryAction) ? 'Continue' : 'Retrieve Myinfo';
    }

    public static String getImportantNotesButtonSub(String entryAction) {
        return isWithdrawAction(entryAction) ? '' : 'with singpass';
    }

    public static String getWithdrawIntroText() {
        return 'You are about to withdraw your consent and authorisation previously given to Credit Bureau (Singapore) Pte Ltd ("CBS").';
    }

    public static String getWithdrawIntroSubText() {
        return 'Please read the following notes carefully before continuing.';
    }

    public static List<String> getWithdrawImpactNotes() {
        return new List<String>{
            'CBS will update your consent status as withdrawn after successful submission of the withdrawal form.',
            'Your employer or the relevant bank will be notified of the withdrawal.',
            'After withdrawal, your employer or the relevant bank will not be able to submit any new credit report request under this consent.',
            'This withdrawal does not affect any credit report request that was already submitted, processed, or completed before the date and time of withdrawal.',
            'You may be required to provide fresh consent if your employer or the relevant bank needs to request your credit report again in future.'
        };
    }

    public static String getWithdrawNextStepNote(Boolean isSingpass, Boolean isNonSingpass) {
        if (isSingpass) {
            return 'To proceed, you may be required to authenticate your identity using Singpass before submitting your withdrawal request.';
        }
        if (isNonSingpass) {
            return 'To proceed, you may be required to provide or confirm your identity information before submitting your withdrawal request.';
        }
        return 'To proceed, you may be required to verify or confirm your identity before submitting your withdrawal request.';
    }

    public static String getWithdrawHrReminder() {
        return 'If you are unsure why you received this link, please contact your HR representative before continuing.';
    }

    public static String getDeclinationCompletionTitle(Boolean hasActiveConsentForDeclination) {
        return hasActiveConsentForDeclination ? 'Consent Already Submitted' : 'Consent Declined Successfully';
    }

    public static List<String> getDeclinationCompletionMessageLines(Boolean hasActiveConsentForDeclination) {
        if (hasActiveConsentForDeclination) {
            return new List<String>{
                'Your consent has already been submitted successfully.',
                'If you no longer wish to provide consent, please use the withdrawal option and authenticate via Singpass to withdraw your previously submitted consent.',
                'Decline is only applicable before consent has been submitted.'
            };
        }
        return new List<String>{
            'Your decision to decline consent has been recorded successfully.',
            'No further action is required from you. Your employer will be notified that consent was not provided for this employment credit check request.'
        };
    }

    public static String getDeclinationCompletionFooterText() {
        return 'You may now close this page.';
    }

    public static String resolveSuccessBankName(
        Map<String, String> pageParameters,
        SObject contactRecord,
        SObject requestItemRecord
    ) {
        String fromUrl = firstNonBlank(
            pageParameters.get('bankName'),
            pageParameters.get('employerName'),
            pageParameters.get('clientName')
        );
        if (!String.isBlank(fromUrl)) {
            return fromUrl;
        }

        String fromContactAccount = getAccountNameFromContactRecord(contactRecord);
        if (!String.isBlank(fromContactAccount)) {
            return fromContactAccount;
        }

        String fromRequest = getStringFieldValue(
            requestItemRecord,
            new List<String>{ 'Client_Name__c', 'Employer_Name__c', 'Bank_Name__c', 'Uploaded_Employer_Name__c' }
        );
        return String.isBlank(fromRequest) ? EMPLOYER_BANK_FALLBACK : fromRequest;
    }

    public static String resolveBankName(
        String pageUrl,
        String withdrawEmployerBankName,
        String successBankName
    ) {
        if (pageUrl != null && pageUrl.contains('/QRSiteWithdrawConsent')) {
            return String.isBlank(withdrawEmployerBankName) ? EMPLOYER_BANK_FALLBACK : withdrawEmployerBankName;
        }
        return String.isBlank(successBankName) ? EMPLOYER_BANK_FALLBACK : successBankName;
    }

    public static String resolveEmployerBankName(
        String pageUrl,
        String completedParam,
        String withdrawEmployerBankName,
        String successBankName
    ) {
        if (pageUrl != null && pageUrl.contains('/QRSiteWithdrawConsent') && completedParam != 'true') {
            return withdrawEmployerBankName;
        }
        return successBankName;
    }

    public static String resolveDataSubjectName(SObject contactRecord, String inputNameFallback) {
        String subjectName = getStringFieldValue(
            contactRecord,
            new List<String>{ 'Principal_Name__c', 'Full_Legal_Name__c', 'Full_Name__c', 'Name' }
        );
        if (!String.isBlank(subjectName)) {
            return subjectName;
        }
        return blankIfNull(inputNameFallback);
    }

    public static String resolveWithdrawDataSubjectName(SObject contactRecord) {
        String subjectName = getStringFieldValue(
            contactRecord,
            new List<String>{ 'Principal_Name__c', 'Full_Legal_Name__c', 'Full_Name__c', 'Name' }
        );
        return String.isBlank(subjectName) ? '' : subjectName;
    }

    public static String resolveWithdrawEmployerBankName(SObject contactRecord) {
        String accountName = getAccountNameFromContactRecord(contactRecord);
        return String.isBlank(accountName) ? EMPLOYER_BANK_FALLBACK : accountName;
    }

    public static String resolveWithdrawConsentStatus(SObject contactRecord) {
        String status = getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' });
        return String.isBlank(status) ? 'N/A' : status;
    }

    public static String resolveWithdrawSubmissionDateTime(SObject contactRecord) {
        Datetime submissionAt = getDatetimeFieldValue(contactRecord, new List<String>{ 'Latest_Submission_Datetime__c' });
        return submissionAt == null ? 'N/A' : submissionAt.format('d MMMM yyyy, h:mm a');
    }

    public static String resolveWithdrawConsentExpiryDate(SObject contactRecord) {
        Date expiryDate = getDateFieldValue(contactRecord, new List<String>{ 'Current_Consent_Expiry_Date__c' });
        return expiryDate == null ? '' : expiryDate.format();
    }

    public static String resolveConsentStatus(SObject contactRecord, Consent__c latestConsent) {
        String status = getStringFieldValue(contactRecord, new List<String>{ 'Current_Consent_Status__c' });
        if (!String.isBlank(status)) {
            return status;
        }
        return latestConsent == null ? '' : blankIfNull(latestConsent.Consent_Status__c);
    }

    public static String resolveSubmissionDateTime(SObject contactRecord, Consent__c latestConsent) {
        Datetime submissionAt = getDatetimeFieldValue(contactRecord, new List<String>{ 'Latest_Submission_Datetime__c' });
        if (submissionAt == null) {
            submissionAt = latestConsent == null ? null : latestConsent.Submitted_At__c;
        }
        return submissionAt == null ? '' : submissionAt.format('d MMMM yyyy, h:mm a');
    }

    public static String resolveConsentExpiryDate(SObject contactRecord) {
        Date expiryDate = getDateFieldValue(contactRecord, new List<String>{ 'Current_Consent_Expiry_Date__c' });
        return expiryDate == null ? '' : expiryDate.format();
    }

    public static Boolean resolveIsNonSingpass(
        SObject successContactRecord,
        Map<String, String> pageParameters,
        String withdrawAuthenticationType,
        Boolean isWithdrawAction
    ) {
        if (isWithdrawAction) {
            if (!String.isBlank(withdrawAuthenticationType)) {
                return withdrawAuthenticationType == 'Non-Singpass';
            }
            return false;
        }

        String authType = getStringFieldValue(successContactRecord, new List<String>{ 'Authentication_Type__c' });
        if (!String.isBlank(authType)) {
            return authType == 'Non-Singpass';
        }

        String fromUrl = firstNonBlank(pageParameters.get('subjectType'), pageParameters.get('authenticationType'));
        return !String.isBlank(fromUrl) && fromUrl.toLowerCase().contains('non');
    }

    public static Boolean resolveIsSingpass(
        Map<String, String> pageParameters,
        String withdrawAuthenticationType,
        Boolean isWithdrawAction
    ) {
        if (isWithdrawAction) {
            if (!String.isBlank(withdrawAuthenticationType)) {
                return withdrawAuthenticationType == 'Singpass';
            }
        }
        String fromUrl = firstNonBlank(pageParameters.get('subjectType'), pageParameters.get('authenticationType'));
        return !String.isBlank(fromUrl) && fromUrl.toLowerCase().contains('singpass') && !fromUrl.toLowerCase().contains('non');
    }

    public static Boolean isActiveConsentStatus(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        String normalized = status.trim().toLowerCase();
        return normalized == 'authorized' || normalized == 'valid';
    }

    public static String resolveContactName(String pageUrl, String withdrawSubjectName, String inputName) {
        if (pageUrl != null && pageUrl.contains('/QRSiteWithdrawConsent')) {
            return String.isBlank(withdrawSubjectName) ? blankIfNull(inputName) : withdrawSubjectName;
        }
        return blankIfNull(inputName);
    }

    public static String resolveWithdrawFormNationality(SObject contactRecord, String inputNationality) {
        String nationalityFromContact = getStringFieldValue(contactRecord, new List<String>{ 'Nationality__c' });
        return String.isBlank(nationalityFromContact) ? blankIfNull(inputNationality) : nationalityFromContact;
    }

    public static String resolveWithdrawFormNric(SObject contactRecord, String inputNric) {
        String idNumberFromContact = getStringFieldValue(
            contactRecord,
            new List<String>{ 'ID_Number__c', 'Passport_Number__c', 'NRIC__c', 'FIN__c' }
        );
        return String.isBlank(idNumberFromContact) ? blankIfNull(inputNric) : idNumberFromContact;
    }

    public static String resolveWithdrawFormDobDay(SObject contactRecord, String inputDobDay) {
        Date contactDob = getDateFieldValue(contactRecord, new List<String>{ 'Date_of_Birth__c', 'DOB__c' });
        return contactDob == null ? blankIfNull(inputDobDay) : leftPad(String.valueOf(contactDob.day()), 2);
    }

    public static String resolveWithdrawFormDobMonth(SObject contactRecord, String inputDobMonth) {
        Date contactDob = getDateFieldValue(contactRecord, new List<String>{ 'Date_of_Birth__c', 'DOB__c' });
        return contactDob == null ? blankIfNull(inputDobMonth) : getMonthName(contactDob.month());
    }

    public static String resolveWithdrawFormDobYear(SObject contactRecord, String inputDobYear) {
        Date contactDob = getDateFieldValue(contactRecord, new List<String>{ 'Date_of_Birth__c', 'DOB__c' });
        return contactDob == null ? blankIfNull(inputDobYear) : String.valueOf(contactDob.year());
    }

    public static String resolveWithdrawFormResidentialAddress(SObject contactRecord, String inputResidentialAddress) {
        String addressFromContact = getStringFieldValue(
            contactRecord,
            new List<String>{ 'Registered_Address__c', 'Residential_Address__c', 'MailingStreet' }
        );
        return String.isBlank(addressFromContact) ? blankIfNull(inputResidentialAddress) : addressFromContact;
    }

    public static String getAccountNameFromContactRecord(SObject contactSObject) {
        if (contactSObject == null) {
            return null;
        }
        try {
            SObject accountRecord = contactSObject.getSObject('Account');
            if (accountRecord == null) {
                return null;
            }
            Object accountName = accountRecord.get('Name');
            return accountName == null ? null : String.valueOf(accountName);
        } catch (Exception e) {
            return null;
        }
    }

    public static String getStringFieldValue(SObject record, List<String> fieldApiNames) {
        if (record == null || fieldApiNames == null) {
            return null;
        }
        for (String apiName : fieldApiNames) {
            if (hasField(record, apiName)) {
                Object value = record.get(apiName);
                if (value != null) {
                    return String.valueOf(value);
                }
            }
        }
        return null;
    }

    public static Datetime getDatetimeFieldValue(SObject record, List<String> fieldApiNames) {
        if (record == null || fieldApiNames == null) {
            return null;
        }
        for (String apiName : fieldApiNames) {
            if (hasField(record, apiName)) {
                Object value = record.get(apiName);
                if (value instanceof Datetime) {
                    return (Datetime) value;
                }
            }
        }
        return null;
    }

    public static Date getDateFieldValue(SObject record, List<String> fieldApiNames) {
        if (record == null || fieldApiNames == null) {
            return null;
        }
        for (String apiName : fieldApiNames) {
            if (hasField(record, apiName)) {
                Object value = record.get(apiName);
                if (value instanceof Date) {
                    return (Date) value;
                }
            }
        }
        return null;
    }

    public static Boolean hasField(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) {
            return false;
        }
        if (!record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            return false;
        }
        try {
            return record.getPopulatedFieldsAsMap().containsKey(fieldApiName);
        } catch (Exception e) {
            return false;
        }
    }

    public static String getMonthName(Integer monthNumber) {
        List<String> monthNames = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        return monthNames[monthNumber - 1];
    }

    public static Integer getMonthNumber(String monthValue) {
        List<String> monthNames = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        for (Integer index = 0; index < monthNames.size(); index++) {
            if (monthNames[index].equalsIgnoreCase(monthValue.trim())) {
                return index + 1;
            }
        }
        return Integer.valueOf(monthValue);
    }

    public static String blankIfNull(String value) {
        return value == null ? '' : value;
    }

    public static String leftPad(String value, Integer targetLength) {
        while (value.length() < targetLength) {
            value = '0' + value;
        }
        return value;
    }

    public static String firstNonBlank(String value1, String value2) {
        if (!String.isBlank(value1)) {
            return value1;
        }
        return String.isBlank(value2) ? null : value2;
    }

    public static String firstNonBlank(String value1, String value2, String value3) {
        if (!String.isBlank(value1)) {
            return value1;
        }
        if (!String.isBlank(value2)) {
            return value2;
        }
        return String.isBlank(value3) ? null : value3;
    }
}