@IsTest
private class UatClientUserIsolationE2ETest {
    private static final Set<String> PORTAL_USER_TYPES = new Set<String>{
        'PowerCustomerSuccess',
        'CustomerSuccess',
        'CspLitePortal',
        'PowerPartner'
    };

    private class UserPair {
        User userA;
        User userB;
        Id accountAId;
        Id accountBId;
    }

    @IsTest(SeeAllData=true)
    static void testClientUserABDataIsolationTemplate() {
        UserPair pair = findPortalUsersFromDifferentAccounts();
        if (pair == null) {
            System.debug(LoggingLevel.WARN, 'UAT TEMPLATE SKIPPED: no two portal users on different Accounts were found.');
            return;
        }

        assertIsolationForViewer(pair.userA, pair.accountAId, pair.accountBId, 'A');
        assertIsolationForViewer(pair.userB, pair.accountBId, pair.accountAId, 'B');
    }

    private static UserPair findPortalUsersFromDifferentAccounts() {
        List<User> portalUsers = [
            SELECT Id, Username, UserType, ContactId, Contact.AccountId
            FROM User
            WHERE IsActive = true
                AND UserType IN :PORTAL_USER_TYPES
                AND ContactId != null
                AND Contact.AccountId != null
            ORDER BY LastLoginDate DESC NULLS LAST, CreatedDate DESC
            LIMIT 200
        ];
        if (portalUsers.size() < 2) {
            return null;
        }

        for (Integer i = 0; i < portalUsers.size(); i++) {
            User leftUser = portalUsers[i];
            Id leftAccountId = leftUser.Contact.AccountId;
            if (leftAccountId == null) {
                continue;
            }
            for (Integer j = i + 1; j < portalUsers.size(); j++) {
                User rightUser = portalUsers[j];
                Id rightAccountId = rightUser.Contact.AccountId;
                if (rightAccountId == null || rightAccountId == leftAccountId) {
                    continue;
                }

                UserPair result = new UserPair();
                result.userA = leftUser;
                result.userB = rightUser;
                result.accountAId = leftAccountId;
                result.accountBId = rightAccountId;
                return result;
            }
        }
        return null;
    }

    private static void assertIsolationForViewer(User viewer, Id ownAccountId, Id foreignAccountId, String label) {
        System.runAs(viewer) {
            String marker = '[Viewer ' + label + ' / ' + viewer.Username + '] ';

            // Baseline: viewer should still access own Account.
            Integer ownAccountCount = countWhere('Account', 'Id = \'' + quoted(ownAccountId) + '\'');
            System.assert(ownAccountCount > 0, marker + 'Own Account should be visible.');

            assertNoForeignData('Account', 'Id = \'' + quoted(foreignAccountId) + '\'', marker + 'Account');
            assertNoForeignData('Contact', 'AccountId = \'' + quoted(foreignAccountId) + '\'', marker + 'Contact');
            assertNoForeignData('Case', 'AccountId = \'' + quoted(foreignAccountId) + '\'', marker + 'Case');

            String consentForeignWhere = buildConsentForeignWhere(foreignAccountId);
            if (String.isNotBlank(consentForeignWhere)) {
                assertNoForeignData('Consent__c', consentForeignWhere, marker + 'Consent__c');
            }

            String consentRequestForeignWhere = buildConsentRequestForeignWhere(foreignAccountId);
            if (String.isNotBlank(consentRequestForeignWhere)) {
                assertNoForeignData('Consent_Request_Item__c', consentRequestForeignWhere, marker + 'Consent_Request_Item__c');
            }

            String reportRequestForeignWhere = buildReportRequestForeignWhere(foreignAccountId);
            if (String.isNotBlank(reportRequestForeignWhere)) {
                assertNoForeignData('Report_Request_Item__c', reportRequestForeignWhere, marker + 'Report_Request_Item__c');
            }

            String exceptionForeignWhere = buildExceptionForeignWhere(foreignAccountId);
            if (String.isNotBlank(exceptionForeignWhere)) {
                assertNoForeignData('Exception__c', exceptionForeignWhere, marker + 'Exception__c');
            } else {
                System.debug(LoggingLevel.WARN, marker + 'Skip Exception__c check: no account linkage field discovered.');
            }
        }
    }

    private static void assertNoForeignData(String objectApiName, String whereClause, String assertLabel) {
        if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
            System.debug(LoggingLevel.WARN, assertLabel + ' skipped because object does not exist.');
            return;
        }
        try {
            Integer foreignCount = countWhere(objectApiName, whereClause);
            System.assertEquals(0, foreignCount, assertLabel + ' should not return foreign-account records.');
        } catch (System.SecurityException secEx) {
            System.debug(LoggingLevel.WARN, assertLabel + ' skipped due to object-level permission: ' + secEx.getMessage());
            return;
        } catch (Exception ex) {
            if (ex.getMessage().contains('Access to entity')) {
                System.debug(LoggingLevel.WARN, assertLabel + ' skipped due to object-level permission: ' + ex.getMessage());
                return;
            }
            throw ex;
        }
    }

    private static Integer countWhere(String objectApiName, String whereClause) {
        String soql = 'SELECT COUNT() FROM ' + objectApiName;
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        return Database.countQuery(soql);
    }

    private static String buildExceptionForeignWhere(Id foreignAccountId) {
        if (!Schema.getGlobalDescribe().containsKey('Exception__c')) {
            return null;
        }
        Map<String, Schema.SObjectField> exceptionFields = Schema.SObjectType.Exception__c.fields.getMap();
        if (exceptionFields.containsKey('Client_Account__c')) {
            return 'Client_Account__c = \'' + quoted(foreignAccountId) + '\'';
        }
        if (exceptionFields.containsKey('Account__c')) {
            return 'Account__c = \'' + quoted(foreignAccountId) + '\'';
        }
        if (!exceptionFields.containsKey('Batch__c') || !Schema.getGlobalDescribe().containsKey('Batch__c')) {
            return null;
        }

        Map<String, Schema.SObjectField> batchFields = Schema.SObjectType.Batch__c.fields.getMap();
        if (batchFields.containsKey('Client_Account__c')) {
            return 'Batch__r.Client_Account__c = \'' + quoted(foreignAccountId) + '\'';
        }
        if (batchFields.containsKey('Account__c')) {
            return 'Batch__r.Account__c = \'' + quoted(foreignAccountId) + '\'';
        }
        return null;
    }

    private static String buildConsentForeignWhere(Id foreignAccountId) {
        if (!Schema.getGlobalDescribe().containsKey('Consent__c')) {
            return null;
        }
        Map<String, Schema.SObjectField> consentFields = Schema.SObjectType.Consent__c.fields.getMap();
        if (!consentFields.containsKey('Data_Subject__c')) {
            return null;
        }
        return 'Data_Subject__r.AccountId = \'' + quoted(foreignAccountId) + '\'';
    }

    private static String buildConsentRequestForeignWhere(Id foreignAccountId) {
        if (!Schema.getGlobalDescribe().containsKey('Consent_Request_Item__c')) {
            return null;
        }
        Map<String, Schema.SObjectField> itemFields = Schema.SObjectType.Consent_Request_Item__c.fields.getMap();
        List<String> orParts = new List<String>();
        if (itemFields.containsKey('Data_Subject__c')) {
            orParts.add('Data_Subject__r.AccountId = \'' + quoted(foreignAccountId) + '\'');
        }
        if (itemFields.containsKey('Consent_Request_Case__c')) {
            orParts.add('Consent_Request_Case__r.AccountId = \'' + quoted(foreignAccountId) + '\'');
        }
        if (orParts.isEmpty()) {
            return null;
        }
        return '(' + String.join(orParts, ' OR ') + ')';
    }

    private static String buildReportRequestForeignWhere(Id foreignAccountId) {
        if (!Schema.getGlobalDescribe().containsKey('Report_Request_Item__c')) {
            return null;
        }
        Map<String, Schema.SObjectField> itemFields = Schema.SObjectType.Report_Request_Item__c.fields.getMap();
        List<String> orParts = new List<String>();
        if (itemFields.containsKey('Report_Request_Case__c')) {
            orParts.add('Report_Request_Case__r.AccountId = \'' + quoted(foreignAccountId) + '\'');
        }
        if (itemFields.containsKey('Data_Subject__c')) {
            orParts.add('Data_Subject__r.AccountId = \'' + quoted(foreignAccountId) + '\'');
        }
        if (orParts.isEmpty()) {
            return null;
        }
        return '(' + String.join(orParts, ' OR ') + ')';
    }

    private static String quoted(Id value) {
        return String.escapeSingleQuotes(String.valueOf(value));
    }
}