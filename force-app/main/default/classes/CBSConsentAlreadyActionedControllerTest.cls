@isTest
private class CBSConsentAlreadyActionedControllerTest {
  @isTest
  static void initShowsDeclinedStatusWithRequestDetails() {
    Contact contactRecord = createContactWithEmployer('Declined');
    Consent__c consentRecord = createConsent(contactRecord, 'Declined');
    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Declined', 'already-actioned-token-a');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'already-actioned-token-a');
    ApexPages.currentPage().getParameters().put('action', 'decline');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    PageReference result = controller.init();

    System.assertEquals(null, result);
    System.assertEquals(true, controller.hasRecord);
    System.assertEquals(true, controller.showPage);
    System.assertEquals(true, controller.showActionedContent);
    System.assertEquals('Consent Request Already Actioned', controller.pageTitle);
    System.assert(controller.openingMessage.contains('decline request'));
    System.assert(controller.currentConsentStatusLine.contains('Declined'));
    System.assertEquals('This may be because:', controller.reasonIntroText);
    System.assertEquals(3, controller.getReasonBullets().size());
    System.assertEquals('What this means', controller.whatThisMeansTitle);
    System.assertEquals(3, controller.getWhatThisMeansItems().size());
    System.assert(controller.getWhatThisMeansItems()[0].contains('Privacy@creditbureau.com.sg'));
    System.assert(controller.contactHrPrefix.contains('Sample Bank Pte Ltd Human Resources'));
    System.assertEquals('hr.support@samplebank.example', controller.getHrSupportEmailDisplay());
    System.assertEquals(true, controller.getShowHrEmailLink());
    System.assertEquals('Declined', controller.currentStatus);
    System.assertEquals(requestItem.Name, controller.referenceId);
  }

  @isTest
  static void initShowsWithdrawnStatusMessage() {
    Contact contactRecord = createContactWithEmployer('Withdrawn');
    Consent__c consentRecord = createConsent(contactRecord, 'Withdrawn');
    consentRecord.Revoked_At__c = System.now().addDays(-1);
    update consentRecord;

    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Withdrawn', 'already-actioned-token-b');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'already-actioned-token-b');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(true, controller.showActionedContent);
    System.assert(controller.getWhatThisMeansItems()[1].contains('Withdrawn'));
    System.assert(!String.isBlank(controller.lastActionDateTimeText));
  }

  @isTest
  static void initShowsValidStatusMessage() {
    Contact contactRecord = createContactWithEmployer('Authorized');
    Consent__c consentRecord = createConsent(contactRecord, 'Valid');
    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Submitted', 'already-actioned-token-c');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'already-actioned-token-c');
    ApexPages.currentPage().getParameters().put('action', 'consent');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(true, controller.showActionedContent);
    System.assert(controller.openingMessage.contains('consent request'));
    System.assertEquals('Valid', controller.currentStatus);
    System.assert(controller.getWhatThisMeansItems()[0].contains('Privacy@creditbureau.com.sg'));
  }

  @isTest
  static void initShowsExpiredStatusMessage() {
    Contact contactRecord = createContactWithEmployer('Expired');
    contactRecord.Current_Consent_Expiry_Date__c = Date.today().addDays(-2);
    update contactRecord;

    Consent__c consentRecord = createConsent(contactRecord, 'Expired');
    consentRecord.Consent_Expiry_Date__c = Date.today().addDays(-2);
    update consentRecord;

    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Expired', 'already-actioned-token-d');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    setBaseParams(contactRecord.Id, consentRecord.Id, requestItem.Id, 'already-actioned-token-d');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(true, controller.showActionedContent);
    System.assert(controller.statusMessage.contains('no longer active'));
    System.assert(!String.isBlank(controller.lastActionDateTimeText));
  }

  @isTest
  static void initShowsConsumedStatusMessage() {
    Contact contactRecord = createContactWithEmployer('Authorized');
    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Consumed', 'already-actioned-token-e');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    setBaseParams(contactRecord.Id, null, requestItem.Id, 'already-actioned-token-e');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(true, controller.showActionedContent);
    System.assert(controller.statusMessage.contains('cannot be reused'));
  }

  @isTest
  static void initShowsFullPageWhenTokenMissingButIdsMatch() {
    Contact contactRecord = createContactWithEmployer('Withdrawn');
    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Withdrawn', 'already-actioned-token-no-url');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    ApexPages.currentPage().getParameters().put('contactId', contactRecord.Id);
    ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
    ApexPages.currentPage().getParameters().put('action', 'decline');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(true, controller.showActionedContent);
    System.assertEquals('Consent Request Already Actioned', controller.pageTitle);
    System.assertEquals(3, controller.getWhatThisMeansItems().size());
  }

  @isTest
  static void initShowsNotAvailableWhenContactIdDoesNotMatchRequestItem() {
    Contact contactRecord = createContactWithEmployer('Declined');
    Contact otherContact = createContactWithEmployer('Declined');
    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Declined', 'already-actioned-token-mismatch');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    ApexPages.currentPage().getParameters().put('contactId', otherContact.Id);
    ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
    ApexPages.currentPage().getParameters().put('action', 'decline');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(false, controller.showActionedContent);
    System.assertEquals('Consent Request Not Available', controller.pageTitle);
  }

  @isTest
  static void initShowsNotAvailableWhenTokenInvalid() {
    Map<String, Schema.SObjectField> itemFields = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
    Boolean hasTokenField =
      itemFields.containsKey('Token__c')
      || itemFields.containsKey('Secure_Token__c')
      || itemFields.containsKey('Access_Token__c');
    if (!hasTokenField) {
      return;
    }

    Contact contactRecord = createContactWithEmployer('Declined');
    createConsent(contactRecord, 'Declined');
    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Declined', 'already-actioned-token-f');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    ApexPages.currentPage().getParameters().put('contactId', contactRecord.Id);
    ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
    ApexPages.currentPage().getParameters().put('token', 'wrong-token');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(false, controller.hasRecord);
    System.assertEquals(false, controller.showActionedContent);
    System.assertEquals(true, controller.showPage);
    System.assertEquals('Consent Request Not Available', controller.pageTitle);
    System.assert(controller.mainMessage.contains('could not be found'));
  }

  @isTest
  static void initHandlesMissingParametersWithoutException() {
    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    PageReference result = controller.init();

    System.assertEquals(null, result);
    System.assertEquals(false, controller.hasRecord);
    System.assertEquals(true, controller.showPage);
    System.assertEquals('Consent Request Not Available', controller.pageTitle);
  }

  @isTest
  static void initLoadsByConsentIdOnly() {
    Contact contactRecord = createContactWithEmployer('Declined');
    Consent__c consentRecord = createConsent(contactRecord, 'Declined');
    Consent_Request_Item__c requestItem = createRequestItem(contactRecord, 'Declined', 'already-actioned-token-g');

    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    ApexPages.currentPage().getParameters().put('consentId', consentRecord.Id);
    ApexPages.currentPage().getParameters().put('requestItemId', requestItem.Id);
    ApexPages.currentPage().getParameters().put('token', 'already-actioned-token-g');

    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();
    controller.init();

    System.assertEquals(true, controller.hasRecord);
    System.assertEquals('Declined', controller.currentStatus);
    System.assertEquals(requestItem.Name, controller.referenceId);
  }

  @isTest
  static void closeButtonAndReturnUrlDefaults() {
    Test.setCurrentPage(Page.CBSConsentAlreadyActionedPage);
    CBSConsentAlreadyActionedController controller = new CBSConsentAlreadyActionedController();

    System.assertEquals('https://www.creditbureau.com.sg', controller.getReturnUrl());
    System.assertEquals('Close This Page', controller.getCloseButtonLabel());
  }

  private static void setBaseParams(Id contactId, Id consentId, Id requestItemId, String tokenValue) {
    ApexPages.currentPage().getParameters().put('contactId', contactId);
    if (consentId != null) {
      ApexPages.currentPage().getParameters().put('consentId', consentId);
      ApexPages.currentPage().getParameters().put('id', consentId);
    }
    if (requestItemId != null) {
      ApexPages.currentPage().getParameters().put('requestItemId', requestItemId);
    }
    ApexPages.currentPage().getParameters().put('token', tokenValue);
  }

  private static Contact createContactWithEmployer(String consentStatus) {
    Account employer = new Account(
      Name = 'Sample Bank Pte Ltd',
      Notification_Email__c = 'hr.support@samplebank.example'
    );
    insert employer;

    String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    Contact contactRecord = new Contact(
      LastName = 'Already Actioned Subject',
      Email = 'already.actioned+' + uniqueSuffix + '@example.com',
      AccountId = employer.Id,
      Date_of_Birth__c = Date.newInstance(1990, 1, 1),
      Full_Name__c = 'Already Actioned Test Subject',
      ID_Number__c = 'S' + uniqueSuffix.right(7),
      ID_Type__c = 'NRIC',
      Portal_Role__c = 'Approver',
      Employment_Status__c = 'Existing Hire',
      Current_Consent_Status__c = consentStatus
    );
    insert contactRecord;
    return contactRecord;
  }

  private static Consent__c createConsent(Contact contactRecord, String status) {
    Consent__c consentRecord = new Consent__c(
      Data_Subject__c = contactRecord.Id,
      Consent_Status__c = status,
      Submitted_At__c = System.now().addDays(-3)
    );
    insert consentRecord;
    return consentRecord;
  }

  private static Consent_Request_Item__c createRequestItem(Contact contactRecord, String status, String tokenValue) {
    Consent_Request_Item__c requestItem = new Consent_Request_Item__c(
      Data_Subject__c = contactRecord.Id,
      Current_Status__c = status,
      Consent_Link_Expires_At__c = System.now().addDays(7)
    );
    Map<String, Schema.SObjectField> itemFields = Consent_Request_Item__c.SObjectType.getDescribe().fields.getMap();
    if (itemFields.containsKey('Token__c')) {
      requestItem.put('Token__c', tokenValue);
    } else if (itemFields.containsKey('Secure_Token__c')) {
      requestItem.put('Secure_Token__c', tokenValue);
    } else if (itemFields.containsKey('Access_Token__c')) {
      requestItem.put('Access_Token__c', tokenValue);
    }
    insert requestItem;
    return [
      SELECT Id, Name, Data_Subject__c, Current_Status__c
      FROM Consent_Request_Item__c
      WHERE Id = :requestItem.Id
      LIMIT 1
    ];
  }
}