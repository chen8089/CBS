# M018 Layout Assignment Impact and Rollback Draft

## Evidence basis

- 26 repository Profile metadata files parsed successfully.
- Sandbox Page Layout list and assignment matrix reviewed.
- Sandbox Profile-owned Contact object permissions queried read-only.
- Active-user counts queried by Profile without exporting user identities.

No Salesforce metadata, Profile or Layout assignment was changed.

## Current-state summary

- Profiles reviewed: 26
- Profiles with direct Profile-level Contact Read: 14
- Profiles without direct Profile-level Contact Read: 12
- Profiles with dedicated CBS Contact layouts: 2
  - `Admin`
  - `Customer Community Plus User`
- Profiles using `Contact-Contact Layout` for all five slots: 22
- Profiles with no Contact layout assignment: 2
- Profiles with custom Contact Record Types visible directly in Profile
  metadata: 1 (`Admin`)

Permission Set grants can add effective access beyond Profile-level
permissions. The matrices do not infer Permission Set access.

## Proposed internal mapping

For internal Profiles with direct Contact Read:

- Master → `Contact-Contact Layout`
- Client User → `Contact-CBS Contact - Client User Layout`
- Data Subject → `Contact-CBS Contact - Data Subject Layout`
- Singpass → `Contact-CBS Contact - SingPass`
- Non-Singpass → `Contact-CBS Contact - Non-SingPass`

Proposed Profile files: 12

1. `Admin.profile-meta.xml`
2. `Analytics Cloud Integration User.profile-meta.xml`
3. `Analytics Cloud Security User.profile-meta.xml`
4. `ContractManager.profile-meta.xml`
5. `CPQ Integration User.profile-meta.xml`
6. `End User.profile-meta.xml`
7. `Executive Sponsor.profile-meta.xml`
8. `MarketingProfile.profile-meta.xml`
9. `Read Only.profile-meta.xml`
10. `Sales Insights Integration User.profile-meta.xml`
11. `SolutionManager.profile-meta.xml`
12. `Standard.profile-meta.xml`

Proposed changed assignment entries: 46.

## Experience Cloud boundary

No assignment change is proposed for:

- `Customer Community Plus User`
- `Community Profile`
- `Partner Portal Profile`
- `PartnerCommunity Profile`
- `PartnerCommunity Profile1779766427188`
- `QR Code Site Profile`
- guest or external Chatter Profiles

`Customer Community Plus User` retains its current Community layouts,
including its current Client User assignment. Any redesign remains controlled
by M021 and A-IMP-09.

## No-access boundary

Profiles without direct Profile-level Contact Read retain their current
assignments or `NOT_ASSIGNED` state. This avoids adding unnecessary Profile
metadata scope.

## Open approval checks

Before converting this draft into the controlled Manifest:

1. confirm whether internal integration Profiles should receive UI layout
   changes when their custom Contact Record Types are hidden in Profile
   metadata;
2. review Permission Sets for effective Record Type access;
3. confirm all 12 Profile files are approved A-IMP-02 scope;
4. confirm Category B-I regression owners for internal Profile changes;
5. reconfirm that all Experience Cloud Profile assignments remain unchanged.

## Rollback

For every approved Profile change, preserve the original five
`layoutAssignments` entries from
`M018_current_layout_assignment.csv`. Rollback restores those exact values.

Rollback must be atomic with M018 layout rollback so a Record Type is never
left assigned to a layout version outside the approved package.
