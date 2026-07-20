# A-IMP-02 Pre-Build Baseline Validation

Date: 2026-07-20

## Controlled baseline

- File: `controlled-documents/Credit Bureau Sandbox 20260715.zip`
- Size: 16,216,067 bytes
- Expected SHA-256:
  `a3c337d997a556dca2cd53492a5621dce09a39b4f9454ac0d24e7d88a6a93a80`
- Actual SHA-256:
  `a3c337d997a556dca2cd53492a5621dce09a39b4f9454ac0d24e7d88a6a93a80`
- Hash result: **PASS**
- Salesforce source API version: `67.0`
- Git baseline tag: `baseline-A-IMP-02`
- Baseline commit:
  `b664a1f120bc80f1cf3be893c45d23cc55b97415`

## Current repository state

- Branch: `feature/A-IMP-02-contact-separation`
- Pre-build scan HEAD:
  `84c9cadda9517e192b35d19c23056b9935b2afb5`
- HEAD is not identical to the approved baseline.
- `baseline-A-IMP-02..HEAD` contains 301 changed files:
  - six Gate 1 documentation outputs;
  - approximately 295 Salesforce/project files from the earlier
    `8391a96` commit.

Material metadata drift includes:

- `Contact.enableHistory`: `false` at baseline, `true` at HEAD;
- 17 processing/consent Contact fields have `trackHistory=true`;
- the six approved governance fields remain `trackHistory=false`;
- four Data Subject-family layouts contain post-baseline changes;
- Credit Bureau app contains a post-baseline Reports tab change;
- Singpass, consent, report-export, Experience Cloud, LWC, profile and other
  changes outside the 37-row Manifest.

The following A-IMP-02 target components remain unimplemented:

- all nine Contact Validation Rules;
- Consent Purpose and Active Request Key fields;
- active-key maintenance Flow;
- Client User Lightning Record Page;
- Client User matching and duplicate controls;
- Client User Flow purpose guard and reuse/fault logic.

## Result

- ZIP integrity: **PASS**
- API version: **PASS**
- Manifest row count: **PASS (37)**
- Current metadata alignment with approved baseline: **FAIL**
- Pre-build disposition: **STOP METADATA IMPLEMENTATION**

The current HEAD is materially different from the approved baseline and is not
an A-IMP-02-compliant target state. Drift must be reconciled before any
Salesforce metadata build begins.

This validation did not modify Salesforce metadata or data.
