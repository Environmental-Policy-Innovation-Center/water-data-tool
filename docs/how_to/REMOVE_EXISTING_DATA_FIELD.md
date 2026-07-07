# How To: Remove an Existing Data Field

> **Status: seed notes (task 13).** Harvested from the Place-filter removal (CONFIG_AUDIT
> task 14). Flesh out into a full guide alongside `ADD_NEW_DATA_FIELD.md` and
> `EDIT_EXISTING_DATA_FIELD.md`. Must cross-reference the category AND/OR rule and the
> base-vs-join-tables model (see `docs/FILTERING.md`).

## The short version: a normal field is a ~2-file removal

Because the four-file model is manifest-driven, removing a *standard* filterable field
(range / bool / radio / multiselect) is small — permit args, sort, histogram, and menu
rendering all **derive** from the manifest, so deleting the source entry cascades:

1. **`config/fields.yml`** — delete the field's manifest entry.
2. **`config/filter_layout.yml`** — remove the field from its category's `filters:` list.
   If that empties the category, remove the category; if it empties the menu, remove the menu.
   (Same for `config/table_layout.yml` if the field was a table column.)
3. **Specs** — drop/adjust anything asserting the param: `filterable_spec`,
   `filter_params_spec`, and the server-render assertions in `home_spec`.
4. **(Optional) migration** — only if the field had its own DB column you also want gone.
   Many filters resolve without a dedicated PWS column (Place used a crosswalk), so this
   step is often skipped.

Nothing else is needed for a fully manifest-driven field: `permit_arguments`,
`sortable_columns`, histogram config, and the generated `_filter_menus.html.erb` all
recompute from the manifest × layout.

## The long version: removing a *custom* control kind

A field with a **bespoke filter kind** (Place was `kind: place`) has extra wiring that does
*not* derive from the manifest. When removing one, grep the field/param name and expect to
touch each of these:

| Concern | Where it lived for Place |
|---|---|
| Permit branch | the `:place` case in `field_registry.rb#permit_arguments` (carried `name_param`) |
| Control dispatch | the `when "place"` arm in `app/views/home/_filter_control.html.erb` |
| Dedicated partial | `app/views/home/_filter_place.html.erb` |
| Stimulus controller | `app/javascript/controllers/place_autocomplete_controller.js` (eager-loaded — deleting the file deregisters it) |
| JS collect/reset | the `case "place"` in `filter_controller.js#collectFilters`, the reset block, and a `place_name` read in `#updateGeoTitle` |
| View helper | `home_helper#place_search_value` |
| Bespoke filtering path | a branch in `filterable.rb#apply_geographic_filters` (crosswalk subquery), not the generic combiner |
| Companion display param | `place_name` carried alongside the geoid |
| Route + controller | `/places/search` → `PlacesController` |

## Caution: classify every grep hit before deleting

A field name often appears in **unrelated features**. `place_geoid` also lives in map
tiling (`TileImpact#for_place_geoids`) and ETL (`build_place_crosswalks`), and the
`PlaceSystemCrosswalk` / `CartographicPlace` models back those — all of which **must
survive** removing the *filter*. Grep the term, then label each hit as *filter* vs.
*other feature* before touching it.

## Verify

- Full spec suite green (`bundle exec rspec`).
- `standardrb` + `erb_lint` clean on changed files.
- `bin/rails routes` loads (no dangling controller reference).
- Manual: the filter no longer renders in the menu UI; an old shared URL carrying the
  removed param still loads without error (the stale param is simply ignored).
