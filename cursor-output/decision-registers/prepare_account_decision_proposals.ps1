param()

$ErrorActionPreference = "Stop"
$registerPath = Join-Path $PSScriptRoot "05_existing_account_baseline_decision_register.csv"
$proposalPath = Join-Path $PSScriptRoot "12_account_business_decision_proposals.csv"
$summaryPath = Join-Path $PSScriptRoot "12_account_business_decision_summary.md"
$accountInventoryPath = Join-Path $PSScriptRoot "..\runtime-evidence\masked-review\R01-account-inventory-masked.csv"

$rows = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)
$accountInventory = @(Import-Csv -LiteralPath $accountInventoryPath -Encoding UTF8)
$notificationByAccount = @{}
foreach ($account in $accountInventory) {
    $notificationByAccount[$account.Account_Token] = [string]$account.Notification_Email_Present
}
$proposals = foreach ($row in $rows) {
    $externalCount = 0
    if ($row.Active_External_Users -match "COUNT=(\d+)") {
        $externalCount = [int]$Matches[1]
    }

    if ($externalCount -gt 0 -and $row.Current_Client_Status -eq "Inactive") {
        $recommendation = "HOLD_AND_REVIEW_EXTERNAL_ACCESS"
        $rationale = "Inactive Account has an active external User but no Opportunity, Contract, File or onboarding Task evidence."
        $requiredDecision = "Choose: deactivate access and exclude; start a new onboarding cycle before reactivation; or approve a documented grandfather exception."
        $evidenceNeeded = "External access entitlement, historical approval, Contract/File evidence and named owner review."
    } elseif ($externalCount -gt 0) {
        $recommendation = "GRANDFATHER_EXCEPTION_CANDIDATE_OR_REBUILD"
        $rationale = "Active external access exists, but no Opportunity, Contract, File or onboarding Task evidence was found."
        $requiredDecision = "Choose: rebuild evidence; approve a documented grandfather exception; start a new onboarding cycle; or suspend access."
        $evidenceNeeded = "External access entitlement, historical approval, Contract/File evidence and named owner review."
    } elseif ($row.Current_Client_Status -eq "Active" -and $row.Client_Code_Status -eq "MISSING") {
        $recommendation = "HOLD_CLIENT_CODE_REMEDIATION_THEN_NEW_ONBOARDING"
        $rationale = "Account is Active but has no Client Code and no qualifying runtime prerequisite evidence."
        $requiredDecision = "Confirm CBS-client classification, approve Client Code remediation and choose new onboarding or exclusion."
        $evidenceNeeded = "CBS-client classification, approved Client Code source, Closed Won/Contract/File evidence."
    } elseif ($row.Current_Client_Status -eq "Active") {
        $recommendation = "START_NEW_ONBOARDING_CYCLE"
        $rationale = "Account is Active with a populated unique Client Code but no qualifying runtime prerequisite evidence."
        $requiredDecision = "Approve a new onboarding cycle or provide evidence supporting a grandfather exception."
        $evidenceNeeded = "Closed Won, Contract, signed File, checklist and approval evidence."
    } elseif ($row.Current_Client_Status -eq "Inactive") {
        $recommendation = "EXCLUDE_OR_NEW_CYCLE_PENDING_BUSINESS"
        $rationale = "Account is Inactive and has no qualifying runtime prerequisite evidence."
        $requiredDecision = "Choose exclusion or a new onboarding cycle before any reactivation."
        $evidenceNeeded = "CBS-client classification and reactivation justification."
    } elseif ($notificationByAccount[$row.Account_ID] -match "^(true|True)$") {
        $recommendation = "HOLD_PENDING_BUSINESS_CLASSIFICATION"
        $rationale = "Notification email is the only positive CBS indicator; status, Client Code, lifecycle evidence and external-user evidence are absent."
        $requiredDecision = "Confirm whether this is a CBS client before selecting exclusion or a remediated new onboarding cycle."
        $evidenceNeeded = "CBS-client classification, notification-email ownership and accountable business owner."
    } else {
        $recommendation = "EXCLUDE_AS_NON_CBS_CANDIDATE_PENDING_CLASSIFICATION"
        $rationale = "Status and Client Code are blank and no Opportunity, Contract, File, onboarding Task or active external User evidence was found."
        $requiredDecision = "Confirm whether this is a CBS client. If yes, approve Client Code remediation and a new onboarding cycle; otherwise approve exclusion."
        $evidenceNeeded = "CBS-client classification and accountable business owner."
    }

    $row.Baseline_Option = $recommendation
    $row.Evidence_To_Rebuild = $evidenceNeeded
    $row.Exception_Reason = if ($recommendation -match "GRANDFATHER") { "REQUIRED IF GRANDFATHER IS SELECTED" } else { "" }
    $row.Business_Owner = "PENDING ASSIGNMENT"
    $row.Decision = "PENDING OWNER APPROVAL"
    $row.Notes = "Automated evidence-based recommendation only; no business approval, DML or status change."

    [pscustomobject]@{
        Account_ID = $row.Account_ID
        Current_Client_Status = $row.Current_Client_Status
        Client_Code_Status = $row.Client_Code_Status
        Active_External_Users = $row.Active_External_Users
        Recommended_Disposition = $recommendation
        Recommendation_Rationale = $rationale
        Required_Business_Decision = $requiredDecision
        Evidence_Required = $evidenceNeeded
        Business_Owner = "PENDING ASSIGNMENT"
        Owner_Decision = "PENDING"
        Approval_Date = ""
        Implementation_Authorised = "NO"
    }
}

$rows | Export-Csv -LiteralPath $registerPath -NoTypeInformation -Encoding UTF8
$proposals | Export-Csv -LiteralPath $proposalPath -NoTypeInformation -Encoding UTF8

$groups = @($proposals | Group-Object Recommended_Disposition | Sort-Object Name)
$summaryLines = @(
    "# Account Business Decision Proposal Summary",
    "",
    "- Total Accounts: $($proposals.Count)",
    "- Final owner approvals recorded: 0",
    "- Active external linked Users: 2",
    "- DML/status changes: none",
    "",
    "## Recommendation counts",
    ""
)
foreach ($group in $groups) {
    $summaryLines += "- $($group.Name): $($group.Count)"
}
$summaryLines += @(
    "",
    "These are evidence-based recommendations, not business decisions. Every Account remains pending assignment and written owner approval."
)
Set-Content -LiteralPath $summaryPath -Value ($summaryLines -join [Environment]::NewLine) -Encoding UTF8

Write-Output "ACCOUNT_PROPOSALS_COMPLETE"
Write-Output "TOTAL=$($proposals.Count)"
foreach ($group in $groups) {
    Write-Output "$($group.Name)=$($group.Count)"
}
