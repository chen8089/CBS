# Contact Identity Profile FLS Review

- Profiles reviewed: 26
- Profiles with all four fields readable/editable: 26
- Critical external/restricted profiles: 16
- Selected policy: keep current Sandbox readable/editable FLS on all 26 Profiles
- Metadata changes authorised in Phase 1: none

## Explicitly accepted exposure

Employment_Status__c, Full_Name__c, ID_Number__c and ID_Type__c remain editable at Profile FLS level for Admin plus external, guest, community, partner, read-only, integration/API and other Profiles represented in the matrix.

Field FLS alone does not grant object access, but any user assigned a listed Profile with effective Contact edit permission can edit these fields. This is broader than the least-privilege recommendation and is recorded as an explicit policy/risk decision.

## Required follow-up

A-IMP-08/Security must reconcile the controlled baseline to the approved Sandbox state and record the named owner. No A-IMP-03 Profile metadata change is authorised.
