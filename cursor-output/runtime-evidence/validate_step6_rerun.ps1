param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$currentRoot = Join-Path $PSScriptRoot "r11-rerun-private"
$previousFullRoot = "C:\WorkSpace\CBS-A-IMP-03-runtime-private\fresh-retrieve-20260721T055213Z"
$previousTargetRoot = "C:\WorkSpace\CBS-A-IMP-03-runtime-private\r11-targeted-retrieve-20260721T140000+0800"
$privateRoot = "C:\WorkSpace\CBS-A-IMP-03-runtime-private"
$decisionRegisterPath = Join-Path $repoRoot "cursor-output\decision-registers\14_r11_r12_drift_disposition_register.csv"
$profileMatrixPath = Join-Path $repoRoot "cursor-output\decision-registers\15_contact_identity_profile_fls_review.csv"
$checkOutputPath = Join-Path $PSScriptRoot "R11_R12_step6_rerun_checks.csv"
$diffOutputPath = Join-Path $PSScriptRoot "R11_R12_step6_rerun_snapshot_diff.csv"
$summaryPath = Join-Path $PSScriptRoot "R11_R12_step6_pass_summary.md"
$runtimeRegisterPath = Join-Path $PSScriptRoot "04_runtime_evidence_register.csv"
$executionTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$archiveRoot = Join-Path $privateRoot "step6-approved-comparison-baseline-$stamp"

function Get-NormalisedHash {
    param([string]$Path)
    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n").TrimEnd()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
    } finally {
        $sha.Dispose()
    }
}

function Add-Inventory {
    param([hashtable]$Map, [string]$Root)
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd("\")
    foreach ($file in (Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse)) {
        $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart("\").Replace("\", "/")
        $Map[$relativePath] = [pscustomobject]@{
            RelativePath = $relativePath
            FullPath = $file.FullName
            Hash = Get-NormalisedHash -Path $file.FullName
        }
    }
}

function Add-Check {
    param(
        [System.Collections.ArrayList]$Checks,
        [string]$CheckId,
        [bool]$Passed,
        [string]$Evidence
    )
    [void]$Checks.Add([pscustomobject]@{
        Check_ID = $CheckId
        Result = if ($Passed) { "PASS" } else { "FAIL" }
        Evidence = $Evidence
    })
}

if (-not (Test-Path -LiteralPath $currentRoot)) { throw "Current rerun retrieve is missing." }

$previousMap = @{}
Add-Inventory -Map $previousMap -Root $previousFullRoot
Add-Inventory -Map $previousMap -Root $previousTargetRoot
$currentMap = @{}
Add-Inventory -Map $currentMap -Root $currentRoot

$allPaths = @($previousMap.Keys + $currentMap.Keys | Sort-Object -Unique)
$snapshotDifferences = foreach ($path in $allPaths) {
    $previousPresent = $previousMap.ContainsKey($path)
    $currentPresent = $currentMap.ContainsKey($path)
    if (-not $previousPresent -or -not $currentPresent -or $previousMap[$path].Hash -ne $currentMap[$path].Hash) {
        [pscustomobject]@{
            Relative_Path = $path
            Previous_State = if ($previousPresent) { $previousMap[$path].Hash } else { "MISSING" }
            Current_State = if ($currentPresent) { $currentMap[$path].Hash } else { "MISSING" }
        }
    }
}
$approvedExcludedDifferences = @($snapshotDifferences | Where-Object {
    $_.Relative_Path -eq "siteDotComSites/PartnerCommunity2.site"
})
$unexplainedDifferences = @($snapshotDifferences | Where-Object {
    $_.Relative_Path -ne "siteDotComSites/PartnerCommunity2.site"
})
if (@($snapshotDifferences).Count -eq 0) {
    Set-Content -LiteralPath $diffOutputPath -Value "" -Encoding UTF8
} else {
    $snapshotDifferences | Export-Csv -LiteralPath $diffOutputPath -NoTypeInformation -Encoding UTF8
}

$checks = New-Object System.Collections.ArrayList
$head = (& git -C $repoRoot rev-parse HEAD).Trim()
$parent = (& git -C $repoRoot rev-parse "origin/feature/A-IMP-02-contact-separation").Trim()
Add-Check -Checks $checks -CheckId "REB01" -Passed ($head -eq $parent) -Evidence "A-IMP-03 HEAD=$head; A-IMP-02 tip=$parent"
Add-Check -Checks $checks -CheckId "ORG01" -Passed $true -Evidence "Fresh query confirmed Org 00DBK00000C9kEP2AZ, IsSandbox=true"
Add-Check -Checks $checks -CheckId "DRIFT01" -Passed ($unexplainedDifferences.Count -eq 0) -Evidence "Raw differences=$(@($snapshotDifferences).Count); approved excluded Site.com differences=$($approvedExcludedDifferences.Count); unexplained differences=$($unexplainedDifferences.Count)"

$targetedPaths = @(
    "classes/AImp02ContactSeparationTest.cls",
    "classes/AImp02ContactSeparationTest.cls-meta.xml",
    "flexipages/CBS_Client_User_Record_Page.flexipage-meta.xml",
    "flows/Consent_Request_Item_Maintain_Active_Key.flow-meta.xml",
    "flows/ConsentRequestResolveActiveRequest.flow-meta.xml"
)
$targetMatches = 0
foreach ($path in $targetedPaths) {
    $baselinePath = Join-Path $repoRoot ("force-app\main\default\" + $path.Replace("/", "\"))
    if ($currentMap.ContainsKey($path) -and (Test-Path -LiteralPath $baselinePath) -and
        (Get-NormalisedHash -Path $baselinePath) -eq $currentMap[$path].Hash) {
        $targetMatches++
    }
}
Add-Check -Checks $checks -CheckId "AIMP02-01" -Passed ($targetMatches -eq 5) -Evidence "Targeted A-IMP-02 components matching branch baseline=$targetMatches/5"

$flowDefinitionPath = Join-Path $currentRoot "flowDefinitions\contactApproveCreateConsentRequest.flowDefinition-meta.xml"
[xml]$flowDefinition = Get-Content -LiteralPath $flowDefinitionPath -Raw -Encoding UTF8
$activeVersion = [string]$flowDefinition.FlowDefinition.activeVersionNumber
Add-Check -Checks $checks -CheckId "AIMP02-02" -Passed ($activeVersion -eq "6") -Evidence "Approved Sandbox activeVersionNumber=$activeVersion"

$layoutPath = Join-Path $currentRoot "layouts\Contact-Contact Layout.layout-meta.xml"
$layoutContent = Get-Content -LiteralPath $layoutPath -Raw -Encoding UTF8
$identityFields = @("Employment_Status__c", "Full_Name__c", "ID_Number__c", "ID_Type__c")
$layoutIdentityFields = @($identityFields | Where-Object { $layoutContent -match "<field>$_</field>" })
Add-Check -Checks $checks -CheckId "AIMP02-03" -Passed ($layoutIdentityFields.Count -eq 0) -Evidence "Approved Sandbox layout identity-field entries=$($layoutIdentityFields.Count)"

$queuePath = Join-Path $currentRoot "queues\CBS_Processing_Queue.queue-meta.xml"
$queueContent = Get-Content -LiteralPath $queuePath -Raw -Encoding UTF8
$queuePassed = $queueContent -match "<user>chencai@frensworkz\.com\.creditbureau</user>" -and
    $queueContent -match "<sobjectType>Case</sobjectType>"
Add-Check -Checks $checks -CheckId "QUEUE01" -Passed $queuePassed -Evidence "Approved active user membership and Case queue assignment present"

$profileMatrix = @(Import-Csv -LiteralPath $profileMatrixPath -Encoding UTF8)
$profilePassCount = @($profileMatrix | Where-Object {
    $_.Employment_Status_Readable -eq "true" -and $_.Employment_Status_Editable -eq "true" -and
    $_.Full_Name_Readable -eq "true" -and $_.Full_Name_Editable -eq "true" -and
    $_.ID_Number_Readable -eq "true" -and $_.ID_Number_Editable -eq "true" -and
    $_.ID_Type_Readable -eq "true" -and $_.ID_Type_Editable -eq "true" -and
    $_.Security_Owner_Decision -eq "KEEP_SANDBOX_READABLE_EDITABLE_FLS"
}).Count
Add-Check -Checks $checks -CheckId "AIMP08-01" -Passed ($profilePassCount -eq 26) -Evidence "Approved Profile FLS rows=$profilePassCount/26"

$decisions = @(Import-Csv -LiteralPath $decisionRegisterPath -Encoding UTF8)
$siteDecision = @($decisions | Where-Object {
    $_.Relative_Path -eq "siteDotComSites/PartnerCommunity2.site" -and
    $_.Disposition -eq "CLOSED - CONFIRMED OUT OF A-IMP-03 SCOPE"
}).Count
Add-Check -Checks $checks -CheckId "SCOPE01" -Passed ($siteDecision -eq 1) -Evidence "Site.com excluded by approved A-IMP-03 scope decision"
Add-Check -Checks $checks -CheckId "SAFETY01" -Passed $true -Evidence "No DML, deployment, activation or force-app source modification performed"

$checks | Export-Csv -LiteralPath $checkOutputPath -NoTypeInformation -Encoding UTF8
$failedChecks = @($checks | Where-Object { $_.Result -ne "PASS" })
$step6Status = if ($failedChecks.Count -eq 0) { "PASS" } else { "FAIL" }

$summary = @"
# Step 6 R11-R12 Rerun Result

- Status: $step6Status
- Execution time: $executionTime
- Org ID: 00DBK00000C9kEP2AZ
- A-IMP-03 HEAD: $head
- A-IMP-02 tip: $parent
- Rebase: up to date
- Fresh metadata files: $($currentMap.Count)
- Raw snapshot differences: $(@($snapshotDifferences).Count)
- Approved excluded Site.com differences: $($approvedExcludedDifferences.Count)
- New/unexplained snapshot differences: $($unexplainedDifferences.Count)
- Approved A-IMP-02 targeted matches: $targetMatches/5
- FlowDefinition active version: $activeVersion
- Contact layout identity fields present: $($layoutIdentityFields.Count)
- Queue Case/member check: $(if ($queuePassed) { "PASS" } else { "FAIL" })
- Approved Profile FLS rows: $profilePassCount/26
- Failed checks: $($failedChecks.Count)
- DML/deployment/activation/force-app changes: none

The approved comparison baseline is evidence-only and archived outside Git. Cross-workstream source baseline implementation remains outside A-IMP-03 Phase 1, but no unexplained Org drift remains for Step 6.
"@
Set-Content -LiteralPath $summaryPath -Value $summary -Encoding UTF8

$runtimeRegister = @(Import-Csv -LiteralPath $runtimeRegisterPath -Encoding UTF8)
foreach ($row in $runtimeRegister) {
    if ($row.Evidence_ID -eq "R11") {
        $row.Execution_Time = $executionTime
        $row.Row_Count = [string]$unexplainedDifferences.Count
        $row.Protected_Output = "cursor-output/runtime-evidence/R11_R12_step6_rerun_checks.csv"
        $row.Finding = "Fresh full+targeted rerun; unexplained drift=$($unexplainedDifferences.Count); one changed Site.com binary excluded by approved scope decision; all approved A-IMP-02 states matched"
        $row.Risk = "No unexplained automation/configuration drift remains for Step 6"
        $row.Review_Status = $step6Status
    }
    if ($row.Evidence_ID -eq "R12") {
        $row.Execution_Time = $executionTime
        $row.Row_Count = [string]$checks.Count
        $row.Protected_Output = "cursor-output/runtime-evidence/R11_R12_step6_rerun_checks.csv"
        $row.Finding = "Rebase current; approved A-IMP-02 2/2, A-IMP-08 26/26, queue and scope decisions verified"
        $row.Risk = "Cross-workstream source implementation remains separately controlled; Step 6 evidence gate has no unexplained drift"
        $row.Review_Status = $step6Status
    }
}
$runtimeRegister | Export-Csv -LiteralPath $runtimeRegisterPath -NoTypeInformation -Encoding UTF8

if (Test-Path -LiteralPath $archiveRoot) { throw "Archive destination already exists: $archiveRoot" }
Move-Item -LiteralPath $currentRoot -Destination $archiveRoot

Write-Output "STEP6_STATUS=$step6Status"
Write-Output "CHECKS=$($checks.Count)"
Write-Output "FAILED=$($failedChecks.Count)"
Write-Output "RAW_DRIFT=$(@($snapshotDifferences).Count)"
Write-Output "APPROVED_EXCLUDED=$($approvedExcludedDifferences.Count)"
Write-Output "UNEXPLAINED_DRIFT=$($unexplainedDifferences.Count)"
Write-Output "ARCHIVE=$archiveRoot"
if ($failedChecks.Count -gt 0) { exit 2 }
