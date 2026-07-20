@isTest
private class ConsentQrAuthenticationServiceTest {
    @isTest
    static void markAuthorizationQrViewedByRequestItemUpdatesFields() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        requestItem.Withdrawal_QR_Viewed_At__c = System.now();
        update requestItem;

        ConsentQrAuthenticationService.markAuthorizationQrViewedByRequestItem(requestItem.Id);

        Consent_Request_Item__c updated = [
            SELECT Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertNotEquals(null, updated.Authorization_QR_Viewed_At__c);
        System.assertEquals(null, updated.Withdrawal_QR_Viewed_At__c);
    }

    @isTest
    static void markWithdrawalQrViewedByRequestItemUpdatesField() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);

        ConsentQrAuthenticationService.markWithdrawalQrViewedByRequestItem(requestItem.Id);

        Consent_Request_Item__c updated = [
            SELECT Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertNotEquals(null, updated.Withdrawal_QR_Viewed_At__c);
    }

    @isTest
    static void evaluateAuthorizationScanReturnsExpectedOutcomes() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        Consent__c activeConsent = new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        insert activeConsent;

        ConsentQrAuthenticationService.AuthorizationScanOutcome activeOutcome =
            ConsentQrAuthenticationService.evaluateAuthorizationScan(requestItem, activeConsent);
        System.assertEquals(true, activeOutcome.isFinished);
        System.assertEquals(false, activeOutcome.shouldMarkAuthorizationQrViewed);

        requestItem.Current_Status__c = 'Submitted';
        ConsentQrAuthenticationService.AuthorizationScanOutcome submittedOutcome =
            ConsentQrAuthenticationService.evaluateAuthorizationScan(requestItem, null);
        System.assertEquals(true, submittedOutcome.isFinished);
        System.assertEquals(false, submittedOutcome.shouldMarkAuthorizationQrViewed);

        requestItem.Current_Status__c = 'Sent';
        ConsentQrAuthenticationService.AuthorizationScanOutcome scanOutcome =
            ConsentQrAuthenticationService.evaluateAuthorizationScan(requestItem, null);
        System.assertEquals(true, scanOutcome.isFinished);
        System.assertEquals(true, scanOutcome.shouldMarkAuthorizationQrViewed);
    }

    @isTest
    static void entryStatusHelpersReturnExpectedValues() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = ConsentTestSupport.createRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        requestItem.Withdrawal_QR_Viewed_At__c = System.now();
        update requestItem;

        Consent__c activeConsent = new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        insert activeConsent;

        System.assertEquals(true, ConsentQrAuthenticationService.hasActiveConsent(activeConsent));
        System.assertEquals(true, ConsentQrAuthenticationService.shouldRedirectToAuthorizationForm(requestItem));
        System.assertEquals(
            true,
            ConsentQrAuthenticationService.shouldRedirectToWithdrawalForm(activeConsent, requestItem, true)
        );

        requestItem.Current_Status__c = 'Submitted';
        System.assertEquals(false, ConsentQrAuthenticationService.shouldRedirectToAuthorizationForm(requestItem));
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'QR Auth Test',
            Email = 'qr.auth+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'QR Auth Test',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver'
        );
        insert contact;
        return contact;
    }
}