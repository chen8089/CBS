# RC11 Experience Cloud supplemental UAT evidence

- Org ID: `00DBK00000C9kEP2AZ`
- Executing user: `cbsneworg@creditbureau.com.sg.chentest`
- Test run: `707BK00001B0xaX`
- Started: `2026-07-20T12:22:28Z`
- Test: `UatClientUserIsolationE2ETest.testClientUserABDataIsolationTemplate`
- Result: PASS
- Salesforce test status: 1 passed, 0 failed, 0 skipped

The test is `SeeAllData=true`. A separate read-only aggregate check confirmed
that ChenTest contained two active portal users attached to two different
Accounts, so the method did not take its top-level "no pair" return path.

The test executes under both portal users and checks own-Account visibility and
foreign-Account isolation for Account, Contact, Case, Consent,
Consent Request Item, Report Request Item and Exception where the object and
account-link fields are available.

This is meaningful technical sharing evidence. The user subsequently approved
on behalf of the Experience/Community owner and project owner and formally
waived browser/page screenshot evidence. RC11 final status:
**RESOLVED_APPROVED_EXCEPTION**.

