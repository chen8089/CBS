/**
 * Shared filter payload for dashboard LWCs (serialized from JavaScript).
 */
public class DashboardFilter {
    @AuraEnabled
    public String ownership { get; set; }
    @AuraEnabled
    public String recordType { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public String lifecycleStage { get; set; }
    @AuraEnabled
    public String authenticationType { get; set; }
    @AuraEnabled
    public String consentType { get; set; }
    @AuraEnabled
    public String dateType { get; set; }
    @AuraEnabled
    public String dateRange { get; set; }
    @AuraEnabled
    public Date startDate { get; set; }
    @AuraEnabled
    public Date endDate { get; set; }
}