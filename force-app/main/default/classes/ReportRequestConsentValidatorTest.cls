@IsTest
private class ReportRequestConsentValidatorTest {
    @TestSetup
    static void setupData() {
        ReportRequestTestSupport.SeedData seedData = ReportRequestTestSupport.createSeedData(4);
        ReportRequestTestSupport.createActiveConsents(
            new List<Contact>{ seedData.dataSubjects[0], seedData.dataSubjects[1], seedData.dataSubjects[2] }
        );
        ReportRequestTestSupport.createBlockedConsent(seedData.dataSubjects[3]);
    }

    @IsTest
    static void validateForSubmissionPositive() {
        Contact eligibleSubject = [
            SELECT Id, AccountId
            FROM Contact
            WHERE LastName = 'Data Subject 0'
            LIMIT 1
        ];
        ReportRequestConsentValidator.ValidationResult result =
            ReportRequestConsentValidator.validateForSubmission(eligibleSubject.Id, eligibleSubject.AccountId);
        System.assertEquals(true, result.isEligible);
        System.assertEquals('ALLOWED', result.reasonCode);
    }

    @IsTest
    static void validateForSubmissionNegative() {
        Contact blockedSubject = [
            SELECT Id, AccountId
            FROM Contact
            WHERE LastName = 'Data Subject 3'
            LIMIT 1
        ];
        ReportRequestConsentValidator.ValidationResult result =
            ReportRequestConsentValidator.validateForSubmission(blockedSubject.Id, blockedSubject.AccountId);
        System.assertEquals(false, result.isEligible);
        System.assertEquals('CONSENT_STATUS_BLOCKED', result.reasonCode);
    }

    @IsTest
    static void validateForSubmissionBulk() {
        List<Contact> subjects = [
            SELECT Id, AccountId
            FROM Contact
            WHERE LastName LIKE 'Data Subject %'
            ORDER BY LastName ASC
        ];
        List<Id> subjectIds = new List<Id>();
        for (Contact subject : subjects) {
            subjectIds.add(subject.Id);
        }

        List<ReportRequestConsentValidator.ValidationResult> results =
            ReportRequestConsentValidator.validateForSubmission(subjectIds, subjects[0].AccountId);
        System.assertEquals(4, results.size());

        Integer blockedCount = 0;
        for (ReportRequestConsentValidator.ValidationResult result : results) {
            if (!result.isEligible) {
                blockedCount++;
            }
        }
        System.assertEquals(1, blockedCount);
    }
}