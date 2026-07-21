# A03-P08 Amendment — Scope Decision (Minimum Internal Test Exposure)

- Decision date: 2026-07-21 (UTC+8)
- Decision owner: 陈财 / CBS系统负责人 (execution authorised in chat)
- Workstream: A-IMP-03 Phase 2
- Manifest row: **A03-P08**

## Scope choice

| Option | Decision |
|---|---|
| Full A-IMP-11 (Section 15/18 final Account page, Path, actions, app assignment) | **Not in scope** — requires A-IMP-11 execution prompt, Section 18 visual gate and final BD workspace |
| **A-IMP-03 minimum internal test exposure (A03-P08 amendment)** | **Approved and implemented** |

## What is included (C030–C032)

| ID | Component | Implementation |
|---|---|---|
| C030 | FLS | Permission sets `CBS_Business_Development_Onboarding_Internal_Test` (read-only) and `CBS_Administrator_Onboarding_Internal_Test` (edit). Admin profile not deployed (org tab-setting drift); assign Admin permission set to internal test admins |
| C031 | Layout | `Account-CBS Account Layout` — section **客户入驻（内部测试）** with Status (Edit) and Cycle (Readonly) |
| C032 | FlexiPage | New `Account_CBS_Onboarding_Internal_Test` — layout-driven `force:detailPanel`; **not** assigned in app metadata |

## Explicit exclusions (unchanged)

- No external User FLS, permission set assignment or Experience/Community exposure
- No `Onboarding_Approved__c` field, write, or backfill
- No Flow, approval, validation, Path, quick actions or Credit Bureau app page override (C033 deferred)
- No modification to `Account_Record_Page_Three_Column` (standard Sales default remains generic)
- Full A-IMP-08 CBS Business Development role/permission set and A-IMP-11 final page remain downstream

## Deployment package

Independent of Wave 1:

- `manifest/package-A-IMP-03-min-exposure.xml`

Wave 1 fields (`package-A-IMP-03-wave1.xml`) must already exist in target org before this package.

## ChenTest manual steps after deploy

1. Assign `CBS_Administrator_Onboarding_Internal_Test` to designated internal Admin test users.
2. Assign `CBS_Business_Development_Onboarding_Internal_Test` only to designated **internal** sandbox BD test users (never external/community users).
3. Optionally set **Account CBS Onboarding Internal Test** as org-default or app-default Account record page for Admin test profile only (Setup → Object Manager → Account → Lightning Record Pages). Do not assign to external profiles.

4. R09 negative check: external/community users must not see onboarding fields even though CBS Account Layout is shared (FLS gate).

## Rollback

Remove permission set assignment, revert layout section, delete flexipage and permission set metadata; restore Admin profile FLS from approved backup if separately authorised.
