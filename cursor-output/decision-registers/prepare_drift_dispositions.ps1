param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$diffPath = Join-Path $repoRoot "cursor-output\runtime-evidence\R11_R12_fresh_retrieve_diff.csv"
$outputPath = Join-Path $PSScriptRoot "14_r11_r12_drift_disposition_register.csv"
$summaryPath = Join-Path $PSScriptRoot "14_r11_r12_drift_disposition_summary.md"

$manifestOmissionPaths = @(
    "classes/AImp02ContactSeparationTest.cls",
    "classes/AImp02ContactSeparationTest.cls-meta.xml",
    "flexipages/CBS_Client_User_Record_Page.flexipage-meta.xml",
    "flows/Consent_Request_Item_Maintain_Active_Key.flow-meta.xml",
    "flows/ConsentRequestResolveActiveRequest.flow-meta.xml"
)

$rows = @(Import-Csv -LiteralPath $diffPath -Encoding UTF8)
$dispositions = foreach ($row in $rows) {
    $path = $row.Relative_Path
    $risk = "LOW"

    if ($manifestOmissionPaths -contains $path) {
        $category = "EXPECTED_A_IMP_02_BASELINE_AHEAD"
        $disposition = "ACCEPTED - TARGETED RETRIEVE MATCHED BASELINE"
        $action = "Add these A-IMP-02 members to the next full comparison manifest; no source change."
        $evidence = "The full-retrieve manifest omitted the A-IMP-02 addition. Targeted retrieve returned it and normalised content matched the branch baseline."
    } elseif ($path -eq "flowDefinitions/contactApproveCreateConsentRequest.flowDefinition-meta.xml") {
        $category = "SANDBOX_AHEAD_REQUIRES_BASELINE_UPDATE"
        $disposition = "HOLD - A-IMP-02 OWNER APPROVAL REQUIRED"
        $action = "A-IMP-02 owner must approve controlled baseline reconciliation from active version 5 to 6."
        $evidence = "Only activeVersionNumber changed from 5 to 6 and the Flow body matches, but the FlowDefinition is REVIEW_ONLY/BLOCKED and cannot be copied automatically."
        $risk = "HIGH"
    } elseif ($path -eq "labels/CustomLabels.labels-meta.xml") {
        $category = "EXPECTED_RETRIEVE_NOISE"
        $disposition = "ACCEPTED RETRIEVE NORMALISATION"
        $action = "Ignore element ordering; retain controlled baseline."
        $evidence = "Git comparison showed the same labels and values reordered by retrieve."
    } elseif ($path -match "^objects/Consent_Request_Item__c/fields/(Active_Request_Key__c|Consent_Purpose__c)\.field-meta\.xml$") {
        $category = "EXPECTED_RETRIEVE_NOISE"
        $disposition = "ACCEPTED RETRIEVE NORMALISATION"
        $action = "Do not modify A-IMP-03 source; retain A-IMP-02 ownership."
        $evidence = "Sandbox added explicit default tags such as trackTrending=false and encryptionScheme=None."
    } elseif ($path -match "^objectTranslations/Consent_Request_Item__c-en_US/") {
        $category = "EXPECTED_RETRIEVE_NOISE"
        $disposition = "ACCEPTED RETRIEVE NORMALISATION"
        $action = "Exclude from A-IMP-03 Manifest."
        $evidence = "Translation stubs were generated for A-IMP-02 fields and contain no A-IMP-03 behaviour."
    } elseif ($path -eq "layouts/Contact-Contact Layout.layout-meta.xml") {
        $category = "TRUE_CONFLICT_REQUIRES_OWNER"
        $disposition = "HOLD - A-IMP-02 OWNER DECISION REQUIRED"
        $action = "A-IMP-02 owner must reconcile the standard Contact layout as-built; A-IMP-03 must not modify it."
        $evidence = "Sandbox removed four identity fields/mini-layout entries that remain Required in the branch baseline; this was not an approved shared-layout change."
        $risk = "HIGH"
    } elseif ($path -eq "queues/CBS_Processing_Queue.queue-meta.xml") {
        $category = "TRUE_CONFLICT_REQUIRES_OWNER"
        $disposition = "HOLD - OPERATIONS/SECURITY OWNER DECISION REQUIRED"
        $action = "Keep named queue membership outside A-IMP-03 source; obtain routing owner approval under R09/R10."
        $evidence = "Sandbox contains a named user member not present in the baseline queue metadata."
        $risk = "HIGH"
    } elseif ($path -match "^profiles/") {
        $category = "TRUE_CONFLICT_REQUIRES_OWNER"
        $disposition = "HOLD - SECURITY/ACCESS OWNER DECISION REQUIRED"
        $action = "Do not bulk-copy profiles. Review effective access and use approved permission sets/minimal access only."
        $evidence = "Sandbox adds six FLS entries absent from the branch, including four editable Contact identity fields across external, guest, integration and standard profiles."
        $risk = "HIGH"
    } elseif ($path -match "^settings/") {
        $category = "EXPECTED_RETRIEVE_NOISE"
        $disposition = "ACCEPTED RETRIEVE NORMALISATION"
        $action = "Do not import whole-org settings into the A-IMP-03 branch."
        $evidence = "Differences are platform/API explicit-default or omitted-default settings with no changed business value."
    } elseif ($path -match "^(cleanDataServices|objects/(BatchJobPart|Order|Quote))/") {
        $category = "EXPECTED_RETRIEVE_NOISE"
        $disposition = "ACCEPTED RETRIEVE NORMALISATION"
        $action = "Exclude from A-IMP-03 Manifest."
        $evidence = "Standard/platform-managed metadata differs only by generated defaults or ordering."
    } elseif ($path -match "^networks/") {
        $category = "EXPECTED_RETRIEVE_NOISE"
        $disposition = "ACCEPTED RETRIEVE NORMALISATION"
        $action = "Do not import Experience Cloud runtime ordering/default metadata."
        $evidence = "Comparison found generated default action overrides/order only, with no business or activation-state change."
    } elseif ($path -eq "objectTranslations/Contact-en_US/Contact-en_US.objectTranslation-meta.xml") {
        $category = "EXPECTED_RETRIEVE_NOISE"
        $disposition = "ACCEPTED RETRIEVE NORMALISATION"
        $action = "Exclude empty/comment-only translation context from A-IMP-03."
        $evidence = "Translation difference contains no changed label or business value."
    } elseif ($path -eq "siteDotComSites/PartnerCommunity2.site") {
        $category = "OTHER_REVIEW"
        $disposition = "HOLD - SEMANTIC SITE.COM COMPARISON REQUIRED"
        $action = "Obtain a controlled Site.com export/publish-version comparison before classification."
        $evidence = "The artifact is binary; byte differences cannot prove semantic or publish-state changes."
        $risk = "HIGH"
    } else {
        $category = "OWNER_REVIEW_REQUIRED"
        $disposition = "HOLD"
        $action = "Obtain component owner disposition before Phase 2."
        $evidence = "No safe automatic classification rule applied."
        $risk = "HIGH"
    }

    [pscustomobject]@{
        Relative_Path = $path
        Original_Difference = $row.Difference
        Category = $category
        Disposition = $disposition
        Risk = $risk
        Evidence = $evidence
        Required_Action = $action
        A_IMP_03_Source_Change_Authorised = "NO"
        Owner_Signoff = if ($category -match "^(EXPECTED_RETRIEVE_NOISE|EXPECTED_A_IMP_02_BASELINE_AHEAD)$") { "NOT REQUIRED FOR A-IMP-03" } else { "PENDING" }
    }
}

$dispositions | Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding UTF8
$groups = @($dispositions | Group-Object Category | Sort-Object Name)
$unclassified = @($dispositions | Where-Object { $_.Category -eq "OWNER_REVIEW_REQUIRED" })
$ownerGated = @($dispositions | Where-Object {
    $_.Category -match "^(TRUE_CONFLICT_REQUIRES_OWNER|SANDBOX_AHEAD_REQUIRES_BASELINE_UPDATE|OTHER_REVIEW)$"
})

$summary = @(
    "# R11-R12 Drift Disposition Summary",
    "",
    "- Original byte-level differences: $($dispositions.Count)",
    "- Unclassified differences: $($unclassified.Count)",
    "- Owner-gated/review paths: $($ownerGated.Count)",
    "- Metadata source changes authorised: none",
    "",
    "## Category counts",
    ""
)
foreach ($group in $groups) {
    $summary += "- $($group.Name): $($group.Count)"
}
$summary += @(
    "",
    "The five baseline-only A-IMP-02 components were caused by omissions in package-full.xml; targeted retrieve confirmed normalised content matches.",
    "",
    "Phase 2 remains HOLD for 28 owner conflicts (26 profiles, Contact layout and queue), one A-IMP-02 FlowDefinition baseline reconciliation, and one binary Site.com semantic review.",
    "",
    "No disposition authorises deployment, DML, activation or copying live-org metadata into the branch."
)
Set-Content -LiteralPath $summaryPath -Value ($summary -join [Environment]::NewLine) -Encoding UTF8

Write-Output "DRIFT_DISPOSITIONS_COMPLETE"
Write-Output "TOTAL=$($dispositions.Count)"
Write-Output "UNCLASSIFIED=$($unclassified.Count)"
Write-Output "OWNER_GATED=$($ownerGated.Count)"
foreach ($group in $groups) {
    Write-Output "$($group.Name)=$($group.Count)"
}
