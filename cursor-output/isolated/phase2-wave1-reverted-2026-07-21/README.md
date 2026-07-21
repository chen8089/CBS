# Phase 2 Wave 1 Revert — Isolated Archive

- Reverted: 2026-07-21 (UTC+8)
- Reason: reset workspace to pure Phase 1 baseline per user instruction
- Phase 1 boundary restored: no metadata source files under `force-app/` or `manifest/` outside approved Phase 1 state

## Isolated files

| Original path | Archive path |
|---|---|
| `force-app/.../Onboarding_Status__c.field-meta.xml` | `force-app/main/default/objects/Account/fields/Onboarding_Status__c.field-meta.xml` |
| `force-app/.../Onboarding_Cycle__c.field-meta.xml` | `force-app/main/default/objects/Account/fields/Onboarding_Cycle__c.field-meta.xml` |
| `manifest/package-A-IMP-03-wave1.xml` | `manifest/package-A-IMP-03-wave1.xml` |

These files are **not** active source. Restore only under explicit Phase 2 re-authorisation.

## Superseded record

- `cursor-output/pre-change-analysis/22_phase2_wave1_execution_record.md` — superseded; do not use for current baseline

## Current baseline

- Git HEAD: `ed2f984c8b0e0afcb3308a09a5eccdba5daa5916`
- `force-app` working tree: clean (no A-IMP-03 Wave 1 untracked files)
- Phase 1 artifacts: retained under `cursor-output/`
- Manifest approval: retained (`20_manifest_written_approval_2026-07-21.md`)
