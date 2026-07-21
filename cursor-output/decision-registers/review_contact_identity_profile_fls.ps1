param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$archiveRoot = "C:\WorkSpace\CBS-A-IMP-03-runtime-private\fresh-retrieve-20260721T055213Z"
$driftRegisterPath = Join-Path $PSScriptRoot "14_r11_r12_drift_disposition_register.csv"
$outputPath = Join-Path $PSScriptRoot "15_contact_identity_profile_fls_review.csv"
$summaryPath = Join-Path $PSScriptRoot "15_contact_identity_profile_fls_review_summary.md"

$fields = @(
    "Contact.Employment_Status__c",
    "Contact.Full_Name__c",
    "Contact.ID_Number__c",
    "Contact.ID_Type__c"
)

$profilePaths = @(Import-Csv -LiteralPath $driftRegisterPath -Encoding UTF8 |
    Where-Object { $_.Relative_Path -match "^profiles/" } |
    Select-Object -ExpandProperty Relative_Path)

$reviewRows = foreach ($relativePath in $profilePaths) {
    $fullPath = Join-Path $archiveRoot ($relativePath.Replace("/", "\"))
    if (-not (Test-Path -LiteralPath $fullPath)) { throw "Profile archive file not found: $relativePath" }

    [xml]$xml = Get-Content -LiteralPath $fullPath -Raw -Encoding UTF8
    $namespace = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $namespace.AddNamespace("m", "http://soap.sforce.com/2006/04/metadata")
    $profileName = [System.IO.Path]::GetFileName($relativePath).Replace(".profile-meta.xml", "")

    $values = @{}
    foreach ($fieldName in $fields) {
        $escapedField = $fieldName.Replace("'", "&apos;")
        $node = $xml.SelectSingleNode("//m:fieldPermissions[m:field='$escapedField']", $namespace)
        $values[$fieldName] = [pscustomobject]@{
            Readable = if ($null -eq $node) { "ABSENT" } else { [string]$node.readable }
            Editable = if ($null -eq $node) { "ABSENT" } else { [string]$node.editable }
        }
    }

    $isAdmin = $profileName -eq "Admin"
    $isExternalOrRestricted = $profileName -match "Chatter|Community|Guest|Partner|QR Code|Read Only|Integration|API Only|Customer"
    $recommendation = if ($isAdmin) {
        "KEEP_ADMIN_EDITABLE"
    } else {
        "REMOVE_PROFILE_EDITABLE_USE_APPROVED_PERMISSION_SET_IF_REQUIRED"
    }
    $risk = if ($isAdmin) {
        "LOW"
    } elseif ($isExternalOrRestricted) {
        "CRITICAL"
    } else {
        "HIGH"
    }

    [pscustomobject]@{
        Profile = $profileName
        Employment_Status_Readable = $values["Contact.Employment_Status__c"].Readable
        Employment_Status_Editable = $values["Contact.Employment_Status__c"].Editable
        Full_Name_Readable = $values["Contact.Full_Name__c"].Readable
        Full_Name_Editable = $values["Contact.Full_Name__c"].Editable
        ID_Number_Readable = $values["Contact.ID_Number__c"].Readable
        ID_Number_Editable = $values["Contact.ID_Number__c"].Editable
        ID_Type_Readable = $values["Contact.ID_Type__c"].Readable
        ID_Type_Editable = $values["Contact.ID_Type__c"].Editable
        Risk = $risk
        Recommended_Policy = $recommendation
        Security_Owner_Decision = "PENDING"
        Metadata_Change_Authorised = "NO"
    }
}

$reviewRows | Sort-Object Profile | Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding UTF8
$allEditable = @($reviewRows | Where-Object {
    $_.Employment_Status_Editable -eq "true" -and
    $_.Full_Name_Editable -eq "true" -and
    $_.ID_Number_Editable -eq "true" -and
    $_.ID_Type_Editable -eq "true"
})
$critical = @($reviewRows | Where-Object { $_.Risk -eq "CRITICAL" })

$summary = @"
# Contact Identity Profile FLS Review

- Profiles reviewed: $($reviewRows.Count)
- Profiles with all four fields editable: $($allEditable.Count)
- Critical external/restricted profiles: $($critical.Count)
- Metadata changes authorised: none

## Finding

All 26 Sandbox Profiles expose Employment_Status__c, Full_Name__c, ID_Number__c and ID_Type__c as readable and editable. This is broader than the approved A-IMP-02 layout-assignment scope and includes external, guest, community, partner, read-only and integration/API profiles.

## Recommended policy

1. Retain editable access only for Admin.
2. Remove direct editable FLS from the other 25 Profiles.
3. Grant any approved internal exception through a narrowly scoped Permission Set, not broad Profile edits.
4. Do not grant the four identity fields to external, guest, community or partner users.
5. Security/A-IMP-08 written approval is required before metadata implementation.
"@
Set-Content -LiteralPath $summaryPath -Value $summary -Encoding UTF8

Write-Output "PROFILE_FLS_REVIEW_COMPLETE"
Write-Output "PROFILES=$($reviewRows.Count)"
Write-Output "ALL_FOUR_EDITABLE=$($allEditable.Count)"
Write-Output "CRITICAL=$($critical.Count)"
