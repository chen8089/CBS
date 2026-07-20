@IsTest
public class ConsentGuestAuthServiceTest {
    @IsTest
    static void isTokenValidForRequestItemReturnsFalseWhenLinkExpired() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent',
            Consent_Link_Expires_At__c = System.now().addDays(-1)
        );
        insert requestItem;

        System.assertEquals(
            false,
            ConsentGuestAuthService.isTokenValidForRequestItem(
                requestItem,
                'guest-token',
                contact.Id
            )
        );
    }

    @IsTest
    static void resolveTokenFieldApiNameMatchesQueryableTokenField() {
        String resolvedField = ConsentGuestAuthService.resolveTokenFieldApiName();
        if (String.isBlank(resolvedField)) {
            return;
        }

        Database.query('SELECT ' + resolvedField + ' FROM Consent_Request_Item__c LIMIT 0');
        System.assertEquals(resolvedField, ConsentGuestAuthService.resolveTokenFieldApiName());
    }

    @IsTest
    static void matchesStoredTokenAllowsNonBlankTokenWhenNoStoredTokenExists() {
        if (!String.isBlank(ConsentGuestAuthService.resolveTokenFieldApiName())) {
            return;
        }

        Contact contact = createContact();
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent',
            Consent_Link_Expires_At__c = System.now().addDays(7)
        );
        insert requestItem;

        System.assertEquals(
            true,
            ConsentGuestAuthService.matchesStoredToken(requestItem, 'guest-token')
        );
    }

    @IsTest
    static void getTokenFieldForQueryReturnsResolvedField() {
        System.assertEquals(
            ConsentGuestAuthService.resolveTokenFieldApiName(),
            ConsentGuestAuthService.getTokenFieldForQuery()
        );
    }

    @IsTest
    static void isRequestItemLinkExpiredReturnsTrueForNullItem() {
        System.assertEquals(true, ConsentGuestAuthService.isRequestItemLinkExpired(null));
    }

    @IsTest
    static void isTokenValidForRequestItemRejectsNullRequestItem() {
        System.assertEquals(
            false,
            ConsentGuestAuthService.isTokenValidForRequestItem(null, 'guest-token', null)
        );
    }

    @IsTest
    static void generateSecureTokenReturns32CharHex() {
        String tokenValue = ConsentGuestAuthService.generateSecureToken();
        System.assertEquals(32, tokenValue.length());
        System.assertNotEquals(ConsentGuestAuthService.generateSecureToken(), tokenValue);
    }

    @IsTest
    static void assignTokenIfMissingPopulatesSecureTokenOnInsert() {
        Contact contact = createContact();
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;

        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent'
        );

        Test.startTest();
        insert requestItem;
        Test.stopTest();

        requestItem = reloadRequestItem(requestItem.Id);
        String storedToken = ConsentGuestAuthService.getStoredToken(requestItem);
        System.assertNotEquals(null, storedToken);
        System.assertEquals(32, storedToken.length());
        System.assertNotEquals(null, requestItem.get('Consent_Link_Expires_At__c'));

        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;
    }

    @IsTest
    static void matchesStoredTokenRejectsMissingAndWrongValues() {
        Contact contact = createContact();
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent'
        );
        insert requestItem;
        requestItem = reloadRequestItem(requestItem.Id);
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;

        System.assertEquals(false, ConsentGuestAuthService.matchesStoredToken(requestItem, null));
        System.assertEquals(false, ConsentGuestAuthService.matchesStoredToken(requestItem, 'wrong-token'));
        System.assertEquals(
            true,
            ConsentGuestAuthService.matchesStoredToken(
                requestItem,
                ConsentGuestAuthService.getStoredToken(requestItem)
            )
        );
    }

    @IsTest
    static void isTokenValidForRequestItemRejectsMismatchedContact() {
        Contact contact = createContact();
        Contact otherContact = createContact();
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent'
        );
        insert requestItem;
        requestItem = reloadRequestItem(requestItem.Id);
        String storedToken = ConsentGuestAuthService.getStoredToken(requestItem);
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;

        System.assertEquals(
            false,
            ConsentGuestAuthService.isTokenValidForRequestItem(
                requestItem,
                storedToken,
                otherContact.Id
            )
        );
        System.assertEquals(
            true,
            ConsentGuestAuthService.isTokenValidForRequestItem(
                requestItem,
                storedToken,
                contact.Id
            )
        );
    }

    @IsTest
    static void buildGuestPageUrlIncludesRequiredParameters() {
        ConsentGuestAuthService.guestSiteBaseUrlOverrideForTests = 'https://qr.example.invalid/qr';
        Contact contact = createContact();
        ConsentRequestItemTriggerHandler.suppressConsentEmail = true;
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent'
        );
        insert requestItem;
        requestItem = reloadRequestItem(requestItem.Id);
        String storedToken = ConsentGuestAuthService.getStoredToken(requestItem);
        ConsentRequestItemTriggerHandler.suppressConsentEmail = false;

        String url = ConsentGuestAuthService.buildGuestPageUrl(
            '/QRSiteSingpassEmployeeImportantNotes',
            contact.Id,
            requestItem.Id,
            storedToken,
            new Map<String, String>{ 'action' => 'authorize' }
        );

        System.assert(url.contains('ContactId=' + contact.Id));
        System.assert(url.contains('requestItemId=' + requestItem.Id));
        System.assert(url.contains('token=' + storedToken));
        System.assert(url.contains('action=authorize'));
        ConsentGuestAuthService.guestSiteBaseUrlOverrideForTests = null;
    }

    @IsTest
    static void normalizeGuestSiteBaseUrlRejectsBlankConfiguration() {
        try {
            ConsentGuestAuthService.normalizeGuestSiteBaseUrl(null);
            System.assert(false, 'Expected exception when guest site configuration is blank.');
        } catch (ConsentGuestAuthService.ConsentGuestAuthServiceException e) {
            System.assert(
                e.getMessage().contains('CBS_Runtime_Config__mdt.Guest_Site_Base_Url__c'),
                'Exception should clearly point to missing environment configuration.'
            );
        }
    }

    @IsTest
    static void normalizeGuestSiteBaseUrlTrimsTrailingSlash() {
        String normalized = ConsentGuestAuthService.normalizeGuestSiteBaseUrl(
            'https://qr.example.invalid/qr/'
        );
        System.assertEquals(
            'https://qr.example.invalid/qr',
            normalized
        );
    }

    @IsTest
    static void buildGuestPageUrlRejectsMissingRequiredInputs() {
        ConsentGuestAuthService.guestSiteBaseUrlOverrideForTests = 'https://qr.example.invalid/qr';
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
            Data_Subject__c = contact.Id,
            Current_Status__c = 'Sent'
        );
        insert requestItem;

        System.assertEquals(
            null,
            ConsentGuestAuthService.buildGuestPageUrl(null, contact.Id, requestItem.Id, 'token', null)
        );
        System.assertEquals(
            null,
            ConsentGuestAuthService.buildGuestPageUrl('/page', null, requestItem.Id, 'token', null)
        );
        System.assertEquals(
            null,
            ConsentGuestAuthService.buildGuestPageUrl('/page', contact.Id, null, 'token', null)
        );
        System.assertEquals(
            null,
            ConsentGuestAuthService.buildGuestPageUrl('/page', contact.Id, requestItem.Id, null, null)
        );
        ConsentGuestAuthService.guestSiteBaseUrlOverrideForTests = null;
    }

    @IsTest
    static void normalizeGuestSiteBaseUrlRejectsUnsafeValues() {
        assertNormalizeGuestSiteBaseUrlFails('http://qr.example.invalid/qr');
        assertNormalizeGuestSiteBaseUrlFails('https://qr.example.invalid/qr?x=1');
        assertNormalizeGuestSiteBaseUrlFails('https://qr.example.invalid/qr#frag');
    }

    @IsTest
    static void getGuestSiteBaseUrlUsesTestOverride() {
        ConsentGuestAuthService.guestSiteBaseUrlOverrideForTests = 'https://qr.example.invalid/qr/';
        System.assertEquals(
            'https://qr.example.invalid/qr',
            ConsentGuestAuthService.getGuestSiteBaseUrl()
        );
        ConsentGuestAuthService.guestSiteBaseUrlOverrideForTests = null;
    }

    @IsTest
    static void nullInputsReturnSafeDefaults() {
        ConsentGuestAuthService.assignTokenIfMissing(null);
        System.assertEquals(null, ConsentGuestAuthService.getStoredToken(null));
        System.assertEquals(false, ConsentGuestAuthService.matchesStoredToken(null, 'token'));
    }

    @IsTest
    static void configuredGuestSiteBaseUrlResolversAreCallable() {
        String metadataBaseUrl = ConsentGuestAuthService.getGuestSiteBaseUrlFromCustomMetadata();

        System.assert(
            metadataBaseUrl == null || metadataBaseUrl.startsWith('https://'),
            'Configured metadata base URL should be blank or HTTPS.'
        );
    }

    private static void assertNormalizeGuestSiteBaseUrlFails(String configuredUrl) {
        try {
            ConsentGuestAuthService.normalizeGuestSiteBaseUrl(configuredUrl);
            System.assert(false, 'Expected invalid guest site URL to be rejected.');
        } catch (ConsentGuestAuthService.ConsentGuestAuthServiceException e) {
            System.assert(!String.isBlank(e.getMessage()));
        }
    }

    private static Consent_Request_Item__c reloadRequestItem(Id requestItemId) {
        return [
            SELECT Id, Data_Subject__c, Consent_Link_Expires_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItemId
        ];
    }

    private static Contact createContact() {
        String suffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'TokenTest',
            Email = 'token.test+' + suffix + '@example.com',
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'Token Test',
            ID_Number__c = 'S' + suffix.right(7),
            ID_Type__c = 'NRIC'
        );
        insert contact;
        return contact;
    }
}