# A-IMP-02 Rollback Runbook Draft

Status: Gate 1 planning only

Rollback is component-based and non-destructive. No rollback command is
authorised in Gate 1.

## Preconditions

- Named rollback authority and checker
- Approved pre-change metadata package
- Approved data backup for any separately authorised remediation
- Deployment and test evidence identifying the failed wave
- Confirmation that rollback does not reintroduce a P1 privacy defect

## Component rollback

### M001-M004 and M009A-M009C

- Deactivate the new scoped rules.
- Restore the four prior field XML files only as a complete rollback package.
- Never restore global requiredness while scoped rules remain partially active.

### M005-M011

- Restore prior Portal Role labels and Client User Record Type values.
- Deactivate/delete only newly created validation rules.
- Do not alter existing record values automatically.

### M012-M014

- Restore the prior active `contactApproveCreateConsentRequest` Flow version.
- Verify that no duplicate active creator remains.
- Close only test Cases under a separately approved test cleanup procedure.

### M013A-M013D

- Deactivate the active-key maintenance Flow.
- Stop new key generation.
- Export existing purpose/key values before any approved field removal.
- Clear generated keys only under separate data approval.
- Do not modify terminal consent requests automatically.

### M015-M016

- Restore the prior Apex class and test class from the approved baseline.
- Run upload regression before accepting rollback.

### M017-M020

- Restore prior layouts and application override.
- Remove the new FlexiPage only after assignments are restored.
- Do not change deferred external profile assignments.

### M022-M023

- Deactivate the Client User Duplicate Rule and Matching Rule.
- Do not merge or delete duplicate Contacts.

### M024-M025

- Restore the approved pre-change object and field XML.
- Preserve already-written field-history evidence according to retention policy.
- Do not enable tracking on PII/MyInfo fields.

## Data restoration boundary

No Salesforce record restoration is authorised by this draft. Any restoration
requires:

- an approved backup CSV;
- record-level owner approval;
- before/after values;
- count reconciliation;
- a separate execution log.

## Rollback verification

- Metadata deploy validation passes.
- No duplicate active Flow exists.
- Category B-I regression passes.
- Client User creation produces no consent request.
- External access is no broader than the approved baseline.
- All residual deviations are recorded.

## Stop conditions

- Rollback would cause data loss.
- Rollback would reintroduce Client User consent contamination.
- Required backup is missing.
- Baseline package cannot be proven.
- Category B-I or external-access regression fails.
