# R11-R12 Drift Disposition Summary

- Original byte-level differences: 61
- Expected retrieve noise: 26
- Expected A-IMP-02 baseline-ahead paths: 5
- Decisions recorded: FlowDefinition, Contact layout, queue membership, all 26 Profile FLS paths and Site.com scope
- Metadata source changes authorised in Phase 1: none

## Confirmed decisions

1. Adopt Sandbox FlowDefinition active version 6 through A-IMP-02.
2. Adopt the Sandbox Contact layout state through A-IMP-02.
3. Retain the active ChenTest CBS Case queue user assignment as environment runtime configuration.
4. Preserve readable/editable FLS for the four Contact identity fields across all 26 Sandbox Profiles; external/restricted-profile exposure is explicitly accepted.
5. Exclude PartnerCommunity2.site because it is unrelated to A-IMP-03.

## Remaining implementation gates

A-IMP-02 must reconcile FlowDefinition and Contact layout; A-IMP-08 must reconcile the 26 Profile baselines and record the named Security owner. A-IMP-03 must then rebase and rerun R11/R12.

No decision authorises deployment, DML, activation or copying live-org metadata directly into A-IMP-03.
