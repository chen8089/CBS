param()

$ErrorActionPreference = "Stop"
$registerPath = Join-Path $PSScriptRoot "05_existing_account_baseline_decision_register.csv"
$proposalPath = Join-Path $PSScriptRoot "12_account_business_decision_proposals.csv"
$decisionRecordPath = Join-Path $PSScriptRoot "13_account_bulk_policy_decision_2026-07-21.md"
$decisionTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

$register = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)
foreach ($row in $register) {
    $externalCount = 0
    if ($row.Active_External_Users -match "COUNT=(\d+)") { $externalCount = [int]$Matches[1] }

    if ($externalCount -gt 0) {
        $row.Decision = "HOLD - ACCESS AND HISTORICAL APPROVAL REVIEW"
    } elseif ([string]::IsNullOrWhiteSpace($row.Current_Client_Status)) {
        $row.Decision = "HOLD - CBS CLIENT CLASSIFICATION REQUIRED"
    } elseif ($row.Current_Client_Status -eq "Active" -and $row.Client_Code_Status -eq "MISSING") {
        $row.Decision = "HOLD - CLIENT CODE REMEDIATION THEN NEW ONBOARDING"
    } elseif ($row.Current_Client_Status -eq "Active") {
        $row.Decision = "NEW ONBOARDING CYCLE SELECTED"
    } else {
        $row.Decision = "HOLD - INDIVIDUAL OWNER REVIEW"
    }

    $row.Business_Owner = "PENDING NAMED CBS OWNER"
    $row.Approval_Date = ""
    $row.Implementation_Status = "NOT AUTHORISED"
    $row.Notes = "Bulk policy selected via Cursor on 2026-07-21; named CBS business/data-owner sign-off remains required before implementation."
}
$register | Export-Csv -LiteralPath $registerPath -NoTypeInformation -Encoding UTF8

$proposals = @(Import-Csv -LiteralPath $proposalPath -Encoding UTF8)
foreach ($row in $proposals) {
    if ($row.Recommended_Disposition -eq "EXCLUDE_AS_NON_CBS_CANDIDATE_PENDING_CLASSIFICATION") {
        $row.Owner_Decision = "HOLD - PER-ACCOUNT CBS CLASSIFICATION"
    } elseif ($row.Recommended_Disposition -eq "HOLD_PENDING_BUSINESS_CLASSIFICATION") {
        $row.Owner_Decision = "HOLD - PER-ACCOUNT CBS CLASSIFICATION"
    } elseif ($row.Recommended_Disposition -eq "START_NEW_ONBOARDING_CYCLE") {
        $row.Owner_Decision = "ACCEPTED POLICY - NEW ONBOARDING CYCLE"
    } elseif ($row.Recommended_Disposition -eq "HOLD_CLIENT_CODE_REMEDIATION_THEN_NEW_ONBOARDING") {
        $row.Owner_Decision = "ACCEPTED POLICY - REMEDIATE THEN NEW CYCLE"
    } else {
        $row.Owner_Decision = "HOLD - ACCESS AND HISTORICAL APPROVAL REVIEW"
    }
    $row.Business_Owner = "PENDING NAMED CBS OWNER"
    $row.Approval_Date = ""
    $row.Implementation_Authorised = "NO"
}
$proposals | Export-Csv -LiteralPath $proposalPath -NoTypeInformation -Encoding UTF8

$record = @"
# Account Bulk Policy Decision Record

- Recorded: $decisionTime
- Scope: 52 masked Account baseline rows
- DML/status changes: none
- Implementation authorisation: none

## Selected policy

1. 48 Accounts with blank status, missing Client Code and no onboarding/external-user evidence remain HOLD pending per-Account CBS-client classification.
2. The Active Account with a populated unique Client Code is selected for a new onboarding cycle.
3. The Active Account with a missing Client Code remains HOLD for approved Client Code remediation, then a new onboarding cycle.
4. The two Accounts with active external linked Users remain HOLD for access entitlement and historical approval review.

These selections are recorded as bulk policy direction. A named CBS business/data owner, per-Account classification where required, and written sign-off are still mandatory. No Account value was changed.
"@
Set-Content -LiteralPath $decisionRecordPath -Value $record -Encoding UTF8

Write-Output "ACCOUNT_POLICY_RECORDED"
Write-Output "TOTAL=$($register.Count)"
Write-Output "IMPLEMENTATION_AUTHORISED=NO"
