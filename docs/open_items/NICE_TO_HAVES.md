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

### Testing: JS/system test for filter param collection

We have no JS tests yet. A small system/JS test would lock down the filter→URL payload contract:
e.g. check a histogram range's gate → Apply → assert the URL carries both `<base>_min` and `<base>_max`
(even at the default domain, without dragging). This is the one layer not covered by the backend
`filterable_spec` — see docs/FILTERING.md "how we know all filters send params" / the standalone-range
seeding in `filter_controller.js#toggleSubcat`.

---

### URL sharing: `view=` param for map vs. table

A shared URL currently always lands on the map; it can't carry which view (map/table) the
sender was in. Add a `view=` URL param so a shared link opens directly on the correct section.
The blocker that deferred this — client-side filter hydration creating cross-controller load
races — is gone: `HomeController#index` now decodes all URL state once and the template
server-renders the initial HTML. So the work is small: read `params[:view]` in
`HomeController#index`, render the active section server-side, and have `nav_controller.js`
write `view=` to the URL on section change. See docs/decisions/URL_MANAGEMENT.md (the `view`
row in the URL Schema table).

---

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

### Frozen (sticky) pinned table columns

`table_layout.yml`'s `pinned:` list makes a column always-visible and hides it from the column
picker, but it does **not** freeze it on horizontal scroll. Only the checkbox (`format: check`)
and name column (`row_header: true`) are sticky, via hardcoded `left-0` / `left-7` offsets in
`home_helper.rb#render_table_cell` + `table_header_component`. So a third pinned column (e.g.
`epa_report`) stays in the table but scrolls away. Freezing any pinned column needs cumulative
`left` offsets — fixed widths for the leading columns, or JS-computed offsets (the name column is
variable-width today). Revisit if freezing more than the identity columns is desired.

---

> **Cleanup:** Remove individual items as they are implemented or ticketed. Delete this file
> when it is empty.
