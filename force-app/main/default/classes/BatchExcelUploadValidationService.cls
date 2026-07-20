public with sharing class BatchExcelUploadValidationService {
    public static final String EXC_MSG_INVALID_EMAIL = 'Invalid Email Format';
    public static final String EXC_MSG_DUPLICATE_EMAIL = 'Duplicate Email';
    public static final String EXC_MSG_INVALID_FULL_NAME = 'Invalid Full Name Format';
    public static final String EXC_MSG_INVALID_EMPLOYMENT_STATUS = 'Invalid Employment Status';
    public static final String EXC_MSG_INVALID_ID_TYPE = 'Invalid ID Type';
    public static final String EXC_MSG_INVALID_NRIC_FIN = 'Invalid NRIC / FIN Format';
    public static final String EXC_MSG_INVALID_PASSPORT = 'Invalid Passport Number Format';
    public static final String EXC_MSG_DUPLICATE_ID_NUMBER = 'Duplicate ID Number';
    public static final String EXC_MSG_INVALID_DOB = 'Invalid Date of Birth';
    public static final String EXC_MSG_INVALID_LAST_EMPLOYMENT_DATE = 'Invalid Last Employment Date';
    public static final String EXC_MSG_EXISTING_HIRE_EMAIL_DOMAIN = 'Existing Hire Email Domain Mismatch';
    public static final String EXC_MSG_DUPLICATE_ROW = 'Duplicate Row in Upload File';
    public static final String EXC_MSG_EXISTING_DS_MATCH = 'Existing Data Subject Match Found';
    public static final String EXC_MSG_EXISTING_ACTIVE_CONSENT = 'Existing Active Consent Found';
    public static final String EXC_MSG_DO_NOT_CONTACT = 'Do Not Contact';

    private static final Set<String> DEFAULT_ALLOWED_ID_TYPES = new Set<String>{ 'NRIC', 'FIN', 'Passport', 'Other' };
    private static final Set<String> DEFAULT_ALLOWED_EMPLOYMENT = new Set<String>{ 'Existing Hire', 'Pre-hire' };
    private static final Set<String> ACTIVE_CONSENT_STATUSES = new Set<String>{ 'ACTIVE', 'VALID', 'AUTHORIZED' };

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
        '^(?=.{1,254}$)(?=.{1,64}@)(?![.])(?!.*\\.\\.)[A-Za-z0-9._%+-]+(?<![.])@' +
        '[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$'
    );
    private static final Pattern NRIC_FIN_PATTERN = Pattern.compile('^[STFGM][0-9]{7}[A-Z]$');
    private static final Pattern PASSPORT_PATTERN = Pattern.compile('^[A-Za-z0-9]{5,20}$');
    private static final Pattern FULL_NAME_SPACES_PATTERN = Pattern.compile('.*\\s{3,}.*');
    private static final Pattern FULL_NAME_ALLOWED_PATTERN = Pattern.compile('^[A-Za-z][A-Za-z .\\\'-]*$');
    private static final Pattern FULL_NAME_DIGITS_ONLY_PATTERN = Pattern.compile('^[0-9\\s]+$');
    private static final Pattern FULL_NAME_SPECIAL_ONLY_PATTERN = Pattern.compile('^[^A-Za-z0-9]+$');
    private static final Pattern DATE_PATTERN_ISO = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}$');
    private static final Pattern DATE_PATTERN_SLASH = Pattern.compile('^\\d{1,2}/\\d{1,2}/\\d{4}$');

    public class ConsentValidationRow {
        public Integer rowNumber;
        public String email;
        public String fullName;
        public String idType;
        public String idNumber;
        public String dateOfBirth;
        public String lastEmploymentDate;
        public String employmentStatus;
    }

    public class RowValidationError {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String errorReason;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String fieldValue;
    }

    public class ValidationContext {
        public Set<String> allowedEmploymentStatuses = new Set<String>();
        public Set<String> allowedIdTypes = new Set<String>();
        public Map<String, Integer> emailDuplicateCounts = new Map<String, Integer>();
        public Map<String, Integer> idDuplicateCounts = new Map<String, Integer>();
        public Map<String, List<Contact>> existingContactsByEmail = new Map<String, List<Contact>>();
        public Map<String, List<Contact>> existingContactsById = new Map<String, List<Contact>>();
        public Set<Id> contactsWithActiveConsent = new Set<Id>();
        public Set<String> allowedExistingHireDomains = new Set<String>();
        public String source;
        public String batchReference;
        public Id accountId;
        public Id batchId;
    }

    public static ValidationContext buildValidationContext(
        List<ConsentValidationRow> rows,
        Id accountId,
        Id batchId,
        String batchReference,
        String source
    ) {
        ValidationContext context = new ValidationContext();
        context.accountId = accountId;
        context.batchId = batchId;
        context.batchReference = batchReference;
        context.source = source;
        context.allowedEmploymentStatuses = resolveAllowedPicklistValues('Employment_Status__c', DEFAULT_ALLOWED_EMPLOYMENT);
        context.allowedIdTypes = resolveAllowedPicklistValues('ID_Type__c', DEFAULT_ALLOWED_ID_TYPES);
        context.allowedExistingHireDomains = resolveAllowedExistingHireDomains(accountId);

        Set<String> allEmails = new Set<String>();
        Set<String> allIdNumbers = new Set<String>();
        for (ConsentValidationRow row : rows) {
            if (row == null || isBlankConsentRow(row)) {
                continue;
            }
            String normalizedEmail = normalizeEmail(row.email);
            String normalizedIdNumber = normalizeIdNumber(row.idNumber);
            if (String.isNotBlank(normalizedEmail)) {
                allEmails.add(normalizedEmail);
                context.emailDuplicateCounts.put(
                    normalizedEmail,
                    (context.emailDuplicateCounts.containsKey(normalizedEmail) ? context.emailDuplicateCounts.get(normalizedEmail) : 0) + 1
                );
            }
            if (String.isNotBlank(normalizedIdNumber)) {
                allIdNumbers.add(normalizedIdNumber);
                context.idDuplicateCounts.put(
                    normalizedIdNumber,
                    (context.idDuplicateCounts.containsKey(normalizedIdNumber) ? context.idDuplicateCounts.get(normalizedIdNumber) : 0) + 1
                );
            }
        }

        List<Contact> existingContacts = queryExistingContacts(accountId, allEmails, allIdNumbers);
        Set<Id> contactIds = new Set<Id>();
        Boolean hasIdNumberField = Schema.SObjectType.Contact.fields.getMap().containsKey('ID_Number__c');
        for (Contact c : existingContacts) {
            contactIds.add(c.Id);
            String normalizedEmail = normalizeEmail((String) c.get('Email'));
            String normalizedIdNumber = hasIdNumberField ? normalizeIdNumber((String) c.get('ID_Number__c')) : null;
            if (String.isNotBlank(normalizedEmail)) {
                addContactIndex(context.existingContactsByEmail, normalizedEmail, c);
            }
            if (String.isNotBlank(normalizedIdNumber)) {
                addContactIndex(context.existingContactsById, normalizedIdNumber, c);
            }
        }
        context.contactsWithActiveConsent = queryContactsWithActiveConsent(contactIds);
        return context;
    }

    public static List<RowValidationError> validateConsentRowStrict(
        ConsentValidationRow row,
        Integer rowNumber,
        ValidationContext context
    ) {
        List<RowValidationError> errors = new List<RowValidationError>();
        String email = trimVal(row.email);
        String fullName = trimVal(row.fullName);
        String idType = normalizeIdType(row.idType);
        String idNumber = trimVal(row.idNumber);
        String normalizedEmail = normalizeEmail(email);
        String normalizedIdNumber = normalizeIdNumber(idNumber);
        String employmentStatus = normalizeEmploymentStatus(row.employmentStatus);
        Date dateOfBirth = parseSupportedDate(row.dateOfBirth);
        Date lastEmploymentDate = parseSupportedDate(row.lastEmploymentDate);

        if (!isValidEmail(email)) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_EMAIL, 'Invalid Email Format: Email Address is blank or not in a valid email format.', 'Email Address', row.email));
        }
        if (String.isNotBlank(normalizedEmail) && context.emailDuplicateCounts.get(normalizedEmail) > 1) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_DUPLICATE_ROW, 'Duplicate Row in Upload File: Another row in the uploaded file contains the same Email Address or ID Number.', 'Email Address', row.email));
        }
        if (String.isNotBlank(normalizedIdNumber) && context.idDuplicateCounts.get(normalizedIdNumber) > 1) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_DUPLICATE_ROW, 'Duplicate Row in Upload File: Another row in the uploaded file contains the same Email Address or ID Number.', 'ID Number', row.idNumber));
        }
        if (
            String.isBlank(fullName) ||
            hasMoreThanTwoConsecutiveSpaces(fullName) ||
            FULL_NAME_DIGITS_ONLY_PATTERN.matcher(fullName).matches() ||
            FULL_NAME_SPECIAL_ONLY_PATTERN.matcher(fullName).matches() ||
            !FULL_NAME_ALLOWED_PATTERN.matcher(fullName).matches()
        ) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_FULL_NAME, 'Invalid Full Name Format: Full Name is blank or does not meet the required name format.', 'Full Name', row.fullName));
        }
        if (!context.allowedEmploymentStatuses.contains(employmentStatus)) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_EMPLOYMENT_STATUS, 'Invalid Employment Status: Employment Status must be Existing Hire or Pre-hire.', 'Employment Status', row.employmentStatus));
        }
        if (!context.allowedIdTypes.contains(idType)) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_ID_TYPE, 'Invalid ID Type: ID Type is not supported.', 'ID Type', row.idType));
        } else if (isSingpassIdType(idType) && !isValidNricOrFin(idNumber)) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_NRIC_FIN, 'Invalid NRIC / FIN Format: ID Number does not match the required NRIC / FIN format.', 'ID Number', row.idNumber));
        } else if ('Passport'.equals(idType) && !isValidPassportNumber(idNumber)) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_PASSPORT, 'Invalid Passport Number Format: Passport Number is blank or contains invalid characters.', 'ID Number', row.idNumber));
        }
        if (dateOfBirth == null || dateOfBirth > Date.today()) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_DOB, 'Invalid Date of Birth: Date of Birth is blank, invalid, or in the future.', 'Date of Birth', row.dateOfBirth));
        }
        if (String.isNotBlank(trimVal(row.lastEmploymentDate))) {
            if (lastEmploymentDate == null || (dateOfBirth != null && lastEmploymentDate < dateOfBirth) || 'Existing Hire'.equals(employmentStatus)) {
                errors.add(buildRowValidationError(rowNumber, EXC_MSG_INVALID_LAST_EMPLOYMENT_DATE, 'Invalid Last Employment Date: Last Employment Date is invalid or inconsistent with the uploaded data.', 'Last Employment Date', row.lastEmploymentDate));
            }
        }
        if ('Existing Hire'.equals(employmentStatus) && String.isNotBlank(normalizedEmail) && !context.allowedExistingHireDomains.isEmpty() && !matchesAnyDomain(normalizedEmail, context.allowedExistingHireDomains)) {
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_EXISTING_HIRE_EMAIL_DOMAIN, 'Existing Hire Email Domain Mismatch: Existing Hire email domain does not match the client account domain.', 'Email Address', row.email));
        }

        List<Contact> matchedContacts = collectMatchedContacts(normalizedEmail, normalizedIdNumber, context);
        if (!matchedContacts.isEmpty()) {
            if (String.isNotBlank(normalizedEmail) && context.existingContactsByEmail.containsKey(normalizedEmail)) {
                errors.add(buildRowValidationError(rowNumber, EXC_MSG_DUPLICATE_EMAIL, 'Duplicate Email: A Data Subject with the same Email Address already exists for this client.', 'Email Address', row.email));
            }
            if (String.isNotBlank(normalizedIdNumber) && context.existingContactsById.containsKey(normalizedIdNumber)) {
                errors.add(buildRowValidationError(rowNumber, EXC_MSG_DUPLICATE_ID_NUMBER, 'Duplicate ID Number: A Data Subject with the same ID Number already exists for this client.', 'ID Number', row.idNumber));
            }
            errors.add(buildRowValidationError(rowNumber, EXC_MSG_EXISTING_DS_MATCH, 'Existing Data Subject Match Found: An existing Data Subject matches the uploaded row.', 'Consent Upload Row', row.email));
            for (Contact matched : matchedContacts) {
                if (hasDoNotContactFlag(matched)) {
                    errors.add(
                        buildRowValidationError(
                            rowNumber,
                            EXC_MSG_DO_NOT_CONTACT,
                            'Do Not Contact: This Data Subject is marked as Do Not Contact and cannot receive consent email.',
                            'Consent Upload Row',
                            String.valueOf(matched.Id)
                        )
                    );
                    break;
                }
            }

            for (Contact matched : matchedContacts) {
                if (context.contactsWithActiveConsent.contains(matched.Id)) {
                    errors.add(buildRowValidationError(rowNumber, EXC_MSG_EXISTING_ACTIVE_CONSENT, 'Existing Active Consent Found: This Data Subject already has an active consent record.', 'Consent Upload Row', String.valueOf(matched.Id)));
                    break;
                }
            }
        }
        return dedupeRowErrors(errors);
    }

    public static List<RowValidationError> validateConsentRowLegacy(
        ConsentValidationRow row,
        Integer rowNumber,
        Set<String> allowedEmploymentStatuses,
        Set<String> allowedIdTypes
    ) {
        List<RowValidationError> errors = new List<RowValidationError>();
        if (!isValidEmail(row.email)) {
            errors.add(buildRowValidationError(rowNumber, 'Invalid Email', 'Invalid Email', 'Email Address', row.email));
            return errors;
        }
        String normalizedIdType = normalizeIdType(row.idType);
        if (isSingpassIdType(normalizedIdType) && !isValidNricOrFin(row.idNumber)) {
            errors.add(buildRowValidationError(rowNumber, 'NRIC / FIN format validation fail', 'NRIC / FIN format validation fail', 'ID Number', row.idNumber));
            return errors;
        }
        if (hasMoreThanTwoConsecutiveSpaces(row.fullName)) {
            errors.add(buildRowValidationError(rowNumber, 'Full Name contains more than 2 consecutive spaces', 'Full Name contains more than 2 consecutive spaces', 'Full Name', row.fullName));
            return errors;
        }
        String requiredMessage = validateLegacyRequiredFieldsMessage(row);
        if (requiredMessage != null) {
            errors.add(buildRowValidationError(rowNumber, requiredMessage, requiredMessage, legacyFieldName(requiredMessage), legacyFieldValue(row, requiredMessage)));
            return errors;
        }
        if (!allowedEmploymentStatuses.contains(normalizeEmploymentStatus(row.employmentStatus))) {
            errors.add(buildRowValidationError(rowNumber, 'Invalid Employment Status', 'Invalid Employment Status', 'Employment Status', row.employmentStatus));
            return errors;
        }
        if (!allowedIdTypes.contains(normalizedIdType)) {
            errors.add(buildRowValidationError(rowNumber, 'Invalid ID Type', 'Invalid ID Type', 'ID Type', row.idType));
        }
        return errors;
    }

    public static Exception__c buildExceptionFromConsentRow(
        ConsentValidationRow row,
        List<RowValidationError> errors,
        ValidationContext context
    ) {
        Exception__c ex = new Exception__c();
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Exception__c.fields.getMap();
        RowValidationError firstError = errors.isEmpty() ? null : errors[0];
        setBatchReferenceFields(ex, fields, context);
        setIfFieldExists(ex, fields, 'Excel_Row_Number__c', row.rowNumber);
        setIfFieldExists(ex, fields, 'Exception_Field_Name__c', firstError == null ? 'Consent Upload Row' : firstError.fieldName);
        setIfFieldExists(ex, fields, 'Field_Value__c', normalizeExceptionFieldValue(firstError == null ? null : firstError.fieldValue));
        setIfFieldExists(ex, fields, 'Exception_Message__c', joinErrorMessages(errors));
        setIfFieldExists(ex, fields, 'Error_Reason__c', joinErrorReasons(errors));
        setIfFieldExists(ex, fields, 'Source__c', context.source);
        setIfFieldExists(ex, fields, 'Status__c', 'New');
        setReferenceOrValue(ex, fields, new List<String>{ 'Account__c', 'Client_Account__c' }, context.accountId);
        setIfFieldExists(ex, fields, 'Row_Number__c', row.rowNumber);
        setIfFieldExists(ex, fields, 'Uploaded_Email__c', row.email);
        setIfFieldExists(ex, fields, 'Uploaded_Full_Name__c', row.fullName);
        setIfFieldExists(ex, fields, 'Uploaded_ID_Type__c', row.idType);
        setIfFieldExists(ex, fields, 'Uploaded_ID_Number__c', row.idNumber);
        setDateOrTextField(ex, fields, 'Uploaded_Date_of_Birth__c', row.dateOfBirth);
        setDateOrTextField(ex, fields, 'Uploaded_Last_Employment_Date__c', row.lastEmploymentDate);
        setIfFieldExists(ex, fields, 'Uploaded_Employment_Status__c', row.employmentStatus);
        return ex;
    }

    public static Exception__c buildExceptionFromConsentError(
        ConsentValidationRow row,
        RowValidationError error,
        ValidationContext context
    ) {
        Exception__c ex = new Exception__c();
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Exception__c.fields.getMap();
        setBatchReferenceFields(ex, fields, context);
        setIfFieldExists(ex, fields, 'Excel_Row_Number__c', row == null ? null : row.rowNumber);
        setIfFieldExists(
            ex,
            fields,
            'Exception_Field_Name__c',
            error == null || String.isBlank(error.fieldName) ? 'Consent Upload Row' : error.fieldName
        );
        setIfFieldExists(ex, fields, 'Field_Value__c', normalizeExceptionFieldValue(error == null ? null : error.fieldValue));
        setIfFieldExists(ex, fields, 'Exception_Message__c', error == null ? null : error.errorMessage);
        setIfFieldExists(ex, fields, 'Error_Reason__c', error == null ? null : error.errorReason);
        setIfFieldExists(ex, fields, 'Source__c', context == null ? null : context.source);
        setIfFieldExists(ex, fields, 'Status__c', 'New');
        setReferenceOrValue(
            ex,
            fields,
            new List<String>{ 'Account__c', 'Client_Account__c' },
            context == null ? null : context.accountId
        );
        setIfFieldExists(ex, fields, 'Row_Number__c', row == null ? null : row.rowNumber);
        setIfFieldExists(ex, fields, 'Uploaded_Email__c', row == null ? null : row.email);
        setIfFieldExists(ex, fields, 'Uploaded_Full_Name__c', row == null ? null : row.fullName);
        setIfFieldExists(ex, fields, 'Uploaded_ID_Type__c', row == null ? null : row.idType);
        setIfFieldExists(ex, fields, 'Uploaded_ID_Number__c', row == null ? null : row.idNumber);
        setDateOrTextField(ex, fields, 'Uploaded_Date_of_Birth__c', row == null ? null : row.dateOfBirth);
        setDateOrTextField(ex, fields, 'Uploaded_Last_Employment_Date__c', row == null ? null : row.lastEmploymentDate);
        setIfFieldExists(ex, fields, 'Uploaded_Employment_Status__c', row == null ? null : row.employmentStatus);
        return ex;
    }

    public static Exception__c buildSimpleException(
        String batchReference,
        String fieldName,
        String fieldValue,
        String message,
        String source
    ) {
        Exception__c ex = new Exception__c();
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Exception__c.fields.getMap();
        setIfFieldExists(ex, fields, 'Batch_Id__c', batchReference);
        setIfFieldExists(ex, fields, 'Exception_Field_Name__c', fieldName);
        setIfFieldExists(ex, fields, 'Field_Value__c', fieldValue);
        setIfFieldExists(ex, fields, 'Exception_Message__c', message);
        setIfFieldExists(ex, fields, 'Source__c', source);
        return ex;
    }

    public static String normalizeEmail(String raw) {
        String trimmed = trimVal(raw);
        return String.isBlank(trimmed) ? null : trimmed.toLowerCase();
    }

    public static String normalizeIdNumber(String raw) {
        String trimmed = trimVal(raw);
        return String.isBlank(trimmed) ? trimmed : trimmed.toUpperCase();
    }

    public static String normalizeEmploymentStatus(String raw) {
        String v = trimVal(raw);
        if (String.isBlank(v)) return v;
        if ('Existing Hire'.equalsIgnoreCase(v) || 'Existing'.equalsIgnoreCase(v)) return 'Existing Hire';
        if ('Pre-hire'.equalsIgnoreCase(v) || 'Pre Hire'.equalsIgnoreCase(v) || 'Prehire'.equalsIgnoreCase(v)) return 'Pre-hire';
        return v;
    }

    public static String normalizeIdType(String raw) {
        String v = trimVal(raw);
        if (String.isBlank(v)) return v;
        if ('NRIC'.equalsIgnoreCase(v)) return 'NRIC';
        if ('FIN'.equalsIgnoreCase(v)) return 'FIN';
        if ('Passport'.equalsIgnoreCase(v)) return 'Passport';
        if ('Other'.equalsIgnoreCase(v)) return 'Other';
        return v;
    }

    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        String normalizedEmail = email.trim();
        if (!EMAIL_PATTERN.matcher(normalizedEmail).matches()) {
            return false;
        }
        if (normalizedEmail.contains('..')) {
            return false;
        }

        Integer atIndex = normalizedEmail.indexOf('@');
        if (atIndex <= 0 || atIndex >= normalizedEmail.length() - 1) {
            return false;
        }
        String localPart = normalizedEmail.substring(0, atIndex);
        String domainPart = normalizedEmail.substring(atIndex + 1);

        if (
            localPart.startsWith('.') ||
            localPart.endsWith('.') ||
            domainPart.startsWith('.') ||
            domainPart.endsWith('.') ||
            domainPart.startsWith('-') ||
            domainPart.endsWith('-')
        ) {
            return false;
        }
        return true;
    }

    public static Boolean isValidNricOrFin(String idNumber) {
        return String.isNotBlank(idNumber) && NRIC_FIN_PATTERN.matcher(idNumber.trim().toUpperCase()).matches();
    }

    public static Boolean isValidPassportNumber(String idNumber) {
        return String.isNotBlank(idNumber) && PASSPORT_PATTERN.matcher(idNumber.trim()).matches();
    }

    public static Boolean hasMoreThanTwoConsecutiveSpaces(String value) {
        return String.isNotBlank(value) && FULL_NAME_SPACES_PATTERN.matcher(value).matches();
    }

    public static Date parseSupportedDate(String rawDate) {
        String value = trimVal(rawDate);
        if (String.isBlank(value)) return null;
        try {
            if (DATE_PATTERN_ISO.matcher(value).matches()) return Date.valueOf(value);
            if (DATE_PATTERN_SLASH.matcher(value).matches()) {
                List<String> p = value.split('/');
                return Date.newInstance(Integer.valueOf(p[2]), Integer.valueOf(p[1]), Integer.valueOf(p[0]));
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    public static Boolean isSingpassIdType(String normalizedIdType) {
        return 'NRIC'.equals(normalizedIdType) || 'FIN'.equals(normalizedIdType);
    }

    public static String trimVal(String raw) {
        return raw == null ? null : raw.trim();
    }

    private static String validateLegacyRequiredFieldsMessage(ConsentValidationRow row) {
        if (String.isBlank(trimVal(row.fullName))) return 'Full Name is required.';
        if (String.isBlank(trimVal(row.idType))) return 'ID Type is required.';
        if (String.isBlank(trimVal(row.idNumber))) return 'ID Number is required.';
        if (String.isBlank(trimVal(row.dateOfBirth))) return 'Date of Birth is required.';
        if (parseSupportedDate(row.dateOfBirth) == null) return 'Date of Birth must be a valid date in YYYY-MM-DD format.';
        if (String.isBlank(trimVal(row.employmentStatus))) return 'Employment Status is required.';
        return null;
    }

    private static String legacyFieldName(String validationMessage) {
        if (validationMessage.startsWith('Full Name')) return 'Full Name';
        if (validationMessage.startsWith('ID Type')) return 'ID Type';
        if (validationMessage.startsWith('ID Number')) return 'ID Number';
        if (validationMessage.startsWith('Date of Birth')) return 'Date of Birth';
        if (validationMessage.startsWith('Employment Status')) return 'Employment Status';
        return 'Consent Upload Row';
    }

    private static String legacyFieldValue(ConsentValidationRow row, String validationMessage) {
        if (validationMessage.startsWith('Full Name')) return row.fullName;
        if (validationMessage.startsWith('ID Type')) return row.idType;
        if (validationMessage.startsWith('ID Number')) return row.idNumber;
        if (validationMessage.startsWith('Date of Birth')) return row.dateOfBirth;
        if (validationMessage.startsWith('Employment Status')) return row.employmentStatus;
        return row.email;
    }

    private static Boolean isBlankConsentRow(ConsentValidationRow row) {
        return String.isBlank(trimVal(row.email)) &&
            String.isBlank(trimVal(row.fullName)) &&
            String.isBlank(trimVal(row.idType)) &&
            String.isBlank(trimVal(row.idNumber)) &&
            String.isBlank(trimVal(row.dateOfBirth)) &&
            String.isBlank(trimVal(row.lastEmploymentDate)) &&
            String.isBlank(trimVal(row.employmentStatus));
    }

    private static Set<String> resolveAllowedPicklistValues(String fieldApiName, Set<String> fallbackValues) {
        Set<String> values = new Set<String>();
        Schema.SObjectField token = Schema.SObjectType.Contact.fields.getMap().get(fieldApiName);
        if (token != null) {
            for (Schema.PicklistEntry entry : token.getDescribe().getPicklistValues()) {
                if (entry.isActive()) values.add(entry.getValue());
            }
        }
        if (values.isEmpty()) values.addAll(fallbackValues);
        return values;
    }

    private static void addContactIndex(Map<String, List<Contact>> indexByValue, String key, Contact contactRec) {
        if (!indexByValue.containsKey(key)) indexByValue.put(key, new List<Contact>());
        indexByValue.get(key).add(contactRec);
    }

    private static List<Contact> queryExistingContacts(Id accountId, Set<String> normalizedEmails, Set<String> normalizedIdNumbers) {
        List<Contact> contacts = new List<Contact>();
        if ((normalizedEmails.isEmpty() && normalizedIdNumbers.isEmpty()) || !Schema.sObjectType.Contact.isAccessible()) {
            return contacts;
        }
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        Boolean hasIdNumberField = contactFields.containsKey('ID_Number__c');
        Boolean hasDoNotContactField = contactFields.containsKey('Do_Not_Contact__c');
        if (!hasIdNumberField) normalizedIdNumbers = new Set<String>();

        Set<String> emailInValues = new Set<String>();
        for (String normalizedEmail : normalizedEmails) {
            if (String.isBlank(normalizedEmail)) continue;
            emailInValues.add(normalizedEmail);
            emailInValues.add(normalizedEmail.toLowerCase());
        }
        String whereClause = 'AccountId = :accountId';
        if (!emailInValues.isEmpty() && !normalizedIdNumbers.isEmpty()) {
            whereClause += ' AND (Email IN :emailInValues OR ID_Number__c IN :normalizedIdNumbers)';
        } else if (!emailInValues.isEmpty()) {
            whereClause += ' AND Email IN :emailInValues';
        } else if (!normalizedIdNumbers.isEmpty()) {
            whereClause += ' AND ID_Number__c IN :normalizedIdNumbers';
        } else {
            return contacts;
        }
        String soql =
            'SELECT Id, AccountId, Email'
            + (hasIdNumberField ? ', ID_Number__c' : '')
            + (hasDoNotContactField ? ', Do_Not_Contact__c' : '')
            + ' FROM Contact WHERE '
            + whereClause;
        return Database.query(soql);
    }

    private static Boolean hasDoNotContactFlag(Contact contactRow) {
        if (contactRow == null) {
            return false;
        }
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        if (!contactFields.containsKey('Do_Not_Contact__c')) {
            return false;
        }
        Object value = contactRow.get('Do_Not_Contact__c');
        return value instanceof Boolean && ((Boolean) value);
    }

    private static Set<String> resolveAllowedExistingHireDomains(Id accountId) {
        Set<String> domains = new Set<String>();
        if (accountId == null || !Schema.sObjectType.Account.isAccessible()) return domains;
        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        String selectedField;
        for (String candidate : new List<String>{ 'Email_Domain__c', 'Allowed_Email_Domains__c', 'Company_Email_Domain__c' }) {
            if (accountFields.containsKey(candidate)) {
                selectedField = candidate;
                break;
            }
        }
        if (String.isBlank(selectedField)) return domains;
        SObject accountRow = Database.query('SELECT Id, ' + selectedField + ' FROM Account WHERE Id = :accountId LIMIT 1');
        String rawDomains = trimVal((String) accountRow.get(selectedField));
        if (String.isBlank(rawDomains)) return domains;
        for (String token : rawDomains.split(',')) {
            String normalized = trimVal(token);
            if (String.isNotBlank(normalized)) domains.add(normalized.toLowerCase());
        }
        return domains;
    }

    private static Boolean matchesAnyDomain(String normalizedEmail, Set<String> allowedDomains) {
        Integer atIndex = normalizedEmail.lastIndexOf('@');
        if (atIndex < 0 || atIndex >= normalizedEmail.length() - 1) return false;
        return allowedDomains.contains(normalizedEmail.substring(atIndex + 1).toLowerCase());
    }

    private static List<Contact> collectMatchedContacts(String normalizedEmail, String normalizedIdNumber, ValidationContext context) {
        Map<Id, Contact> matches = new Map<Id, Contact>();
        if (String.isNotBlank(normalizedEmail) && context.existingContactsByEmail.containsKey(normalizedEmail)) {
            for (Contact c : context.existingContactsByEmail.get(normalizedEmail)) matches.put(c.Id, c);
        }
        if (String.isNotBlank(normalizedIdNumber) && context.existingContactsById.containsKey(normalizedIdNumber)) {
            for (Contact c : context.existingContactsById.get(normalizedIdNumber)) matches.put(c.Id, c);
        }
        return matches.values();
    }

    private static Set<Id> queryContactsWithActiveConsent(Set<Id> contactIds) {
        Set<Id> result = new Set<Id>();
        if (contactIds.isEmpty() || !Schema.sObjectType.Consent__c.isAccessible()) return result;
        for (Consent__c consentRec : [SELECT Data_Subject__c, Consent_Status__c FROM Consent__c WHERE Data_Subject__c IN :contactIds]) {
            String status = consentRec.Consent_Status__c == null ? null : consentRec.Consent_Status__c.trim().toUpperCase();
            if (ACTIVE_CONSENT_STATUSES.contains(status)) result.add(consentRec.Data_Subject__c);
        }
        return result;
    }

    private static RowValidationError buildRowValidationError(Integer rowNumber, String reason, String message, String fieldName, String fieldValue) {
        RowValidationError error = new RowValidationError();
        error.rowNumber = rowNumber;
        error.errorReason = reason;
        error.errorMessage = message;
        error.fieldName = fieldName;
        error.fieldValue = fieldValue;
        return error;
    }

    public static String joinErrorMessages(List<RowValidationError> rowErrors) {
        List<String> messages = new List<String>();
        for (RowValidationError error : rowErrors) if (error != null && String.isNotBlank(error.errorMessage)) messages.add(error.errorMessage);
        return String.join(messages, ' | ');
    }

    public static String joinErrorReasons(List<RowValidationError> rowErrors) {
        Set<String> reasons = new Set<String>();
        for (RowValidationError error : rowErrors) if (error != null && String.isNotBlank(error.errorReason)) reasons.add(error.errorReason);
        return String.join(new List<String>(reasons), ' | ');
    }

    public static List<RowValidationError> dedupeRowErrors(List<RowValidationError> rowErrors) {
        List<RowValidationError> uniqueErrors = new List<RowValidationError>();
        Set<String> dedupeKeys = new Set<String>();
        for (RowValidationError rowError : rowErrors) {
            if (rowError == null) continue;
            String key = rowError.errorReason + '|' + rowError.fieldName;
            if (dedupeKeys.contains(key)) continue;
            dedupeKeys.add(key);
            uniqueErrors.add(rowError);
        }
        return uniqueErrors;
    }

    private static void setReferenceOrValue(SObject target, Map<String, Schema.SObjectField> fieldsMap, List<String> candidateFields, Object value) {
        for (String fieldApi : candidateFields) {
            if (fieldsMap.containsKey(fieldApi)) {
                setIfFieldExists(target, fieldsMap, fieldApi, value);
                return;
            }
        }
    }

    private static void setIfFieldExists(SObject target, Map<String, Schema.SObjectField> fieldsMap, String fieldApi, Object value) {
        if (fieldsMap.containsKey(fieldApi)) target.put(fieldApi, value);
    }

    private static void setDateOrTextField(SObject target, Map<String, Schema.SObjectField> fieldsMap, String fieldApi, String rawValue) {
        if (!fieldsMap.containsKey(fieldApi)) return;
        if (fieldsMap.get(fieldApi).getDescribe().getType() == Schema.DisplayType.DATE) {
            target.put(fieldApi, parseSupportedDate(rawValue));
        } else {
            target.put(fieldApi, rawValue);
        }
    }

    private static void setBatchReferenceFields(
        Exception__c ex,
        Map<String, Schema.SObjectField> fields,
        ValidationContext context
    ) {
        if (ex == null || fields == null) {
            return;
        }
        if (context != null) {
            setReferenceOrValue(ex, fields, new List<String>{ 'Batch__c' }, context.batchId);
            setIfFieldExists(ex, fields, 'Batch_Id__c', context.batchId == null ? context.batchReference : String.valueOf(context.batchId));
        } else {
            setIfFieldExists(ex, fields, 'Batch_Id__c', null);
        }
    }

    private static String normalizeExceptionFieldValue(String rawFieldValue) {
        String trimmed = trimVal(rawFieldValue);
        return String.isBlank(trimmed) ? 'Blank' : trimmed;
    }
}