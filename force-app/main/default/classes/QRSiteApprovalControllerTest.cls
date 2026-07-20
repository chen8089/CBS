@isTest
private class QRSiteApprovalControllerTest {
    @isTest
    static void scanAndApproveMarksRequestItemViewed() {
        Contact contact = createContact();
        Consent_Request_Item__c existingRequestItem = getOrCreateRequestItem(contact);
        existingRequestItem.Current_Status__c = 'Sent';
        existingRequestItem.Uploaded_Full_Name__c = contact.Full_Name__c;
        existingRequestItem.Uploaded_ID_Number__c = contact.ID_Number__c;
        existingRequestItem.Uploaded_Date_of_Birth__c = contact.Date_of_Birth__c;
        update existingRequestItem;
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, existingRequestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.scanAndApprove();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'Authentication completed successfully. Please continue the authorization form on your computer.',
            controller.resultMessage
        );

        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :contact.Id]);
        List<Consent__c> consents = [
            SELECT Data_Subject__c, Consent_Status__c, Action_Type__c, Submitted_At__c,
                MyInfo_Name__c, MyInfo_ID_Number__c, MyInfo_Date_of_Birth__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
        ];
        System.assertEquals(0, consents.size());

        List<Consent_Request_Item__c> requestItems = [
            SELECT Current_Status__c, Authorization_QR_Viewed_At__c, Data_Subject__c, Uploaded_Full_Name__c,
                Uploaded_ID_Number__c, Uploaded_Date_of_Birth__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :contact.Id
        ];
        System.assertNotEquals(0, requestItems.size());

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c, Authorization_QR_Viewed_At__c, Data_Subject__c, Uploaded_Full_Name__c,
                Uploaded_ID_Number__c, Uploaded_Date_of_Birth__c
            FROM Consent_Request_Item__c
            WHERE Id = :existingRequestItem.Id
        ];
        System.assertEquals('Sent', updatedRequestItem.Current_Status__c);
        System.assertNotEquals(null, updatedRequestItem.Authorization_QR_Viewed_At__c);
        System.assertEquals(contact.Full_Name__c, updatedRequestItem.Uploaded_Full_Name__c);
        System.assertEquals(contact.ID_Number__c, updatedRequestItem.Uploaded_ID_Number__c);
        System.assertEquals(contact.Date_of_Birth__c, updatedRequestItem.Uploaded_Date_of_Birth__c);
    }

    @isTest
    static void scanAndApproveResetsWithdrawnRequestItemForNewAttempt() {
        Contact contact = createContact();
        Consent_Request_Item__c existingRequestItem = getOrCreateRequestItem(contact);
        existingRequestItem.Current_Status__c = 'Withdrawn';
        existingRequestItem.Uploaded_Full_Name__c = contact.Full_Name__c;
        existingRequestItem.Uploaded_ID_Number__c = contact.ID_Number__c;
        existingRequestItem.Uploaded_Date_of_Birth__c = contact.Date_of_Birth__c;
        update existingRequestItem;
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, existingRequestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.scanAndApprove();
        Test.stopTest();

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c, Authorization_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :existingRequestItem.Id
        ];
        System.assertEquals('Withdrawn', updatedRequestItem.Current_Status__c);
        System.assertNotEquals(null, updatedRequestItem.Authorization_QR_Viewed_At__c);
    }

    @isTest
    static void scanAndApproveShowsErrorWhenRequestItemMissing() {
        Contact contact = createContact();
        delete [SELECT Id FROM Consent_Request_Item__c WHERE Data_Subject__c = :contact.Id];
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('requestItemId', 'a00INVALID000000');

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.scanAndApprove();
        Test.stopTest();

        System.assertEquals(true, controller.isFinished);
        System.assertEquals('Invalid link or missing request parameter. The operation failed.', controller.resultMessage);
        System.assertEquals(0, [SELECT COUNT() FROM Consent_Request_Item__c WHERE Data_Subject__c = :contact.Id]);
    }

    @isTest
    static void scanAndApproveDoesNotDuplicateActiveConsent() {
        Contact contact = createContact();
        insert new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, getOrCreateRequestItem(contact));

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.scanAndApprove();
        Test.stopTest();

        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'Authorization submitted successfully. The process is complete, and you may close this page.',
            controller.resultMessage
        );
        System.assertEquals(1, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :contact.Id]);
    }

    @isTest
    static void scanAndApproveShowsSubmittedMessageForSubmittedRequestItem() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.scanAndApprove();
        Test.stopTest();

        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'Authorization submitted successfully. The process is complete, and you may close this page.',
            controller.resultMessage
        );

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Submitted', updatedRequestItem.Current_Status__c);

    }

    @isTest
    static void checkStatusPCRedirectsToConsentFormForViewedRequestItem() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        update requestItem;
        Test.setCurrentPage(Page.QRSiteShowQrPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.checkStatusPC();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(requestItem.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
    }

    @isTest
    static void checkStatusPCRedirectsToCompletionForExistingActiveConsent() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        Consent__c consent = new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        insert consent;
        Test.setCurrentPage(Page.QRSiteShowQrPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.checkStatusPC();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals('true', result.getParameters().get('completed'));
    }

    @isTest
    static void consentFormPropertiesReadRequestItemValues() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        requestItem.Uploaded_Full_Name__c = 'Uploaded Name Should Not Display';
        requestItem.Uploaded_ID_Number__c = 'Uploaded ID Should Not Display';
        requestItem.Uploaded_Date_of_Birth__c = Date.newInstance(2001, 2, 3);
        update requestItem;
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        QRSiteApprovalController controller = new QRSiteApprovalController();

        System.assertEquals(contact.Full_Name__c, controller.getContactName());
        System.assertEquals('', controller.getNationality());
        System.assertEquals(contact.ID_Number__c, controller.getNricNumber());
        System.assertEquals('01', controller.getDobDay());
        System.assertEquals('January', controller.getDobMonth());
        System.assertEquals('1990', controller.getDobYear());
        System.assertEquals('', controller.getResidentialAddress());
        System.assertEquals(contact.Full_Name__c, controller.inputName);
        System.assertEquals(contact.ID_Number__c, controller.inputNric);
        System.assertEquals('01', controller.inputDobDay);
        System.assertEquals('January', controller.inputDobMonth);
        System.assertEquals('1990', controller.inputDobYear);
    }

    @isTest
    static void consentFormShowsCompletionMessageForCompletedParameter() {
        Contact contact = createContact();
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('completed', 'true');

        QRSiteApprovalController controller = new QRSiteApprovalController();

        System.assertEquals(false, controller.getShowConsentForm());
        System.assertEquals(true, controller.getShowCompletionMessage());
        System.assertEquals('Consent Submitted Successfully', controller.getCompletionMessageLine1());
        System.assertEquals(
            'The process is complete, and you may close this page.',
            controller.getCompletionMessageLine2()
        );
        System.assertEquals(2, controller.getCompletionMessageLines().size());
        System.assertEquals('', controller.getCompletionFooterText());
    }

    @isTest
    static void successPageSummaryLoadsFromRequestItemAndContact() {
        Contact contact = createContact();
        Account employerAccount = new Account(Name = 'ACME BANK');
        insert employerAccount;
        contact.AccountId = employerAccount.Id;
        contact.Current_Consent_Status__c = 'Authorized';
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Latest_Submission_Datetime__c')) {
            contact.put('Latest_Submission_Datetime__c', System.now());
        }
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Authentication_Type__c')) {
            contact.put('Authentication_Type__c', 'Non-Singpass');
        }
        update contact;

        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        if (Schema.SObjectType.Consent_Request_Item__c.fields.getMap().containsKey('Employer_Name__c')) {
            requestItem.put('Employer_Name__c', 'ABC Employer');
            update requestItem;
        }

        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('completed', 'true');
        ApexPages.currentPage().getParameters().put('completedMode', 'submitted');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);
        ApexPages.currentPage().getParameters().put('requestId', requestItem.Id);

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertEquals(true, controller.getShowSuccessSummary());
        System.assertEquals(false, controller.getIsActiveConsentPage());
        System.assertEquals('Authorized', controller.getConsentStatus());
        System.assertNotEquals('', controller.getSubmissionDateTime());
        System.assertNotEquals('', controller.getDataSubjectName());
        System.assertEquals(true, controller.getShowNonSingpassManualVerificationNote());
        System.assertEquals('ACME BANK', controller.getEmployerBankName());
        System.assertEquals('ACME BANK', controller.getSuccessBankName());
    }

    @isTest
    static void successPageShowsErrorForInvalidToken() {
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('completed', 'true');
        ApexPages.currentPage().getParameters().put('token', 'invalid-token');

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertEquals(false, controller.getShowSuccessSummary());
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void successBankNamePrefersBankNameParam() {
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('completed', 'true');
        ApexPages.currentPage().getParameters().put('bankName', 'Preferred Bank');
        ApexPages.currentPage().getParameters().put('employerName', 'Fallback Employer');

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertEquals('Preferred Bank', controller.getSuccessBankName());
    }

    @isTest
    static void successBankNameFallsBackToEmployerNameParam() {
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('completed', 'true');
        ApexPages.currentPage().getParameters().put('employerName', 'Fallback Employer');

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertEquals('Fallback Employer', controller.getSuccessBankName());
    }

    @isTest
    static void activeConsentPageShowsDuplicateWarningAndAccountName() {
        Contact contact = createContact();
        Account employerAccount = new Account(Name = 'Active Employer Account');
        insert employerAccount;
        contact.AccountId = employerAccount.Id;
        contact.Current_Consent_Status__c = 'Authorized';
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Latest_Submission_Datetime__c')) {
            contact.put('Latest_Submission_Datetime__c', System.now().addMinutes(-5));
        }
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Authentication_Type__c')) {
            contact.put('Authentication_Type__c', 'Non-Singpass');
        }
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Current_Consent_Expiry_Date__c')) {
            contact.put('Current_Consent_Expiry_Date__c', Date.today().addYears(1));
        }
        update contact;

        Test.setCurrentPage(Page.QRSiteConsentForm);
        ApexPages.currentPage().getParameters().put('completed', 'true');
        ApexPages.currentPage().getParameters().put('activeConsent', 'true');
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertEquals(true, controller.getShowSuccessSummary());
        System.assertEquals(true, controller.getIsActiveConsentPage());
        System.assertEquals('Active Consent Found', controller.getCompletionMessageLine1());
        System.assertEquals(3, controller.getCompletionMessageLines().size());
        System.assertEquals('Active Employer Account', controller.getEmployerBankName());
        System.assertEquals(true, controller.getShowDuplicateSubmissionWarning());
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Current_Consent_Expiry_Date__c')) {
            System.assertNotEquals('', controller.getConsentExpiryDate());
        }
    }

    @isTest
    static void submitFormRequiresConsentCheckbox() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        update requestItem;
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.submitForm();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(1, ApexPages.getMessages().size());
        System.assertEquals('Please select the consent checkbox before submitting.', ApexPages.getMessages()[0].getSummary());
    }

    @isTest
    static void submitFormCreatesConsentAndEndsFlowWhenConsented() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        requestItem.Uploaded_Full_Name__c = contact.Full_Name__c;
        requestItem.Uploaded_ID_Number__c = contact.ID_Number__c;
        requestItem.Uploaded_Date_of_Birth__c = contact.Date_of_Birth__c;
        update requestItem;
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.isConsented = true;
        controller.inputName = 'Edited Name';
        controller.inputNationality = 'Singaporean';
        controller.inputNric = 'S7654321A';
        controller.inputDobDay = '15';
        controller.inputDobMonth = 'February';
        controller.inputDobYear = '1991';
        controller.inputResidentialAddress = '456 Edited Address';
        PageReference result = controller.submitForm();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'Authorization submitted successfully. The process is complete, and you may close this page.',
            controller.resultMessage
        );
        System.assertEquals('Consent Submitted Successfully', controller.getCompletionMessageLine1());
        System.assertEquals(2, controller.getCompletionMessageLines().size());
        System.assertEquals('', controller.getCompletionFooterText());

        Consent__c createdConsent = [
            SELECT Id, Data_Subject__c, Consent_Status__c, Action_Type__c, MyInfo_Name__c,
                MyInfo_Nationality__c, MyInfo_ID_Number__c, MyInfo_Date_of_Birth__c,
                MyInfo_Residential_Address__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(contact.Id, createdConsent.Data_Subject__c);
        System.assertEquals('Active', createdConsent.Consent_Status__c);
        System.assertEquals('Consent Given', createdConsent.Action_Type__c);
        System.assertEquals('Edited Name', createdConsent.MyInfo_Name__c);
        System.assertEquals('Singaporean', createdConsent.MyInfo_Nationality__c);
        System.assertEquals('S7654321A', createdConsent.MyInfo_ID_Number__c);
        System.assertEquals(Date.newInstance(1991, 2, 15), createdConsent.MyInfo_Date_of_Birth__c);
        System.assertEquals('456 Edited Address', createdConsent.MyInfo_Residential_Address__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Submitted', updatedRequestItem.Current_Status__c);

        Contact authorizedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Authorized', authorizedContact.Current_Consent_Status__c);
        System.assertEquals('Active Consent', authorizedContact.Data_Subject_Lifecycle_Stage__c);
    }

    @isTest
    static void submitFormAcceptsNumericMonthInput() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        update requestItem;
        Test.setCurrentPage(Page.QRSiteConsentForm);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.isConsented = true;
        controller.inputName = 'Numeric Month';
        controller.inputNationality = 'SG';
        controller.inputNric = 'S1234567A';
        controller.inputDobDay = '15';
        controller.inputDobMonth = '2';
        controller.inputDobYear = '1991';
        controller.inputResidentialAddress = 'Numeric Month Address';
        controller.submitForm();
        Test.stopTest();

        Consent__c createdConsent = [
            SELECT MyInfo_Date_of_Birth__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(Date.newInstance(1991, 2, 15), createdConsent.MyInfo_Date_of_Birth__c);
    }

    @isTest
    static void withdrawalFormPropertiesReadConsentValues() {
        Contact contact = createContact();
        createActiveConsent(contact);
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        QRSiteApprovalController controller = new QRSiteApprovalController();

        System.assertEquals('Consent Name', controller.getContactName());
        System.assertEquals('Singaporean', controller.getNationality());
        System.assertEquals('S1111111A', controller.getNricNumber());
        System.assertEquals('02', controller.getDobDay());
        System.assertEquals('March', controller.getDobMonth());
        System.assertEquals('1992', controller.getDobYear());
        System.assertEquals('123 Consent Address', controller.getResidentialAddress());
    }

    @isTest
    static void submitWithdrawalRequiresCheckbox() {
        Contact contact = createContact();
        createActiveConsent(contact);
        update new Contact(Id = contact.Id, Current_Consent_Status__c = 'Authorized');
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.submitWithdrawal();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(1, ApexPages.getMessages().size());
        System.assertEquals('Please confirm your withdrawal before submitting.', ApexPages.getMessages()[0].getSummary());
    }

    @isTest
    static void submitWithdrawalUpdatesConsentAndEndsFlow() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        update new Contact(Id = contact.Id, Current_Consent_Status__c = 'Authorized');
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.hasConfirmedWithdrawal = true;
        PageReference result = controller.submitWithdrawal();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('true', result.getParameters().get('completed'));
        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'Withdrawal submitted successfully. The process is complete, and you may close this page.',
            controller.resultMessage
        );
        System.assertEquals('Withdrawal submitted successfully.', controller.getWithdrawalCompletionMessageLine1());
        System.assertEquals(1, controller.getWithdrawalCompletionMessageLines().size());
        System.assertEquals('', controller.getWithdrawalCompletionFooterText());

        Consent__c unchangedConsent = [
            SELECT Consent_Status__c, Action_Type__c, MyInfo_Name__c, MyInfo_Nationality__c,
                MyInfo_ID_Number__c, MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c
            FROM Consent__c
            WHERE Id = :consent.Id
        ];
        System.assertEquals('Active', unchangedConsent.Consent_Status__c);
        System.assertEquals('Consent Given', unchangedConsent.Action_Type__c);

        List<Consent__c> withdrawnConsents = [
            SELECT Data_Subject__c, Consent_Status__c, Action_Type__c, Revoked_At__c,
                Withdrawn_By_Client__c, MyInfo_Name__c, MyInfo_Nationality__c,
                MyInfo_ID_Number__c, MyInfo_Date_of_Birth__c, MyInfo_Residential_Address__c
            FROM Consent__c
            WHERE Data_Subject__c = :contact.Id
            AND Consent_Status__c = 'Withdrawn'
        ];
        System.assertEquals(1, withdrawnConsents.size());
        Consent__c withdrawnConsent = withdrawnConsents[0];
        System.assertEquals(contact.Id, withdrawnConsent.Data_Subject__c);
        System.assertEquals('Consent Withdrawn', withdrawnConsent.Action_Type__c);
        System.assertNotEquals(null, withdrawnConsent.Revoked_At__c);
        System.assertEquals(true, withdrawnConsent.Withdrawn_By_Client__c);
        System.assertEquals(unchangedConsent.MyInfo_Name__c, withdrawnConsent.MyInfo_Name__c);
        System.assertEquals(unchangedConsent.MyInfo_Nationality__c, withdrawnConsent.MyInfo_Nationality__c);
        System.assertEquals(unchangedConsent.MyInfo_ID_Number__c, withdrawnConsent.MyInfo_ID_Number__c);
        System.assertEquals(unchangedConsent.MyInfo_Date_of_Birth__c, withdrawnConsent.MyInfo_Date_of_Birth__c);
        System.assertEquals(unchangedConsent.MyInfo_Residential_Address__c, withdrawnConsent.MyInfo_Residential_Address__c);

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Withdrawn', updatedRequestItem.Current_Status__c);

        Contact withdrawnContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Withdrawn', withdrawnContact.Current_Consent_Status__c);
        System.assertEquals('Consent Withdrawn', withdrawnContact.Data_Subject_Lifecycle_Stage__c);
    }

    @isTest
    static void submitWithdrawalWithoutActiveConsentStillCompletesStatusUpdateFlow() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        update new Contact(Id = contact.Id, Current_Consent_Status__c = 'Authorized');
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        controller.hasConfirmedWithdrawal = true;
        PageReference result = controller.submitWithdrawal();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('true', result.getParameters().get('completed'));
        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'Withdrawal submitted successfully. The process is complete, and you may close this page.',
            controller.resultMessage
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :contact.Id AND Consent_Status__c = 'Withdrawn']
        );
    }

    @isTest
    static void withdrawalPageShowsMessageWhenNoActiveConsentForContact() {
        Contact contact = createContact();
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        QRSiteApprovalController controller = new QRSiteApprovalController();

        System.assertEquals(false, controller.getShowWithdrawalForm());
        System.assertEquals(true, controller.getShowWithdrawalCompletionMessage());
        System.assertEquals('No Active Consent Record Found', controller.getWithdrawalCompletionMessageLine1());
        System.assertEquals(
            'We are unable to find an active consent record associated with this request.',
            controller.getWithdrawalCompletionMessageLine2()
        );
        System.assertEquals(3, controller.getWithdrawalCompletionMessageLines().size());
        System.assertEquals('You may now close this page.', controller.getWithdrawalCompletionFooterText());
    }

    @isTest
    static void withdrawalPageInvalidContactIdShowsInvalidLinkMessage() {
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', '003000000000000AAA');

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertEquals(false, controller.getShowWithdrawalForm());
        System.assert(ApexPages.getMessages().size() > 0);
    }

    @isTest
    static void withdrawalPageShowsMessageWhenLatestConsentIsWithdrawn() {
        Contact contact = createContact();
        Consent__c activeConsent = createActiveConsent(contact);
        Test.setCreatedDate(activeConsent.Id, Datetime.now().addDays(-1));
        createWithdrawnConsent(activeConsent);
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        QRSiteApprovalController controller = new QRSiteApprovalController();

        System.assertEquals(false, controller.getShowWithdrawalForm());
        System.assertEquals(true, controller.getShowWithdrawalCompletionMessage());
        System.assertEquals('No Active Consent Record Found', controller.getWithdrawalCompletionMessageLine1());
    }

    @isTest
    static void withdrawQrPageShowsMessageWhenNoActiveConsentForContact() {
        Contact contact = createContact();
        Test.setCurrentPage(Page.QRSiteWithdrawQrPage);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        QRSiteApprovalController controller = new QRSiteApprovalController();

        System.assertEquals(false, controller.getShowWithdrawQrCode());
        System.assertEquals(true, controller.getShowWithdrawalCompletionMessage());
        System.assertEquals('No Active Consent Record Found', controller.getWithdrawalCompletionMessageLine1());
        System.assertEquals(3, controller.getWithdrawalCompletionMessageLines().size());
        System.assertEquals('You may now close this page.', controller.getWithdrawalCompletionFooterText());
    }

    @isTest
    static void goToWithdrawQrPageRedirectsWithoutWithdrawingConsent() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteWithdrawConsent);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('id', consent.Id);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToWithdrawQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(consent.Id, result.getParameters().get('id'));
        System.assertEquals(true, result.getRedirect());

        Consent__c unchangedConsent = [
            SELECT Consent_Status__c
            FROM Consent__c
            WHERE Id = :consent.Id
        ];
        System.assertEquals('Active', unchangedConsent.Consent_Status__c);
    }

    @isTest
    static void consentExtensionWithdrawConsentRedirectsToWithdrawQrPage() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteConsentDetail);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('id', consent.Id);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        ApexPages.StandardController standardController = new ApexPages.StandardController(consent);
        QRSiteConsentExtension extension = new QRSiteConsentExtension(standardController);

        Test.startTest();
        PageReference result = extension.withdrawConsent();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(consent.Id, result.getParameters().get('id'));
        System.assertEquals(true, result.getRedirect());

        Consent__c unchangedConsent = [
            SELECT Consent_Status__c
            FROM Consent__c
            WHERE Id = :consent.Id
        ];
        System.assertEquals('Active', unchangedConsent.Consent_Status__c);
    }

    @isTest
    static void scanAndConfirmWithdrawalMarksRequestItemViewed() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteWithdrawActionConfirmPage);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('id', consent.Id);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.scanAndConfirmWithdrawal();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'Authentication completed successfully. Please continue the withdrawal form on your computer.',
            controller.resultMessage
        );

        Consent_Request_Item__c updatedRequestItem = [
            SELECT Current_Status__c, Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Submitted', updatedRequestItem.Current_Status__c);
        System.assertNotEquals(null, updatedRequestItem.Withdrawal_QR_Viewed_At__c);
    }

    @isTest
    static void checkWithdrawStatusPCRedirectsToWithdrawalAfterQrViewed() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        requestItem.Withdrawal_QR_Viewed_At__c = System.now();
        update requestItem;
        Test.setCurrentPage(Page.QRSiteWithdrawQrPage);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('id', consent.Id);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.checkWithdrawStatusPC();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(consent.Id, result.getParameters().get('id'));
        System.assertEquals(true, result.getRedirect());

        Consent_Request_Item__c restoredRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Submitted', restoredRequestItem.Current_Status__c);
    }

    @isTest
    static void checkWithdrawStatusPCDoesNotRedirectBeforeScan() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteWithdrawQrPage);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('id', consent.Id);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.checkWithdrawStatusPC();
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void declinationPageShowsSuccessWhenNoActiveConsent() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteDeclinationComplete);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.recordDeclination();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(false, controller.getHasActiveConsentForDeclination());
        System.assertEquals('Consent Declined Successfully', controller.getDeclinationCompletionTitle());
        System.assertEquals(2, controller.getDeclinationCompletionMessageLines().size());
        System.assertEquals('You may now close this page.', controller.getDeclinationCompletionFooterText());
        System.assertEquals(0, [SELECT COUNT() FROM Consent__c WHERE Data_Subject__c = :contact.Id]);

        Contact declinedContact = [
            SELECT Current_Consent_Status__c, Data_Subject_Lifecycle_Stage__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Declined', declinedContact.Current_Consent_Status__c);
        System.assertEquals('Consent Declined', declinedContact.Data_Subject_Lifecycle_Stage__c);

        Consent_Request_Item__c declinedRequestItem = [
            SELECT Current_Status__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Declined', declinedRequestItem.Current_Status__c);
    }

    @isTest
    static void declinationPageBlocksDeclineWhenActiveConsentExists() {
        Contact contact = createContact();
        contact.Current_Consent_Status__c = 'Authorized';
        update contact;
        Consent__c consent = createActiveConsent(contact);
        Test.setCurrentPage(Page.QRSiteDeclinationComplete);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.recordDeclination();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.getHasActiveConsentForDeclination());
        System.assertEquals('Consent Already Submitted', controller.getDeclinationCompletionTitle());
        System.assertEquals(3, controller.getDeclinationCompletionMessageLines().size());

        Consent__c unchangedConsent = [
            SELECT Consent_Status__c
            FROM Consent__c
            WHERE Id = :consent.Id
        ];
        System.assertEquals('Active', unchangedConsent.Consent_Status__c);

        Contact unchangedContact = [
            SELECT Current_Consent_Status__c
            FROM Contact
            WHERE Id = :contact.Id
        ];
        System.assertEquals('Authorized', unchangedContact.Current_Consent_Status__c);
    }

    @isTest
    static void declinationPageDoesNotBlockWhenLatestConsentIsWithdrawn() {
        Contact contact = createContact();
        Consent__c activeConsent = createActiveConsent(contact);
        Test.setCreatedDate(activeConsent.Id, Datetime.now().addDays(-1));
        createWithdrawnConsent(activeConsent);
        Test.setCurrentPage(Page.QRSiteDeclinationComplete);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.recordDeclination();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(false, controller.getHasActiveConsentForDeclination());
        System.assertEquals('Consent Declined Successfully', controller.getDeclinationCompletionTitle());
    }

    @isTest
    static void goToQrPageRedirectsWithContactId() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(requestItem.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(true, result.getRedirect());
    }

    @isTest
    static void goToNextQrPageRoutesAuthorizeActionToAuthorizationQrPage() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(requestItem.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(true, controller.getIsAuthorizeAction());
        System.assertEquals(false, controller.getIsWithdrawAction());
        System.assertEquals(true, result.getRedirect());
    }

    @isTest
    static void goToNextQrPageRoutesWithdrawActionToWithdrawalQrPageByContactId() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(consent.Id, result.getParameters().get('id'));
        System.assertEquals(false, controller.getIsAuthorizeAction());
        System.assertEquals(true, controller.getIsWithdrawAction());
        System.assertEquals(true, result.getRedirect());
    }

    @isTest
    static void goToNextQrPageAcceptsFifteenCharacterContactIdForWithdrawAction() {
        Contact contact = createContact();
        Consent__c consent = createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Submitted';
        update requestItem;
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', String.valueOf(contact.Id).substring(0, 15));
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(consent.Id, result.getParameters().get('id'));
        System.assertEquals(true, result.getRedirect());
    }

    @isTest
    static void continueWithdrawalRoutesNonSingpassToWithdrawConsentWhenActive() {
        Contact contact = createContact();
        createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        Contact updateContact = new Contact(Id = contact.Id, Current_Consent_Status__c = 'Authorized');
        if (Schema.SObjectType.Contact.fields.getMap().containsKey('Authentication_Type__c')) {
            updateContact.put('Authentication_Type__c', 'Non-Singpass');
        }
        update updateContact;
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.continueWithdrawal();

        System.assertNotEquals(null, result);
        System.assertEquals(true, controller.getHasActiveConsent());
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(ConsentGuestAuthService.getStoredToken(requestItem), result.getParameters().get('token'));
        System.assertEquals('withdraw', result.getParameters().get('action'));
    }

    @isTest
    static void continueWithdrawalRoutesToNoActiveConsentPageWhenStatusNotActive() {
        Contact contact = createContact();
        createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        update new Contact(Id = contact.Id, Current_Consent_Status__c = 'Withdrawn');
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.continueWithdrawal();

        System.assertNotEquals(null, result);
        System.assertEquals(false, controller.getHasActiveConsent());
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(null, result.getParameters().get('id'));
    }

    @isTest
    static void handleImportantNotesEntryRedirectsWhenNoActiveConsent() {
        Contact contact = createContact();
        createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        update new Contact(Id = contact.Id, Current_Consent_Status__c = 'Expired');
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.handleImportantNotesEntry();

        System.assertNotEquals(null, result);
        System.assertEquals(false, controller.getHasActiveConsent());
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(ConsentGuestAuthService.getStoredToken(requestItem), result.getParameters().get('token'));
        System.assertEquals('withdraw', result.getParameters().get('action'));
        System.assertEquals(null, result.getParameters().get('id'));
    }

    @isTest
    static void handleImportantNotesEntryAllowsActiveConsentValidStatus() {
        Contact contact = createContact();
        createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        update new Contact(Id = contact.Id, Current_Consent_Status__c = 'Valid');
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.handleImportantNotesEntry();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.getHasActiveConsent());
    }

    @isTest
    static void importantNotesUsesWithdrawSpecificContent() {
        Contact contact = createContact();
        Account employer = new Account(Name = 'ABC Employer');
        insert employer;
        update new Contact(Id = contact.Id, AccountId = employer.Id, Current_Consent_Status__c = 'Authorized');
        createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);

        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');
        QRSiteApprovalController authorizeController = new QRSiteApprovalController();
        List<String> authorizeNotes = authorizeController.getImportantNotesList();

        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);
        QRSiteApprovalController withdrawController = new QRSiteApprovalController();
        List<String> withdrawNotes = withdrawController.getImportantNotesList();

        System.assertEquals('Important Notes', authorizeController.getImportantNotesTitle());
        System.assertEquals('Important Notes Before Withdrawing Consent', withdrawController.getImportantNotesTitle());
        System.assertNotEquals(authorizeNotes, withdrawNotes);
        System.assertEquals('Continue', withdrawController.getImportantNotesButtonMain());
        System.assertEquals('ABC Employer', withdrawController.getWithdrawEmployerBankName());
        System.assertEquals('Authorized', withdrawController.getWithdrawConsentStatus());
        System.assertEquals(true, withdrawController.getHasActiveConsent());
    }

    @isTest
    static void hasActiveConsentAllowsValidStatusCaseInsensitive() {
        Contact contact = createContact();
        createActiveConsent(contact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        update new Contact(Id = contact.Id, Current_Consent_Status__c = ' valid ');

        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertEquals(true, controller.getHasActiveConsent());
    }

    @isTest
    static void goToNextQrPageRequiresActionParameter() {
        Contact contact = createContact();
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(false, controller.getHasValidEntryAction());
        System.assertEquals(1, ApexPages.getMessages().size());
    }

    @isTest
    static void goToNextQrPageRoutesWithdrawWithoutActiveConsentToWithdrawalMessagePage() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(1, ApexPages.getMessages().size());
    }

    @isTest
    static void goToWithdrawQrPageBlocksMismatchedContactAndConsent() {
        Contact consentContact = createContact();
        Contact otherContact = createContact();
        Consent__c consent = createActiveConsent(consentContact);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(consentContact);
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', otherContact.Id);
        ApexPages.currentPage().getParameters().put('id', consent.Id);
        ApexPages.currentPage().getParameters().put('action', 'withdraw');
        ConsentTestSupport.applyGuestLinkParams(consentContact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(1, ApexPages.getMessages().size());
    }

    @isTest
    static void goToQrPageRedirectsToCompletionWhenActiveConsentExists() {
        Contact contact = createContact();
        createActiveConsent(contact);
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals('true', result.getParameters().get('completed'));
        System.assertEquals(true, result.getRedirect());
    }

    @isTest
    static void goToQrPageClearsStaleAuthorizationQrViewBeforeFreshQr() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Authorization_QR_Viewed_At__c = System.now();
        update requestItem;
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(requestItem.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(true, result.getRedirect());

        Consent_Request_Item__c refreshedRequestItem = [
            SELECT Authorization_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals(null, refreshedRequestItem.Authorization_QR_Viewed_At__c);
    }

    @isTest
    static void goToQrPageClearsDeclinedRequestItemQrViewsForReauthorization() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Declined';
        requestItem.Authorization_QR_Viewed_At__c = System.now().addDays(-1);
        requestItem.Withdrawal_QR_Viewed_At__c = System.now().addDays(-1);
        update requestItem;
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(requestItem.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(true, result.getRedirect());

        Consent_Request_Item__c resetRequestItem = [
            SELECT Current_Status__c, Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Declined', resetRequestItem.Current_Status__c);
        System.assertEquals(null, resetRequestItem.Authorization_QR_Viewed_At__c);
        System.assertNotEquals(null, resetRequestItem.Withdrawal_QR_Viewed_At__c);
    }

    @isTest
    static void goToQrPageClearsWithdrawnRequestItemQrViewsForReauthorization() {
        Contact contact = createContact();
        Consent__c activeConsent = createActiveConsent(contact);
        Test.setCreatedDate(activeConsent.Id, Datetime.now().addDays(-1));
        createWithdrawnConsent(activeConsent);
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        requestItem.Current_Status__c = 'Withdrawn';
        requestItem.Authorization_QR_Viewed_At__c = System.now().addDays(-1);
        requestItem.Withdrawal_QR_Viewed_At__c = System.now().addDays(-1);
        update requestItem;
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToNextQrPage();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(contact.Id, result.getParameters().get('ContactId'));
        System.assertEquals(requestItem.Id, result.getParameters().get('requestItemId'));
        System.assertEquals(true, result.getRedirect());

        Consent_Request_Item__c resetRequestItem = [
            SELECT Current_Status__c, Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c
            FROM Consent_Request_Item__c
            WHERE Id = :requestItem.Id
        ];
        System.assertEquals('Withdrawn', resetRequestItem.Current_Status__c);
        System.assertEquals(null, resetRequestItem.Authorization_QR_Viewed_At__c);
        System.assertNotEquals(null, resetRequestItem.Withdrawal_QR_Viewed_At__c);
    }

    @isTest
    static void goToQrPageShowsMessageForMissingContactId() {
        Test.setCurrentPage(Page.QRSiteImportantNotes);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.goToQrPage();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(1, ApexPages.getMessages().size());
    }

    @isTest
    static void scanAndApproveHandlesMissingContactId() {
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.scanAndApprove();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isFinished);
        System.assertEquals('Invalid link or missing request parameter. The operation failed.', controller.resultMessage);
    }

    @isTest
    static void checkStatusMobileShowsCompletedMessageForActiveConsent() {
        Contact contact = createContact();
        insert new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given'
        );
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.checkStatusMobile();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isFinished);
        System.assertEquals(
            'You have already completed the authorization. No further action is required.',
            controller.resultMessage
        );
    }

    @isTest
    static void checkStatusPCDoesNotRedirectForWithdrawnConsent() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        insert new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Withdrawn',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Withdrawn'
        );
        Test.setCurrentPage(Page.QRSiteShowQrPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.checkStatusPC();
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void checkStatusPCDoesNotRedirectForActiveThenWithdrawnConsent() {
        Contact contact = createContact();
        Consent_Request_Item__c requestItem = getOrCreateRequestItem(contact);
        Consent__c activeConsent = createActiveConsent(contact);
        Test.setCreatedDate(activeConsent.Id, Datetime.now().addDays(-1));
        createWithdrawnConsent(activeConsent);
        Test.setCurrentPage(Page.QRSiteShowQrPage);
        ConsentTestSupport.applyGuestLinkParams(contact.Id, requestItem);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.checkStatusPC();
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void rejectShowsDeclinedMessage() {
        Contact contact = createContact();
        Test.setCurrentPage(Page.QRSiteActionConfirmPage);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);

        Test.startTest();
        QRSiteApprovalController controller = new QRSiteApprovalController();
        PageReference result = controller.reject();
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals(true, controller.isFinished);
        System.assertEquals('You have declined the authorization. The process is complete.', controller.resultMessage);
    }

    @isTest
    static void staticUiTextGettersReturnExpectedContent() {
        Contact contact = createContact();
        Test.setCurrentPage(Page.QRSiteImportantNotes);
        ApexPages.currentPage().getParameters().put('ContactId', contact.Id);
        ApexPages.currentPage().getParameters().put('action', 'authorize');

        QRSiteApprovalController controller = new QRSiteApprovalController();
        System.assertNotEquals('', controller.getCurrentDateString());
        System.assertEquals('You may withdraw your consent in the future by using the withdrawal link provided in your email, where applicable.', controller.getWithdrawalGuidanceText());
        System.assertEquals('Please do not submit another consent form using this link.', controller.getDuplicateSubmissionText());
        System.assertEquals('A confirmation email will be sent to you for your records.', controller.getConfirmationEmailText());
        System.assertEquals('If you have any questions, please contact your HR representative or CBS support.', controller.getHelpText());
        System.assertEquals('You are about to withdraw your consent and authorisation previously given to Credit Bureau (Singapore) Pte Ltd ("CBS").', controller.getWithdrawIntroText());
        System.assertEquals('Please read the following notes carefully before continuing.', controller.getWithdrawIntroSubText());
        System.assertEquals('If you are unsure why you received this link, please contact your HR representative before continuing.', controller.getWithdrawHrReminder());
    }

    private static Contact createContact() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Contact contact = new Contact(
            LastName = 'QRSite Test',
            Email = 'qrsite.test+' + uniqueSuffix + '@example.com',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Employment_Status__c = 'Existing Hire',
            Full_Name__c = 'QRSite Test',
            ID_Number__c = 'S' + uniqueSuffix.right(7),
            ID_Type__c = 'NRIC',
            Portal_Role__c = 'Approver'
        );
        insert contact;
        return contact;
    }

    private static Consent_Request_Item__c getOrCreateRequestItem(Contact contact) {
        List<Consent_Request_Item__c> requestItems = [
            SELECT Id, Current_Status__c, Authorization_QR_Viewed_At__c, Withdrawal_QR_Viewed_At__c,
                Data_Subject__c, Uploaded_Full_Name__c,
                Uploaded_ID_Number__c, Uploaded_Date_of_Birth__c
            FROM Consent_Request_Item__c
            WHERE Data_Subject__c = :contact.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (requestItems.size() > 0) {
            return requestItems[0];
        }

        return ConsentTestSupport.createRequestItem(contact);
    }

    private static Consent__c createActiveConsent(Contact contact) {
        Consent__c consent = new Consent__c(
            Data_Subject__c = contact.Id,
            Consent_Status__c = 'Active',
            Submitted_At__c = System.now(),
            Action_Type__c = 'Consent Given',
            MyInfo_Name__c = 'Consent Name',
            MyInfo_Nationality__c = 'Singaporean',
            MyInfo_ID_Number__c = 'S1111111A',
            MyInfo_Date_of_Birth__c = Date.newInstance(1992, 3, 2),
            MyInfo_Residential_Address__c = '123 Consent Address'
        );
        insert consent;
        return consent;
    }

    private static Consent__c createWithdrawnConsent(Consent__c activeConsent) {
        Consent__c consent = new Consent__c(
            Data_Subject__c = activeConsent.Data_Subject__c,
            Consent_Status__c = 'Withdrawn',
            Revoked_At__c = System.now(),
            Action_Type__c = 'Consent Withdrawn',
            Withdrawn_By_Client__c = true,
            MyInfo_Name__c = activeConsent.MyInfo_Name__c,
            MyInfo_Nationality__c = activeConsent.MyInfo_Nationality__c,
            MyInfo_ID_Number__c = activeConsent.MyInfo_ID_Number__c,
            MyInfo_Date_of_Birth__c = activeConsent.MyInfo_Date_of_Birth__c,
            MyInfo_Residential_Address__c = activeConsent.MyInfo_Residential_Address__c
        );
        insert consent;
        return consent;
    }
}