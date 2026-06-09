# URL State Management

## Status
**Decision made. Implementation not yet started.**
See [URL_STATE_IMPLEMENTATION.md](URL_STATE_IMPLEMENTATION.md) for the step-by-step agent guide.

---

## The Problem

All user state — filters, sort, page, column visibility/order — is encoded in the URL. This is intentional: it makes views bookmarkable and shareable, a core use case.

Two pressure points exist as the app grows:

- **Filter params** — verbose keys like `synthetic_organic_chemicals_10yr_min` (36 chars each). With 110 range params at worst case, filter state alone is ~3,100 chars unencoded.
- **Column state** — 70 columns. The `cols=` comma-separated param at full selection is ~1,370 chars unencoded.

Worst-case total (all filters active, all columns visible): **~5,400 chars** — 2.7× over the browser/proxy safe limit of ~2,000 chars.

A third related problem: **selected-row exports** pass individual PWSID query params (`pwsids[]=TX0230032&...`), which hits URL limits around 150–200 selected rows. The controller currently caps this at 500 with silent truncation.

---

## Decisions

### 1. Filter + Column State → Zlib + Base64 GET param

Compress the entire filter and column state into a single opaque `s=` param:

```
/table?s=eJyLjgUAAYAB_w
```

**Why Zlib+Base64 over string aliasing:**

Aliasing was evaluated. It reduces worst-case URL length to ~1,687 chars — under the limit — but only if the min/max direction is encoded into the alias itself (e.g., `a61n`/`a61x`). Aliases with `_min`/`_max` suffixes still exceed the limit. The result is an alias like `a61n` — completely unreadable, requiring a permanent alias registry to maintain. There is no readability payoff.

Zlib+Base64 is strictly better in this situation:
- No alias registry to maintain — new filters and columns just work
- Automatically handles future growth
- Same opaqueness as aliases
- Simpler implementation: one encode/decode utility vs. a registry mapping every param

Worst-case compression estimate: filter param names contain heavy repetition (`_rate_min=`, `_5yr_max=`, `_10yr_max=`). Deflate is designed for exactly this. Compressed + base64 encoded worst case lands well under 2,000 chars in typical use. The absolute worst case (all 110 range params simultaneously active) is a theoretical edge case that does not occur in real sessions.

**Human readability:** Not required. Shareable links are important; readable links are not.

**Backwards compatibility:** If `params[:s]` is absent, fall back to parsing individual params. This preserves any existing bookmarked or shared URLs.

### 2. Selected-Row Exports → POST

When specific rows are selected for export, IDs are submitted via POST body rather than GET query params.

**Why POST:**
- POST bodies have no practical size limit — thousands of IDs are fine
- The 500-row cap (`MAX_PWSID_SELECTION`) and its silent truncation are removed entirely
- An export is an ephemeral one-time action, not a shareable URL — the core objection to POST (breaking bookmarking) does not apply here

**Why not Zlib+Base64 for IDs:**
Compressing a list of ~500 IDs (5,000 raw chars) still produces ~2,500–3,300 encoded chars at best — borderline at worst case. POST eliminates the problem entirely with no size concern at any scale.

**Filter-based exports** (no rows selected) stay as GET — filter params are compact and this path is a legitimate "fetch this resource" operation.

---

## Current State (before implementation)

- Filter params: individual verbose keys via `FilterState.toUrlParams()` in `filter_state.js`
- Column state: `cols=` comma-separated param, already implemented
- Selected-row exports: GET with `pwsids[]` array params, capped at 500 with silent truncation in `exports_controller.rb`

---

## What Was Considered and Rejected

| Approach | Why Rejected |
|---|---|
| String aliasing | Aliases are unreadable; requires registry maintenance; min/max direction must be encoded into alias (no `_min`/`_max` suffix); narrow worst-case buffer |
| Zlib+Base64 for ID exports | Worst-case borderline; POST is simpler and has no constraint |
| Server-side token storage | Introduces DB/Redis storage, TTL logic, expiration handling — operational overhead with no benefit over stateless compression |
| POST for filter state | Breaks bookmarking and link sharing, which are core use cases |
| Index mapping / bitmasking | Fragile to schema changes; breaks existing bookmarked URLs when columns added/removed |

---

## Research Reference

For the full pattern comparison matrix (string aliasing, encoding/decoding, index mapping, bitmasking, mixed patterns), see the archived research section below.

<details>
<summary>Pattern comparison matrix and implementation sketches</summary>

| Solution | URL Size | Resiliency to Future Changes | Custom Ordering Support | Maintenance Overhead |
|---|---|---|---|---|
| String Aliasing | Medium-Small | High (explicit alias per field) | High | Low (alias registry) |
| Encoding / Decoding | Medium | High (no coupling to code order) | High | None |
| Index Mapping | Tiny | Low (index shifts break old links) | High | Medium |
| Mixed Pattern | Small | Medium (inherits index fragility) | High | Medium |
| Bitmasking | Absolute Smallest | Low (bit removal breaks sequence) | No | High |

**Encoding / Decoding (Zlib + Base64) sketch:**

```ruby
# app/lib/url_state_codec.rb
require 'zlib'
require 'base64'
require 'json'

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

```js
// JS encode side — pako library (synchronous, zlib format compatible with Ruby)
import pako from "pako"

export const encodeState = (paramsObj) => {
  const compressed = pako.deflate(JSON.stringify(paramsObj))
  return btoa(String.fromCharCode(...compressed))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}
```

</details>
