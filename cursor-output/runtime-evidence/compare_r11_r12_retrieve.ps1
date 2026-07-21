param(
    [string]$ExpectedOrgId = "00DBK00000C9kEP2AZ",
    [string]$ExpectedUsername = "cbsneworg@creditbureau.com.sg.chentest"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$baselineRoot = Join-Path $repoRoot "force-app\main\default"
$retrievedRoot = Join-Path $PSScriptRoot "fresh-retrieve-private"
$privateRoot = "C:\WorkSpace\CBS-A-IMP-03-runtime-private"
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$archiveRoot = Join-Path $privateRoot "fresh-retrieve-$stamp"
$executionTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

if (-not (Test-Path -LiteralPath $baselineRoot)) { throw "Baseline metadata root not found." }
if (-not (Test-Path -LiteralPath $retrievedRoot)) { throw "Fresh retrieve root not found." }
if (Test-Path -LiteralPath $archiveRoot) { throw "Archive destination already exists." }

function Get-Inventory {
    param([string]$Root)
    $rootPath = (Resolve-Path -LiteralPath $Root).Path.TrimEnd("\")
    $rows = foreach ($file in (Get-ChildItem -LiteralPath $rootPath -File -Recurse)) {
        $relativePath = $file.FullName.Substring($rootPath.Length).TrimStart("\").Replace("\", "/")
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $normalised = ($content -replace "`r`n", "`n").TrimEnd()
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalised)
            $hashBytes = $sha.ComputeHash($bytes)
            $hash = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
        } finally {
            $sha.Dispose()
        }
        [pscustomobject]@{
            Relative_Path = $relativePath
            SHA256_Normalised = $hash
            Size_Bytes = $file.Length
        }
    }
    return @($rows)
}

function Export-Rows {
    param([string]$Path, $Rows)
    $rowArray = @($Rows | Where-Object { $null -ne $_ })
    if ($rowArray.Count -eq 0) {
        Set-Content -LiteralPath $Path -Value "" -Encoding UTF8
    } else {
        $rowArray | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
    }
}

$baselineInventory = @(Get-Inventory -Root $baselineRoot)
$sandboxInventory = @(Get-Inventory -Root $retrievedRoot)

$baselineMap = @{}
foreach ($row in $baselineInventory) { $baselineMap[[string]$row.Relative_Path] = $row }
$sandboxMap = @{}
foreach ($row in $sandboxInventory) { $sandboxMap[[string]$row.Relative_Path] = $row }

$allPaths = @($baselineMap.Keys + $sandboxMap.Keys | Sort-Object -Unique)
$differences = foreach ($path in $allPaths) {
    $baselinePresent = $baselineMap.ContainsKey($path)
    $sandboxPresent = $sandboxMap.ContainsKey($path)
    $status = if (-not $baselinePresent) {
        "SANDBOX_ONLY"
    } elseif (-not $sandboxPresent) {
        "BASELINE_ONLY"
    } elseif ($baselineMap[$path].SHA256_Normalised -ne $sandboxMap[$path].SHA256_Normalised) {
        "CONTENT_CHANGED"
    } else {
        "MATCH"
    }
    if ($status -ne "MATCH") {
        [pscustomobject]@{
            Relative_Path = $path
            Difference = $status
            Baseline_SHA256 = if ($baselinePresent) { $baselineMap[$path].SHA256_Normalised } else { "" }
            Sandbox_SHA256 = if ($sandboxPresent) { $sandboxMap[$path].SHA256_Normalised } else { "" }
        }
    }
}

$automationPattern = "^(flows|flowDefinitions|approvalProcesses|triggers|classes|workflows|assignmentRules|escalationRules|matchingRules|duplicateRules)/"
$automationDifferences = @($differences | Where-Object { $_.Relative_Path -match $automationPattern })
$sandboxOnly = @($differences | Where-Object { $_.Difference -eq "SANDBOX_ONLY" })
$baselineOnly = @($differences | Where-Object { $_.Difference -eq "BASELINE_ONLY" })
$changed = @($differences | Where-Object { $_.Difference -eq "CONTENT_CHANGED" })

$baselineInventoryPath = Join-Path $PSScriptRoot "R12_baseline_hash_inventory.csv"
$sandboxInventoryPath = Join-Path $PSScriptRoot "R12_sandbox_hash_inventory.csv"
$differencePath = Join-Path $PSScriptRoot "R11_R12_fresh_retrieve_diff.csv"
$automationPath = Join-Path $PSScriptRoot "R11_automation_diff.csv"
Export-Rows -Path $baselineInventoryPath -Rows $baselineInventory
Export-Rows -Path $sandboxInventoryPath -Rows $sandboxInventory
Export-Rows -Path $differencePath -Rows $differences
Export-Rows -Path $automationPath -Rows $automationDifferences

$baselineCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$summary = @"
# R11-R12 Fresh Retrieve Comparison

- Org ID: $ExpectedOrgId
- Executing user: $ExpectedUsername
- Execution time: $executionTime
- Baseline commit: $baselineCommit
- Baseline files: $($baselineInventory.Count)
- Fresh Sandbox files: $($sandboxInventory.Count)
- Total differences: $($differences.Count)
- Sandbox-only files: $($sandboxOnly.Count)
- Baseline-only files: $($baselineOnly.Count)
- Content-changed files: $($changed.Count)
- Automation-scope differences: $($automationDifferences.Count)
- Hash method: SHA-256 after CRLF/LF normalisation and trailing whitespace removal
- DML/deployment/activation: none

The full and automation-scoped path/hash differences are recorded in CSV. Any difference remains review-gated; this comparison does not authorise metadata changes.
"@
$summaryPath = Join-Path $PSScriptRoot "R11_R12_fresh_retrieve_summary.md"
Set-Content -LiteralPath $summaryPath -Value $summary -Encoding UTF8

$registerPath = Join-Path $PSScriptRoot "04_runtime_evidence_register.csv"
$register = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)
foreach ($row in $register) {
    if ($row.Evidence_ID -eq "R11") {
        $row.Execution_Time = $executionTime
        $row.Row_Count = [string]$automationDifferences.Count
        $row.Protected_Output = "cursor-output/runtime-evidence/R11_automation_diff.csv"
        $row.Finding = "Automation differences=$($automationDifferences.Count); fresh Sandbox files=$($sandboxInventory.Count)"
        $row.Risk = if ($automationDifferences.Count -eq 0) { "No byte-level automation drift detected in manifest scope" } else { "Automation drift requires review before implementation" }
        $row.Review_Status = if ($automationDifferences.Count -eq 0) { "EXECUTED - NO DIFF" } else { "EXECUTED - PENDING REVIEW" }
    }
    if ($row.Evidence_ID -eq "R12") {
        $row.Execution_Time = $executionTime
        $row.Row_Count = [string]$differences.Count
        $row.Protected_Output = "cursor-output/runtime-evidence/R11_R12_fresh_retrieve_diff.csv"
        $row.Finding = "Total differences=$($differences.Count); Sandbox-only=$($sandboxOnly.Count); baseline-only=$($baselineOnly.Count); changed=$($changed.Count)"
        $row.Risk = if ($differences.Count -eq 0) { "No byte-level drift detected in manifest scope" } else { "Latest baseline differs from Sandbox and requires disposition" }
        $row.Review_Status = if ($differences.Count -eq 0) { "EXECUTED - NO DIFF" } else { "EXECUTED - PENDING REVIEW" }
    }
}
$register | Export-Csv -LiteralPath $registerPath -NoTypeInformation -Encoding UTF8

Move-Item -LiteralPath $retrievedRoot -Destination $archiveRoot

Write-Output "R11_R12_COMPLETE"
Write-Output "BASELINE_FILES=$($baselineInventory.Count)"
Write-Output "SANDBOX_FILES=$($sandboxInventory.Count)"
Write-Output "TOTAL_DIFFERENCES=$($differences.Count)"
Write-Output "AUTOMATION_DIFFERENCES=$($automationDifferences.Count)"
Write-Output "ARCHIVE=$archiveRoot"
