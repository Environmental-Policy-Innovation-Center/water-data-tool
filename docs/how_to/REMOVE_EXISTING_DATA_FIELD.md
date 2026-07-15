# How To: Remove an Existing Data Field

##### How to remove a data field, filter, or column.

Because the four-file model is manifest-driven, removing a *standard* field is small — most wiring derives from the manifest and cascades when you delete the entry. A field with custom wiring needs more care. ("The manifest" = `config/fields.yml`.)

See also:
- [docs/FILTERING.md](../FILTERING.md) — how filtering works end-to-end (config sources, AND/OR combining, base-vs-join tables).
- [docs/ETL.md](../ETL.md) — the import pipeline: generic vs. custom importers and casting.
- Sibling how-tos: [ADD_NEW_DATA_FIELD.md](ADD_NEW_DATA_FIELD.md) · [EDIT_EXISTING_DATA_FIELD.md](EDIT_EXISTING_DATA_FIELD.md).

---

## The short version: a standard field is a ~2-file removal

A *standard* field (range / bool / radio / multiselect) is small to remove — permit args, sort, histogram, and menu rendering all **derive** from the manifest, so deleting the source entry cascades:

1. **`config/fields.yml`** — delete the field's manifest entry.
2. **`config/filter_layout.yml`** — remove the field from its category's `filters:` list. If that empties the category, remove the category; if it empties the menu, remove the menu. (Same for `config/table_layout.yml` if the field was a table column.)
3. **Specs** — drop or adjust anything asserting the param: `spec/models/concerns/filterable_spec.rb`, `spec/filters/filter_params_spec.rb`, and the server-render assertions in `spec/requests/home_spec.rb` (plus `spec/columns/table_layout_spec.rb` if it was a table column).
4. **(Optional) migration** — only if the field had its own DB column you also want gone. Many filters resolve without a dedicated column, so this step is often skipped.

Nothing else is needed for a fully manifest-driven field: `permit_arguments`, `sortable_columns`, histogram config, and the generated `_filter_menus.html.erb` all recompute from the manifest × layout.

---

## Removing a whole satellite table (not just a field)

If the field you're removing was the *last* field on its satellite table, remove the table too —
this mirrors `ADD_NEW_DATA_FIELD.md`'s "Brand-new table" subsection, in reverse:

1. **The model** — delete `app/models/<model>.rb`.
2. **The association** — remove the `has_one`/`has_many` line from `app/models/public_water_system.rb`.
3. **The manifest's model registry** — remove the entry from `MODEL_CLASSES` in `app/fields/field_registry.rb`.
4. **The export join list** — remove the `LEFT JOIN` line from `ASSOCIATION_JOINS` in
   `app/exporters/public_water_system_exporter.rb`. This isn't optional cleanup: a stale join to a
   dropped table raises `PG::UndefinedTable: relation does not exist` on the next export, the same
   failure mode as forgetting to add it in the first place.
5. **The factory and model spec** — delete `spec/factories/<table>.rb` and `spec/models/<model>_spec.rb`.
6. **A migration** — `drop_table :<table_name>`.

Each of these fails loudly if missed (`KeyError`, `PG::UndefinedTable`, or a `NameError` on the deleted
constant) — none of it fails silently, so `bin/ci` will catch a skipped step.

---

## The long version: removing a custom control kind

A field with a **custom filter kind** (e.g. the removed Place filter, `kind: place`) has extra wiring that does *not* derive from the manifest. Grep the field/param name and expect to touch each of these:

| Concern | Where it lived for Place |
|---|---|
| Permit branch | the `:place` case in `FieldRegistry.permit_arguments` (`app/fields/field_registry.rb`; carried `name_param`) |
| Control dispatch | the `when "place"` arm in `app/views/home/_filter_control.html.erb` |
| Dedicated partial | `app/views/home/_filter_place.html.erb` |
| Stimulus controller | `app/javascript/controllers/place_autocomplete_controller.js` (eager-loaded — deleting the file deregisters it) |
| JS collect / reset | the `case "place"` in `filter_controller.js#collectFilters`, the reset block, and a `place_name` read in `#updateGeoTitle` |
| View helper | `home_helper#place_search_value` |
| Custom filtering path | a branch in `filterable.rb#apply_geographic_filters` (crosswalk subquery), not the generic combiner |
| Companion display param | `place_name` carried alongside the geoid |
| Route + controller | `/places/search` → `PlacesController` |

---

## Caution: classify every grep hit before deleting

A field name often appears in **unrelated features**. `place_geoid` also lives in map tiling (`TileImpact#for_place_geoids`) and ETL (`build_place_crosswalks`), and the `PlaceSystemCrosswalk` / `CartographicPlace` models back those — all of which **must survive** removing the *filter*. Grep the term, then label each hit as *filter* vs. *other feature* before touching it.

---

## Verify

- `bin/ci` runs clean.
- `bin/rails routes` loads (no dangling controller reference — only relevant if you removed a route/controller).
- Manual: the filter no longer renders in the menu UI; an old shared URL carrying the removed param still loads without error (the stale param is simply ignored).
