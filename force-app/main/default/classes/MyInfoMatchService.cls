public with sharing class MyInfoMatchService {
    public static final String RESULT_MATCHED = 'MATCHED';
    public static final String RESULT_MISMATCH_ID = 'MISMATCH_ID';
    public static final String RESULT_MISMATCH_DOB = 'MISMATCH_DOB';
    public static final String RESULT_INSUFFICIENT_DATA = 'INSUFFICIENT_DATA';

    public class MatchResult {
        public Boolean matched;
        public String resultCode;
    }

    public class MyInfoSnapshot {
        public String principalName;
        public String emailAddress;
        public String nationality;
        public String idType;
        public String gender;
        public String idNumber;
        public String maritalStatus;
        public String passType;
        public String registeredAddress;
        public String passportNumber;
        public Date dateOfBirth;
    }

    public static MatchResult evaluateIdentityMatch(
        String singpassIdNumber,
        Date singpassDateOfBirth,
        List<String> referenceIdNumbers,
        Date referenceDateOfBirth
    ) {
        MatchResult result = new MatchResult();
        result.matched = false;
        result.resultCode = RESULT_INSUFFICIENT_DATA;

        String normalizedSingpassId = normalizeIdNumber(singpassIdNumber);
        if (String.isBlank(normalizedSingpassId)) {
            return result;
        }

        Boolean idMatched = false;
        if (referenceIdNumbers != null) {
            for (String referenceId : referenceIdNumbers) {
                if (normalizeIdNumber(referenceId) == normalizedSingpassId) {
                    idMatched = true;
                    break;
                }
            }
        }
        if (!idMatched) {
            result.resultCode = RESULT_MISMATCH_ID;
            return result;
        }

        if (singpassDateOfBirth != null && referenceDateOfBirth != null && singpassDateOfBirth != referenceDateOfBirth) {
            result.resultCode = RESULT_MISMATCH_DOB;
            return result;
        }

        result.matched = true;
        result.resultCode = RESULT_MATCHED;
        return result;
    }

    public static String normalizeIdNumber(String rawValue) {
        return String.isBlank(rawValue) ? '' : rawValue.trim().toUpperCase();
    }
}