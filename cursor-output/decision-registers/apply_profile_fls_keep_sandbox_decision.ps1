param()

$ErrorActionPreference = "Stop"
$matrixPath = Join-Path $PSScriptRoot "15_contact_identity_profile_fls_review.csv"
$matrixSummaryPath = Join-Path $PSScriptRoot "15_contact_identity_profile_fls_review_summary.md"
$driftRegisterPath = Join-Path $PSScriptRoot "14_r11_r12_drift_disposition_register.csv"
$driftSummaryPath = Join-Path $PSScriptRoot "14_r11_r12_drift_disposition_summary.md"
$decisionRecordPath = Join-Path $PSScriptRoot "16_drift_owner_decisions_2026-07-21.md"

$matrix = @(Import-Csv -LiteralPath $matrixPath -Encoding UTF8)
foreach ($row in $matrix) {
    $row.Security_Owner_Decision = "KEEP_SANDBOX_READABLE_EDITABLE_FLS"
    $row.Metadata_Change_Authorised = "NO - PHASE 1"
}
$matrix | Export-Csv -LiteralPath $matrixPath -NoTypeInformation -Encoding UTF8

$drift = @(Import-Csv -LiteralPath $driftRegisterPath -Encoding UTF8)
foreach ($row in $drift) {
    if ($row.Relative_Path -match "^profiles/") {
        $row.Disposition = "DECIDED - ADOPT SANDBOX READABLE/EDITABLE FLS"
        $row.Required_Action = "A-IMP-08 controlled baseline reconciliation preserving editable FLS for all 26 Profiles; record accepted external/restricted-profile risk."
        $row.Owner_Signoff = "DECISION CONFIRMED 2026-07-21; NAMED SECURITY OWNER RECORD PENDING"
    }
}
$drift | Export-Csv -LiteralPath $driftRegisterPath -NoTypeInformation -Encoding UTF8

$matrixSummary = @"
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
"@
Set-Content -LiteralPath $matrixSummaryPath -Value $matrixSummary -Encoding UTF8

$driftSummary = @"
# R11-R12 Drift Disposition Summary

- Original byte-level differences: 61
- Expected retrieve noise: 26
- Expected A-IMP-02 baseline-ahead paths: 5
- Decisions recorded: FlowDefinition, Contact layout, queue membership, all 26 Profile FLS paths and Site.com scope
- Metadata source changes authorised in Phase 1: none

## Confirmed decisions

1. Adopt Sandbox FlowDefinition active version 6 through A-IMP-02.
2. Adopt the Sandbox Contact layout state through A-IMP-02.
3. Retain the active ChenTest CBS Case queue user assignment as environment runtime configuration.
4. Preserve readable/editable FLS for the four Contact identity fields across all 26 Sandbox Profiles; external/restricted-profile exposure is explicitly accepted.
5. Exclude PartnerCommunity2.site because it is unrelated to A-IMP-03.

## Remaining implementation gates

A-IMP-02 must reconcile FlowDefinition and Contact layout; A-IMP-08 must reconcile the 26 Profile baselines and record the named Security owner. A-IMP-03 must then rebase and rerun R11/R12.

No decision authorises deployment, DML, activation or copying live-org metadata directly into A-IMP-03.
"@
Set-Content -LiteralPath $driftSummaryPath -Value $driftSummary -Encoding UTF8

Add-Content -LiteralPath $decisionRecordPath -Value @"

## Profile FLS policy decision

The selected policy is to keep the current Sandbox readable/editable FLS for Employment_Status__c, Full_Name__c, ID_Number__c and ID_Type__c across all 26 Profiles. The broader external/restricted-profile exposure is explicitly recorded. A named Security owner and controlled A-IMP-08 baseline reconciliation remain required.
"@ -Encoding UTF8

Write-Output "PROFILE_FLS_POLICY_RECORDED"
Write-Output "POLICY=KEEP_SANDBOX_READABLE_EDITABLE"
Write-Output "PROFILES=26"
Write-Output "PHASE1_METADATA_CHANGES=0"
