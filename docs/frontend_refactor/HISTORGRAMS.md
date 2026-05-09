# Histograms and Range Sliders

Histogram range sliders appear throughout the filter menus. Each slider fetches bin data from the server, renders an SVG bar chart, and exposes two drag handles that write min/max values to hidden inputs consumed by `filter_controller.js` on Apply.

---

## How It Works

### Server-Side Endpoint

```
GET /public_water_systems/histogram?field=paperwork_violations_5yr
→ { bins: [{ min: 1, max: 5, count: 412 }, ...], domain_min: 1, domain_max: 1070 }
```

**Controller:** `app/controllers/public_water_systems/histograms_controller.rb`

Maintains a `FIELD_CONFIG` hash mapping every allowed field name (symbol) to its source model and any `histogram_bins` kwargs. This drives both model routing and the `ALLOWED_FIELDS` security allowlist. Unknown fields return `400`.

**Model concern:** `app/models/concerns/histogrammable.rb`

Included in: `ViolationsSummary`, `Demographic`, `EnvironmentalJustice`, `TrendDatum`, `WatershedHazard`, `FundingSummary`. Provides `histogram_bins(field, num_bins: 50, min_threshold: 0)`. Uses PostgreSQL `width_bucket` for server-side binning. By default excludes rows where `field <= 0`; pass `min_threshold: nil` for signed/negative fields (trend/change data).

### Stimulus Controller

**File:** `app/javascript/controllers/slider_controller.js`

| Concept | Detail |
|---|---|
| `field` value | DB column name; drives the histogram fetch |
| `url` value | Histogram endpoint URL |
| `format` value | Controls label formatting and domain clamping (see below) |
| `chart` target | SVG element where bars and handles are rendered |
| `minInput` / `maxInput` targets | Hidden inputs; written on pointerup; read by `filter_controller.js` on Apply |
| `zeroLabel` target | Only rendered for `percent_change` format; shows "0" centered between min and max labels |

**Lifecycle:**
- `connect()` — fetches bins, renders full-range SVG, positions handles at domain extremes. Fires on page load even when the panel is hidden.
- Pointer drag — moves handle, shows floating value tooltip. No server calls.
- `pointerup` — commits current min/max to hidden inputs.
- `resetToFullRange()` — called by `filter_controller.js` on Reset; restores handles and clears inputs.

**Module-level cache:** Responses are stored in a module-level `Map` keyed by field name. Each unique field fetches exactly once per browser session regardless of how many times its panel opens or closes.

### `format` Value

Controls axis label formatting and domain clamping applied in `#init()`:

| Value | Labels | Domain clamping |
|---|---|---|
| *(not set)* | `1,234` (integer, no symbol) | `domain_min` floored at 1 |
| `currency` | `$1,234` | `domain_min` floored at 1 |
| `percent` | `96%` | Always 0–100, ignoring server values |
| `percent_change` | `-45%` / `+12%` with `0` midpoint label | At least -100 to +100; server values extend if wider |

### ERB Partial

**File:** `app/views/home/_slider_panel.html.erb`

Accepted locals: `panel_id`, `field`, `min_input_id`, `max_input_id`, `label` (default: "Number of violations"), `format` (default: nil). Used by `RangeFilterItemComponent` and direct renders in `_filter_menus.html.erb`.

---

## Key Decisions

### No chart library

The slider is a custom SVG Stimulus controller. The legacy app used Highcharts. We do not, for three reasons:
1. **No build step** — Importmaps-only stack; npm-based libraries require a bundler or CDN pin with limited control.
2. **Drag-range-select is the primary feature** — any chart library gives you bars but you write all the interaction (handles, range coloring, hidden input wiring, Stimulus lifecycle) on top anyway.
3. **Size** — the controller is ~250 lines and does everything needed. Highcharts is ~1MB, Chart.js ~200KB, ApexCharts similar — none solve the core interaction problem.

### Square-root bar scaling

Bar heights use `sqrt(bin.count) / sqrt(maxCount)` rather than a linear ratio. Water system data is almost always right-skewed — most systems cluster at low values, a handful have extreme counts. With linear scaling, bins containing hundreds of systems become invisible slivers next to bins containing thousands. Square-root scaling is perceptually honest (preserves relative ordering), makes minority-count bins visible, and is less aggressive than log scale. Applied consistently across all histograms — no per-field logic.

### Capped columns for trend/change data

`population_pct_change_capped` and `mhi_pct_change_capped` are used for both display and filtering, not the raw `population_pct_change` / `mhi_pct_change` columns. The raw columns contain legitimate data artifacts — a military installation going from 2 to 11,112 connections produces a raw value of +555,500%. With 50 bins and a domain that wide, all real data collapses into bin #1 with nothing visible elsewhere. The `_capped` columns were pre-computed in the ETL (capped at ±200%) and always intended for display and filter use. Raw columns are retained for data completeness.

### Server-side histograms

The legacy app computed histograms client-side from Mapbox vector tile features (visible features only, naturally limiting the distribution). The Rails app uses vector tiles — feature data is not available as JS objects. PostgreSQL `width_bucket` runs a single query server-side; the response is stable between ETL imports and cached in the browser for the session.

---

## Edge Cases

- **Single-value data** (`domain_max === domain_min`): renders as a flat horizontal line with handles at both ends.
- **Reset before fetch completes:** `resetToFullRange()` returns early if bins haven't loaded. Handles stay at last committed position. Edge case; not addressed.
- **Fetch on page load:** all connected slider panels fire their fetch immediately, not on first reveal. The module-level cache ensures each unique field fetches once regardless.

---

## Design Mocks

All mocks: `docs/mocks/subfilters_and_histograms/`

- `histogram_bar_style.png` — target bar style: lighter blue, rounded tops, spacing between bars, bold label, horizontal separator line
- `historgram_style_variations.png` — six edge-case states: default, dragging, set range, single value, percent change with signed axis, low-value clustering
- `histogram_under_subfilter.png` — how the slider sits within the Compliance menu under a non-health violation parent

---

## TODO

- **Confirm health violation subcat slider behavior** — when do histogram panels open and close? What range should sliders show on first load? Needs design/product confirmation before treating as complete.
- **Hover bin counts** — show bin count tooltip on bar `mouseover` (not only during handle drag). `#showTip` / `#hideTip` are already wired; add `pointerenter`/`pointerleave` listeners on bar rects.
- **Manual text input** — let users type min/max values directly. `minInputTarget` / `maxInputTarget` exist; add visible text inputs, clamp and sync to handle position on `change`.
- **Styling pass** — bar style, hover feedback, and visual edge cases per the mock (`histogram_bar_style.png` and `historgram_style_variations.png`). Partially done; full pass pending.
