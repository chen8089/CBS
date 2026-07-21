# A-IMP-03 Phase 2 Re-authorisation Record

- Recorded: 2026-07-21 (UTC+8)
- Channel: Cursor user instruction
- Prior state: pure Phase 1 baseline reset (`23_phase1_baseline_reset_record.md`)
- Authorisation basis:
  - Exact Manifest written approval: 陈财 / CBS系统负责人, 2026-07-21
  - Step 7 Account baseline policy approval: 陈财 / CBS系统负责人, 2026-07-21
  - User re-authorisation: **Phase 2 Wave 1 restored and active**

## Authorised scope (immediate)

| Item_ID | Component | Action |
|---|---|---|
| A03-003 | `Account.Onboarding_Status__c` | CREATE — Wave 1 inert field |
| A03-004 | `Account.Onboarding_Cycle__c` | CREATE — Wave 1 inert field |

## Still not authorised

- Sandbox deployment (unless separately requested)
- Flow/approval activation
- RUNTIME GATED and HOLD Manifest rows
- Wave 2 data remediation DML
- Production / UAT
- Layout, FLS, validation rules

## Source restored from

`cursor-output/isolated/phase2-wave1-reverted-2026-07-21/`

## Controlled state

`A-IMP-03 PHASE 2 WAVE 1 AUTHORISED — BUILD IN WORKSPACE; DEPLOYMENT SEPARATELY GATED`
