# Configuration Audit & Action Plan

> How configuration is spread across the codebase today, the full process for adding
> a new data field, and a sequenced plan to consolidate it toward data-driven (and
> eventually portal/CSV-driven) configuration.
>
> Scope: the **field / filter / column / tooltip / ETL spine** — the config that
> governs how a data field travels from a source CSV to a usable, tooltipped filter
> in the UI. Map-rendering config (`map_controller.js`) is noted but out of scope
> (see §6).

---

## 1. The configuration surface

A single logical data field (e.g. `poverty_rate`) is currently described in **eight
places across four languages** (Ruby, YAML, ERB, JS). Nothing enforces that these
agree — the column name string is the implicit join key, validated only by eye.

| # | Location | Format | Governs | Loaded by |
|---|----------|--------|---------|-----------|
| 1 | `app/services/etl/importers/*.rb` (13 files) + `importer.rb` `FILE_IMPORTERS` | Ruby | Source CSV header → DB column mapping + type casting | ETL run |
| 2 | `db/schema.rb` / migrations (28 tables) | Ruby | Physical DB columns & types | Rails boot |
| 3 | `config/filters.yml` | YAML | URL param keys, range columns, sortable columns, histogram fields, violations groupings, strong-params | `FilterRegistry` |
| 4 | `config/columns.yml` | YAML | Table columns: label, format, sort key, source association, CSV label, SQL export expr, picker category | `ColumnRegistry` |
| 5 | `config/tooltips.yml` | YAML | Filter-menu & export help text | `HomeHelper::TOOLTIPS` |
| 6 | `app/javascript/controllers/filter_controller.js` `FILTERS[]` | JS | DOM-id ↔ param wiring, value maps, badge counting, URL restore | Browser |
| 7 | `app/views/home/_filter_menus.html.erb` (~598 lines) | ERB | The actual filter UI: hardcoded checkbox/panel/input IDs, labels, tooltip keys, field names | Render |
| 8 | `config/datasets.yml` | YAML | Downloads-page dataset provenance (largely standalone) | `HomeHelper::DATASETS` |

`app/models/concerns/filterable.rb` is not config *data*, but it holds **hand-written
SQL per filter group** (join strategy, AND-vs-OR semantics, special joins for
boil-water / place / county / bounds). It must be extended when a filter needs
semantics beyond a plain range/equality match.

---

## 2. How they connect

The unifying key is the **column / field name** (`poverty_rate`,
`groundwater_rule_5yr`). That same string is restated independently in ~6 of the
locations above.

```
  SOURCE CSV  (e.g. "a_int.identified_as_disadvantaged")
        │
        │  [1] ETL importer .rb  — renames + casts (cast_dec / cast_score / cast_bool …)
        ▼
  DB COLUMN  cejst_disadvantaged_pct  ◄──── [2] schema.rb
        │
        ├──────────────┬───────────────┬──────────────────┐
        ▼              ▼               ▼                  ▼
  [3] filters.yml  [4] columns.yml   (read by Arel     (histogram bins)
   • range_col      • label           in filterable.rb)
   • sortable_col   • format
   • histogram      • sql_expr
   • permit keys    • category
        │              │
        ▼              ▼
   FilterRegistry   ColumnRegistry
        │              │
        │              ├──► home_helper renders <td>, CSV / GeoJSON export
        │              └──► column picker panel (manage_columns_controller.js — DOM-driven)
        ▼
   ┌─── client_payload_json ──► #filter-registry-config <script> (browser)
   │
   ▼
  [6] filter_controller.js FILTERS[]   ◄── must mirror by eye ──►  [7] _filter_menus.html.erb
       • param: "cejst_..._min/max"              • checkbox_id "more-cejst"
       • minInputId "min-cejst"                  • panel_id   "subcat-cejst"
       • parentId  "more-cejst"                  • field      "cejst_disadvantaged_pct"
       • panelId   "subcat-cejst"                • tooltip_text ◄── [5] tooltips.yml
```

**Critical coupling:** three ID namespaces (`more-X`, `subcat-X`, `min-X` / `max-X`,
`slider-X`) are hand-authored in **both** `filter_controller.js` and
`_filter_menus.html.erb` and must match exactly. There is **no codegen, schema, or
test** verifying the JS `FILTERS[]` entries line up with the ERB IDs or the YAML
params. The existing `filter_registry_spec.rb` / `column_registry_spec.rb` validate
each file **in isolation**, not against each other or against the DOM.

A bright spot: the **column picker** (`manage_columns_controller.js`) is already fully
DOM-driven off server-rendered `data-col-key` / `data-category` attributes sourced
from `ColumnRegistry`. It is proof the data-driven approach works here.

---

## 3. Full process to add one new data field (today)

Example: EPIC ships a new CSV column to expose as a filterable, sortable, tooltipped
range filter that also appears in the table and exports.

| Step | File | What you add |
|------|------|--------------|
| 1 | migration → `schema.rb` | `add_column :demographics, :lead_service_lines_pct, :decimal` |
| 2 | `etl/importers/<file>.rb` | `lead_service_lines_pct: cast_dec(row["<source_header>"])` |
| 3 | `config/filters.yml` → `range_column_groups.<group>.columns` | `- lead_service_lines_pct` |
| 4 | `config/filters.yml` → `sortable_column_groups.<group>` | `- lead_service_lines_pct` (if sortable) |
| 5 | `config/filters.yml` → `histogram_field_groups.<group>` | `- {name: lead_service_lines_pct, format: percent}` |
| 6 | `config/columns.yml` | full block: key, label, sort, format, size, source, category, csv_label, sql_expr |
| 7 | `config/tooltips.yml` → `filter_menus` | `lead_service_lines: "..."` |
| 8 | `filter_controller.js` → `FILTERS[]` | `{ type:"range", group:5, parentId:"more-lsl", panelId:"subcat-lsl", param_min:"..._min", param_max:"..._max", minInputId:"min-lsl", maxInputId:"max-lsl" }` |
| 9 | `_filter_menus.html.erb` | a `GroupRangeComponent` with **matching** `checkbox_id`, `panel_id`, `field`, `min_input_id`, `max_input_id`, `tooltip_text: filter_tooltips["lead_service_lines"]` |
| 10 | `filterable.rb` *(only if needed)* | new association/join or non-default AND/OR semantics |

**~9 edits across 4 languages, with ~5 hand-matched string IDs and no compile-time
validation.** Miss one and the filter silently fails to count in a badge, restore
from URL, or apply — with no error.

---

## 4. Risk / coupling analysis

1. **JS ↔ ERB ID contract (steps 8–9) is the worst offender.** The same ad-hoc IDs
   live in two files with no shared source. This is the single biggest barrier to a
   non-engineer adding a filter.
2. **The column name is restated ~6×** with no canonical declaration.
3. **`filters.yml` does four unrelated jobs** (filter, sort, histogram, strong-params)
   keyed off overlapping column lists — internal redundancy.
4. **`columns.yml` and `filters.yml` overlap heavily** — both enumerate the same
   demographic / violation / EJ / funding / hazard columns ("display" vs "filter"),
   so they drift independently.

---

## 5. Recommendations

### A. Make the existing split safe (cheap, immediate)
- **A1 — cross-config consistency spec.** One RSpec asserting the invariants that
  currently rely on eyeballing (see §7 for the durable subset).
- **A2 — derive JS `FILTERS[]` IDs from a per-filter slug** instead of hand-authoring
  five IDs. *(Note: A2 is absorbed by B — see §6 sequencing.)*

### B. Consolidate to one field manifest (the real fix)
Collapse `columns.yml` + the filter/sort/histogram sections of `filters.yml` into a
single `config/fields.yml` keyed by column name, where each field declares everything
about itself:

```yaml
fields:
  poverty_rate:
    model: demographic              # DB source + join association
    db_type: decimal
    source_header: "pw_..._poverty" # ETL mapping
    label: "Households below poverty line"
    category: demographics
    format: pct
    tooltip: "Poverty rate is the percentage…"
    table:     { show: true, sortable: true, csv_label: "…below the poverty line (%)" }
    filter:    { kind: range, menu: 5, coercion: decimal }
    histogram: { format: percent }
```

`ColumnRegistry`, `FilterRegistry`, the ETL column maps, tooltips, **and** the JS
payload all derive from this one file. The filter menu becomes a loop over the
manifest instead of ~598 hand-written lines, and IDs become convention-derived
(this is where A2 lands for free). Per-field work drops from **9 edits to 1 block**.

### C. Portal / CSV-driven config (long term)
Once a single manifest exists, "add a filter via CSV/portal" becomes a thin CRUD
layer that writes to / overrides the manifest. The ETL already proves the registry
pattern (`FILE_IMPORTERS`). **Consolidation (B) is the prerequisite; the portal is
not blocked by ingestion — it's blocked by the field being scattered across 9 places.**

The one piece that stays code is `filterable.rb`'s SQL semantics. A manifest can
declare `filter.kind: range|bool|group|geo` and route to a generic applier for the
~90% common case, leaving only genuinely special filters (boil-water, place, bounds)
as custom methods.

---

## 6. Sequencing decision: A vs B

A and B are **complementary, not mutually exclusive**, but B *subsumes* part of A:

- **A2 folds entirely into B** (manifest-generated HTML ⇒ convention IDs for free).
- **A1 splits**: the *file↔file* checks become moot after B (one file); the
  *manifest↔reality* checks (field→DB column, param→permit, ID→DOM) survive B and
  become more valuable.

Therefore the recommended order is a **hybrid**, not strict A-then-B or B-then-A:

1. Write **only the durable slice of the spec** (§7) — the manifest-shaped invariants.
2. Do **B** (consolidate to `fields.yml`) under that safety net.
3. Let the spec **grow with the manifest** as each column group migrates.

This keeps B-first momentum without running a file-spanning refactor blind, and skips
the throwaway cross-file checks B would delete. Strict B-first is acceptable only if
you accept doing the refactor with no net beyond existing isolated specs + manual QA.

### Field → model routing: manifest-driven, with a bounded custom exception

A common question: does the manifest decide which model/table a field lands on, or
is that still manual ETL? **Answer: the manifest drives the *routing* (destination);
custom Ruby remains only for special *transforms*.** This is proven by the Phase 1
prototype — `FieldRegistry.etl_mapping` derives, purely from `config/fields.yml`, the
same `source_file → model → [columns]` routing the 13 importers currently hardcode:

```
SOURCE FILE: epa_sabs_xwalk.csv
  → upsert into demographic:
      poverty_rate            ← cast_decimal(row["hh_below_pov_per"])
      median_household_income ← cast_integer(row["mhi"])
      …
SOURCE FILE: xwalk_pct_change_10yr.csv
  → upsert into trend_datum:
      population_pct_change   ← cast_decimal(row["total_pop_pct_change_2011_2021"])
```

| Aspect | Manifest-driven? | Notes |
|---|---|---|
| Field → model/table (destination) | ✅ | `model:` per field; a generic importer groups + upserts |
| Header rename + cast | ✅ | `source.header` / `source.cast` |
| One file → two models (`sdwis_viols`) | ✅ | each field declares its own `model:` |
| Four files → one model (EJ) | ✅ | shared `model:`, merged on `pwsid` |
| `GROUP BY`/`SUM` aggregation (`pwsid_npdes_usts_rmps_imp`) | ❌ custom | transform stays Ruby |
| 1 GB geojson SAX stream (`epa_sabs_geoms`) | ❌ custom | transform stays Ruby |
| Derived/computed (`stusps` from pwsid prefix) | ❌ custom | no source column |
| Post-import spatial steps | ❌ custom | derived, not mapped |

**The documented limitation:** the ~4 structurally special files keep custom
importers for their *transform* — but they still declare their destination `model:`
in the manifest, so the manifest stays authoritative for "where does this field
live." A generic, manifest-driven importer handles the flat-map majority; special
importers are the bounded exception. Mirrors the filter story: generic applier for
the common case, custom code for genuinely special ones.

> **Out of scope — map config.** `map_controller.js` holds `REGION_STATES`,
> `STATE_FIT_BOUNDS`, `REGION_CAMERAS`, and inline MapLibre layer/paint definitions.
> This is map-rendering config, not data-field config, and does not participate in the
> §3 flow (the only thread is `symbology_field`, which already travels the normal
> filter path). Listed here only for a complete inventory.

---

## 7. Interaction with the FILTER_SERVER_RENDER refactor

`docs/open_items/FILTER_SERVER_RENDER.md` (FSR) is a **planned, not-yet-started**
refactor that moves filter-menu state restoration from JavaScript
(`filter_controller.js#restoreDomState`) to server-rendered ERB. It and this
consolidation **diagnose the same root cause** — the `FILTERS[]` ↔ `_filter_menus.html.erb`
hardcoded-ID drift — on two different axes:

| | FSR | `fields.yml` manifest |
|---|---|---|
| Axis it fixes | *Runtime hydration* (who restores menu state: JS → server) | *Definition* (where a field is declared: 8 places → 1) |
| FSR's own stated goal | lists "**single source of truth for filters**" as an enabled outcome | **is** that single source, more completely |

**They are synergistic, not conflicting — but they must not run in parallel on the
same ERB/JS, and they should explicitly *merge* at one step:**

- FSR **shrinks** the JS side of the manifest's job: it deletes `#restoreDomState`
  and slims `FILTERS[]` to ~10–15 interaction-only entries. After FSR the manifest
  never models restore IDs in JS — the server owns restore.
- The manifest **cheapens** FSR: instead of hand-converting ~598 ERB lines to read
  `@filter_state` one control type at a time, the menu becomes a loop over the
  manifest. The hardcoded IDs FSR calls the core fragility get *generated*, not
  hand-maintained.
- Therefore the manifest's final step (generate `_filter_menus.html.erb` from the
  manifest) and FSR's core (rewrite that ERB for server render) are **the same piece
lets   of work** — ideally do it once (§8 Phase 5), not twice.
  - **Execution note:** we ultimately *split* these to de-risk — server-render the
    existing ERB first (Approach B), then generate it from the manifest (8b). They still
    converge on the same generated ERB; we just reach it in two passes. See Phase 5.

Consequence for §5A: once FSR lands, the JS↔ERB ID-drift bug class disappears
*structurally*, so that specific consistency check becomes unnecessary. The durable
manifest↔DB / param↔permit invariants remain.

---

## 8. Order of operations toward a single config file

**Goal:** `config/fields.yml` as the single source of truth for *what each field is*, with the
*least possible* custom configuration — and every unavoidable custom case **declared inside
the manifest itself** so it is discoverable and test-enforced (never silent).

Note the end state is **not one file — by design.** The target is **four config files, each with
one job**, so it is always unambiguous where a given concern is set:

- **`fields.yml`** — definition + capability (what each field *is*). **Order-independent**: file
  order is for human organization only; nothing should depend on it, so the manifest never has to
  be order-maintained.
- **`filter_layout.yml`** — filter menu order + nesting.
- **`table_layout.yml`** — column + category order. *(Eventually wanted for consistency — so that
  ordering lives in layout files **everywhere**, never incidentally in the manifest; see §8.4.)*
- **`tooltips.yml`** — filter/export copy, a first-class config file kept separate (§8.2).

Adding a field always touches `fields.yml`, plus `filter_layout.yml` when it needs a menu control.
The win is "8 scattered places → 4 purposeful, single-job files," not a single mega-file.

Phases 0–4 are back-end only and **independent of FSR** (bankable now). Phase 5 *is*
FSR. Each phase ships independently; the app works at every step.

### Phase 0 — Backstop spec ✅ DONE
Two specs that make every later phase safe (`spec/fields/field_registry_spec.rb`):
- [x] **Invariant spec**: every data field's column exists on its model's table;
      every range filter targets a real column; every histogram column resolves.
- [x] **Parity / golden-master spec** (the cutover backstop): `FieldRegistry` output
      **equals, field-for-field,** today's `ColumnRegistry.columns` (direct `TableColumn`
      equality, in order), `ColumnRegistry.categories`, and `FilterRegistry`
      (`permit_arguments`, `sortable_columns`, `histogram_field_config`). This is what
      lets Phase 3 swap consumers with confidence. Tooltips excluded by design (§8.2).

### Phase 1 — Prototype ✅ DONE
- [x] `config/fields.yml` + `app/fields/field_registry.rb` (representative Demographics
      subset across 2 models / 2 source files).
- [x] `FieldRegistry.etl_mapping` proves manifest-driven field→model routing (§ above).
- [x] `spec/fields/field_registry_spec.rb` — 12 examples, 0 failures.

### Phase 2 — Full manifest, back-end only ✅ DONE
- [x] Expanded `fields.yml` to **every field** — 84 fields: all range/sort/histogram
      groups (demographics, violations, EJ, funding, watershed, trends) **plus** the core
      `PublicWaterSystem` controls (radio, bool, multi-select, place, pop_cat). Rate-tier
      remains a legacy-only `FILTERS[]` control not yet ported (tracked for Phase 5).
- [x] Grew `FieldRegistry` + `MODEL_CLASSES` to reproduce **every** server-side view
      (78 columns, 76 sortable, 55 histogram, 127 permit keys — all byte-identical).
- [x] Phase 0 parity spec green across the whole manifest (12 examples).
- [x] `table:` dropped — derived from `model` (`Model.table_name`); annotated canonical
      example at the top of `fields.yml`; fixed key ordering across entries.
- [x] **Filter `menu`/`section` tags** added to all 64 menu-rendered filters (ported from
      the legacy `FILTERS[]` groups + the ERB `CategoryComponent` labels). **These are
      interim seed data** — under the layout-file design (§8.4) placement moves out of the
      manifest into `filter_layout.yml`, and these tags are removed in Phase 5.
- [~] **ETL `source:` blocks** present for demographics + trend (the two flat-map files
      whose headers are known); remaining files' headers land in Phase 4. Custom-case
      register (§8.1) still to be annotated.

### Phase 3 — Cut server-side consumers over to `FieldRegistry` ✅ DONE (scoped)
Cut over only the concerns the manifest can **fully own** so the legacy source can be
*deleted* (true single source), not merely mirrored. Anything whose `filters.yml` section
still feeds a second consumer is deferred to avoid split-brain (two files defining the same
param names) — those move atomically in Phase 5.
- [x] `ColumnRegistry` now reads `columns` + `categories` from `FieldRegistry`; **`config/columns.yml`
      deleted** (its only consumer was `ColumnRegistry`). All behavior (panel groups, visibility,
      CSV/GeoJSON export) is unchanged — it operates on the column list, now manifest-sourced.
- [x] `HistogramsController` reads histogram config straight from `FieldRegistry`; **`histogram_field_groups`
      removed from `config/filters.yml`** and `FilterRegistry.histogram_field_config` deleted (histogram
      config is a manifest concern, not a filter-param one — no pass-through left behind).
- [x] Backstop: `column_registry_spec` (value-based) guards the manifest columns transitively via the
      delegating `ColumnRegistry`; `field_registry_spec` owns the histogram-config characterization. The
      now-tautological column/category/histogram parity examples were dropped; **permit-args + sortable-map
      parity stays** (still cross-checks the independent `filters.yml`).
- [x] `config/environments/development.rb` watches `config/fields.yml` (was `columns.yml`).
- **Deferred to Phase 5** (entangled — `filters.yml` sections feed `Filterable`/`Sortable`/`client_payload`,
      not just the permit/sort projections the manifest models): `permit_arguments`, `sortable_columns` +
      `sortable_table_joins`, the range-column groups, violations subcats, and `client_payload`.
- **Not applicable**: `HomeHelper` tooltips + `tooltips.yml` stay as-is by design (§8.2 — concept-keyed,
      not 1:1 with fields). No ERB/JS change.

### Phase 4 — ETL routing via a generic importer
- [x] `Etl::Importers::Generic` consumes `FieldRegistry.etl_mapping` for the 8 flat-map files.
- [x] Completed manifest `source:` coverage (incl. ~20 **ingest-only** source-only fields) +
      `custom_imports` register declaring the 5 structurally-special files (model + reason).
- [x] **Characterization backstop** (`generic_spec`): the generic importer reproduces every
      flat-map importer's parsed rows byte-for-byte on its fixture.
- [x] **No-silent-gaps spec**: every `FILE_IMPORTERS` file is classified exactly once —
      generic (`etl_mapping`) or custom (`custom_imports`).
- [x] **Cutover (DONE):** `FILE_IMPORTERS` routes the 8 flat-map files through `Generic`; the 8
      flat-map importer classes + their specs are deleted (`app/services/etl/importers/` is now
      `generic` + the 5 custom ones). `generic_spec` is value-based + covers `import!` routing;
      `zeitwerk:check` clean. Full suite green.

**Decoupling / risk note:** everything except the cutover is *additive config* — it changes no
live ingestion. The manifest's `source:` axis **describes** ingestion; `FILE_IMPORTERS`
**executes** it. So the descriptive config (source blocks, ingest-only fields, `custom_imports`,
the generic importer, the specs) can be kept and banked even if we never flip execution to
generic — the flat-map importers keep running and the characterization spec keeps proving the
generic one *could* replace them. The cutover is the only step that needs dev intervention.

**Phase 6 candidate — derive the importer registry:** after cutover, `FILE_IMPORTERS` is
redundant with `etl_mapping` ∪ `custom_imports`. With a file-naming convention (source-file stem
= `file_key` = manifest `source.file`; custom importers = `Etl::Importers::#{file_key.camelize}`,
which today's classes already follow), `FILE_IMPORTERS`/`FILE_EXTENSIONS` could be derived
(generic ⇒ `Generic`; custom ⇒ camelized class; default `.csv`, exceptions declared). Keep them
explicit through the Phase 4 cutover; collapse in Phase 6 if we want one source of truth. Worth
documenting the file-naming convention there.

### Export-SQL derivation — drop hand-written `value_sql` + table aliases ✅ DONE
The manifest no longer carries a `value_sql` per column. All 77 export expressions were plain
`<alias>.<column>` (zero computed), so `FieldRegistry` now **derives** the export expression as
`#{Model.table_name}.#{db_column || key}` (`export_sql`). Two columns whose name ≠ DB column got an
explicit `db_column:` (`epa_report → detailed_facility_report`, `symbology_field → service_area_type`),
and `epa_report` gained the `model: public_water_system` it had been missing. Export inclusion is now
signalled by "has a model" — only the value-less `check` column (no model) is skipped, exactly as before.
`PublicWaterSystemExporter` was switched from short JOIN aliases (`d`/`td`/`ej`/`vs`/`bws`/`fs`/`wh`/`pws`)
to full table names so the derived `table.column` resolves directly. Safety: a characterization check
confirmed `derived == current value_sql` for every column before removal; the value-based
`column_registry_spec` csv/geojson assertions (now full table names) + the real-DB exporter spec guard the
output. Result: 77 fewer hand-written config lines and no alias map for the data team to memorize.

### Phase 5 — Layout files + front-end generation = execute the FSR refactor (the convergence)
- [x] **Author `config/filter_layout.yml`** (§8.4): the ordered, **nested** menu → section →
      filter → sub-filter tree, referencing field keys. Seeded from the current `menu`/`section`
      tags + the subcat nesting in `_filter_menus.html.erb` (the two 5yr/10yr violation panels and
      the watershed-hazards panel — the nesting flat tags can't express). Read by `FilterLayout`
      (app/filters/filter_layout.rb): `placements` (ordered leaf `Placement`s with menu/section/parent),
      `field_keys`. **Additive only** — nothing consumes it yet; the live ERB is unchanged.
- [x] **Layout backstop spec** (`spec/filters/filter_layout_spec.rb`): the layout references every
      menu-tagged filter field **exactly once** (no orphans/dupes) and places each under the menu/section
      its manifest tags declare; panels are layout-only ids, never field keys. The 5 menu-less filter
      fields (`total_population`, `no_health_insurance_rate`, `owner_rate`, `renter_rate`,
      `population_in_poverty_rate`) are backend-only and correctly absent.
- [x] **Populate filter copy & state (the "where it lives" decision applied).** Manifest `filter:`
      blocks gained `label` / `tooltip` (ref) / `options` (radio·multiselect·pop_cat·rate_tier, each value +
      label); the layout categories + parent-filters gained `label` / `tooltip`. Option values pulled from the
      live JS maps (`OWNER_TYPE_MAP`, `POP_CAT_MAP`, `RATE_TIER_BTN_MAP`, etc.; radio "Both" = null value =
      no filter).
- [x] **Removed the interim `menu`/`section` tags from `fields.yml`** — placement now lives only in
      `filter_layout.yml`. The 5 backend-only filters are marked `filter.backend_only: true`; the layout
      reshaped to `category → {label, tooltip?, filters}` and parent-filter `→ {label, tooltip?, sub_filters}`.
      Backstop spec flipped from tag-parity to **membership**: every surfaced filter is in the layout exactly
      once, backend-only stays out, parent keys are never fields. Full suite green (929).
- [x] **`default`/initial-state designation** — two distinct concepts, each one job:
      **(1) `default: true`** marks an initially-on choice — placed on the option (radio/multiselect/pop_cat/
      rate_tier; e.g. all six `owner_type` options) or on a default-checked bool. **(2) `has_select_all: true`**
      (manifest, flat multiselects only — e.g. `owner_type`; `primacy_type` omits it) means "render a
      select-all/deselect-all control" and carries *no* state. A parent-filter's check-all is **implied by its
      `sub_filters`** (no flag in the layout). Either control's checked appearance is **derived** from its
      members' `default`, never declared (mirrors the app's `syncSelectAll`/`syncParentFromSubcat`).
      *(Was the open Phase-4/5 TODO.)*
> **Sequencing note (actual, post-decision).** §7 assumed generation + server-render happen in
> *one pass*. In practice we **split them**: server-render the *existing* hand-written ERB first
> (Approach B — incremental, one control type at a time, each with a request spec and browser QA),
> and defer the manifest-loop *generation* (Approach A) as a follow-on. Lower risk, and it ships
> user-visible value per control. The two remaining halves below reflect that split.

- [x] **(8a) Server-render filter state from the decoded URL** — Approach B, incremental. **Done —
      Checkpoint A.** radio · bool · multiselect · range-select · rate-tier · range sliders ·
      subcat parents · population-size · paperwork ranges · place autocomplete.
      *(browser-QA-heavy; each control type landed with request-spec coverage.)*
- [x] **(8b) Generate `_filter_menus.html.erb` from `filter_layout.yml` × `fields.yml`** — DONE.
      The menu ERB is now a ~25-line driver looping `FilterLayout.menus → categories → filters` into
      one `_filter_*` partial per control kind (golden-master-verified ≡ the prior hand-written output).
      The **tab bar (`index.html.erb`), the dropdown panels, and the More-overflow placeholders all loop
      `FilterLayout.menus`**, so the menu set, labels, and **order are layout-driven (definition order)** —
      `id` is only a stable DOM/badge/JS handle. Element ids are key-derived (`filter-K`, `panel-K`,
      `min-K`/`max-K`), not hand-authored. (8b + 9 shipped as one combined batch — see note below.)
- [x] **(9) FSR Phase 3 — JS convergence.** DONE. `filter_controller.js` rewritten **DOM-driven** off
      the `data-filter-*` contract emitted by the generated ERB; `FILTERS[]`, `#restoreDomState`, and the
      value-maps are **deleted** (not slimmed — server-render seeds active state, so there is no client
      registry left). Minor follow-ups tracked separately: subcat-parent `indeterminate` connect hook
      (still JS-set on interaction only) and `view=` URL support.
  > **Combined-batch note:** 8b and 9 were done together because the end state has hardcoding in
  > *neither* the ERB nor the JS — generating the ERB with key-derived ids and a `data-filter-*` contract,
  > then rewriting the JS to read that contract, is zero-throwaway (a separate 8b would have rewritten
  > ids that 9 then deletes). See `docs/FILTERING.md` → "Source of truth (implementation)".
- [ ] Close out `docs/open_items/FILTER_SERVER_RENDER.md`.

**Logical checkpoints for Phase 5:**
- **Checkpoint A — server owns first paint. ✅ REACHED.** 8a complete — every filter control renders
  its state from the URL; a shared link needs no JS restore.
- **Checkpoint B — one-file field edits. ✅ REACHED.** 8b complete. The menu ERB (and the tab bar) are
  generated from the manifest × layout; adding/removing/reordering a filter or menu no longer touches
  hand-written ERB. **This is the consolidation payoff.**
- **Checkpoint C — FSR closed. ✅ REACHED.** 9 complete. `#restoreDomState` gone, `FILTERS[]` **deleted
  entirely** (DOM-driven, not interaction-only), the JS↔ERB ID-drift bug class is structurally
  impossible. (Remaining: close the FSR doc.)
- [x] **(Symmetry) `config/table_layout.yml` — DONE.** Column order + category membership +
      category order/labels now live in `table_layout.yml` (read by `TableLayout`); `ColumnRegistry`
      composes manifest × layout exactly as the filter side composes `FieldRegistry` × `FilterLayout`.
      Removed `display.category` from every field and the top-level `categories:` block from `fields.yml`.
      Backstopped by `table_layout_spec` (membership) + the value-based `column_registry_spec` (golden
      master — composed output unchanged). The four-file goal (§8.6) is now realized: `fields.yml` (what),
      `filter_layout.yml` (filter arrangement), `table_layout.yml` (table arrangement), `tooltips.yml` (copy).
**(Thread A) Retire `config/filters.yml` — backend cutover, in three stages:**

- [x] **Stage 1 — sort + permit args read the manifest. DONE.** `permit_arguments`, `sortable_columns`,
      and the derived `sortable_table_joins` (association = model symbol; join when the model isn't the base
      `PublicWaterSystem`) now come from `FieldRegistry`; `FilterParams`, `HomeController`, and `Sortable`
      point at it. Guarded by the permit/sort parity spec. `filters.yml` now feeds only `Filterable` + the
      client-payload view. (This resolves the old `sortable_table_joins` caveat — it derived cleanly from the
      manifest, no new home needed.)
- [ ] **Stage 2 — replace `Filterable` with a layout-driven combiner + adopt the filters/sub_filters
      AND/OR rule** (see the semantics decision below). Derive each filter's column / table / coercion / join
      from the manifest, and its **AND/OR structure from `filter_layout.yml` nesting**; retire the per-model
      `apply_*` methods and the `range_column_groups` + `violations` sections of `filters.yml`. This
      **deliberately changes behavior** for two groups (funding and violations → AND): rewrite the OR specs
      that assert the old behavior — `filterable_spec` 294 / 309 / 322 (violations) and 423 (funding) — to AND;
      the within-parent subcat OR specs (268 / 281) and watershed (449, already `sub_filters`) stay. Update
      `docs/FILTERING.md` to the new rule.
- [ ] **Stage 3 — delete `filters.yml` + `FilterRegistry` + parity spec.** After Stage 2, only
      `client_payload` remains. Give it a deliberate home, then delete the file, the registry, and the
      permit/sort **parity spec** (`field_registry_spec` "parity with FilterRegistry"). End state: the
      four-file model with `filters.yml` + `FilterRegistry` gone.
  > **Caveat — `client_payload`.** The one remaining non-trivial piece: the JSON contract shipped to
  > `filter_controller.js` (`#filter-registry-config`). Decide its home as part of Stage 3.

> **Filtering semantics — the AND/OR rule (decided 2026-06).** Combination is read straight off
> `filter_layout.yml` structure: **sibling `filters:` entries AND; entries within a `sub_filters:` list
> OR.** Categories are purely visual and no longer affect AND/OR. Two intrinsic ORs are unchanged: a single
> multiselect's selected values OR among themselves, and a range's own min/max AND. To make a set of filters
> OR, nest them under a parent with `sub_filters`; to AND them, list them as siblings.
>
> This **supersedes** the old per-model behavior (where `funding` / `watershed` / `violations` models OR'd
> across their columns). Under the new rule **funding → AND** (plain siblings) and **violations →
> `open_health_viol AND health_5yr AND health_10yr AND paperwork_5yr AND paperwork_10yr`**, with each
> `health_*` parent's sub-filters OR'ing within. **Watershed stays OR** because its columns are already
> `sub_filters`; demographic / EJ / trend stay AND (plain siblings). Trade-off accepted: filter behavior now
> depends on the layout's nesting — but the nesting *is* the semantic grouping, so the layout is its right
> owner.

<!-- Deffered - we are going to hold off on CSV import logic and not tackle duing this refactor -->
### Phase 6 — Portal / CSV-driven config
- [ ] Manifest override source (CSV record or admin portal) — a thin CRUD layer that
      writes/overrides `fields.yml`.
- [ ] Generic filter applier driven by `filter.kind`; custom SQL only for special filters.

---

## 8.1 The custom-config register (least-custom discipline)

The goal is least custom config, **not zero** — some transforms genuinely cannot be
declarative. The discipline that keeps it honest: **every custom path is declared in
the manifest and enforced by a spec, so custom config is always a deliberate, visible
choice — never silent drift.**

Add a manifest annotation wherever declarative config stops, e.g.:

```yaml
watershed_hazards:        # field/group needing a non-declarative transform
  model: watershed_hazard
  source: { file: pwsid_npdes_usts_rmps_imp }
  custom:
    importer: Etl::Importers::PwsidNpdesUstsRmpsImp
    reason: "Multiple HUC12 rows per pwsid — pre-aggregated with GROUP BY/SUM at import."
```

Known custom cases to register (the bounded exception set):

| Case | Where | Why it stays custom |
|---|---|---|
| `epa_sabs_geoms.geojson` | ETL | 1 GB streamed SAX parse + geometry |
| `pwsid_npdes_usts_rmps_imp` | ETL | `GROUP BY pwsid, SUM(...)` aggregation |
| `stusps` from pwsid prefix | ETL | derived/computed, no source column |
| Post-import spatial steps | ETL | centroids, state codes, place crosswalks |
| Boil-water / place / county / bounds filters | `filterable.rb` | special joins / non-range SQL semantics |

The Phase 4 + Phase 0 specs assert this register is **complete**: nothing custom
exists that isn't declared here.

---

## 8.2 Tooltips: intentionally not consolidated (yet)

`tooltips.yml` does **not** fold cleanly into the per-field manifest, and Phase 2 leaves
it alone on purpose. Reasons:

- **Concept-keyed, not field-keyed.** One tooltip (`groundwater_rule`) serves *both* the
  5yr and 10yr fields; `most_common_rate_tier`'s tooltip is keyed `annual_water_sewer_bill`.
- **Some tooltips belong to category headers, not fields** (`primary_type`, `violations`,
  `population_size`, `boil_water_notices`, `funding_2021_2025`) and to non-field
  affordances (`exports.geojson`).

So a strict per-field `tooltip:` would either duplicate text across variants or fail to
represent header/affordance tooltips. **Decision:** tooltips stay in `tooltips.yml` for
now — the manifest carries no `tooltip:` key and the parity spec does **not** assert
tooltip parity. A future option (not scheduled) is a `concepts:` section in the manifest
that fields reference by key — revisit during Phase 5 when the filter-menu ERB (which
actually renders tooltips) is generated from the manifest.

---

## 8.3 The manifest is a "surfaced or ingested" list, not a "what exists" list

`fields.yml` describes every field the app **surfaces or ingests** — not the full database
schema. A field belongs here when it is shown as a table column, filtered on, drawn as a
histogram, **or** loaded from a source file; it earns its place by having at least one of the
four blocks (`source` / `display` / `filter` / `histogram`). A field is added only when we
choose to ingest and/or surface it, so **exposure is a product-driven decision** whoever edits
`fields.yml` must have an answer for. The pipeline loads more columns than appear here.

Four independent axes, each signalled by the presence of its block: `source` (ingested from a
file — may be the *only* block, i.e. ingest-only/source-only), `display` (table column), `filter`
(filterable; placement + grouping then live in `filter_layout.yml`, §8.4), `histogram`. A field
can have any subset — e.g. `total_population` is a column + histogram but has **no** menu control;
`cejst_disadvantaged_pct` is a column whose filter lives under the *Population → Vulnerability*
menu even though its table category is Environmental Justice; ~20 fields are source-only (ingested,
never surfaced). **Menus, categories, and parent-filters are not fields and never appear here** —
they live only in `filter_layout.yml`.

**When is a field NOT column-shaped at all?** Rule of thumb: *does it have a single,
readable per-PWS value?* If not, it never gets a `display` block regardless of product
intent — e.g. `place_geoid` (a user-supplied search/join key, not a PWS attribute) and
`bounds`/`county_geoid` (map/geographic inputs). Contrast `pop_cat_5`, which *does* have a
per-row value but product chose to show `total_population` instead — a genuine product call.

### Ingested but not yet surfaced — product review candidates

These columns are imported into the DB but appear in no column/filter/histogram today.
Bring product answers before adding any to `fields.yml`:

| Model | Plausibly valuable to surface | Likely internal / metadata |
|---|---|---|
| PublicWaterSystem | `population_served_count`, `service_connections_count`, `years_operating`, `primacy_agency`, `primary_source_code`, `first_reported_date`, `ewg_report_link` | `phone_number` |
| ViolationsSummary | `total_violations_5yr`, `total_violations_10yr`, `violations_all_years` | — |
| Demographic | `household_income_lowest_quintile` | — |
| TrendDatum | `unemployment_pct_change`, `poverty_pct_change`, `poc_pct_change`, `households_pct_change`, `population_in_poverty_pct_change`, `lowest_quintile_pct_change` | `income_change_flag`, `population_change_flag` |
| EnvironmentalJustice | `cvi_cancer_risk`, `cvi_life_expectancy`, `cvi_redlining`, `ejscreen_disability_rate`, `ejscreen_drinking_water`, `cejst_lead_paint_indicator`, `cejst_low_life_expectancy_pctl` | — |
| FundingSummary | `median_srf_assistance` | — |
| WatershedHazard | `npdes_permits` | — |
| BoilWaterSummary | `first_advisory_date`, `last_advisory_date` | `download_url`, `date_range_display`, `tooltip_text`, `state`, `state_reporting_year_min/max` |

(Regenerate anytime: compare each `Model.column_names` to the columns referenced by the
manifest — the same check the durable invariant spec performs.)

---

## 8.4 Placement & ordering: layout files, not manifest tags

**Decision:** arrangement (which menu/category, in what order, with what nesting) lives in
dedicated **layout files**, not as tags on each field. The manifest owns *what each field
is* (definition + capability); the layout files own *how fields are arranged*.

```
fields.yml          → definition + capability  (is it a column? filterable? a histogram? how?)
filter_layout.yml   → the ordered, NESTED menu → section → filter → sub-filter tree
table_layout.yml    → column order + category order   (optional / lower priority)
```

The layout files reference fields **by key** and pull every detail (label, kind, format,
tooltip) from the manifest — a key reference, not duplicated data.

### Why a separate file beats per-field `menu`/`section` tags

1. **Nesting.** The filter menu is a tree — subcat panels are a *parent checkbox with
   ordered child range filters* (health violations 5yr/10yr). Flat per-field tags cannot
   express parent→children ordering; a nested layout file does:
   ```yaml
   compliance:
     violations:
       - has_open_violations
       - health_5yr:                     # parent panel
           - groundwater_rule_5yr        # ordered children
           - surface_water_treatment_5yr
   ```
2. **Single owner of order.** Order is explicit and total (menus, sections, filters within a
   section, sub-filters) — no reliance on incidental YAML file-order.
3. **Backend-only filters fall out cleanly.** A field that is filterable via URL but has no
   menu control (`total_population`) simply doesn't appear in the layout — absence *is* the
   statement. No "omit menu/section" special case.
4. **Reorder = edit one ordered list.** Portal/CSV-friendly; the natural drag-and-drop target.

### The condition that keeps two files safe (non-negotiable)

Splitting placement into a second file is the *same shape* as the columns.yml-vs-filters.yml
problem this whole effort fixes — it is only safe **with an enforcing spec**, which the old
setup lacked. The layout backstop spec must assert: every layout key ∈ manifest; every
filterable field appears in the layout **exactly once** or is explicitly marked backend-only;
no orphans, no duplicates. With that spec, the split is clean separation; without it, it is
new drift.

Also: **don't reuse the name `filters.yml`** (the legacy file being retired) — use
`filter_layout.yml` / `table_layout.yml`.

### Asymmetry between the two layout files

- **`filter_layout.yml` — clear win.** The nesting makes it strictly more expressive than
  tags; this is real, not cosmetic.
- **`table_layout.yml` — wanted for *consistency*, lower *expressiveness* ROI.** The table is
  *flat* (no nesting), so it doesn't need a layout file to be *expressible* the way the filter menu
  does. But it's still worth authoring: it makes column-within-category order explicit (today it is
  manifest file-order) and lets `display.category` membership move out of the field — which means
  **ordering lives in layout files everywhere and `fields.yml` carries no order at all.** That
  uniformity (one obvious place per concern) is the reason to do it, not an expressiveness gap.

**Current state:** the `menu`/`section` tags in `fields.yml` are interim seed data for
`filter_layout.yml`. They are removed in Phase 5 when the layout file is authored.

### Taxonomy (terms used everywhere — see docs/FILTERING.md)

`Menu` (L1) → `Category` (L2) → `Filter` (L3) → `Sub-filter` (L4) → `Range` (L5). **Filter**,
not "Group": "Open violations" is a filter; "Health violations (5yr)" is a filter that *also*
reveals sub-filters — and L4 being "Sub-**filter**" implies L3 is a Filter. (The JS `group`
control-type and `GroupRangeComponent` are a separate *control-type* axis, not the L3 taxonomy
level.) In `filter_layout.yml` the manifest's interim L2 tag `section:` maps 1:1 to `Category`.

### Where filter copy & state live (decided — applied in the generator step)

**One discriminator, no exceptions: does it have a manifest record?** A filterable value (an L3
filter or L4 sub-filter) has a record in `fields.yml`. Menus, categories, and parent-filters
(`health_5yr`, `watershed_hazards`) do **not** — they are layout-only grouping / check-all tools.

- **Has a record → all its copy & state live in the manifest** `filter:` block: the menu `label`,
  the `tooltip` ref (into `tooltips.yml`), and — for radio / multiselect — the ordered `options`
  (each `value` + `label`, with `default: true` on the initially-on ones) plus `has_select_all` for a
  flat multiselect that has a bulk control. Note `filter.label` is the MENU label, a separate key
  from the table `display.label` (the two differ ≈half the time).
- **No record → its copy & state live in `filter_layout.yml`**: the menu / category / parent-filter
  `label` and `tooltip` ref. A parent-filter's check-all is implied by its `sub_filters` (no flag), and
  any bulk control's checked appearance is *derived* from its members' `default`, never declared.

The **layout always owns the tree** — which menu/category a filter sits in, the order of filters /
categories / sub-filters, and the nesting. It does *not* reach inside a filter to reorder its
options (option order is intrinsic to the field → manifest). **`tooltips.yml` always owns the
tooltip text.**

So: **field → manifest, container → layout, text → tooltips.yml.** One rule, no per-field special
cases, every setting in exactly one file — flat multiselects flag a bulk control with `has_select_all`,
parent-filters get theirs implicitly from `sub_filters`. *These keys are added in the generator step (Phase 5 increment 2), not the
initial placement-only `filter_layout.yml`.*

---

## 9. Remaining task summary

**Status snapshot (2026-06):** Phases 0–4 are **complete** — the back-end is fully manifest-driven
(definition, model routing, ETL import, server views, sort/filter/histogram config all derive from
`fields.yml`). **Phase 5 is in progress:** layout files authored (task 7 ✅); filter state is now
**server-rendered for every filter control** (8a done — **Checkpoint A**). Still outstanding: the
manifest-loop **ERB generation** (8b — the one-file-edit payoff) and the **JS convergence** (9).
See the three Phase-5 checkpoints above.

| # | Task | Phase | Status | FSR-coupled? |
|---|------|-------|--------|--------------|
| 1 | Parity/golden-master spec vs current registries | 0 | ✅ done | no |
| 2 | Expand `fields.yml` to all groups + core PWS controls | 2 | ✅ done | no |
| 3 | Grow `FieldRegistry` to reproduce every server view | 2 | ✅ done | no |
| 4 | Register custom cases in-manifest (`custom_imports`, §8.1) + no-silent-gaps spec | 2/4 | ✅ done | no |
| 5 | Cut `ColumnRegistry` + histogram config over; delete `columns.yml` + `histogram_field_groups` | 3 | ✅ done (permit/sortable deferred to P5) | no |
| 6 | ETL `source:` coverage (all 8 generic files) + `Generic` importer + cutover | 4 | ✅ done | no |
| 7 | Author `filter_layout.yml` (nested) + layout backstop spec; remove `menu`/`section` tags from manifest | 5 | ✅ done | **yes — is FSR** |
| 8a | **Server-render** filter state from decoded URL (Approach B, per control type) | 5 | ✅ done — all controls (**Checkpoint A**) | **yes — is FSR** |
| 8b | **Generate** filter-menu ERB from `filter_layout.yml` × `fields.yml` (manifest loop) | 5 | ◻ todo — **the one-file-edit payoff (Checkpoint B)** | **yes — is FSR** |
| 9 | FSR Phase 3 — delete `#restoreDomState`, slim `FILTERS[]`, indeterminate hook, `view=` | 5 | ◻ todo (per-control specs land with 8a) | **yes — is FSR** |
| 10 | Port `rate_tier` control into the manifest + layout | 5 | ✅ manifest+layout+server-render done; JS removal rides with #9 | partial |
| 11 | Portal / CSV override layer + generic filter applier | 6 | ◻ todo | no |
| 12 | `table_layout.yml` for explicit column/category order *(wanted for consistency — ordering out of the manifest)* | 5/6 | ◻ todo | no |
| 13 | **How-to / decision tree: "adding a data point"** — flat-map vs custom, migration-needed?, new-column-on-existing-file vs new-file vs new-table; the surfacing axes (display/filter/histogram). Likely `docs/ADDING_A_FIELD.md` | docs | ◻ todo | no |
| 14 | **Remove `Place` as a filter** — drop the filter-menu UI, `place_geoid` filtering (`filterable.rb`), its manifest/layout/permit entries, the `FILTERS[]` entry, and the now-dead `/places/search` autocomplete. **Keep** `PlaceSystemCrosswalk`, its ETL, map tiling (`tile_impact.rb`), and the two PWS-name searchboxes (the `search` param — a separate feature). **Best done after 8b** so it doubles as the `docs/REMOVE_A_FILTER.md` reference (removal ≈ a layout-file edit). | 5/docs | ◻ todo | partial |
| 15 | **Menu id → menu key (readability fast-follow)** — replace the integer menu `id` (1–5, More=`10`) with the readable menu key across the `container-menu-*` / `main-filter-grp-*` / `more-filter-grp-*` / `container-menu-btn-*` / `container-filter-count-menu-*` ids + the 4 JS controllers (`filter`/`filter_menu`/`filter_layout`/`nav`, incl. the hardcoded More=`10`), then drop `id:` from `filter_layout.yml` (order already comes from file order). Pairs with the FSR JS rewrite — it touches the same controllers. | 5/cleanup | ◻ todo | no |

---

*Generated as a configuration audit. Companion docs: `docs/ETL.md` (ingestion),
`docs/FILTERING.md` (filter behavior & stack),
`docs/open_items/FILTER_SERVER_RENDER.md` (the §7 refactor this converges with).*
