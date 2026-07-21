# A-IMP-03 Rollback Runbook — Draft

This is a planning draft. Rollback actions require release-owner approval and a tested restore package.

## Preconditions

- Preserve approved pre-deployment metadata package and commit.
- Preserve protected before-values, record counts, Account decision register and Task/approval evidence.
- Step 7 approved dispositions in `decision-registers/05_existing_account_baseline_decision_register.csv` govern any approved restore/skip decisions.
- Record every deployed component, active version, assignment and manual runtime action.
- Never delete audit/history or business records merely to make rollback easier.

## Rollback sequence

1. Stop new onboarding entry through the approved operational control.
2. Deactivate completion notification, return/cancel, approval submission, start and Task synchronisation Flows in reverse dependency order.
3. Deactivate/disable the approval process and safely recall/unlock affected test records under administrator control.
4. Disable new validation/uniqueness controls if they block approved restoration.
5. Restore changed metadata from the approved pre-deployment commit:
   - `Client_Code__c` and `Client_Status__c`;
   - Task Type;
   - Account history flags;
   - any approved permissions/layout exposure.
6. Restore data only from owner-approved before-values:
   - never automatically overwrite later legitimate business changes;
   - preserve onboarding/approval evidence;
   - reconcile every restored/skipped row.
7. Remove newly created fields/components only when they contain no required business or audit evidence and removal is separately approved. Otherwise leave them inaccessible/inert.
8. Remove `Client Onboarding` Task Type only after approved migration of all Tasks using it.
9. Re-run lifecycle, Task, external access and A-IMP-02 regression checks.
10. Fresh retrieve and compare with the approved rollback target.

## Component-specific controls

- `Onboarding_Approved__c`: disable downstream A-IMP-06 use before restoring values or access.
- Approval history: retain as authoritative evidence; do not erase.
- Task completion/evidence fields: export and retain before any component removal.
- Client Status values: do not remove a value while records still use it.
- Client Code uniqueness: disable constraint before a necessary restore, but retain the duplicate-risk register.
- Field history: restoring metadata does not remove existing history; document retention behaviour.

## Rollback verification

- No active A-IMP-03 Flow or approval remains unless explicitly retained.
- Account/Task counts reconcile with the rollback decision log.
- Existing external access is not expanded.
- A-IMP-02 Client User/Data Subject behaviour passes regression.
- No Production/UAT action is inferred from this draft.
