# Cursor Phase 1 Startup Confirmation

- Project root: `C:\WorkSpace\CBS-A-IMP-03-Remote`
- API: 67.0
- Baseline: `Credit Bureau Sandbox 20260715.zip`
- Baseline SHA-256: `a3c337d997a556dca2cd53492a5621dce09a39b4f9454ac0d24e7d88a6a93a80`
- Branch: `feature/A-IMP-03-account-onboarding`
- Original Phase 1 analysis baseline commit: `0c1bd8793ad8caa8871d1deb46f4b87142fac3db` in the archived isolated workspace
- Current clean branch commit: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- Baseline classification: A-IMP-03 child branch at the approved A-IMP-02 remote tip
- Remote branch: `origin/feature/A-IMP-03-account-onboarding`, created on 2026-07-21 13:19 (UTC+8) from A-IMP-02 tip `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`

The prior independently initialised workspace is retained only as audit evidence. This clean clone tracks `origin/feature/A-IMP-03-account-onboarding`; its HEAD, A-IMP-03 remote tip and A-IMP-02 parent tip are all `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`. No metadata source change was introduced while migrating Phase 1 artifacts.

## Seven controlled inputs

1. `CBS_Category_A_A-IMP-03_客户账户生命周期与客户入驻_Cursor受控执行提示词_CN_v1.0.docx` — A-IMP-03 confirmed decisions and execution authority.
2. `CBS_Category_A_Solution_Design_v1.4_Visual_Approved_and_Implementation_Ready.docx` — approved functional target.
3. `CBS_Category_A_A-IMP-01_Implementation_Mapping_and_Deployment_Plan_v1.1_Corrected.docx` — canonical technical names and workstream boundaries.
4. `CBS_Category_A_A-IMP-02_Client_User_and_Data_Subject_Separation_Cursor_Execution_Prompt_v1.0.docx` — dependency execution boundary.
5. `CBS_Category_A_A-IMP-02_Phase_1_Pre_Change_Impact_Report_v1.1_Revised_for_Final_Phase_2_Approval.docx` — A-IMP-02 decision/status evidence.
6. `CBS_Category_A_A-IMP-02_Exact_Metadata_Manifest_v1.1_Revised.csv` — overlap and rebase control.
7. `Credit Bureau Sandbox 20260715.zip` — current-state technical baseline.

`SHA256SUMS.txt` is the sole checksum authority per delivery-owner instruction. The Word lock file and guide-embedded hashes are ignored.

## A-IMP-02 status

Version v1.1 controlled documents originally state: `Decision complete - final approval and runtime evidence gate pending`. On 2026-07-21 13:15 (UTC+8), the repository was connected to `https://github.com/chen8089/CBS.git` and `origin/feature/A-IMP-02-contact-separation` was fetched. The remote tip is `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916` (`Record Client User deployment retrievals`, 2026-07-21 09:35:58 +08:00). Its approval package records `A-IMP-02 PHASE 2 CHENTEST IMPLEMENTATION APPROVED`, ChenTest deployment/retrieval evidence, approved baseline `8391a967683f5e07b3a4f4b01fe1db927fbff054`, and no Production/UAT authorisation. Phase 2 A-IMP-03 must use the then-approved post-A-IMP-02 tip/as-built baseline, rebase, diff, revalidate the Manifest and run regression.

## Authority boundary

This run is Phase 1 analysis only. Cursor will not modify metadata source, execute DML, run write-capable anonymous Apex/Flow, deploy, activate/deactivate, perform Production operations or UAT. Runtime evidence must be executed by an authorised Sandbox operator. Any Manifest-external component remains a proposed amendment only.
