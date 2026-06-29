# Remember To

A scratchpad for docs housekeeping — things to write, update, remove, or decide on.

---

### Add

- **Column Management** — how the config works, where it's used, what the helpers do
- **How to add new data** — full guide covering filters, table columns, exports, etc. (flesh out
  the `docs/how_to/ADD_NEW_DATA_FIELD.md` stub; once written, cross-link it from the headers of
  `config/fields.yml`, `config/filter_layout.yml`, and `config/table_layout.yml`).
- **Github Workflows** — document the deploy pipeline and PR environment lifecycle


### Update

- `ETL.md`
- `FILTERING.md`
- `GLOSSARY.md`
- `MAPPING.md`
- `TAILWINDS_CSS_GUIDE.md`
- `DEPLOYMENTS.md`
- `FRONTEND_DECISION.md`
- `HISTOGRAMS.md`
- `DATA_TABLE.md`
- `URL_MANAGEMENT.md` — add section (see note in `NICE_TO_HAVES.md`)
- `Contributing` — how other open source repos handle this; style guides, PR norms, etc.
- `README` — confirm it's up to date and refs all relevant docs _(partially done)_

### Remove

- `TRANSITION.md` — legacy migration notes, likely stale

### Decide

- `ETL_STRING_NORMALIZATION.md` — still relevant?
- `API.md` — still accurate / needed?
- `OPEN_WORK_ITEMS.md` — ready to delete once fully extracted _(see `NICE_TO_HAVES.md`)_
- `DRAG_DROP_SORTABLE_JS.md` — keep as open item or move to nice-to-have?

- `mocks` directory

- CI
  - Add ci notes on how to handle brakeman faiures
  - Add ci nots on how to handle bundler-audit failures


### Verify / Check

- **Boil Water Summary filter** — placeholder exists in Notices UI but is disabled; confirm when filter is implemented

### Other

- Reorganize `docs/` structure — remove stale implementation guides, consider new categories
  (runbooks, guides, architecture, domain concepts)
- **Test GeoJSON exports**


- Remove Place filter