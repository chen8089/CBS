# A-IMP-02 Phase 2 Approval Submission Summary

Submission status: A-IMP-02 PHASE 2 CHENTEST IMPLEMENTATION APPROVED

## Scope

This package combines:

- controlled-file and SHA-256 verification;
- 37-row Manifest static validation;
- metadata dependency and drift analysis;
- R01-R08 masked Sandbox evidence;
- R09-01 Contact history capacity evidence and the remaining R09 checklist;
- three business disposition register drafts;
- updated implementation Manifest;
- runtime evidence mapping;
- risk/conflict register;
- final candidate file list.

Approved scoped Salesforce metadata was deployed to ChenTest. No Salesforce
business record was modified by this implementation activity.

## Completed

1. Baseline ZIP SHA-256 verified:
   `a3c337d997a556dca2cd53492a5621dce09a39b4f9454ac0d24e7d88a6a93a80`.
2. API version `67.0` confirmed.
3. Exact Manifest v1.1 validated: 37 rows and 37 unique IDs.
4. Static component and dependency scans completed.
5. Candidate paths classified as add, modify, retain, deferred, read-only or
   pending approval.
6. R01-R08 executed against the confirmed `ChenTest CBS` Sandbox using SELECT
   only.
7. Result CSVs reconciled to recorded row counts.
8. Review copies mask Email, Username and Salesforce record IDs with stable
   SHA-256-derived tokens.
9. Three business disposition register drafts created.
10. A-IMP-08 and A-IMP-09 boundaries reconfirmed.
11. No new object, API rename, automatic merge/delete, record-type conversion
    or cross-Category change is proposed.
12. R09-01 Contact history capacity collected: 17 of 20 standard fields
    tracked; the M025 replacement target is 6 of 20.

## Runtime evidence summary

- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- R01: 122 Contacts
  - Singpass: 119
  - Non_Singpass: 2
  - Data_Subject: 1
  - Client_User: 0
- R02: 0 Client User prohibited-data rows
- R03: 0 legacy Client Admin rows
- R04: remediated from 117 rows to 0; RC02 approved
- R05: 0 duplicate Client User groups
- R06-CORRECTED-01: 0 duplicate groups across all approved active statuses
- R07: 2 active linked external users; 0 latest-R04 overlaps
- R08: 4 assignments approved for retention under RC04
- R09-01: collected; 17 of 20 standard Contact history fields tracked
- R09-02: administrator confirms Field Audit Trail is not licensed or enabled
  and A-IMP-02 does not rely on extended retention
- R09-03: passes; Queue supports Case and has one active direct user member
- R09-04: passes; executing user can create Case and write all M014 fields
- R09-05: passes; relevant licences are active and required features are
  available for the current scope

## Formally approved exceptions

1. The user approved on behalf of B/C/D/F/I and Experience/Community owners
   and the project owner.
2. Manual rows B-08, D-01 and F-02 are waived.
3. Experience Cloud page/screenshot evidence is waived.
4. Four historical Client User-linked Consent Request Items are approved for
   retention without remediation.

## P1/P2 risks and conflicts

- RC01 resolved on 2026-07-20: project owner approved commit `8391a96` as the
  new Salesforce metadata Git baseline.
- RC02 is resolved: R04 remediation is verified at zero rows and the user
  formally approved in both business-owner and privacy-owner capacities.
- RC03 is resolved: neither active external user's Contact overlaps the latest
  R04 result.
- RC04 is resolved by security/data-owner approval to retain both permission
  sets for both active Client Users as required Community access and
  object-view permissions.
- RC05 is resolved: no `Subject` records remain and the Sandbox active Portal
  Role values match repository metadata.
- Contact history is partially and incorrectly configured relative to
  M024-M025.
- RC07 is resolved: the approved corrected R06 found zero cross-status
  duplicate groups.
- RC06 is resolved: R09-01, R09-03, R09-04 and R09-05 pass; R09-02 is
  administrator-confirmed not applicable.
- RC08 is resolved: the internal M018 matrix was deployed to ChenTest
  (`0AfBK00000BUDMT0A5`), all 60 ProfileLayout mappings were verified, the
  shared Contact layout is retained, and Community layouts remain unchanged
  for A-IMP-09.
- RC09 is resolved: M030 was implemented and the six blocking classes passed
  the final post-deployment run `707BK00001B1HY3`.
- Automated B/C/D/F/I rows passed. E/G/H remain approved not applicable.
- RC10 is resolved by formal approved exception.
- RC11 is resolved by formal approved exception.
- RC12-RC15 are not silently waived by this RC10/RC11 decision and retain
  their separately documented controls.

## Changes requiring written approval

No component is eligible for Production deployment now. Written decisions are
required for:

1. M024-M025 history correction;
2. all remaining runtime-gated activations outside the approved RC10/RC11
   scope.

## Workstream boundaries

- Business Development permissions remain deferred to A-IMP-08.
- Full Experience Cloud isolation remains deferred to A-IMP-09.
- A-IMP-02 may only verify current-state external no-regression.
- No Production deployment or UAT is authorised.

## Recommendation

RC10 and RC11 may be marked resolved by approved exception. Do not infer
Production deployment authority from this ChenTest approval.

Recommended next actions:

1. Retain the written Phase 2 approval and exception records.
2. Use approved metadata baseline `8391a96` for subsequent diffs.
3. Address RC12-RC15 separately before any scope they control is promoted.
4. Obtain separate written authority before Production deployment.

RC10/RC11 closure is permitted. Production deployment remains unauthorised.
