# Population size filter and table column reference different metrics

## Context

### What
The "Population size" filter (checkboxes: "Very small," "Small," "Medium," "Large," "Very large")
and the table column labeled "Population size" are backed by two unrelated fields. The filter
narrows correctly against the data it targets, but the table gives no visible way to confirm that —
a filtered row can show a "Population size" value far outside the bucket you just selected, making
the filter look broken when it isn't.

### Why
Found during manual QA of the `Filterable` generalization on `feat/add-awai-fields-part-1-RRA`
(unrelated to that work — confirmed present on `main` too). Left unaddressed, this will keep
reading as a filter bug to anyone spot-checking results against the table, including future
developers and users.

---

## Discovery

### The two fields involved
- **The filter** — `pop_cat_5` (`config/fields.yml`): `kind: multiselect`, filter-only (no
  `display:` block), targets `public_water_systems.pop_cat_5`. This is EPA's own pre-bucketed
  population-served category, loaded directly from the SABS source file
  (`app/services/etl/importers/epa_sabs.rb`).
- **The table column** — `total_population` (`config/fields.yml`), labeled "Population size" in
  `display:`, targets `demographic.total_pop`. This is a census-based total population estimate,
  loaded from the `epa_sabs_xwalk` source file's `total_pop` header. Different source file,
  different metric, no defined relationship to `pop_cat_5`.

### The filter is correct
`pop_cat_5`'s buckets line up exactly with `population_served_count` — a column loaded in the same
`epa_sabs.rb` import step, from the same source rows as `pop_cat_5` itself:

| `pop_cat_5` bucket | `population_served_count` range | count |
|---|---|---|
| `<=500` | 0–500 | 22,472 |
| `501-3,300` | 501–3,300 | 12,718 |
| `3,301-10,000` | 3,301–10,000 | 4,912 |
| `10,001-100,000` | 10,005–100,000 | 4,049 |
| `>100,000` | 100,200–8,271,000 | 482 |
| (null) | — | 9 |

Every bucket's min/max lines up exactly with its option label — the filter is doing what it says.

### The mismatch, demonstrated
Systems with `pop_cat_5 = "<=500"` ("Very small, 500 or less") pulled by `total_population`
descending:

```
CA4310027  pop_cat_5=<=500  total_population=1,890,988
CA1910041  pop_cat_5=<=500  total_population=507,663
CA3710042  pop_cat_5=<=500  total_population=399,557
```

A system EPA buckets as serving 500 or fewer people can show ~1.9M in the table's "Population
size" column — because that column isn't measuring what the filter measures.

### Where the correct number already lives
`population_served_count` exists on `public_water_systems` (ETL-loaded, same import step as
`pop_cat_5`) but has **no `config/fields.yml` entry** — not filterable (beyond the `pop_cat_5`
bucket derived from it), not sortable, not shown in the main results table. It's already surfaced
elsewhere under a different label:
- PWS detail page overview (`app/views/public_water_systems/sections/_overview.html.erb`) —
  "Population Served"
- Map popup (`app/views/home/_map_popup_template.html.erb`) — "Customers served"

So today, the only way to visually confirm the `pop_cat_5` filter is doing the right thing is to
open a system's detail page or its map popup — not the main table.

---

## Implementation Guide

Not started — this needs a product/labeling decision, not just a code change. Options, roughly in
order of effort:

1. **Add `population_served_count` to the manifest** as a displayable, sortable field
   (`config/fields.yml` + `config/table_layout.yml`), so the table itself can show the number that
   backs the `pop_cat_5` filter. Follow `docs/how_to/ADD_NEW_DATA_FIELD.md` — the column already
   exists on `public_water_systems`, so this is closer to Step 3+ (manifest entry, table
   placement) than a full new-field walkthrough.
2. **Relabel `total_population`** away from "Population size" (e.g. "Total population (census)")
   so its adjacency to the `pop_cat_5` filter's "Population size" label stops implying a
   relationship that doesn't exist.
3. Do both — clarifies the existing column's meaning and gives users a way to verify the filter
   without leaving the table.

---

> **Cleanup:** Delete this file when resolved. Reference the closing PR in the commit message.
