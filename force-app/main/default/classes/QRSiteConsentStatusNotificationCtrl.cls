/**
 * Shared status notification pages for the Singpass Employee consent journey.
 */
public without sharing class QRSiteConsentStatusNotificationCtrl {
    public String contactId { get; private set; }
    public String requestItemId { get; private set; }
    public String token { get; private set; }
    public Boolean showPage { get; private set; }
    public String pageTitle { get; private set; }
    public String footerText { get; private set; }
    public Boolean showSummary { get; private set; }

    public String consentStatus { get; private set; }
    public String submissionDateTime { get; private set; }
    public String consentExpiryDate { get; private set; }
    public String dataSubjectName { get; private set; }
    public String employerBankName { get; private set; }

    private List<String> messageLines = new List<String>();
    private Contact contactRecord;

    public QRSiteConsentStatusNotificationCtrl() {
        parseUrlParameters();
        showPage = false;
        showSummary = false;
        footerText = 'You may now close this browser window.';
    }

    public PageReference initActiveConsent() {
        return initNotification(
            'Active Consent Found',
            new List<String>{
                'You already have an active consent record with Credit Bureau (Singapore) Pte Ltd ("CBS").',
                'No further consent submission is required at this time.',
                'Your employer or the relevant bank may proceed based on your current consent status.',
                'If you wish to withdraw your consent, please use the withdrawal link provided in the email from ' + resolveBankName() + ' Human Resources and authenticate via Singpass.'
            },
            true
        );
    }

    public PageReference initInvalidLink() {
        return initNotification(
            'Invalid Link',
            new List<String>{
                'This link is invalid or cannot be used.',
                'Please use the latest consent request link sent to you by your employer\'s Human Resources team.',
                'If you continue to experience issues, please contact ' + resolveBankName() + ' Human Resources for assistance.'
            },
            false
        );
    }

    public PageReference initLinkExpired() {
        return initNotification(
            'Link Expired',
            new List<String>{
                'This consent request link has expired.',
                'Please contact ' + resolveBankName() + ' Human Resources to request a new consent link if you still wish to provide consent.'
            },
            false
        );
    }

    public PageReference initAlreadyActioned() {
        return initNotification(
            'Consent Request Already Actioned',
            new List<String>{
                'This consent request has already been actioned and can no longer be processed through this link.',
                'If you have questions about your consent status, please contact ' + resolveBankName() + ' Human Resources.'
            },
            true
        );
    }

    public List<String> getMessageLines() {
        return messageLines;
    }

    private PageReference initNotification(String title, List<String> lines, Boolean includeSummary) {
        try {
            pageTitle = title;
            messageLines = lines == null ? new List<String>() : lines;
            showSummary = includeSummary == true;

            Id parsedContactId = parseId(contactId);
            if (parsedContactId != null) {
                contactRecord = queryContact(parsedContactId);
                if (contactRecord != null && showSummary) {
                    loadSummary();
                }
            }

            if (contactRecord != null && showSummary) {
                employerBankName = resolveBankName();
            }

            showPage = true;
            return null;
        } catch (Exception e) {
            pageTitle = 'Unable to Load Page';
            messageLines = new List<String>{
                'We could not display the requested information at this time.',
                'Please try again later or contact your employer\'s Human Resources team.'
            };
            showSummary = false;
            showPage = true;
            return null;
        }
    }

    private void loadSummary() {
        dataSubjectName = firstNonBlank(
            getStringFieldValue(contactRecord, new List<String>{ 'Principal_Name__c', 'Full_Name__c', 'Name' }),
            'Employee'
        );
        employerBankName = resolveBankName();

        String status = blankIfNull(contactRecord.Current_Consent_Status__c);
        consentStatus = String.isBlank(status) ? 'Authorized' : status;

        Datetime submittedAt = getDatetimeFieldValue(
            contactRecord,
            new List<String>{ 'Latest_Submission_Datetime__c' }
        );
        submissionDateTime = submittedAt == null ? '' : submittedAt.format('d MMMM yyyy, h:mm a');

        Date expiryDate = getDateFieldValue(
            contactRecord,
            new List<String>{ 'Current_Consent_Expiry_Date__c' }
        );
        consentExpiryDate = expiryDate == null ? '' : formatDate(expiryDate);
    }

    private String resolveBankName() {
        if (contactRecord != null && contactRecord.Account != null && !String.isBlank(contactRecord.Account.Name)) {
            return contactRecord.Account.Name;
        }
        return 'your employer';
    }

    private Contact queryContact(Id subjectId) {
        Map<String, Schema.SObjectField> fieldMap = Contact.SObjectType.getDescribe().fields.getMap();
        List<String> fields = new List<String>{ 'Id', 'Name', 'AccountId', 'Account.Name' };
        List<String> optional = new List<String>{
            'Principal_Name__c',
            'Full_Name__c',
            'Current_Consent_Status__c',
            'Current_Consent_Expiry_Date__c',
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

    private void parseUrlParameters() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        contactId = firstNonBlank(params.get('contactId'), params.get('ContactId'));
        requestItemId = firstNonBlank(params.get('requestItemId'), params.get('consentRequestItemId'));
        token = params.get('token');
    }

    private String formatDate(Date dateValue) {
        if (dateValue == null) {
            return '';
        }
        return Datetime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0)).format('d MMMM yyyy');
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