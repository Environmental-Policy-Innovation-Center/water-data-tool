# Histograms and Range Sliders

Histogram range sliders appear throughout the filter menus. Each slider fetches bin data from the server, renders an SVG bar chart, and exposes two drag handles that write min/max values to hidden inputs consumed by `filter_controller.js` on Apply.

---

## How It Works

### Server-Side Endpoint

```
GET /public_water_systems/histogram?field=paperwork_violations_5yr
→ {
    bins: [
      { min: 1.0, max: 2.0, count: 412 },
      { min: 2.0, max: 3.0, count: 0 },
      ...
    ],
    domain_min: 1,
    domain_max: 1070
  }
```

**Controller:** `app/controllers/public_water_systems/histograms_controller.rb`

Maintains a `FIELD_CONFIG` hash mapping every allowed field name (symbol) to its source model and any `histogram_bins` kwargs. This drives both model routing and the `ALLOWED_FIELDS` security allowlist. Unknown fields return `400`.

**Model concern:** `app/models/concerns/histogrammable.rb`

Included in: `ViolationsSummary`, `Demographic`, `EnvironmentalJustice`, `TrendDatum`, `WatershedHazard`, `FundingSummary`.

Provides `histogram_bins(field, format: nil, num_bins: nil, min_threshold: 0)`. The number of bins is determined by the field's `format` (see Bin Strategy below). Uses PostgreSQL `width_bucket` for server-side binning, then fills gaps in Ruby so the response always contains exactly `num_bins` entries — including empty bins with `count: 0`.

**Bin boundaries are theoretical, not data-derived.** Each bin's `min`/`max` in the response represents the uniform theoretical bucket boundaries, not the actual data min/max within that bucket. This keeps bar positioning and coloring consistent regardless of data distribution.

**`min_threshold` behavior by format:**
- `percent` — no threshold applied; 0% is a valid data point and the domain is fixed at 0–100 regardless of data.
- `percent_change` — no threshold applied by default; an explicit non-zero threshold is respected (uses `.nonzero?` guard). 0% change is a valid data point.
- `count` / `currency` / default — rows where `field <= 0` are excluded before computing domain min/max. Pass `min_threshold: nil` to include all non-null rows.

### Stimulus Controller

**File:** `app/javascript/controllers/slider_controller.js`

| Concept | Detail |
|---|---|
| `field` value | DB column name; drives the histogram fetch |
| `url` value | Histogram endpoint URL |
| `format` value | Controls bin strategy, label formatting, and domain clamping (see below) |
| `chart` target | SVG element where bars and handles are rendered |
| `minInput` / `maxInput` targets | Hidden inputs; written on pointerup; read by `filter_controller.js` on Apply |
| `minTextInput` / `maxTextInput` targets | Visible `type=text` inputs below the SVG; bidirectional sync with drag handles via `#syncTextInputs` and `#onTextChange` |
| `zeroLabel` target | Always rendered as `sr-only` (screen readers only). Previously conditionally visible for `percent_change`; now always present so the controller can write to it unconditionally. |

**Lifecycle:**
- `connect()` — fetches bins, renders full-range SVG, positions handles at domain extremes. Fires on page load even when the panel is hidden.
- Pointer drag — moves handle, shows floating value tooltip. No server calls.
- `pointerup` — commits current min/max to hidden inputs.
- `resetToFullRange()` — called by `filter_controller.js` on Reset; restores handles, clears hidden inputs, and calls `#syncTextInputs()` to clear the visible text inputs (restoring placeholders).
- `#handleStateChange()` (on `filters:changed`) — when the geo `state` param actually changed, clears the cached bins/inputs and, if the panel is currently visible, re-fetches for the new state (see [State scoping](#state-scoping) below).

**Module-level cache:** Responses are stored in a module-level `Map` keyed by `"{field}|{state}"` (empty string for national scope). Each unique field/state pair fetches exactly once per browser session regardless of how many times its panel opens, closes, or the geo scope changes and changes back.

### `format` Value

Controls bin count, axis label formatting, and domain clamping applied in `#init()`:

| Value | Labels | Domain clamping | Bin strategy |
|---|---|---|---|
| *(not set / count)* | `1,234` (integer, no symbol) | `domain_min` floored at 1; `domain_max` padded to a nice round number **unless** it's a small-count domain (below) | Integer bins up to cap of 30, then equal-width (see Bin Strategy) |
| `currency` | `$1,234` | `domain_min` floored at 1; `domain_max` padded to a nice round number (`#niceMax`) | Equal-width, 30 bins |
| `percent` | `96%` | Always 0–100, ignoring server values | Fixed 20 bins of 5 percentage points |
| `percent_change` | `-45%` / `+12%` | Always −200 to +200 (matches ETL cap on `_capped` columns) | Fixed 40 bins of 10 percentage points |

**Small-count domain exception:** when a `count` field has few enough distinct integer values that the server's own 30-bin cap never kicks in (`#isSmallCountDomain()`: `format === "count" && bins.length > 0 && bins.length < 30`), the frontend keeps the literal `domain_max` instead of padding it with `#niceMax`. A field with only values 1 and 2 (e.g. boil water notices in a low-volume state) renders a domain of exactly `[1, 2]`, not `[1, 5]` or similar — see [Small-count domain layout](#small-count-domain-layout) below. A large-range count field (e.g. hundreds or thousands of violations at national scope) still gets the same `niceMax` padding as currency.

---

## Bin Strategy

The number and width of bins varies by data type, because equal-width bins work poorly for skewed or bounded data.

### `percent` and `percent_change`
Fixed semantic bins: always the same boundaries regardless of the data. Percentage fields get 20 bins of 5pp (0–5%, 5–10%, …, 95–100%). Percent change fields get 40 bins of 10pp (−200% to +200%) — the domain matches the ETL cap on `_capped` columns. The domain is clamped on the frontend; the server uses these fixed ranges when querying.

### `count` (integer fields: violations, hazards, funded times)
Adaptive integer binning. When `domain_max ≤ 30`: one bin per integer (so a max of 8 produces 8 bars, one per violation count). When `domain_max > 30`: equal-width bins capped at 30. This prevents a field ranging 0–8 from producing 30 bars, most of which are empty.

### `currency` and other continuous fields
Equal-width, 30 bins. The `min_threshold: 0` already excludes zero-valued rows from the range computation, which avoids one common skew problem (most systems having $0 in a funding field). The square-root bar scale handles remaining right-skew visually.

---

## Bar Positioning

Bars are positioned by **value** — each bar's left and right pixel edges are computed via `#valToX(bin.min)` and `#valToX(bin.max)`. This ensures bars and handles share the same coordinate system regardless of any frontend domain extension (e.g. `niceMax`). An earlier index-based approach (`x = PAD_L + i * barW`) was equivalent only when `domMax` exactly matched the backend's bin upper boundary; value-based positioning removes that hidden dependency.

The track is inset asymmetrically: `PAD_L` on the left (reserves space for the y-axis label and tick marks) and `PAD_R` on the right (handle clearance only).

Empty bins (`count: 0`) render as zero-height paths — genuine visual gaps in the distribution.

### Small-count domain layout

Value-based positioning breaks down for a small-count domain (see the domain clamping exception above): with `domain_max` left unpadded, the last bin's theoretical span is squeezed almost to zero width by the server's `upper_bound = max_val + 1` convention, producing one giant bar plus a barely-visible sliver instead of evenly-sized bars. When `#isSmallCountDomain()` is true, `#draw()` switches to **index-based** equal-width bars instead — each of the `n` bins gets an equal `1/n` share of the track, keyed by array position rather than by value. Tick marks switch too: instead of `#autoTicks`' nicely-rounded values, only the boundaries *between* bars are marked (the handles already mark the two ends), avoiding a run of visually meaningless fractional ticks on a domain that's only 1-2 wide.

### Handle-to-bar alignment
The min handle at `domMin` sits at the left edge of the first bar. The max handle at `domMax` (the `niceMax`-extended boundary) sits at the right edge of the track, leaving a small visual gap between the last bar and the track edge for readability. Handles at intermediate values land somewhere within the bar that contains that value (not necessarily centered — this is expected and correct). The floating tooltip above the handle shows the precise value; bar coloring is approximate visual context.

### Bar coloring
A bar is colored blue (inside the selected range) or gray (outside) using its theoretical boundaries:

```
blue if: bin.theoreticalMax > curMin && bin.theoreticalMin <= curMax
```

The strict `>` on the upper bound treats bins as half-open intervals `[min, max)`. This prevents a bin whose theoretical max falls exactly at `curMin` from being incorrectly colored.

---

## Key Decisions

### No chart library

The slider is a custom SVG Stimulus controller. The legacy app used Highcharts. We do not, for three reasons:
1. **No build step** — Importmaps-only stack; npm-based libraries require a bundler or CDN pin with limited control.
2. **Drag-range-select is the primary feature** — any chart library gives you bars but you write all the interaction (handles, range coloring, hidden input wiring, Stimulus lifecycle) on top anyway.
3. **Size** — the controller is ~300 lines and does everything needed. Highcharts is ~1MB, Chart.js ~200KB, ApexCharts similar — none solve the core interaction problem.

### Square-root bar scaling

Bar heights use `sqrt(bin.count) / sqrt(maxCount)` rather than a linear ratio. Water system data is almost always right-skewed — most systems cluster at low values, a handful have extreme counts. With linear scaling, bins containing hundreds of systems become invisible slivers next to bins containing thousands. Square-root scaling is perceptually honest (preserves relative ordering), makes minority-count bins visible, and is less aggressive than log scale. Applied consistently across all histograms — no per-field logic.

### Empty bins are gaps, not stubs

A bin with `count: 0` renders as a zero-height rect — an honest visual gap in the distribution. The frontend enforces this: the `Math.max(1, ...)` height floor only applies when `bin.count > 0`. Without this, empty bins render as 1px stubs that look like very short bars.

### Theoretical boundaries, not actual data values

The backend returns uniform theoretical bucket boundaries rather than the actual data min/max within each bucket. This is more consistent: bar positioning, bar coloring, and axis labels all describe the same ranges. It also means empty buckets can be included in the response with the correct boundary values even though no data fell in them.

### Capped columns for trend/change data

`population_pct_change_capped` and `mhi_pct_change_capped` are used for both display and filtering. The raw columns contain legitimate data artifacts — a military installation going from 2 to 11,112 connections produces a raw value of +555,500%. The `_capped` columns were pre-computed in the ETL (capped at ±200%) and always intended for display and filter use.

### No handle snapping

Handles move freely to any value. For integer count fields, `Math.round()` in `#xToVal` ensures the value is always a whole number. The filter sends that exact value to the backend; the highlighted bars are approximate visual context. Precision filtering is handled via the manual text inputs (see below).

### Server-side histograms

The legacy app computed histograms client-side from Mapbox vector tile features (visible features only, naturally limiting the distribution). The Rails app uses vector tiles — feature data is not available as JS objects. PostgreSQL `width_bucket` runs a single query server-side; the response is stable between ETL imports and cached in the browser for the session.

### State scoping

Every histogram is scoped to the current geo `state` when one is active, not just BWN's. `HistogramsController#show` passes `params[:state]` through to `model_scope`, which — when a state is present — narrows the model to `pwsid`s in that state via a subquery on `PublicWaterSystem` (`model.where(pwsid: PublicWaterSystem.where(stusps:).select(:pwsid))`) before calling `histogram_bins`. So a slider's domain and bins reflect only that state's data, e.g. TX's `groundwater_rule_10yr` max is TX's own max, not the national one.

On the frontend, `slider_controller.js` reads `FilterState.get().state` and includes it in both the fetch (`?field=...&state=...`) and the cache key. `#handleStateChange` clears cached bins and re-fetches whenever the state actually changes (not on every `filters:changed` — see `#loadedState` in `load()`) and the panel is currently visible; a collapsed panel picks up the new state's data the next time it's expanded instead of fetching in the background.

Because a slider's domain is state-specific, a stale min/max from the previous state could silently misfilter or become meaningless in the new one. `map_controller.js`'s `#setStateFilter`/`#clearStateFilter` strip `_min`/`_max` keys from `FilterState` (`#withoutRangeParams`) whenever the geo state changes — but only for slider-backed (`data-filter-kind="range"`) fields, resolved from the DOM the same way `filter_controller.js`'s `#rangeBaseParam` does. A `range_select` field (density, size) has a fixed, state-independent domain (a static dropdown step list, not a histogram) and is left untouched, so it keeps filtering and its badge across any state change — same as every non-range filter kind. The checked slider itself doesn't drop either: `#refreshCheckedRangeDefaults` repopulates the new state's domain defaults once the strip runs, so the filter re-applies rather than silently disappearing (see `docs/open_items/BWN_MANUAL_TEST_PLAN.md` §9 for the manual test).

---

## Performance Caching

Three private fields in `slider_controller.js` avoid repeated DOM queries during pointer events:

| Field | Set | Used |
|---|---|---|
| `#bars = []` | Reset in `#draw()`, populated during the `#bins.forEach` loop | `#colorBars()` iterates this array instead of `querySelectorAll` on every pointer event |
| `#rect = null` | Assigned at `pointerdown` via `getBoundingClientRect()` | `#onMove` uses the cached rect — no layout reflow at 60fps |
| `#tipMin` / `#tipMax` | `#makeTip()` returns `{ g, path, text }` struct; assigned after bars are drawn | `#showTip` / `#hideTip` use `.g`, `.path`, `.text` directly — no `querySelector` on each call |

---

## Y-Axis and Hover

### Y-axis scale
A rotated "# of utilities" label runs along the left edge of the chart. Tick marks are rendered at nice intervals (`#yTicks`) at sqrt-scaled heights to match bar positions.

**Design decision:** Tick marks are purely visual scale indicators — they show the relative shape of the sqrt scaling curve (so a tall bar "feels" proportional) without adding count labels. Exact counts are intentionally deferred to the hover tooltip, keeping the axis clean. This also avoids the layout problem of fitting variable-width count labels in the narrow `Y_AXIS_W = 26px` reserved space.

### Hover count tooltip
Hovering a bar shows a dark blue floating pill tooltip with the exact count (e.g., "15 utilities"). This is the primary way users discover actual counts — the y-axis gives scale context, the tooltip gives precision. Hit targets are transparent `<rect>` elements sized to `Math.max(12, barHeight)` so short bars are still hoverable. Uses `#showHoverTip` / `#hideTip("hover")` with `pointerenter` / `pointerleave` listeners.

Works on both mouse and touch, but with different event semantics: mouse uses `pointerenter`/`pointerleave` (hover), touch uses `pointerdown`/`pointerup` (tap-to-reveal). The explicit `pointerup` dismiss for touch is necessary because `pointerleave` does not reliably fire on touch lift in iOS Safari.

---

## Manual Text Inputs

Implemented (ticket #114). Users can type min/max values directly into visible text inputs below the SVG. The inputs and drag handles stay in sync bidirectionally.

### Layout

Two `type=text` inputs live in `_slider_panel.html.erb` in a flex row below the SVG, labeled "Min" and "Max". They use `inputmode="numeric"` for mobile keyboards, `aria-label` for screen readers, and format-specific placeholders (`"Enter Min %"` / `"Enter Max %"` for percent formats, `"Enter Min $"` / `"Enter Max $"` for currency, `"Enter Min"` / `"Enter Max"` otherwise) to signal "no filter applied on this side."

**Important:** `FILTER_ROW_CLASSES` in `application_helper.rb` applies `size-4` (16px) to all non-checkbox inputs inside filter row `<li>` elements via a compound Tailwind selector. The selectors include `:not([type=text])` so the slider text inputs are explicitly excluded and receive their full `w-full` width.

### Targets

`minTextInput` and `maxTextInput` are declared in `static targets`. The controller uses `hasMinTextInputTarget` / `hasMaxTextInputTarget` guards so render paths without these inputs (e.g., old-style `data-subcat-panel` sliders) do not throw.

### Handle → text input sync (`#syncTextInputs`)

Called after every drag (`#onUp`), keyboard move, and `resetToFullRange()`. Shows the formatted value when either (a) the handle is off the domain boundary, or (b) the user has explicitly typed into that input (`#minSet` / `#maxSet` flags are true). Clears the input (restores placeholder) only when the handle is at the domain boundary *and* no value has been explicitly typed.

Display format by type: percent/percent_change → `75%`; currency → `$12,345`; count/default → `12,345`. Thousands separators are stripped by `#onTextChange` before parsing so re-entry always works.

### Text input → handle sync (`#onTextChange`)

Bound once per controller instance (guarded by `#textInputsBound` flag to survive ResizeObserver-triggered redraws). Fires on `change` and `Enter`. Strips formatting characters (`$`, `%`, `,`, whitespace, leading `+`), parses the float, clamps to `[domMin, curMax]` (min side) or `[curMin, domMax]` (max side), rounds to integer, writes to the hidden input, and repositions the handle.

Empty input resets that side to the domain default (handle snaps back, placeholder reappears) and clears the `#minSet` / `#maxSet` flag. Valid input sets the flag so the displayed value persists across subsequent `#syncTextInputs` calls even when the typed value equals the domain boundary.

---

## Edge Cases

- **Single-value data** (`domain_max === domain_min`, e.g. every matching system has exactly 1 violation): renders one full-width bar sized to the total count, with the "# of utilities" y-axis label and hover tooltip — the same bar-drawing path as any other histogram, just with one bin spanning the whole track. (Previously this drew a bare flat line with no bar and no y-axis label; that early-return branch now reaches the normal rendering calls instead of stopping short.)
- **Integer field with small range** (e.g., max=4): returns 4 bins of width 1, rendered as 4 equal-width bars via the small-count domain layout above, each representing exactly one integer value.
- **Overlapping drag handles:** if a drag or typed value causes the min and max handles to land on the same pixel, the one most recently moved is brought to the front of the SVG paint order (`#raiseHandle`, tracked in `#topHandle`) so it stays independently clickable/draggable instead of being covered by the other. A pixel-offset approach was tried first and rejected — a few pixels of separation isn't visually obvious enough for a user to tell which handle they're grabbing.
- **Max handle at `domMax`**: sits at the right edge of the last bar. The backend's `upper_bound = max_val + 1` in `width_bucket` ensures the maximum data value always falls in the last bucket (not an overflow bucket).
- **Reset before fetch completes:** `resetToFullRange()` returns early if bins haven't loaded.
- **Fetch on page load:** all connected slider panels fire their fetch immediately, not on first reveal. The module-level cache ensures each unique field/state pair fetches once regardless.
- **A state transitions through a zero-result state with the panel open** (e.g. TX → a state with zero matching rows for this field → OH, panel never collapsed): the histogram correctly re-fetches and re-renders for the third state. The reload trigger in `#handleStateChange` is gated only on the panel being visible, not on the *previous* fetch having returned any bins — a state legitimately having zero matching rows must not suppress the next state's reload.

---

## Design Mocks

All mocks: `docs/mocks/subfilters_and_histograms/`

- `histogram_bar_style.png` — target bar style: lighter blue, rounded tops, spacing between bars, bold label, horizontal separator line
- `historgram_style_variations.png` — edge-case states: default, select slider (tooltip shown), set range (bars left of handle gray), single value, percent change with signed axis, low-value integer bins, hover with y-axis tick marks
- `histogram_under_subfilter.png` — how the slider sits within the Compliance menu under a non-health violation parent
