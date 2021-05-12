---
name: Chart Upgrade
about: Request to change a Chart version
title: ''
labels: improvement
assignees: ''

---

**What Chart should be upgraded?**

/e.g., dexidp/dex 2.15/

**Why should this Chart be upgraded?**

- [ ] We need to perform a security upgrade.
- [ ] We need it for a new feature: *which feature (link to blocked issue)*.
- [ ] We need to keep up to prevent future issues.
- [ ] Other: *Write the reason here*

**Acceptance criteria**

- I checked the migration of the new Chart:
    - [ ] I upgraded a Chart and determined that no migration steps are needed.
    - [ ] I upgraded a Chart and added [migration steps](https://github.com/elastisys/compliantkubernetes-apps/blob/main/migration).
- [ ] I tested the functionality provided by the new Chart (e.g., Auth flow, Grafana dashboards, etc.)
