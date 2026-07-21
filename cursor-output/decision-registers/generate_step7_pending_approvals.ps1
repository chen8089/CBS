param()

$ErrorActionPreference = "Stop"
$registerPath = Join-Path $PSScriptRoot "05_existing_account_baseline_decision_register.csv"
$proposalPath = Join-Path $PSScriptRoot "12_account_business_decision_proposals.csv"
$pendingCsvPath = Join-Path $PSScriptRoot "17_account_baseline_pending_approval_register.csv"
$summaryPath = Join-Path $PSScriptRoot "17_account_baseline_pending_approval_summary.md"
$step7RecordPath = Join-Path $PSScriptRoot "17_step7_account_baseline_status.md"
$executionTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

$register = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)
$proposals = @(Import-Csv -LiteralPath $proposalPath -Encoding UTF8)
$proposalByAccount = @{}
foreach ($row in $proposals) { $proposalByAccount[$row.Account_ID] = $row }

function Get-ApprovalPackage {
    param($Row)
    switch -Regex ($Row.Decision) {
        "ACCESS AND HISTORICAL APPROVAL REVIEW" { return "AP-03" }
        "NEW ONBOARDING CYCLE SELECTED" { return "AP-04" }
        "CLIENT CODE REMEDIATION THEN NEW ONBOARDING" { return "AP-05" }
        default { return "AP-02" }
    }
}

$pendingRows = foreach ($row in $register) {
    $proposal = $proposalByAccount[$row.Account_ID]
    $approvalPackage = Get-ApprovalPackage -Row $row
    [pscustomobject]@{
        Pending_Approval_ID = "$approvalPackage-$($row.Account_ID)"
        Approval_Package = $approvalPackage
        Account_ID = $row.Account_ID
        Masked_Account_Name = $row.Masked_Account_Name
        Current_Client_Status = $row.Current_Client_Status
        Client_Code_Status = $row.Client_Code_Status
        Active_External_Users = $row.Active_External_Users
        Recommended_Disposition = $proposal.Recommended_Disposition
        Selected_Policy_Decision = $row.Decision
        Required_Business_Decision = $proposal.Required_Business_Decision
        Evidence_Required = $row.Evidence_To_Rebuild
        Business_Owner = "PENDING NAMED CBS OWNER"
        Data_Owner = "PENDING NAMED CBS DATA OWNER"
        Approval_Status = "PENDING WRITTEN APPROVAL"
        Approval_Date = ""
        Implementation_Authorised = "NO"
        Blocking_Step = "Step 7 / Step 8 / Phase 2"
    }
}

$pendingRows | Export-Csv -LiteralPath $pendingCsvPath -NoTypeInformation -Encoding UTF8

$ap02 = @($pendingRows | Where-Object { $_.Approval_Package -eq "AP-02" }).Count
$ap03 = @($pendingRows | Where-Object { $_.Approval_Package -eq "AP-03" }).Count
$ap04 = @($pendingRows | Where-Object { $_.Approval_Package -eq "AP-04" }).Count
$ap05 = @($pendingRows | Where-Object { $_.Approval_Package -eq "AP-05" }).Count

$summary = @"
# Account Baseline Pending Approval Summary

- Generated: $executionTime
- Org: 00DBK00000C9kEP2AZ (ChenTest)
- Accounts in baseline register: $($register.Count)
- Accounts with written business/data-owner approval: 0
- Implementation authorised: none
- DML/status changes: none

## Step 7 status

The baseline decision register is populated for all 52 Accounts. Every row remains pending named CBS business/data-owner written approval. No Account may be treated as onboarding-approved or automatically updated.

## Approval packages

- **AP-01** (1 item): Assign named CBS Business Owner and Data Owner for Account baseline sign-off.
- **AP-02** ($ap02 items): Per-Account CBS-client classification for Accounts with blank status and no lifecycle/access evidence. Bulk direction: exclusion candidate pending classification; not an approved exclusion.
- **AP-03** ($ap03 items): External-access and historical-approval review for Accounts with active linked external Users but no Opportunity/Contract/File/Task evidence.
- **AP-04** ($ap04 item): Approve start of a new onboarding cycle for an Active Account with a populated unique Client Code but no qualifying prerequisite evidence.
- **AP-05** ($ap05 item): Approve Client Code remediation source and then a new onboarding cycle for an Active Account with missing Client Code.

## Accounts requiring individual attention (5)

| Account token | Status | Client Code | External users | Selected policy | Approval package |
|---|---|---|---|---|---|
| H-0ccf5d877077f67a | Inactive | Present | 1 | Access/history review HOLD | AP-03 |
| H-901b28a9b096504e | Active | Present | 1 | Access/history review HOLD | AP-03 |
| H-3afd39c385c74a37 | Active | Present | 0 | New onboarding cycle selected | AP-04 |
| H-b52d9048500f523e | Active | Missing | 0 | Remediate Client Code then new cycle | AP-05 |
| H-4dfe138aba56a92d | Blank | Missing | 0 | CBS classification HOLD (notification only) | AP-02 |

## Bulk classification batch (47 Accounts)

Forty-seven Accounts share the same pending decision: **HOLD - CBS CLIENT CLASSIFICATION REQUIRED**. They have blank status, missing Client Code, no Opportunity/Contract/File/Task evidence and no active external Users. Business may approve one written batch rule with named exceptions, or require per-Account classification.

Full token list: see 17_account_baseline_pending_approval_register.csv where Approval_Package=AP-02.

## Cross-cutting approvals still required

1. Confirm no existing Active/Inactive Account is grandfathered as onboarding-complete without evidence.
2. Approve disposition for 49 missing Client Codes before any uniqueness/enforcement control is enabled.
3. Approve handling of 2 active external linked Users before any access change or onboarding activation.
4. Record named approver name, role and approval date for every AP package.

## Files

- Baseline register: 05_existing_account_baseline_decision_register.csv
- Proposals: 12_account_business_decision_proposals.csv
- Pending approvals: 17_account_baseline_pending_approval_register.csv
- Bulk policy record: 13_account_bulk_policy_decision_2026-07-21.md
"@
Set-Content -LiteralPath $summaryPath -Value $summary -Encoding UTF8

$step7 = @"
# Step 7 Account Baseline Status

- Status: **POPULATED / PENDING BUSINESS APPROVAL**
- Execution time: $executionTime
- Accounts populated: $($register.Count)
- Written approvals recorded: 0
- Implementation authorised: none

The existing Account baseline decision register is fully populated from R01-R08 masked runtime evidence and selected bulk policy direction. Step 7 evidence collection and register population are complete. Step 7 business approval is not complete until AP-01 through AP-05 are signed by named CBS owners.

Pending approval register: 17_account_baseline_pending_approval_register.csv
"@
Set-Content -LiteralPath $step7RecordPath -Value $step7 -Encoding UTF8

Write-Output "STEP7_PENDING_APPROVALS_COMPLETE"
Write-Output "ACCOUNTS=$($register.Count)"
Write-Output "PENDING=$($pendingRows.Count)"
Write-Output "AP-02=$ap02"
Write-Output "AP-03=$ap03"
Write-Output "AP-04=$ap04"
Write-Output "AP-05=$ap05"
