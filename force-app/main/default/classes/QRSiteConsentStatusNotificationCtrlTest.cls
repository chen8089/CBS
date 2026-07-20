@IsTest
private class QRSiteConsentStatusNotificationCtrlTest {
    private static Contact createContactWithAccount() {
        Account accountRec = new Account(Name = 'Status Notification Bank');
        insert accountRec;

        Contact contactRec = new Contact(
            LastName = 'Status Notification',
            AccountId = accountRec.Id,
            Email = 'status.notification+' + String.valueOf(System.now().getTime()) + '@example.com',
            Current_Consent_Status__c = 'Authorized'
        );

        Map<String, Schema.SObjectField> fields = Contact.SObjectType.getDescribe().fields.getMap();
        if (fields.containsKey('Full_Name__c')) {
            contactRec.put('Full_Name__c', 'Status Notification User');
        }
        if (fields.containsKey('Date_of_Birth__c')) {
            contactRec.put('Date_of_Birth__c', Date.newInstance(1990, 1, 1));
        }
        if (fields.containsKey('Employment_Status__c')) {
            contactRec.put('Employment_Status__c', 'Existing Hire');
        }
        if (fields.containsKey('ID_Type__c')) {
            contactRec.put('ID_Type__c', 'NRIC');
        }
        if (fields.containsKey('ID_Number__c')) {
            contactRec.put('ID_Number__c', 'S1234567A');
        }
        if (fields.containsKey('Portal_Role__c')) {
            contactRec.put('Portal_Role__c', 'Approver');
        }
        if (fields.containsKey('Latest_Submission_Datetime__c')) {
            contactRec.put('Latest_Submission_Datetime__c', System.now());
        }
        if (fields.containsKey('Current_Consent_Expiry_Date__c')) {
            contactRec.put('Current_Consent_Expiry_Date__c', Date.today().addYears(1));
        }

        insert contactRec;
        return contactRec;
    }

    @IsTest
    static void initMethodsShowPageAndLoadSummary() {
        Contact contactRec = createContactWithAccount();

        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('contactId', String.valueOf(contactRec.Id));
        ApexPages.currentPage().getParameters().put('requestItemId', 'a01123456789012AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-001');

        QRSiteConsentStatusNotificationCtrl ctrl = new QRSiteConsentStatusNotificationCtrl();

        PageReference result = ctrl.initActiveConsent();
        System.assertEquals(null, result);
        System.assertEquals(true, ctrl.showPage);
        System.assertEquals(true, ctrl.showSummary);
        System.assertEquals('Active Consent Found', ctrl.pageTitle);
        System.assertNotEquals(null, ctrl.getMessageLines());
        System.assertEquals('Status Notification Bank', ctrl.employerBankName);
        System.assert(!String.isBlank(ctrl.dataSubjectName));
        System.assert(!String.isBlank(ctrl.consentStatus));
    }

    @IsTest
    static void initMethodsHandleNonSummaryStatesAndBadIds() {
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('ContactId', 'not-a-valid-id');
        ApexPages.currentPage().getParameters().put('consentRequestItemId', 'a01123456789012AAA');
        ApexPages.currentPage().getParameters().put('token', 'token-002');

        QRSiteConsentStatusNotificationCtrl ctrl = new QRSiteConsentStatusNotificationCtrl();

        ctrl.initInvalidLink();
        System.assertEquals(true, ctrl.showPage);
        System.assertEquals(false, ctrl.showSummary);
        System.assertEquals('Invalid Link', ctrl.pageTitle);

        ctrl.initLinkExpired();
        System.assertEquals('Link Expired', ctrl.pageTitle);
        System.assertEquals(false, ctrl.showSummary);

        ctrl.initAlreadyActioned();
        System.assertEquals('Consent Request Already Actioned', ctrl.pageTitle);
        System.assertEquals(true, ctrl.showSummary);
    }
}