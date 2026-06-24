# Nice to Haves

## Context

### What
A running list of improvements, features, and cleanup items that are lower priority —
worthwhile but not blocking anything and not yet ticketed.

### Why
Keeps ideas visible without cluttering higher-priority open items docs. Items here should
be ticketed when there is capacity, or deleted if they're no longer relevant.

---

## Items

### Performance: Server-Side Cache for Default Table State

The default table state (no filters, default sort, page 1) is identical for every user and
only changes when a new ETL import runs. Cache the `HomeController#table` response keyed on
`[filter_params, sort/direction/page, DataImport.maximum(:imported_at)]`. Cache is free to
be long-lived — it self-invalidates on the next import. Solid Cache is already configured in
production; no infrastructure work needed.

---

### Data: Health Check Rake Task

A rake task that asserts expected data exists after an ETL run — something like:

```ruby
raise "CartographicCounty missing" unless CartographicCounty.count > 0
raise "counties not populated" unless PublicWaterSystem.where.not(counties: [nil, ""]).exists?
```

Would run post-import and report to a Slack channel or log. Useful for catching silent failures
(e.g. OOM mid-run that leaves tables partially populated). Determine reporting destination
(Slack channel, CloudWatch alarm, etc.) with the EPIC team before implementing.

---

### Filters: Known Gaps

- **Boil Water Summary filtering** — placeholder checkbox exists in the Notices filter UI but is disabled (`data unavailable`). The filter is not yet functional.


---

### application.css: Confirm Defaults and Clean Up

`app/assets/tailwind/application.css` has some leftover notes and may have unconfirmed
defaults around branding. Before the project is considered stable: confirm base defaults,
verify brand values are intentional, and remove any stale comments.

---

> **Cleanup:** Remove individual items as they are implemented or ticketed. Delete this file
> when it is empty.
