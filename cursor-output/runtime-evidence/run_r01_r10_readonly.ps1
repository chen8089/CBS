param(
    [string]$TargetOrg = "CBS-A-IMP-03",
    [string]$ExpectedOrgId = "00DBK00000C9kEP2AZ",
    [string]$ExpectedUsername = "cbsneworg@creditbureau.com.sg.chentest"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$reviewDir = Join-Path $PSScriptRoot "masked-review"
$privateDir = "C:\WorkSpace\CBS-A-IMP-03-runtime-private"
$rawDir = Join-Path $privateDir "raw"
$errorLog = Join-Path $privateDir "query-errors.log"

New-Item -ItemType Directory -Force -Path $reviewDir | Out-Null
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
Set-Content -LiteralPath $errorLog -Value "" -Encoding UTF8

function Get-Value {
    param($Row, [string]$Name)
    if ($null -eq $Row) { return $null }
    $property = $Row.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Protect-Value {
    param($Value)
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { return "" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Value)
        $hash = $sha.ComputeHash($bytes)
        $hex = -join ($hash | ForEach-Object { $_.ToString("x2") })
        return "H-" + $hex.Substring(0, 16)
    } finally {
        $sha.Dispose()
    }
}

function Invoke-ReadOnlyQuery {
    param(
        [string]$EvidenceId,
        [string]$Name,
        [string]$Soql,
        [switch]$Tooling,
        [switch]$Optional
    )

    $safeName = ($Name -replace "[^A-Za-z0-9_-]", "_")
    $outputPath = Join-Path $rawDir "$EvidenceId-$safeName.csv"
    $arguments = @(
        "data", "query",
        "--target-org", $TargetOrg,
        "--query", $Soql,
        "--result-format", "csv",
        "--output-file", $outputPath
    )
    if ($Tooling) { $arguments += "--use-tooling-api" }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & sf @arguments 2>&1
    $queryExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($queryExitCode -ne 0) {
        $message = "$EvidenceId/$Name failed: $($output -join ' ')"
        Add-Content -LiteralPath $errorLog -Value $message -Encoding UTF8
        if ($Optional) {
            Write-Output -NoEnumerate @()
            return
        }
        throw $message
    }

    if (-not (Test-Path -LiteralPath $outputPath)) {
        Write-Output -NoEnumerate @()
        return
    }
    $content = Get-Content -LiteralPath $outputPath -Encoding UTF8
    if ($content.Count -le 1) {
        Write-Output -NoEnumerate @()
        return
    }
    Write-Output -NoEnumerate @(Import-Csv -LiteralPath $outputPath -Encoding UTF8)
}

function Export-Review {
    param([string]$FileName, $Rows)
    $path = Join-Path $reviewDir $FileName
    $rowArray = @($Rows | Where-Object { $null -ne $_ })
    if ($rowArray.Count -eq 0) {
        Set-Content -LiteralPath $path -Value "" -Encoding UTF8
    } else {
        $rowArray | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
    }
    return $path
}

function Chunk-Array {
    param([array]$Items, [int]$Size = 100)
    $chunks = @()
    for ($index = 0; $index -lt $Items.Count; $index += $Size) {
        $last = [Math]::Min($index + $Size - 1, $Items.Count - 1)
        $chunks += ,@($Items[$index..$last])
    }
    return $chunks
}

$executionTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

# Identity lock: stop before evidence collection if the target is not ChenTest.
$organization = Invoke-ReadOnlyQuery -EvidenceId "CONTROL" -Name "organization" `
    -Soql "SELECT Id, Name, IsSandbox FROM Organization"
if ($organization.Count -ne 1 -or (Get-Value $organization[0] "Id") -ne $ExpectedOrgId -or
    [string](Get-Value $organization[0] "IsSandbox") -notmatch "^(true|True)$") {
    throw "Target org identity mismatch or target is not a Sandbox."
}

$executingUser = Invoke-ReadOnlyQuery -EvidenceId "CONTROL" -Name "executing-user" `
    -Soql "SELECT Id, Username, IsActive FROM User WHERE Username = '$ExpectedUsername' LIMIT 1"
if ($executingUser.Count -ne 1 -or [string](Get-Value $executingUser[0] "Username") -ne $ExpectedUsername) {
    throw "Executing user identity mismatch."
}

# R01 / R02 / R03 account inventory.
$r01Status = Invoke-ReadOnlyQuery -EvidenceId "R01" -Name "status-counts" `
    -Soql "SELECT Client_Status__c, COUNT(Id) RecordCount FROM Account GROUP BY Client_Status__c"
$r01Types = Invoke-ReadOnlyQuery -EvidenceId "R01" -Name "type-recordtype-counts" `
    -Soql "SELECT Type, COUNT(Id) RecordCount FROM Account GROUP BY Type"
$accounts = Invoke-ReadOnlyQuery -EvidenceId "R01" -Name "account-inventory" `
    -Soql "SELECT Id, Name, Client_Code__c, Client_Status__c, Active__c, Notification_Email__c, OwnerId, Type FROM Account ORDER BY Id"

$maskedAccounts = foreach ($row in $accounts) {
    [pscustomobject]@{
        Account_Token = Protect-Value (Get-Value $row "Id")
        Name_Token = Protect-Value (Get-Value $row "Name")
        Client_Code_Token = Protect-Value (Get-Value $row "Client_Code__c")
        Client_Code_Present = -not [string]::IsNullOrWhiteSpace([string](Get-Value $row "Client_Code__c"))
        Client_Status = Get-Value $row "Client_Status__c"
        Active_Indicator = Get-Value $row "Active__c"
        Notification_Email_Present = -not [string]::IsNullOrWhiteSpace([string](Get-Value $row "Notification_Email__c"))
        Owner_Present = -not [string]::IsNullOrWhiteSpace([string](Get-Value $row "OwnerId"))
        Type = Get-Value $row "Type"
    }
}
$r01StatusReview = foreach ($group in ($accounts | Group-Object { [string](Get-Value $_ "Client_Status__c") })) {
    [pscustomobject]@{
        Client_Status__c = $group.Name
        RecordCount = $group.Count
    }
}
$r01TypeReview = foreach ($group in ($accounts | Group-Object { [string](Get-Value $_ "Type") })) {
    [pscustomobject]@{
        Type = $group.Name
        RecordCount = $group.Count
    }
}
Export-Review "R01-account-inventory-masked.csv" $maskedAccounts | Out-Null
Export-Review "R01-status-counts.csv" $r01StatusReview | Out-Null
Export-Review "R01-type-recordtype-counts.csv" $r01TypeReview | Out-Null

$normalisedCodeGroups = $accounts |
    Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-Value $_ "Client_Code__c")) } |
    Group-Object { ([string](Get-Value $_ "Client_Code__c")).Trim().ToUpperInvariant() } |
    Where-Object { $_.Count -gt 1 }

$r02Review = foreach ($group in $normalisedCodeGroups) {
    [pscustomobject]@{
        Normalised_Code_Token = Protect-Value $group.Name
        Duplicate_Count = $group.Count
        Account_Tokens = (($group.Group | ForEach-Object { Protect-Value (Get-Value $_ "Id") }) -join ";")
    }
}
Export-Review "R02-normalised-duplicates-masked.csv" $r02Review | Out-Null

# R04 Opportunity prerequisite.
$opportunities = Invoke-ReadOnlyQuery -EvidenceId "R04" -Name "opportunities" `
    -Soql "SELECT Id, AccountId, StageName, CloseDate, IsWon, IsClosed FROM Opportunity WHERE AccountId != NULL ORDER BY AccountId, CloseDate DESC"
$r04Review = foreach ($row in $opportunities) {
    [pscustomobject]@{
        Opportunity_Token = Protect-Value (Get-Value $row "Id")
        Account_Token = Protect-Value (Get-Value $row "AccountId")
        Stage = Get-Value $row "StageName"
        Close_Date = Get-Value $row "CloseDate"
        Is_Won = Get-Value $row "IsWon"
        Is_Closed = Get-Value $row "IsClosed"
    }
}
Export-Review "R04-opportunities-masked.csv" $r04Review | Out-Null

# R05 Contract readiness.
$contracts = Invoke-ReadOnlyQuery -EvidenceId "R05" -Name "contracts" `
    -Soql "SELECT Id, AccountId, ContractNumber, Status, StartDate, ContractTerm, EndDate, OwnerId FROM Contract ORDER BY AccountId, StartDate DESC"
$r05Review = foreach ($row in $contracts) {
    [pscustomobject]@{
        Contract_Token = Protect-Value (Get-Value $row "Id")
        Account_Token = Protect-Value (Get-Value $row "AccountId")
        Contract_Number_Token = Protect-Value (Get-Value $row "ContractNumber")
        Status = Get-Value $row "Status"
        Start_Date = Get-Value $row "StartDate"
        Contract_Term = Get-Value $row "ContractTerm"
        End_Date = Get-Value $row "EndDate"
        Owner_Token = Protect-Value (Get-Value $row "OwnerId")
    }
}
Export-Review "R05-contracts-masked.csv" $r05Review | Out-Null

# R06 Contract Files, batched from R05 IDs.
$contractIds = @($contracts | ForEach-Object { Get-Value $_ "Id" } | Where-Object { $_ })
$contractLinks = @()
$chunkNumber = 0
foreach ($chunk in (Chunk-Array -Items $contractIds -Size 100)) {
    if ($chunk.Count -eq 0) { continue }
    $chunkNumber++
    $inClause = ($chunk | ForEach-Object { "'$_'" }) -join ","
    $rows = Invoke-ReadOnlyQuery -EvidenceId "R06" -Name "contract-files-$chunkNumber" `
        -Soql "SELECT Id, LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.FileType, ShareType, Visibility FROM ContentDocumentLink WHERE LinkedEntityId IN ($inClause)"
    $contractLinks += $rows
}
$r06Review = foreach ($row in $contractLinks) {
    [pscustomobject]@{
        Link_Token = Protect-Value (Get-Value $row "Id")
        Contract_Token = Protect-Value (Get-Value $row "LinkedEntityId")
        Document_Token = Protect-Value (Get-Value $row "ContentDocumentId")
        Title_Token = Protect-Value (Get-Value $row "ContentDocument.Title")
        File_Type = Get-Value $row "ContentDocument.FileType"
        Share_Type = Get-Value $row "ShareType"
        Visibility = Get-Value $row "Visibility"
    }
}
Export-Review "R06-contract-files-masked.csv" $r06Review | Out-Null

# R07 Task usage.
$r07Counts = Invoke-ReadOnlyQuery -EvidenceId "R07" -Name "task-type-status-counts" `
    -Soql "SELECT Status, COUNT(Id) RecordCount FROM Task GROUP BY Status"
$tasks = Invoke-ReadOnlyQuery -EvidenceId "R07" -Name "onboarding-like-tasks" `
    -Soql "SELECT Id, WhatId, WhoId, Subject, Status, ActivityDate, OwnerId, CreatedDate FROM Task WHERE Subject LIKE '%onboard%' OR Subject LIKE '%client%' ORDER BY CreatedDate DESC"
$r07Review = foreach ($row in $tasks) {
    [pscustomobject]@{
        Task_Token = Protect-Value (Get-Value $row "Id")
        What_Token = Protect-Value (Get-Value $row "WhatId")
        Who_Token = Protect-Value (Get-Value $row "WhoId")
        Subject_Token = Protect-Value (Get-Value $row "Subject")
        Type = "FIELD_NOT_AVAILABLE_IN_ORG"
        Status = Get-Value $row "Status"
        Activity_Date = Get-Value $row "ActivityDate"
        Owner_Token = Protect-Value (Get-Value $row "OwnerId")
        Created_Date = Get-Value $row "CreatedDate"
    }
}
Export-Review "R07-task-type-status-counts.csv" $r07Counts | Out-Null
Export-Review "R07-onboarding-like-tasks-masked.csv" $r07Review | Out-Null

# R08 active external Users.
$externalUsers = Invoke-ReadOnlyQuery -EvidenceId "R08" -Name "active-external-users" `
    -Soql "SELECT Id, Username, IsActive, UserType, Profile.Name, ContactId, Contact.AccountId FROM User WHERE ContactId != NULL AND IsActive = TRUE ORDER BY Contact.AccountId"
$r08Review = foreach ($row in $externalUsers) {
    [pscustomobject]@{
        User_Token = Protect-Value (Get-Value $row "Id")
        Username_Token = Protect-Value (Get-Value $row "Username")
        User_Type = Get-Value $row "UserType"
        Profile = Get-Value $row "Profile.Name"
        Contact_Token = Protect-Value (Get-Value $row "ContactId")
        Account_Token = Protect-Value (Get-Value $row "Contact.AccountId")
        Is_Active = Get-Value $row "IsActive"
    }
}
Export-Review "R08-active-external-users-masked.csv" $r08Review | Out-Null

# R09 roles, permissions, queues and approver candidates.
$roles = Invoke-ReadOnlyQuery -EvidenceId "R09" -Name "roles" `
    -Soql "SELECT Id, Name, DeveloperName, ParentRoleId FROM UserRole ORDER BY DeveloperName"
$assignments = Invoke-ReadOnlyQuery -EvidenceId "R09" -Name "permission-assignments" `
    -Soql "SELECT AssigneeId, PermissionSet.Name, PermissionSet.IsOwnedByProfile FROM PermissionSetAssignment WHERE PermissionSet.Name LIKE 'CBS%' ORDER BY PermissionSet.Name"
$queues = Invoke-ReadOnlyQuery -EvidenceId "R09" -Name "queues" `
    -Soql "SELECT Id, Name, DeveloperName, Type FROM Group WHERE Type = 'Queue' ORDER BY DeveloperName"
$queueObjects = Invoke-ReadOnlyQuery -EvidenceId "R09" -Name "queue-objects" `
    -Soql "SELECT QueueId, SobjectType FROM QueueSobject ORDER BY QueueId, SobjectType"
$activeAdmins = Invoke-ReadOnlyQuery -EvidenceId "R09" -Name "active-admin-candidates" `
    -Soql "SELECT Id, Username, Profile.Name, UserRole.DeveloperName, IsActive FROM User WHERE IsActive = TRUE AND (Profile.Name = 'System Administrator' OR UserRole.DeveloperName LIKE '%Admin%') ORDER BY Id"

$r09RoleReview = foreach ($row in $roles) {
    [pscustomobject]@{
        Role_Token = Protect-Value (Get-Value $row "Id")
        Name_Token = Protect-Value (Get-Value $row "Name")
        Developer_Name_Token = Protect-Value (Get-Value $row "DeveloperName")
        Parent_Token = Protect-Value (Get-Value $row "ParentRoleId")
    }
}
$r09AssignmentReview = foreach ($row in $assignments) {
    [pscustomobject]@{
        Assignee_Token = Protect-Value (Get-Value $row "AssigneeId")
        Permission_Set = Get-Value $row "PermissionSet.Name"
        Profile_Owned = Get-Value $row "PermissionSet.IsOwnedByProfile"
    }
}
$r09QueueReview = foreach ($row in $queues) {
    [pscustomobject]@{
        Queue_Token = Protect-Value (Get-Value $row "Id")
        Name_Token = Protect-Value (Get-Value $row "Name")
        Developer_Name = Get-Value $row "DeveloperName"
        Type = Get-Value $row "Type"
    }
}
$r09QueueObjectReview = foreach ($row in $queueObjects) {
    [pscustomobject]@{
        Queue_Token = Protect-Value (Get-Value $row "QueueId")
        Sobject_Type = Get-Value $row "SobjectType"
    }
}
$r09AdminReview = foreach ($row in $activeAdmins) {
    [pscustomobject]@{
        User_Token = Protect-Value (Get-Value $row "Id")
        Username_Token = Protect-Value (Get-Value $row "Username")
        Profile = Get-Value $row "Profile.Name"
        Role_Token = Protect-Value (Get-Value $row "UserRole.DeveloperName")
        Is_Active = Get-Value $row "IsActive"
    }
}
Export-Review "R09-roles-masked.csv" $r09RoleReview | Out-Null
Export-Review "R09-permission-assignments-masked.csv" $r09AssignmentReview | Out-Null
Export-Review "R09-queues-masked.csv" $r09QueueReview | Out-Null
Export-Review "R09-queue-objects-masked.csv" $r09QueueObjectReview | Out-Null
Export-Review "R09-active-admin-candidates-masked.csv" $r09AdminReview | Out-Null

# R10 optional Setup/capacity queries. Failures are captured without changing org state.
$flowDefinitions = Invoke-ReadOnlyQuery -EvidenceId "R10" -Name "flow-definitions" `
    -Soql "SELECT Id, DeveloperName, ActiveVersionId, LatestVersionId FROM FlowDefinition" -Tooling -Optional
$accountFieldDefinitions = Invoke-ReadOnlyQuery -EvidenceId "R10" -Name "account-field-history" `
    -Soql "SELECT QualifiedApiName, IsFieldHistoryTracked FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Account'" -Tooling -Optional
$userLicenses = Invoke-ReadOnlyQuery -EvidenceId "R10" -Name "user-licenses" `
    -Soql "SELECT Id, Name, Status, TotalLicenses, UsedLicenses FROM UserLicense ORDER BY Name" -Optional
$customNotifications = Invoke-ReadOnlyQuery -EvidenceId "R10" -Name "custom-notification-types" `
    -Soql "SELECT Id, DeveloperName, MasterLabel FROM CustomNotificationType ORDER BY DeveloperName" -Tooling -Optional

Export-Review "R10-flow-definitions.csv" $flowDefinitions | Out-Null
Export-Review "R10-account-field-history.csv" $accountFieldDefinitions | Out-Null
Export-Review "R10-user-licenses.csv" $userLicenses | Out-Null
Export-Review "R10-custom-notification-types.csv" $customNotifications | Out-Null

# Build the existing Account baseline decision register.
$opportunitiesByAccount = @{}
foreach ($row in $opportunities) {
    $key = [string](Get-Value $row "AccountId")
    if (-not $opportunitiesByAccount.ContainsKey($key)) { $opportunitiesByAccount[$key] = @() }
    $opportunitiesByAccount[$key] += $row
}
$contractsByAccount = @{}
foreach ($row in $contracts) {
    $key = [string](Get-Value $row "AccountId")
    if (-not $contractsByAccount.ContainsKey($key)) { $contractsByAccount[$key] = @() }
    $contractsByAccount[$key] += $row
}
$linksByContract = @{}
foreach ($row in $contractLinks) {
    $key = [string](Get-Value $row "LinkedEntityId")
    if (-not $linksByContract.ContainsKey($key)) { $linksByContract[$key] = @() }
    $linksByContract[$key] += $row
}
$tasksByAccount = @{}
foreach ($row in $tasks) {
    $key = [string](Get-Value $row "WhatId")
    if (-not $tasksByAccount.ContainsKey($key)) { $tasksByAccount[$key] = @() }
    $tasksByAccount[$key] += $row
}
$usersByAccount = @{}
foreach ($row in $externalUsers) {
    $key = [string](Get-Value $row "Contact.AccountId")
    if (-not $usersByAccount.ContainsKey($key)) { $usersByAccount[$key] = @() }
    $usersByAccount[$key] += $row
}
$duplicateKeys = @{}
foreach ($group in $normalisedCodeGroups) { $duplicateKeys[$group.Name] = $group.Count }

$baselineRows = foreach ($account in $accounts) {
    $accountId = [string](Get-Value $account "Id")
    $code = [string](Get-Value $account "Client_Code__c")
    $normalisedCode = if ([string]::IsNullOrWhiteSpace($code)) { "" } else { $code.Trim().ToUpperInvariant() }
    $accountOpportunities = @()
    if ($opportunitiesByAccount.ContainsKey($accountId)) { $accountOpportunities = @($opportunitiesByAccount[$accountId]) }
    $closedWon = @($accountOpportunities | Where-Object { [string](Get-Value $_ "StageName") -eq "Closed Won" }).Count
    $accountContracts = @()
    if ($contractsByAccount.ContainsKey($accountId)) { $accountContracts = @($contractsByAccount[$accountId]) }
    $fileCount = 0
    foreach ($contract in $accountContracts) {
        $contractId = [string](Get-Value $contract "Id")
        if ($linksByContract.ContainsKey($contractId)) { $fileCount += @($linksByContract[$contractId]).Count }
    }
    $accountTasks = @()
    if ($tasksByAccount.ContainsKey($accountId)) { $accountTasks = @($tasksByAccount[$accountId]) }
    $accountUsers = @()
    if ($usersByAccount.ContainsKey($accountId)) { $accountUsers = @($usersByAccount[$accountId]) }
    $codeStatus = if ([string]::IsNullOrWhiteSpace($code)) {
        "MISSING"
    } elseif ($duplicateKeys.ContainsKey($normalisedCode)) {
        "DUPLICATE_NORMALISED"
    } else {
        "PRESENT_UNIQUE_IN_EXPORT"
    }

    [pscustomobject]@{
        Account_ID = Protect-Value $accountId
        Masked_Account_Name = Protect-Value (Get-Value $account "Name")
        Current_Client_Status = Get-Value $account "Client_Status__c"
        Client_Code_Status = $codeStatus
        Closed_Won_Evidence = "COUNT=$closedWon"
        Contract_Evidence = "COUNT=$($accountContracts.Count)"
        Signed_File_Evidence = "LINK_COUNT=$fileCount; BUSINESS_VERIFICATION_REQUIRED"
        Existing_Onboarding_Tasks = "MATCH_COUNT=$($accountTasks.Count)"
        Active_External_Users = "COUNT=$($accountUsers.Count)"
        Proposed_Target_Status = "PENDING BUSINESS DECISION"
        Baseline_Option = "PENDING: rebuild / grandfather exception / new cycle / hold / exclude"
        Evidence_To_Rebuild = "PENDING OWNER REVIEW"
        Exception_Reason = ""
        Business_Owner = "PENDING"
        Decision = "PENDING"
        Approval_Date = ""
        Implementation_Status = "NOT AUTHORISED"
        Notes = "No automatic approval or status update"
    }
}
$baselinePath = Join-Path $repoRoot "cursor-output\decision-registers\05_existing_account_baseline_decision_register.csv"
$baselineRows | Export-Csv -LiteralPath $baselinePath -NoTypeInformation -Encoding UTF8

$trackedHistoryCount = @($accountFieldDefinitions | Where-Object {
    [string](Get-Value $_ "IsFieldHistoryTracked") -match "^(true|True)$"
}).Count
$missingClientCode = @($accounts | Where-Object {
    [string]::IsNullOrWhiteSpace([string](Get-Value $_ "Client_Code__c"))
}).Count
$missingNotification = @($accounts | Where-Object {
    [string]::IsNullOrWhiteSpace([string](Get-Value $_ "Notification_Email__c"))
}).Count
$missingOwner = @($accounts | Where-Object {
    [string]::IsNullOrWhiteSpace([string](Get-Value $_ "OwnerId"))
}).Count

$evidenceRows = @(
    [pscustomobject]@{Evidence_ID="R01";Scope="Account lifecycle profile";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Status/type distributions and Account inventory";Row_Count=$accounts.Count;Protected_Output="$privateDir\raw\R01-*";Masked="Yes";Finding="Accounts=$($accounts.Count); Missing Client Code=$missingClientCode; Missing notification=$missingNotification; Missing owner=$missingOwner";Risk="Lifecycle population requires owner review";Related_Manifest_Items="A03-001,A03-002,A03-P09";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R02";Scope="Duplicate Client Code";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Offline trim/case normalisation of read-only Account export";Row_Count=$r02Review.Count;Protected_Output="$reviewDir\R02-normalised-duplicates-masked.csv";Masked="Yes";Finding="Normalised duplicate groups=$($r02Review.Count)";Risk="Uniqueness remains gated until approved disposition";Related_Manifest_Items="A03-001";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R03";Scope="Existing Account baseline";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Account joined offline to R04-R08 evidence";Row_Count=$baselineRows.Count;Protected_Output="cursor-output/decision-registers/05_existing_account_baseline_decision_register.csv";Masked="Yes";Finding="One masked decision row per Account; all decisions pending business owner";Risk="No existing Account is automatically approved";Related_Manifest_Items="A03-001,A03-002,A03-008,A03-P09";Reviewer="";Review_Status="PENDING BUSINESS APPROVAL"},
    [pscustomobject]@{Evidence_ID="R04";Scope="Opportunity prerequisite";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Opportunity by Account and StageName";Row_Count=$opportunities.Count;Protected_Output="$reviewDir\R04-opportunities-masked.csv";Masked="Yes";Finding="Opportunities=$($opportunities.Count); Closed Won=$(@($opportunities | Where-Object { [string](Get-Value $_ 'StageName') -eq 'Closed Won' }).Count)";Risk="Per-Account prerequisite remains Flow design input";Related_Manifest_Items="A03-013,A03-015";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R05";Scope="Contract readiness";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Contract status/date/term inventory";Row_Count=$contracts.Count;Protected_Output="$reviewDir\R05-contracts-masked.csv";Masked="Yes";Finding="Contracts=$($contracts.Count)";Risk="Business validity still requires review";Related_Manifest_Items="A03-013,A03-015";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R06";Scope="Contract Files";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="ContentDocumentLink for Contract IDs from R05";Row_Count=$contractLinks.Count;Protected_Output="$reviewDir\R06-contract-files-masked.csv";Masked="Yes";Finding="Contract file links=$($contractLinks.Count); titles masked";Risk="Signed/executed meaning requires business verification";Related_Manifest_Items="A03-015";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R07";Scope="Existing Task usage";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Task Type/Status aggregate and onboarding/client subject search";Row_Count=$tasks.Count;Protected_Output="$reviewDir\R07-*";Masked="Yes";Finding="Onboarding/client-like Tasks=$($tasks.Count); aggregate rows=$($r07Counts.Count)";Risk="Collision/idempotency design review required";Related_Manifest_Items="A03-005,A03-012,A03-013,A03-014,A03-P03";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R08";Scope="External Users";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Active Users with Contact and Account";Row_Count=$externalUsers.Count;Protected_Output="$reviewDir\R08-active-external-users-masked.csv";Masked="Yes";Finding="Active external linked Users=$($externalUsers.Count)";Risk="Existing access requires Account baseline decision";Related_Manifest_Items="A03-P09,A03-P10";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R09";Scope="Roles permissions queues approvers";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Roles, CBS permission assignments, queues, queue objects, active admin candidates";Row_Count=($roles.Count+$assignments.Count+$queues.Count+$queueObjects.Count+$activeAdmins.Count);Protected_Output="$reviewDir\R09-*";Masked="Yes";Finding="Roles=$($roles.Count); CBS assignments=$($assignments.Count); queues=$($queues.Count); admin candidates=$($activeAdmins.Count)";Risk="Named checker and maker-checker routing require approval";Related_Manifest_Items="A03-006,A03-008,A03-009,A03-015,A03-016";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R10";Scope="Feature and capacity";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time=$executionTime;Query_or_Setup_Check="Tooling FlowDefinition/FieldDefinition plus licence and notification inventories";Row_Count=($flowDefinitions.Count+$accountFieldDefinitions.Count+$userLicenses.Count+$customNotifications.Count);Protected_Output="$reviewDir\R10-*";Masked="Yes";Finding="Flow definitions=$($flowDefinitions.Count); Account tracked-history fields=$trackedHistoryCount; licences=$($userLicenses.Count); notification types=$($customNotifications.Count)";Risk="Flow Approval Process availability/routing still requires Setup/metadata confirmation if query unavailable";Related_Manifest_Items="A03-003-A03-016,A03-P01-A03-P07";Reviewer="";Review_Status="PENDING REVIEW"},
    [pscustomobject]@{Evidence_ID="R11";Scope="Automation configuration drift";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time="PENDING";Query_or_Setup_Check="Fresh metadata retrieve and static comparison";Row_Count="";Protected_Output="PENDING";Masked="Yes";Finding="Pending R11/R12 retrieve stage";Risk="Org drift unknown until retrieve";Related_Manifest_Items="A03-013-A03-016,A03-P10";Reviewer="";Review_Status="PENDING"},
    [pscustomobject]@{Evidence_ID="R12";Scope="Latest baseline comparison";Org_ID=$ExpectedOrgId;Executor=$ExpectedUsername;Execution_Time="PENDING";Query_or_Setup_Check="Fresh retrieve/hash/diff";Row_Count="";Protected_Output="PENDING";Masked="Yes";Finding="Pending R11/R12 retrieve stage";Risk="Do not implement before comparison";Related_Manifest_Items="ALL";Reviewer="";Review_Status="PENDING"}
)

$registerPath = Join-Path $PSScriptRoot "04_runtime_evidence_register.csv"
$evidenceRows | Export-Csv -LiteralPath $registerPath -NoTypeInformation -Encoding UTF8

$summary = @"
# R01-R10 Automated Read-only Execution Summary

- Target alias: $TargetOrg
- Org ID: $ExpectedOrgId
- Executing user: $ExpectedUsername
- Execution time: $executionTime
- Raw output: $privateDir (outside Git repository)
- Masked review output: cursor-output/runtime-evidence/masked-review
- DML/deployment/activation: none

## Counts

- Accounts: $($accounts.Count)
- Normalised duplicate Client Code groups: $($r02Review.Count)
- Opportunities: $($opportunities.Count)
- Contracts: $($contracts.Count)
- Contract File links: $($contractLinks.Count)
- Onboarding/client-like Tasks: $($tasks.Count)
- Active external linked Users: $($externalUsers.Count)
- Roles: $($roles.Count)
- CBS permission assignments: $($assignments.Count)
- Queues: $($queues.Count)
- Active administrator candidates: $($activeAdmins.Count)
- Flow definitions returned: $($flowDefinitions.Count)
- Account history fields tracked: $trackedHistoryCount

R03 business decisions, signed-file interpretation, approver selection and activation decisions remain subject to owner review. R11-R12 are executed separately through fresh metadata retrieve/hash/diff.
"@
Set-Content -LiteralPath (Join-Path $PSScriptRoot "R01-R10_execution_summary.md") -Value $summary -Encoding UTF8

Write-Output "R01_R10_COMPLETE"
Write-Output "ORG_ID=$ExpectedOrgId"
Write-Output "EXECUTOR=$ExpectedUsername"
Write-Output "ACCOUNTS=$($accounts.Count)"
Write-Output "DUPLICATE_GROUPS=$($r02Review.Count)"
Write-Output "CONTRACT_FILE_LINKS=$($contractLinks.Count)"
Write-Output "QUERY_ERROR_LOG=$errorLog"
