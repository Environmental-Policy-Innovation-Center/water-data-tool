# How To: Edit an Existing Data Field

##### How to change how an existing field behaves or appears.

The first question is always **which of the four config files owns the attribute you're changing** — edit there, and the rest derives. ("The manifest" = `config/fields.yml`; its header comment documents every key.)

See also:
- [docs/FILTERING.md](../FILTERING.md) — how filtering works end-to-end (config sources, AND/OR combining, the DOM contract).
- [docs/ETL.md](../ETL.md) — the import pipeline: generic vs. custom importers and casting.
- Sibling how-tos: [ADD_NEW_DATA_FIELD.md](ADD_NEW_DATA_FIELD.md) · [REMOVE_EXISTING_DATA_FIELD.md](REMOVE_EXISTING_DATA_FIELD.md).

---

## Which file owns what

| You want to change… | Edit | Notes |
|---|---|---|
| Table column header text | `fields.yml` → `display.label` | |
| Number / date / currency formatting | `fields.yml` → `display.format` / `format_opts` | |
| CSV export header | `fields.yml` → `display.csv_label` | |
| Whether it's sortable / the sort param | `fields.yml` → `display.sort` | omit to make it unsortable |
| Filter menu label | `fields.yml` → `filter.label` | distinct from `display.label` |
| Filter kind (range / radio / bool / multiselect) | `fields.yml` → `filter.kind` | also revisit options / coercion; switching to `bool` on a non-boolean column also needs `checked_value` |
| Histogram format | `fields.yml` → `histogram.format` | |
| Tooltip copy | `config/tooltips.yml` | manifest references it by key |
| **Which menu / category a filter lives in** | `config/filter_layout.yml` | **changes AND/OR — see below** |
| **Filter order within a menu** | `config/filter_layout.yml` | order = file order |
| **Table column order / picker category** | `config/table_layout.yml` | order = file order |
| Source feed column or cast | `fields.yml` → `source` | may need a re-import |

Rule of thumb: **`fields.yml` = what a field is; the layout files = where it sits.** "Rename / reformat / re-source" → the manifest. "Move / reorder / regroup" → a layout file.

---

## Moving a filter changes its boolean logic

Filter placement in `filter_layout.yml` is semantic, not just visual (see [docs/FILTERING.md](../FILTERING.md)):

- **Same category → filters OR together.**
- **Across categories → filters AND together.**

So moving a filter into another category, or splitting one category into two, **changes results**, not just layout. Before moving a range/bool filter, confirm the intended logic: grouping two filters means "match either"; separating them means "match both."

---

## Common edits

- **Relabel a column or filter** → `fields.yml` (`display.label` / `filter.label`). No layout change.
- **Reorder columns or filters** → the relevant layout file; order follows file order.
- **Re-categorize a filter** → move its key between categories in `filter_layout.yml`; re-check the AND/OR implication above.
- **Change a format** → `fields.yml` `display.format` (and `histogram.format` if charted).
- **Make a shown filter URL-only** → remove its key from the layout file. No flag needed — a filterable field absent from the layout is filterable by its param but hidden from the menu.
- **Rename the field key** → touches the manifest key plus its references in both layout files (and any spec referencing the param). Treat it like a small remove + add; grep the old key first.
- **Switch a filter to `kind: bool` on a non-boolean column** → also set `filter.checked_value` (see `ADD_NEW_DATA_FIELD.md` Step 3). Without it the predicate compares against a literal `true`, which either matches nothing or raises a Postgres type error against a string column.
- **Add a Rails `enum` to an existing column** → only if something will actually consume the enum's *key* (a filter doing value translation, a dedicated display formatter — see `Demographic#most_common_rate_tier`). Otherwise the model's attribute reader returns the key instead of the stored value, silently breaking that field's table display. See `ADD_NEW_DATA_FIELD.md` Step 1 for the full explanation and the `CertificationSummary` example this app hit.

---

## Worked example — relabel and reformat a column

Suppose you want the poverty column to read "Poverty rate" and show one decimal place. Both attributes live in the manifest's `display` block, so it's a one-file edit — nothing in the layout files changes:

```yaml
poverty_rate:
  display:
    label: "Poverty rate"          # was: "Households below poverty line"
    format: pct
    format_opts: {precision: 1}    # add one decimal place
```

Contrast with **moving** that filter to a different menu — that's a `filter_layout.yml` edit, and it changes AND/OR logic (see above).

---

## Verify

- `bin/ci` runs clean (the golden-master specs catch unintended composed-output changes).
- **If you changed a filter's `kind` or `param`,** update the specs that assert it: `spec/filters/filter_params_spec.rb` and `spec/models/concerns/filterable_spec.rb`.
- The change shows where intended; for a moved filter, sanity-check the AND/OR result with a combined filter selection.
