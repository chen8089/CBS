param()

$ErrorActionPreference = "Stop"
$approvalDate = "2026-07-21"
$approvalTimestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
$businessOwner = "陈财 / CBS系统负责人"
$dataOwner = "陈财 / CBS系统负责人"
$baseDir = $PSScriptRoot

$registerPath = Join-Path $baseDir "05_existing_account_baseline_decision_register.csv"
$proposalPath = Join-Path $baseDir "12_account_business_decision_proposals.csv"
$pendingPath = Join-Path $baseDir "17_account_baseline_pending_approval_register.csv"
$approvalMdPath = Join-Path $baseDir "18_account_baseline_business_owner_approval_2026-07-21.md"
$step7StatusPath = Join-Path $baseDir "17_step7_account_baseline_status.md"
$bulkPolicyPath = Join-Path $baseDir "13_account_bulk_policy_decision_2026-07-21.md"

function Set-AccountDecision {
    param($Row, $Decision, $ImplementationStatus, $NotesSuffix)
    $Row.Business_Owner = $businessOwner
    $Row.Decision = $Decision
    $Row.Approval_Date = $approvalDate
    $Row.Implementation_Status = $ImplementationStatus
    if ($NotesSuffix) {
        $Row.Notes = ($Row.Notes.TrimEnd() + " " + $NotesSuffix).Trim()
    }
    return $Row
}

$register = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)
$updatedRegister = foreach ($row in $register) {
    switch ($row.Account_ID) {
        "H-0ccf5d877077f67a" {
            Set-AccountDecision $row `
                "APPROVED - DEACTIVATE ACCESS AND EXCLUDE" `
                "POLICY APPROVED - NOT IMPLEMENTED" `
                "Business owner approved deactivate access and exclude on $approvalDate via Cursor."
        }
        "H-901b28a9b096504e" {
            Set-AccountDecision $row `
                "APPROVED - GRANDFATHER EXCEPTION (NOT ONBOARDING-COMPLETE)" `
                "POLICY APPROVED - NOT IMPLEMENTED" `
                "Business owner approved documented grandfather exception on $approvalDate; not onboarding-complete."
        }
        "H-3afd39c385c74a37" {
            Set-AccountDecision $row `
                "APPROVED - NEW ONBOARDING CYCLE" `
                "POLICY APPROVED - NOT IMPLEMENTED" `
                "Business owner approved new onboarding cycle on $approvalDate via Cursor."
        }
        "H-b52d9048500f523e" {
            Set-AccountDecision $row `
                "APPROVED - REMEDIATE CLIENT CODE THEN NEW ONBOARDING CYCLE" `
                "POLICY APPROVED - NOT IMPLEMENTED" `
                "Business owner approved Client Code remediation then new cycle on $approvalDate via Cursor."
        }
        default {
            Set-AccountDecision $row `
                "APPROVED - BATCH HOLD RULE (EXCLUSION CANDIDATE)" `
                "POLICY APPROVED - NOT IMPLEMENTED" `
                "Business owner approved AP-02 batch hold rule on $approvalDate; not an approved exclusion."
        }
    }
}
$updatedRegister | Export-Csv -LiteralPath $registerPath -NoTypeInformation -Encoding UTF8

$proposals = @(Import-Csv -LiteralPath $proposalPath -Encoding UTF8)
$updatedProposals = foreach ($row in $proposals) {
    $row.Business_Owner = $businessOwner
    $row.Approval_Date = $approvalDate
    $row.Implementation_Authorised = "NO - PHASE 2 ONLY"
    switch ($row.Account_ID) {
        "H-0ccf5d877077f67a" { $row.Owner_Decision = "APPROVED - DEACTIVATE ACCESS AND EXCLUDE" }
        "H-901b28a9b096504e" { $row.Owner_Decision = "APPROVED - GRANDFATHER EXCEPTION (NOT ONBOARDING-COMPLETE)" }
        "H-3afd39c385c74a37" { $row.Owner_Decision = "APPROVED - NEW ONBOARDING CYCLE" }
        "H-b52d9048500f523e" { $row.Owner_Decision = "APPROVED - REMEDIATE CLIENT CODE THEN NEW ONBOARDING CYCLE" }
        default { $row.Owner_Decision = "APPROVED - BATCH HOLD RULE (EXCLUSION CANDIDATE)" }
    }
    $row
}
$updatedProposals | Export-Csv -LiteralPath $proposalPath -NoTypeInformation -Encoding UTF8

$pending = @(Import-Csv -LiteralPath $pendingPath -Encoding UTF8)
$updatedPending = foreach ($row in $pending) {
    $row.Business_Owner = $businessOwner
    $row.Data_Owner = $dataOwner
    $row.Approval_Status = "APPROVED"
    $row.Approval_Date = $approvalDate
    $row.Implementation_Authorised = "NO - PHASE 2 ONLY"
    $row.Selected_Policy_Decision = ($updatedRegister | Where-Object { $_.Account_ID -eq $row.Account_ID }).Decision
    $row
}
$updatedPending | Export-Csv -LiteralPath $pendingPath -NoTypeInformation -Encoding UTF8

$approvalMd = @"
# Account Baseline Business Owner Approval Record

- Recorded: $approvalTimestamp
- Org: 00DBK00000C9kEP2AZ (ChenTest)
- Approval channel: Cursor business-owner confirmation
- CBS Business Owner: $businessOwner
- CBS Data Owner: $dataOwner
- DML/status changes: none
- Salesforce implementation authorised: none (Phase 2 planning only)

## Approval scope

The business owner approved AP-01 through AP-05 and the bulk policy direction recorded in `13_account_bulk_policy_decision_2026-07-21.md`. This approval authorises Phase 1 closure of Step 7 and Phase 2 planning. It does **not** authorise deployment, activation, DML, or writing `Onboarding_Approved__c`.

## Package decisions

| Package | Decision |
|---|---|
| AP-01 | Named CBS business/data owner sign-off channel confirmed via Cursor; formal name pending |
| AP-02 | Batch hold rule approved for 48 Accounts: exclusion candidates remain on classification HOLD; no automatic exclusion |
| AP-03 | H-0ccf5d877077f67a: deactivate external access and exclude |
| AP-03 | H-901b28a9b096504e: documented grandfather exception; **not** onboarding-complete |
| AP-04 | H-3afd39c385c74a37: new onboarding cycle approved |
| AP-05 | H-b52d9048500f523e: Client Code remediation then new onboarding cycle approved |

## Cross-cutting confirmations

1. No existing Active/Inactive Account is grandfathered as onboarding-complete without evidence.
2. Missing Client Code disposition is approved only as planning input for Phase 2 remediation design.
3. External-user handling for the two affected Accounts follows the AP-03 decisions above.
4. Phase 2, deployment, activation and Production/UAT remain separately gated.

## Account counts after approval

- Total Accounts: 52
- Batch hold rule (AP-02): 48
- Deactivate/exclude (AP-03): 1
- Grandfather exception not onboarding-complete (AP-03): 1
- New onboarding cycle (AP-04): 1
- Remediate Client Code then new cycle (AP-05): 1

## Formal name follow-up

The approver selected **Other** for sign-off identity. Replace the placeholder owner values in registers once the formal name and role are supplied.
"@
Set-Content -LiteralPath $approvalMdPath -Value $approvalMd -Encoding UTF8

$step7 = @"
# Step 7 Account Baseline Status

- Status: **BUSINESS APPROVAL COMPLETE**
- Execution time: $approvalTimestamp
- Accounts populated: 52
- Written approvals recorded: 52 (policy direction only)
- Salesforce implementation authorised: none

Step 7 register population and business-owner policy approval are complete. Formal approver name/role remain pending replacement of the placeholder owner values. Phase 2 DML, deployment and activation remain separately gated.

Approval record: 18_account_baseline_business_owner_approval_2026-07-21.md
Pending register: 17_account_baseline_pending_approval_register.csv
"@
Set-Content -LiteralPath $step7StatusPath -Value $step7 -Encoding UTF8

$bulkAppend = @"

## Business owner approval

- Approved: $approvalTimestamp
- Approver: $businessOwner
- Scope: AP-01 through AP-05 and cross-cutting confirmations in `18_account_baseline_business_owner_approval_2026-07-21.md`
- AP-02 batch rule: approved as classification HOLD for exclusion candidates; not approved exclusions
- Implementation: not authorised
"@
Add-Content -LiteralPath $bulkPolicyPath -Value $bulkAppend -Encoding UTF8

Write-Output "BUSINESS_APPROVAL_RECORDED"
Write-Output "ACCOUNTS=52"
Write-Output "APPROVAL_DATE=$approvalDate"
