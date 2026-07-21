# Drift Owner Decision Record - 2026-07-21

- FlowDefinition: confirmed; adopt Sandbox active version 6 through A-IMP-02 baseline reconciliation.
- Contact Layout: confirmed; adopt Sandbox state for Employment_Status__c, Full_Name__c, ID_Number__c and ID_Type__c through A-IMP-02.
- CBS Processing Queue: confirmed; retain the active user assignment required for CBS Case routing as environment runtime configuration.
- Profile FLS: review completed. All four fields are readable/editable on all 26 Profiles; exact Security/A-IMP-08 policy approval remains pending.
- PartnerCommunity2.site: confirmed unrelated to A-IMP-03 and excluded from its Manifest.

Phase 1 only: no metadata source change, DML, deployment or activation was performed.

## Profile FLS policy decision

The selected policy is to keep the current Sandbox readable/editable FLS for Employment_Status__c, Full_Name__c, ID_Number__c and ID_Type__c across all 26 Profiles. The broader external/restricted-profile exposure is explicitly recorded. A named Security owner and controlled A-IMP-08 baseline reconciliation remain required.
