# R11-R12 Fresh Retrieve Comparison

- Org ID: 00DBK00000C9kEP2AZ
- Executing user: cbsneworg@creditbureau.com.sg.chentest
- Execution time: 2026-07-21T13:52:13+08:00
- Baseline commit: ed2f984c8b0e0afcb3308a09a5eccdba5daa5916
- Baseline files: 5127
- Fresh Sandbox files: 5124
- Total differences: 61
- Sandbox-only files: 2
- Baseline-only files: 5
- Content-changed files: 54
- Automation-scope differences: 5
- Hash method: SHA-256 after CRLF/LF normalisation and trailing whitespace removal
- DML/deployment/activation: none

The full and automation-scoped path/hash differences are recorded in CSV. Any difference remains review-gated; this comparison does not authorise metadata changes.

## Disposition update

- All 61 original paths classified; unclassified: 0.
- Five baseline-only A-IMP-02 components were omitted from `package-full.xml`; targeted retrieve confirmed normalised content matches.
- Classification: 26 expected retrieve-noise paths, 5 expected A-IMP-02 baseline-ahead paths, 1 Sandbox-ahead FlowDefinition, 28 true owner conflicts and 1 binary Site.com review.
- The Flow body matches, but active version 5 versus Sandbox version 6 remains an A-IMP-02 owner-controlled baseline reconciliation.
- Decisions recorded: adopt Sandbox FlowDefinition version 6 through A-IMP-02; adopt Sandbox Contact layout state through A-IMP-02; retain the ChenTest queue user assignment; exclude Site.com as unrelated to A-IMP-03.
- Profile policy confirmed: preserve current readable/editable FLS for all four identity fields across all 26 Profiles; the broad external/restricted-profile exposure is explicitly recorded.
- Remaining follow-up: two controlled A-IMP-02 baseline updates and 26 controlled A-IMP-08 Profile baseline reconciliations, followed by A-IMP-03 rebase and R11/R12 rerun.
- Exact dispositions: `cursor-output/decision-registers/14_r11_r12_drift_disposition_register.csv`.
