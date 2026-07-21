param()

$ErrorActionPreference = "Stop"
$registerPath = Join-Path $PSScriptRoot "14_r11_r12_drift_disposition_register.csv"
$summaryPath = Join-Path $PSScriptRoot "14_r11_r12_drift_disposition_summary.md"
$decisionRecordPath = Join-Path $PSScriptRoot "16_drift_owner_decisions_2026-07-21.md"
$rows = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)

foreach ($row in $rows) {
    if ($row.Relative_Path -eq "flowDefinitions/contactApproveCreateConsentRequest.flowDefinition-meta.xml") {
        $row.Disposition = "DECIDED - ADOPT SANDBOX ACTIVE VERSION 6"
        $row.Required_Action = "A-IMP-02 controlled baseline reconciliation to version 6, followed by A-IMP-03 rebase and R11/R12 rerun."
        $row.Owner_Signoff = "DECISION CONFIRMED 2026-07-21; NAMED A-IMP-02 OWNER RECORD PENDING"
    } elseif ($row.Relative_Path -eq "layouts/Contact-Contact Layout.layout-meta.xml") {
        $row.Disposition = "DECIDED - ADOPT SANDBOX LAYOUT STATE"
        $row.Required_Action = "A-IMP-02 controlled as-built update removing the four identity fields from the shared layout/mini-layout; A-IMP-03 must not edit it directly."
        $row.Owner_Signoff = "DECISION CONFIRMED 2026-07-21; NAMED A-IMP-02 OWNER RECORD PENDING"
    } elseif ($row.Relative_Path -eq "queues/CBS_Processing_Queue.queue-meta.xml") {
        $row.Disposition = "DECIDED - RETAIN ACTIVE USER QUEUE MEMBERSHIP"
        $row.Required_Action = "Preserve the current ChenTest CBS Case queue assignment as environment runtime configuration; do not generalise the username across environments."
        $row.Owner_Signoff = "DECISION CONFIRMED 2026-07-21; OPERATIONS OWNER RECORD PENDING"
    } elseif ($row.Relative_Path -match "^profiles/") {
        $row.Disposition = "FLS REVIEW COMPLETE - SECURITY POLICY APPROVAL PENDING"
        $row.Evidence = "All 26 Profiles expose Employment_Status__c, Full_Name__c, ID_Number__c and ID_Type__c as readable/editable; 16 are external/restricted critical profiles."
        $row.Required_Action = "Approve Admin-only direct editable FLS and use narrowly scoped Permission Sets for any internal exception; remove broad Profile editable access."
        $row.Owner_Signoff = "PENDING SECURITY/A-IMP-08"
    } elseif ($row.Relative_Path -eq "siteDotComSites/PartnerCommunity2.site") {
        $row.Disposition = "CLOSED - CONFIRMED OUT OF A-IMP-03 SCOPE"
        $row.Required_Action = "Exclude from the A-IMP-03 Manifest; no semantic Site.com comparison required for this workstream."
        $row.Owner_Signoff = "CONFIRMED 2026-07-21"
    }
}

$rows | Export-Csv -LiteralPath $registerPath -NoTypeInformation -Encoding UTF8

$summary = @"
# R11-R12 Drift Disposition Summary

- Original byte-level differences: 61
- Expected retrieve noise: 26
- Expected A-IMP-02 baseline-ahead paths: 5
- Confirmed decisions recorded on 2026-07-21: FlowDefinition, Contact layout, queue membership and Site.com scope
- Profile FLS review completed: 26 Profiles; all four identity fields editable on all 26
- Critical external/restricted Profiles: 16
- Metadata source changes authorised in Phase 1: none

## Confirmed decisions

1. Reconcile the A-IMP-02 FlowDefinition baseline to Sandbox active version 6.
2. Adopt the Sandbox Contact layout state for the four identity fields through A-IMP-02 as-built reconciliation.
3. Retain the active CBS Case queue user assignment as ChenTest runtime configuration.
4. Exclude PartnerCommunity2.site because it is unrelated to A-IMP-03.

## Remaining approval

Security/A-IMP-08 must approve the exact four-field FLS policy for 26 Profiles. Recommended default: Admin retains direct editable FLS; the other 25 Profiles lose direct editable access and receive only approved internal exceptions through a minimum Permission Set. No external, guest, community or partner access should be granted.

No decision authorises deployment, DML, activation or copying live-org metadata into the A-IMP-03 branch.
"@
Set-Content -LiteralPath $summaryPath -Value $summary -Encoding UTF8

$record = @"
# Drift Owner Decision Record - 2026-07-21

- FlowDefinition: confirmed; adopt Sandbox active version 6 through A-IMP-02 baseline reconciliation.
- Contact Layout: confirmed; adopt Sandbox state for Employment_Status__c, Full_Name__c, ID_Number__c and ID_Type__c through A-IMP-02.
- CBS Processing Queue: confirmed; retain the active user assignment required for CBS Case routing as environment runtime configuration.
- Profile FLS: review completed. All four fields are readable/editable on all 26 Profiles; exact Security/A-IMP-08 policy approval remains pending.
- PartnerCommunity2.site: confirmed unrelated to A-IMP-03 and excluded from its Manifest.

Phase 1 only: no metadata source change, DML, deployment or activation was performed.
"@
Set-Content -LiteralPath $decisionRecordPath -Value $record -Encoding UTF8

Write-Output "DRIFT_OWNER_DECISIONS_RECORDED"
Write-Output "PROFILE_POLICY_APPROVAL_PENDING=26"
Write-Output "PHASE1_METADATA_CHANGES=0"
