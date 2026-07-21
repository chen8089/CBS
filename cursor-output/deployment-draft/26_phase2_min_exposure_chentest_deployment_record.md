# Phase 2 Minimum Exposure (A03-P08) ChenTest Deployment Record

- Deployed: 2026-07-21 (UTC+8)
- Org: ChenTest `00DBK00000C9kEP2AZ`
- Alias: `CBS-A-IMP-03`
- User: `cbsneworg@creditbureau.com.sg.chentest`
- Deploy ID: `0AfBK00000BV2oo0AD`
- Status: **Succeeded**
- Elapsed: ~3.22s
- Test level: NoTestRun
- Prior failed attempt: `0AfBK00000BV6Z30AL` (Admin profile tab-setting drift — not deployed)

## Package

`manifest/package-A-IMP-03-min-exposure.xml` (API 67.0)

Independent of Wave 1 (`manifest/package-A-IMP-03-wave1.xml`). Requires Wave 1 fields already present in org.

## Components deployed

| State | Name | Type |
|---|---|---|
| Created | `Account_CBS_Onboarding_Internal_Test` | FlexiPage |
| Changed | `Account-CBS Account Layout` | Layout |
| Created | `CBS_Administrator_Onboarding_Internal_Test` | PermissionSet |
| Created | `CBS_Business_Development_Onboarding_Internal_Test` | PermissionSet |

## Boundaries preserved

- No external User FLS or permission set assignment in this deploy
- No `Onboarding_Approved__c` field or write
- No Flow, approval, validation, Path, app navigation (C033) or `Account_Record_Page_Three_Column` change
- Not full A-IMP-11 — see `decision-registers/26_a03_p08_amendment_scope_decision_2026-07-21.md`

## Post-deploy manual steps (ChenTest)

1. Assign `CBS_Administrator_Onboarding_Internal_Test` to internal Admin test user(s).
2. Assign `CBS_Business_Development_Onboarding_Internal_Test` to internal BD test user(s) only.
3. Optionally activate `Account CBS Onboarding Internal Test` as Account Lightning page for internal test profiles.
4. R09 negative check: confirm external/community users do not see onboarding fields.

## Rollback reference

Remove permission set assignments; redeploy prior layout from approved backup; delete flexipage and permission sets if separately approved. See `rollback-draft/09_rollback_runbook_draft.md`.
