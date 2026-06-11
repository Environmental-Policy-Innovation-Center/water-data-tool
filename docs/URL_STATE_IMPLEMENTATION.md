# URL State Implementation Guide

## Status
**Not started.**

For the decision rationale behind these choices, see [URL_MANAGEMENT.md](URL_MANAGEMENT.md).

---

## What This Implements

Two independent changes:

1. **Zlib+Base64 compression** of filter + column state into a single `s=` GET param (shareable URLs)
2. **POST-based export** for selected rows, removing the 500-row cap

These can be implemented independently in either order.

---

## Part 1: Zlib+Base64 URL State Compression

### What changes

| File | Change |
|---|---|
| `app/lib/url_state_codec.rb` | New: server-side decode utility |
| `app/controllers/home_controller.rb` | Read `params[:s]`, decode, merge into filter/col params |
| `app/javascript/url_state_codec.js` | New: client-side encode utility |
| `app/javascript/filter_state.js` | Use `encodeState()` when building URLs |
| `app/javascript/controllers/filter_controller.js` | Encode state into `s=` param on apply |
| `app/javascript/controllers/nav_controller.js` | Decode `s=` on page load to restore state |
| `config/importmap.rb` | Pin `pako` library |

### Step 1 — Add pako to importmap

`pako` is a synchronous JS Zlib library. Its `deflate` output (zlib format, RFC 1950) is compatible with Ruby's `Zlib::Inflate.inflate`.

```ruby
# config/importmap.rb
pin "pako", to: "https://cdn.jsdelivr.net/npm/pako@2.1.0/dist/pako.esm.mjs"
```

Alternatively, vendor it locally: download `pako.esm.mjs` to `vendor/javascript/` and pin with `to:` pointing to the local path. Vendoring is preferred if the project avoids CDN dependencies at runtime.

### Step 2 — Server-side decode utility

```ruby
# app/lib/url_state_codec.rb
require "zlib"
require "base64"
require "json"

module UrlStateCodec
  def self.decode(str)
    return {} if str.blank?
    json = Zlib::Inflate.inflate(Base64.urlsafe_decode64(str))
    JSON.parse(json)
  rescue Zlib::Error, ArgumentError, JSON::ParserError
    {}
  end
end
```

### Step 3 — Controller integration

In `HomeController` (and any other controller that reads filter/col state), decode the `s=` param and merge it with incoming params. Fall back to standard param parsing if `s=` is absent — this preserves any existing bookmarked URLs.

```ruby
# app/controllers/home_controller.rb
def filter_params
  if params[:s].present?
    decoded = UrlStateCodec.decode(params[:s])
    # Merge decoded state into a params-like structure for FilterParams
    ActionController::Parameters.new(decoded).permit(*FilterRegistry.permit_arguments)
  else
    FilterParams.permit(params)
  end
end

def column_params
  if params[:s].present?
    decoded = UrlStateCodec.decode(params[:s])
    decoded["cols"].to_s
  else
    params[:cols].to_s
  end
end
```

Adjust the exact merge strategy to match how `@columns` is currently resolved.

### Step 4 — Client-side encode utility

```js
// app/javascript/url_state_codec.js
import pako from "pako"

export const encodeState = (paramsObj) => {
  const compressed = pako.deflate(JSON.stringify(paramsObj))
  // Convert to URL-safe base64 (no padding)
  return btoa(String.fromCharCode(...compressed))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "")
}

export const decodeState = (str) => {
  if (!str) return {}
  try {
    const binary = atob(str.replace(/-/g, "+").replace(/_/g, "/"))
    const bytes = Uint8Array.from(binary, c => c.charCodeAt(0))
    return JSON.parse(pako.inflate(bytes, { to: "string" }))
  } catch {
    return {}
  }
}
```

### Step 5 — Encode state when building URLs

Update `filter_state.js` to expose an `toEncodedParam()` method alongside the existing `toUrlParams()`:

```js
// app/javascript/filter_state.js
import { encodeState } from "url_state_codec"

// ... existing code ...

export const toEncodedParam = (colsCsv) => {
  const state = { ...current }
  if (colsCsv) state.cols = colsCsv
  return encodeState(state)
}
```

Then in `filter_controller.js`, when building the URL to push to history or navigate to, use `s=` instead of individual params:

```js
const encoded = FilterState.toEncodedParam(currentColsCsv)
const url = `${window.location.pathname}?s=${encoded}`
history.pushState({}, "", url)
```

### Step 6 — Decode state on page load

On page load, if `s=` is present in the URL, decode it and restore filter + column state:

```js
// In the relevant Stimulus connect() method
const sp = new URLSearchParams(window.location.search)
const encoded = sp.get("s")
if (encoded) {
  const state = decodeState(encoded)
  FilterState.set(state)
  // restore column visibility from state.cols
}
```

### Step 7 — Export controller

The export controller reads filter state. Update `export_controller.js` to pass `s=` when doing a filter-based (no rows selected) export:

```js
// app/javascript/controllers/export_controller.js
download(event) {
  event.preventDefault()
  const format = this.formatTargets.find(el => el.checked)?.value || "csv"
  const ids = SelectionState.getIds()

  if (ids.length > 0) {
    // POST path — see Part 2
  } else {
    const encoded = FilterState.toEncodedParam(/* cols csv */)
    const params = new URLSearchParams({ s: encoded })
    if (format !== "csv") params.set("file_format", format)
    window.location.href = `${this.urlValue}?${params}`
  }
}
```

### Testing checklist

- [ ] Round-trip: encode in JS, decode in Ruby, params match original
- [ ] Backwards compat: URL without `s=` still works (existing bookmarks)
- [ ] Malformed `s=` value returns empty state gracefully (no 500)
- [ ] All filter types survive encode/decode (arrays, ranges, booleans, strings)
- [ ] Column state survives encode/decode including order
- [ ] Shared URL reproduces the correct filter + column state in a fresh browser session

---

## Part 2: POST-Based Export for Selected Rows

### What changes

| File | Change |
|---|---|
| `config/routes.rb` | Add `post` route for exports |
| `app/controllers/public_water_systems/exports_controller.rb` | Accept POST; remove `MAX_PWSID_SELECTION` cap |
| `app/javascript/controllers/export_controller.js` | Submit form via POST when IDs present |

### Step 1 — Add POST route

```ruby
# config/routes.rb
resources :public_water_systems, only: [] do
  resource :exports, only: [:show, :create], module: :public_water_systems
end
```

Or if exports is a standalone route, add:

```ruby
post "exports", to: "public_water_systems/exports#create"
```

Check existing routes for the right shape. The POST action can live in `#create` or `#show` — use whichever is consistent with the existing route structure.

### Step 2 — Update the controller

Remove `MAX_PWSID_SELECTION`. The POST body has no practical size limit.

```ruby
# app/controllers/public_water_systems/exports_controller.rb
module PublicWaterSystems
  class ExportsController < ApplicationController
    def show
      scope = PublicWaterSystem.apply_filters(FilterParams.permit(params)).with_details
      export(scope)
    end

    def create
      scope = PublicWaterSystem.where(pwsid: export_params[:pwsids]).with_details
      export(scope)
    end

    private

    def export(scope)
      exporter = PublicWaterSystemExporter.new(scope)
      if params[:file_format] == "geojson"
        render_geojson_export(exporter)
      else
        render_csv_export(exporter)
      end
    end

    def export_params
      params.permit(pwsids: [])
    end

    # ... render methods unchanged ...
  end
end
```

### Step 3 — POST from export_controller.js

Build a temporary form and submit it. The browser handles the file download response the same as GET.

```js
// app/javascript/controllers/export_controller.js
import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import * as SelectionState from "selection_state"

export default class extends Controller {
  static targets = ["format"]
  static values = { url: String }

  download(event) {
    event.preventDefault()
    const format = this.formatTargets.find(el => el.checked)?.value || "csv"
    const ids = SelectionState.getIds()

    if (ids.length > 0) {
      this.#postExport(ids, format)
    } else {
      this.#getExport(format)
    }
  }

  #postExport(ids, format) {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.urlValue
    this.#addHidden(form, "authenticity_token", this.#csrfToken())
    if (format !== "csv") this.#addHidden(form, "file_format", format)
    ids.forEach(id => this.#addHidden(form, "pwsids[]", id))
    document.body.appendChild(form)
    form.submit()
    document.body.removeChild(form)
  }

  #getExport(format) {
    const params = FilterState.toUrlParams()
    if (format !== "csv") params.set("file_format", format)
    window.location.href = `${this.urlValue}?${params}`
  }

  #addHidden(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }

  #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content ?? ""
  }
}
```

### Testing checklist

- [ ] Selecting 1 row and exporting produces a file with 1 row
- [ ] Selecting 600+ rows exports all of them (no truncation at 500)
- [ ] CSRF token is present and request is not rejected (422)
- [ ] CSV and GeoJSON format both work via POST
- [ ] Filter-based export (no rows selected) still works via GET
- [ ] `MAX_PWSID_SELECTION` constant and its usage are fully removed

---

## Implementation Order

Either part can be shipped independently. Part 2 (POST exports) is smaller and higher impact — it removes a live silent truncation bug. Consider doing Part 2 first.
