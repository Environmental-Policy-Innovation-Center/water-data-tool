import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

// Keyed by "field|state" so each state gets its own cached histogram.
const CACHE = new Map()
const SVG_H = 100       // bar + handle area
const X_AXIS_H = 12     // tick lines below the handle baseline
const BAR_TOP_PAD = 4   // clear pixels above tallest bar so y-axis label fits
const HOVER_AREA_H = 16 // extra viewBox headroom above y=0 so hover pill clears the tallest bar
const HANDLE_R = 5
const Y_AXIS_W = 26     // pixels reserved on the left for y-axis label and tick marks
const PAD_L = Y_AXIS_W + HANDLE_R  // left track inset (y-axis area + handle clearance)
const PAD_R = HANDLE_R             // right track inset (handle clearance only)
const HANDLE_Y = SVG_H - HANDLE_R * 2  // handle center on the histogram baseline
const BLUE         = "#3B82F6" // blue-500 — highlighted bars, active handles
const NEUTRAL_400  = "#bfbfbf" // --color-neutral-400 in @theme — unselected bars
const NEUTRAL_700  = "#565656" // --color-neutral-700 in @theme — axes, tick marks, labels, inactive handles
const NS = "http://www.w3.org/2000/svg"

export default class extends Controller {
  static values = { field: String, url: String, format: String }
  static targets = ["chart", "axisRow", "minLabel", "maxLabel", "minInput", "maxInput", "zeroLabel", "minTextInput", "maxTextInput"]

  #bins = []
  #domMin = 0
  #domMax = 0
  #curMin = 0
  #curMax = 0
  #dragging = null
  #tipMin = null
  #tipMax = null
  #tipHover = null
  #tipText = { min: null, max: null, hover: null }
  #tipTextW = { min: 0, max: 0, hover: 0 }
  #minHandle = null
  #maxHandle = null
  #topHandle = "max"  // whichever handle was moved most recently renders on top when they overlap
  #bars = []
  #rect = null
  #svgW = 0
  #ro = null
  #needsDefaults = false
  #minSet = false
  #maxSet = false
  #minPlaceholder = ""
  #maxPlaceholder = ""
  #loadPromise = null
  #loadedState = null
  #reloadedForState = false
  #handleStateChange = () => {
    const newState = FilterState.get().state ?? ""
    if (this.#loadedState === null || newState === this.#loadedState) return

    this.#loadedState = null
    this.#loadPromise = null
    this.#minSet = false
    this.#maxSet = false
    this.minInputTarget.value = ""
    this.maxInputTarget.value = ""
    this.#needsDefaults = true

    if (this.#bins.length) {
      this.#bins = []
      while (this.chartTarget.firstChild) this.chartTarget.firstChild.remove()
    }

    if (!this.element.classList.contains("hidden")) {
      this.#reloadedForState = true
      this.load()
    }
  }

  connect() {
    this.#ro = new ResizeObserver(entries => {
      const w = Math.round(entries[0]?.contentRect.width ?? 0)
      if (w <= 0 || w === this.#svgW) return
      this.#svgW = w
      if (this.#dragging) this.#rect = this.chartTarget.getBoundingClientRect()
      if (this.#bins.length) this.#draw()
    })
    this.#ro.observe(this.chartTarget)
    document.addEventListener("filters:changed", this.#handleStateChange)

    if (this.hasMinTextInputTarget) this.#minPlaceholder = this.minTextInputTarget.placeholder
    if (this.hasMaxTextInputTarget) this.#maxPlaceholder = this.maxTextInputTarget.placeholder

    if (!this.element.classList.contains("hidden")) this.load()
  }

  // Guards on #loadedState, not #bins.length — a state can legitimately have zero matching rows.
  async load() {
    const field = this.fieldValue
    if (!field) return
    const state = FilterState.get().state ?? ""
    if (this.#loadedState === state) return

    if (!this.#loadPromise) {
      this.#loadPromise = this.#fetchHistogram(field, state)
    }

    const data = await this.#loadPromise
    if (!data || this.#loadedState === state) return
    const wasStateReload = this.#reloadedForState
    this.#reloadedForState = false
    this.#loadedState = state
    this.#init(data, wasStateReload)
  }

  #fetchHistogram(field, state = "") {
    const cacheKey = `${field}|${state}`
    if (!CACHE.has(cacheKey)) {
      const params = new URLSearchParams({field})
      if (state) params.set("state", state)
      CACHE.set(cacheKey,
        fetch(`${this.urlValue}?${params}`)
          .then(resp => resp.ok ? resp.json() : null)
          .catch(() => null)
      )
    }

    return CACHE.get(cacheKey)
  }

  disconnect() {
    this.#ro?.disconnect()
    document.removeEventListener("filters:changed", this.#handleStateChange)
    this.chartTarget.removeEventListener("pointerdown", this.#onDown)
    this.chartTarget.removeEventListener("pointermove", this.#onMove)
    this.chartTarget.removeEventListener("pointerup", this.#onUp)
  }

  resetToFullRange() {
    if (!this.#bins.length) return
    this.#curMin = this.#domMin
    this.#curMax = this.#domMax
    this.#moveHandle("min", this.#valToX(this.#domMin))
    this.#moveHandle("max", this.#valToX(this.#domMax))
    this.#deactivateHandle("min")
    this.#deactivateHandle("max")
    this.#colorBars()
    if (this.#tipMin) this.#tipMin.g.style.display = "none"
    if (this.#tipMax) this.#tipMax.g.style.display = "none"
    this.minInputTarget.value = ""
    this.maxInputTarget.value = ""
    this.#minSet = false
    this.#maxSet = false
    this.#syncTextInputs()
  }

  // Called by filter_controller when a health subcat slider panel is revealed.
  // Ensures inputs carry domain defaults so Apply always sends params for checked subcats.
  // If histogram data hasn't loaded yet, sets a flag so #init applies defaults once fetch resolves.
  populateDefaultsIfEmpty() {
    this.load()
    if (this.#loadedState === null) {
      // Keyed on #loadedState, not #bins.length — a field can legitimately have zero rows.
      this.#needsDefaults = true
      return
    }
    if (!this.minInputTarget.value) this.minInputTarget.value = this.#domMin
    if (!this.maxInputTarget.value) this.maxInputTarget.value = this.#domMax
  }

  // Stimulus action: fired by data-action on the min/max text inputs (change + keydown.enter).
  // keydown.enter must be prevented so it doesn't submit the filter form.
  textInputChanged(event) {
    if (event.type === "keydown") event.preventDefault()
    const which = event.currentTarget === this.minTextInputTarget ? "min" : "max"
    this.#onTextChange(which, event)
  }

  #init({ bins, domain_min, domain_max }, stateReload = false) {
    this.#bins = bins
    this.#syncEmptyState()

    const fmt = this.formatValue
    if (fmt === "percent") {
      domain_min = 0
      domain_max = 100
    } else if (fmt === "percent_change") {
      domain_min = Math.min(domain_min, -200)
      domain_max = Math.max(domain_max, 200)
    } else {
      // count and currency: floor at 1 so scale always starts at 1 / $1
      domain_min = Math.min(domain_min, 1)
      if (this.#isSmallCountDomain()) {
        // Few discrete integer values — keep the true max rather than padding it.
        domain_max = Math.ceil(domain_max)
      } else {
        // Extend past data max so bars end with visual breathing room before the track edge.
        domain_max = this.#niceMax(domain_min, domain_max)
      }
    }

    this.#domMin = domain_min
    this.#domMax = domain_max

    if (stateReload) {
      this.#minSet = false
      this.#maxSet = false
      this.#curMin = domain_min
      this.#curMax = domain_max
      this.minInputTarget.value = ""
      this.maxInputTarget.value = ""
    } else {
      this.#curMin = domain_min
      this.#curMax = domain_max

      const minVal = this.minInputTarget.value
      const maxVal = this.maxInputTarget.value

      if (minVal) this.#curMin = parseFloat(minVal)
      if (maxVal) this.#curMax = parseFloat(maxVal)

      if (!minVal) this.minInputTarget.value = this.#curMin
      if (!maxVal) this.maxInputTarget.value = this.#curMax
    }

    this.#draw()
    // SR-only labels for screen readers — visual labels are rendered in the SVG x-axis.
    this.minLabelTarget.textContent = this.#fmt(domain_min)
    this.maxLabelTarget.textContent = this.#fmt(domain_max)
    if (this.hasZeroLabelTarget) this.zeroLabelTarget.textContent = "0"
    this.#syncTextInputs()
    if (stateReload || this.#needsDefaults) {
      this.#needsDefaults = false
      this.populateDefaultsIfEmpty()
    }
    if (stateReload) {
      this.element.dispatchEvent(new CustomEvent("slider:state-reload", { bubbles: true }))
    }
  }

  // True when a count histogram has few enough distinct integer values (server caps bins at 30)
  // to render as discrete category bars instead of a continuous scale.
  #isSmallCountDomain() {
    return this.formatValue === "count" && this.#bins.length > 0 && this.#bins.length < 30
  }

  // No data for this field/scope — collapse the chart and disable manual entry (it would
  // otherwise clamp to a domain edge and send a misleading filter).
  #syncEmptyState() {
    const empty = this.#bins.length === 0
    this.chartTarget.classList.toggle("hidden", empty)
    if (this.hasAxisRowTarget) this.axisRowTarget.classList.toggle("hidden", empty)
    if (this.hasMinTextInputTarget) {
      this.minTextInputTarget.disabled = empty
      this.minTextInputTarget.placeholder = empty ? "No data" : this.#minPlaceholder
    }
    if (this.hasMaxTextInputTarget) {
      this.maxTextInputTarget.disabled = empty
      this.maxTextInputTarget.placeholder = empty ? "No data" : this.#maxPlaceholder
    }
  }

  // Brings a handle to the front of the SVG paint order (and therefore pointer hit-testing)
  // so the one most recently moved stays grabbable even if it lands on top of the other.
  #raiseHandle(which) {
    this.#topHandle = which
    const g = which === "min" ? this.#minHandle : this.#maxHandle
    if (g) this.chartTarget.appendChild(g)
  }

  // A bar with square bottom corners and rounded top corners, capped so the radius never
  // exceeds half the bar's own height or width (needed for short/thin bars).
  #roundedBarPath(bx, by, bw, height) {
    const r = Math.min(3, height / 2, bw / 2)
    return `M ${bx} ${by + height} L ${bx} ${by + r} Q ${bx} ${by} ${bx + r} ${by} L ${bx + bw - r} ${by} Q ${bx + bw} ${by} ${bx + bw} ${by + r} L ${bx + bw} ${by + height} Z`
  }

  #draw() {
    const svg = this.chartTarget
    const totalH = SVG_H + X_AXIS_H
    // Extend viewBox upward so the hover tooltip pill has room above tall bars.
    svg.setAttribute("viewBox", `0 -${HOVER_AREA_H} ${this.#svgW} ${totalH + HOVER_AREA_H}`)
    svg.setAttribute("height", String(totalH + HOVER_AREA_H))
    svg.setAttribute("preserveAspectRatio", "none")
    svg.innerHTML = ""
    this.#tipMin = null
    this.#tipMax = null
    this.#tipHover = null
    this.#tipText = { min: null, max: null, hover: null }
    this.#tipTextW = { min: 0, max: 0, hover: 0 }
    this.#minHandle = null
    this.#maxHandle = null
    this.#bars = []

    if (!this.#bins.length) return

    if (this.#domMin === this.#domMax) {
      // Every system shares this single value — draw one full-width bar rather than a bare line.
      const barArea = SVG_H - HANDLE_R * 2 - 2 - BAR_TOP_PAD
      const total = this.#bins.reduce((sum, bin) => sum + bin.count, 0)
      const bx = PAD_L
      const bw = this.#svgW - PAD_L - PAD_R
      const by = HANDLE_Y - barArea
      if (total > 0 && bw > 0) {
        const d = this.#roundedBarPath(bx, by, bw, barArea)
        // #colorBars() needs a bin-max strictly greater than domMin (half-open interval) to color this blue.
        const bar = this.#el("path", { d, fill: BLUE, "data-bin-min": this.#domMin, "data-bin-max": this.#domMax + 1, "aria-hidden": "true" })
        svg.appendChild(bar)
        this.#bars.push(bar)

        const label = total === 1 ? "1 utility" : `${total.toLocaleString("en-US")} utilities`
        const hit = this.#el("rect", {
          x: bx, y: by, width: bw, height: barArea,
          fill: "transparent", "pointer-events": "all", "aria-hidden": "true"
        })
        hit.addEventListener("pointerenter", () => this.#showHoverTip(label, this.#svgW / 2, by))
        hit.addEventListener("pointerleave", () => this.#hideTip("hover"))
        hit.addEventListener("pointerup", (e) => { if (e.pointerType === "touch") this.#hideTip("hover") })
        this.#tipHover = this.#makeTip("dark")
        svg.appendChild(hit)
        svg.appendChild(this.#tipHover.g)
      }
      this.#drawYAxis(svg, total, total ? Math.sqrt(total) : 1, barArea)
      this.#drawXAxis(svg)
      this.#minHandle = this.#addHandle("min", PAD_L)
      this.#maxHandle = this.#addHandle("max", this.#svgW - PAD_R)
      svg.removeEventListener("pointerdown", this.#onDown)
      svg.addEventListener("pointerdown", this.#onDown)
      return
    }

    const maxCount = Math.max(...this.#bins.map(b => b.count))
    const sqrtMax = maxCount ? Math.sqrt(maxCount) : 1
    const barArea = SVG_H - HANDLE_R * 2 - 2 - BAR_TOP_PAD
    const gap = 1

    // Square root scale: water data is right-skewed — most systems cluster at low values with a
    // long sparse tail. Sqrt lifts small bars enough to show the distribution shape without
    // flattening them like linear would. Gentler than log, and safe for zero-count bins.
    const isSmallCount = this.#isSmallCountDomain()
    const trackL = PAD_L
    const trackR = this.#svgW - PAD_R
    const hitRects = []
    this.#bins.forEach((bin, i) => {
      const h = bin.count > 0 && maxCount ? Math.max(1, (Math.sqrt(bin.count) / sqrtMax) * barArea) : 0
      let binLeft, binRight
      if (isSmallCount) {
        // Few discrete integer values (e.g. 1-2 notices) — divide the track evenly by index
        // instead of by value so each gets a full-width bar rather than a sliver.
        binLeft  = trackL + (i / this.#bins.length) * (trackR - trackL)
        binRight = trackL + ((i + 1) / this.#bins.length) * (trackR - trackL)
      } else {
        // Value-based positioning: use the bin's theoretical boundaries via #valToX so bars
        // stay aligned with handle positions regardless of domain extension (e.g. niceMax).
        binLeft  = this.#valToX(bin.min)
        binRight = Math.min(this.#valToX(bin.max), trackR)
      }
      const bx = binLeft + gap / 2
      const bw = Math.max(1, binRight - binLeft - gap)
      const by = HANDLE_Y - h
      const d  = h > 0 ? this.#roundedBarPath(bx, by, bw, h) : ""
      const bar = this.#el("path", { d, "data-bin-min": bin.min, "data-bin-max": bin.max, "aria-hidden": "true" })
      svg.appendChild(bar)
      this.#bars.push(bar)

      if (bin.count > 0) {
        const cx = (binLeft + binRight) / 2
        const label = bin.count === 1 ? "1 utility" : `${bin.count.toLocaleString("en-US")} utilities`
        const baseline = HANDLE_Y
        const hitH = Math.max(12, h)
        const hit = this.#el("rect", {
          x: bx, y: baseline - hitH, width: bw, height: hitH,
          fill: "transparent", "pointer-events": "all", "aria-hidden": "true"
        })
        // Mouse: show on enter, hide on leave. Touch: show on press, hide on release —
        // pointerleave is unreliable on touch pointerup (iOS Safari), so pointerup is explicit.
        hit.addEventListener("pointerenter", () => this.#showHoverTip(label, cx, by))
        hit.addEventListener("pointerleave", () => this.#hideTip("hover"))
        hit.addEventListener("pointerup", (e) => { if (e.pointerType === "touch") this.#hideTip("hover") })
        hitRects.push(hit)
      }
    })
    hitRects.forEach(r => svg.appendChild(r))

    this.#tipMin = this.#makeTip()
    this.#tipMax = this.#makeTip()
    this.#tipHover = this.#makeTip("dark")

    this.#drawYAxis(svg, maxCount, sqrtMax, barArea)
    this.#drawXAxis(svg)

    svg.appendChild(this.#tipMin.g)
    svg.appendChild(this.#tipMax.g)
    svg.appendChild(this.#tipHover.g)

    // Add handles in DOM order with #topHandle last, so it stays paintable/clickable if overlapping.
    const handleOrder = this.#topHandle === "min" ? ["max", "min"] : ["min", "max"]
    handleOrder.forEach(which => {
      const x = this.#valToX(which === "min" ? this.#curMin : this.#curMax)
      if (which === "min") this.#minHandle = this.#addHandle("min", x)
      else this.#maxHandle = this.#addHandle("max", x)
    })
    this.#setHandleActive("min")
    this.#setHandleActive("max")
    this.#colorBars()
    svg.removeEventListener("pointerdown", this.#onDown)
    svg.addEventListener("pointerdown", this.#onDown)
  }

  #drawXAxis(svg) {
    // Baseline sits flush at bar bottom; tick marks sit below the handles.
    const baseY = HANDLE_Y
    svg.appendChild(this.#el("line", {
      x1: PAD_L, x2: this.#svgW - PAD_R,
      y1: baseY, y2: baseY,
      stroke: NEUTRAL_700, "stroke-width": 1, "shape-rendering": "crispEdges"
    }))

    const ticks = this.#xTicks()
    const tickTop = baseY
    const tickBot = tickTop + 6

    ticks.forEach(({ value, x }) => {
      const tickX = x ?? this.#valToX(value)
      svg.appendChild(this.#el("line", {
        x1: tickX, x2: tickX,
        y1: tickTop, y2: tickBot,
        stroke: NEUTRAL_700, "stroke-width": 1.5
      }))
    })
  }

  // Returns tick positions and labels for the x-axis based on format and domain.
  #xTicks() {
    const fmt = this.formatValue

    if (fmt === "percent") {
      return [0, 20, 40, 60, 80, 100].map(v => ({ value: v }))
    }

    if (fmt === "percent_change") {
      return [
        { value: -200 },
        { value: -100 },
        { value: 0 },
        { value: 100 },
        { value: 200 }
      ]
    }

    if (this.#isSmallCountDomain()) {
      // Ends are already marked by the handles — only mark the splits between bars.
      const trackL = PAD_L
      const trackR = this.#svgW - PAD_R
      const n = this.#bins.length
      return Array.from({length: n - 1}, (_, i) => ({x: trackL + ((i + 1) / n) * (trackR - trackL)}))
    }

    // count / currency: auto-select up to 5 evenly-spaced round ticks
    return this.#autoTicks(this.#domMin, this.#domMax, 5)
  }

  // Computes up to maxCount nicely-rounded tick values spanning [min, max].
  #autoTicks(min, max, maxCount) {
    const range = max - min
    if (range === 0) return [{ value: min }]

    const step  = this.#niceStep(range, maxCount)
    const ticks = []
    const start = Math.ceil(min / step) * step
    for (let v = start; v <= max + step * 0.001; v += step) {
      const rounded = Math.round(v * 1e9) / 1e9
      if (rounded >= min && rounded <= max) {
        ticks.push({ value: rounded })
      }
    }

    if (!ticks.length || Math.abs(ticks[0].value - min) > step * 0.01)
      ticks.unshift({ value: min })
    if (Math.abs(ticks[ticks.length - 1].value - max) > step * 0.01)
      ticks.push({ value: max })

    return ticks
  }

  #niceStep(range, maxCount = 5) {
    if (range <= 0) return 1
    const rawStep  = range / (maxCount - 1)
    const mag      = Math.pow(10, Math.floor(Math.log10(rawStep)))
    const norm     = rawStep / mag
    const niceNorm = norm < 1.5 ? 1 : norm < 3.5 ? 2 : norm < 7.5 ? 5 : 10
    return niceNorm * mag
  }

  #niceMax(min, max) {
    if (max <= min) return max
    const step = this.#niceStep(max - min)
    const candidate = Math.ceil(max / step) * step
    // Must be strictly > max so the last bin (theoretical max = domain_max + 1)
    // always lands within the track when using value-based bar positioning.
    return candidate > max ? candidate : candidate + step
  }

  #makeTip(style = "light") {
    const g = this.#el("g", { class: "slider-tip", "aria-hidden": "true" })
    g.style.display = "none"
    const isDark = style === "dark"
    const path = this.#el("path", {
      fill: isDark ? BLUE : "white",
      stroke: isDark ? BLUE : "#d1d5db",
      "stroke-width": 1
    })
    const text = this.#el("text", {
      "text-anchor": "middle", "font-size": 14,
      fill: isDark ? "white" : "#4b5563",
      "dominant-baseline": "middle"
    })
    g.appendChild(path)
    g.appendChild(text)
    return { g, path, text }
  }

  #addHandle(which, x) {
    const val = which === "min" ? this.#curMin : this.#curMax
    const label = which === "min" ? "Minimum" : "Maximum"
    const g = this.#el("g", {
      id: `${this.fieldValue}-${which}-handle`,
      "data-handle": which,
      role: "slider",
      "aria-label": `${label} value`,
      "aria-valuenow": String(val),
      "aria-valuemin": String(this.#domMin),
      "aria-valuemax": String(this.#domMax),
      "aria-valuetext": this.#fmt(val),
      "aria-orientation": "horizontal",
      tabindex: "0"
    })
    g.style.cursor = "grab"
    g.setAttribute("transform", `translate(${x}, ${HANDLE_Y})`)

    g.addEventListener("pointerenter", () => {
      if (this.#dragging) return
      const curVal = which === "min" ? this.#curMin : this.#curMax
      this.#showTip(curVal, this.#valToX(curVal), which)
    })
    g.addEventListener("pointerleave", () => {
      if (this.#dragging) return
      this.#hideTip(which)
    })
    g.addEventListener("keydown", (e) => {
      const cur = which === "min" ? this.#curMin : this.#curMax
      let newVal
      if (e.key === "ArrowLeft" || e.key === "ArrowDown") newVal = cur - (e.shiftKey ? 10 : 1)
      else if (e.key === "ArrowRight" || e.key === "ArrowUp") newVal = cur + (e.shiftKey ? 10 : 1)
      else if (e.key === "Home") newVal = this.#domMin
      else if (e.key === "End") newVal = this.#domMax
      else return
      e.preventDefault()
      if (which === "min") {
        this.#curMin = Math.min(Math.max(this.#domMin, newVal), this.#curMax)
      } else {
        this.#curMax = Math.max(Math.min(this.#domMax, newVal), this.#curMin)
      }
      this.#raiseAndMoveHandle(which)
      this.#updateAriaHandle(which)
      this.#setHandleActive(which)
      this.#colorBars()
      this.minInputTarget.value = this.#curMin
      this.maxInputTarget.value = this.#curMax
      this.#syncTextInputs()
    })

    this.chartTarget.appendChild(g)
    return g
  }

  #moveHandle(which, x) {
    const h = which === "min" ? this.#minHandle : this.#maxHandle
    if (h) h.setAttribute("transform", `translate(${x}, ${HANDLE_Y})`)
  }

  // Brings a handle to the front and repositions it at its current value — used wherever a
  // keyboard/typed edit changes #curMin/#curMax directly (drag instead goes through #onMove).
  #raiseAndMoveHandle(which) {
    this.#raiseHandle(which)
    this.#moveHandle(which, this.#valToX(which === "min" ? this.#curMin : this.#curMax))
  }

  #activateHandle(which) {
    const g = which === "min" ? this.#minHandle : this.#maxHandle
    if (!g) return
    g.innerHTML = ""
    g.appendChild(this.#el("circle", { cx: 0, cy: 0, r: HANDLE_R + 3, fill: "#d1d5db" }))
    g.appendChild(this.#el("circle", { cx: 0, cy: 0, r: HANDLE_R + 1.5, fill: "white" }))
    g.appendChild(this.#el("circle", { cx: 0, cy: 0, r: HANDLE_R, fill: BLUE }))
  }

  #deactivateHandle(which) {
    const g = which === "min" ? this.#minHandle : this.#maxHandle
    if (!g) return
    g.innerHTML = ""
    g.appendChild(this.#el("circle", { cx: 0, cy: 0, r: HANDLE_R, fill: NEUTRAL_700 }))
  }

  #setHandleActive(which) {
    const cur = which === "min" ? this.#curMin : this.#curMax
    const dom = which === "min" ? this.#domMin : this.#domMax
    if (cur !== dom) this.#activateHandle(which)
    else this.#deactivateHandle(which)
  }

  #hideTip(which) {
    const tip = which === "min" ? this.#tipMin : which === "max" ? this.#tipMax : this.#tipHover
    if (tip) tip.g.style.display = "none"
  }

  #updateAriaHandle(which) {
    const g = which === "min" ? this.#minHandle : this.#maxHandle
    if (!g) return
    const val = which === "min" ? this.#curMin : this.#curMax
    g.setAttribute("aria-valuenow", String(val))
    g.setAttribute("aria-valuetext", this.#fmt(val))
  }

  #colorBars() {
    this.#bars.forEach(bar => {
      const inside = +bar.dataset.binMax > this.#curMin && +bar.dataset.binMin <= this.#curMax
      bar.setAttribute("fill", inside ? BLUE : NEUTRAL_400)
    })
  }

  #onDown = (event) => {
    const handle = event.target.closest("[data-handle]")
    if (!handle) return

    this.#dragging = handle.dataset.handle
    this.#rect = this.chartTarget.getBoundingClientRect()
    this.#raiseHandle(this.#dragging)
    this.#activateHandle(this.#dragging)
    this.chartTarget.setPointerCapture(event.pointerId)
    this.chartTarget.addEventListener("pointermove", this.#onMove)
    this.chartTarget.addEventListener("pointerup", this.#onUp, { once: true })
    event.preventDefault()
  }

  #onMove = (event) => {
    const rect = this.#rect
    const x = Math.max(PAD_L, Math.min(this.#svgW - PAD_R, (event.clientX - rect.left) * (this.#svgW / rect.width)))
    const val = this.#xToVal(x)

    if (this.#dragging === "min") {
      this.#curMin = Math.min(val, this.#curMax)
      this.#moveHandle("min", this.#valToX(this.#curMin))
      this.#showTip(this.#curMin, this.#valToX(this.#curMin), "min")
      this.#updateAriaHandle("min")
    } else {
      this.#curMax = Math.max(val, this.#curMin)
      this.#moveHandle("max", this.#valToX(this.#curMax))
      this.#showTip(this.#curMax, this.#valToX(this.#curMax), "max")
      this.#updateAriaHandle("max")
    }
    this.#colorBars()
  }

  #onUp = () => {
    const dragged = this.#dragging
    this.#dragging = null
    this.#rect = null
    this.chartTarget.removeEventListener("pointermove", this.#onMove)
    this.minInputTarget.value = this.#curMin
    this.maxInputTarget.value = this.#curMax
    this.#syncTextInputs()
    if (dragged) {
      this.#hideTip(dragged)
      this.#setHandleActive(dragged)
    }
  }

  #showTip(val, x, which) {
    const tip = which === "min" ? this.#tipMin : this.#tipMax
    if (!tip) return

    const tipPath = tip.path
    const text    = tip.text
    const formatted = this.#fmt(val)
    const textChanged = formatted !== this.#tipText[which]
    if (textChanged) {
      text.textContent = formatted
      this.#tipText[which] = formatted
    }
    tip.g.style.display = ""

    const pillH   = 20
    const padX    = 6
    const rx      = pillH / 2   // maximum rounding — full capsule ends
    const arrowH  = 5
    const arrowHW = 3
    const gap     = 3

    // Arrow tip clears the active handle's outer ring (HANDLE_R + 3).
    const arrowTipY = HANDLE_Y - (HANDLE_R + 3) - gap
    const pillTopY  = arrowTipY - arrowH - pillH
    const pillBotY  = pillTopY + pillH

    if (textChanged || this.#tipTextW[which] === 0) this.#tipTextW[which] = text.getComputedTextLength()
    const textW = this.#tipTextW[which]
    // Minimum width ensures the bottom always has a straight segment for the arrow.
    const pillW  = Math.max(textW + padX * 2, 2 * (rx + arrowHW) + 2)
    const pillX  = x - pillW / 2
    const arrowX = x

    // Single path: capsule (oval ends via arcs) + downward-pointing arrow, drawn clockwise.
    const d = [
      `M ${pillX + rx} ${pillTopY}`,
      `L ${pillX + pillW - rx} ${pillTopY}`,
      `A ${rx} ${rx} 0 0 1 ${pillX + pillW} ${pillTopY + rx}`,
      `L ${pillX + pillW} ${pillBotY - rx}`,
      `A ${rx} ${rx} 0 0 1 ${pillX + pillW - rx} ${pillBotY}`,
      `L ${arrowX + arrowHW} ${pillBotY}`,
      `L ${arrowX} ${arrowTipY}`,
      `L ${arrowX - arrowHW} ${pillBotY}`,
      `L ${pillX + rx} ${pillBotY}`,
      `A ${rx} ${rx} 0 0 1 ${pillX} ${pillBotY - rx}`,
      `L ${pillX} ${pillTopY + rx}`,
      `A ${rx} ${rx} 0 0 1 ${pillX + rx} ${pillTopY}`,
      "Z"
    ].join(" ")

    tipPath.setAttribute("d", d)
    text.setAttribute("x", String(pillX + pillW / 2))
    text.setAttribute("y", String(pillTopY + pillH / 2 + 2))
  }

  #drawYAxis(svg, maxCount, sqrtMax, barArea) {
    // Entire y-axis is decorative — wrapped in aria-hidden so AT uses the handle ARIA instead.
    const g = this.#el("g", { "aria-hidden": "true" })
    const baseY = HANDLE_Y
    const midY = baseY / 2

    const axisLabel = this.#el("text", {
      "text-anchor": "middle", "dominant-baseline": "middle",
      "font-size": 14, fill: NEUTRAL_700,
      transform: `translate(6, ${midY}) rotate(-90)`
    })
    axisLabel.textContent = "# of utilities"
    g.appendChild(axisLabel)

    if (maxCount) {
      // Center each tick midway between the axis label right edge (~x=10) and the bar area.
      const tickCX = (10 + PAD_L) / 2
      this.#yTicks(maxCount).forEach(count => {
        const tickY = count === 0 ? baseY : baseY - (Math.sqrt(count) / sqrtMax) * barArea
        g.appendChild(this.#el("line", {
          x1: tickCX - 3, x2: tickCX + 3,
          y1: tickY, y2: tickY,
          stroke: NEUTRAL_700, "stroke-width": 1
        }))
      })
    }

    svg.appendChild(g)
  }

  #yTicks(maxCount) {
    if (maxCount <= 0) return [0]
    const step = this.#niceStep(maxCount, 4)
    const top = Math.ceil(maxCount / step) * step
    const ticks = []
    for (let v = 0; v <= top + step * 0.001; v += step) {
      ticks.push(Math.round(v))
    }
    return ticks
  }

  #showHoverTip(label, cx, barTopY) {
    const tip = this.#tipHover
    if (!tip) return

    const textChanged = label !== this.#tipText.hover
    if (textChanged) {
      tip.text.textContent = label
      this.#tipText.hover = label
    }
    tip.g.style.display = ""

    const pillH   = 20
    const padX    = 6
    const rx      = 4
    const arrowH  = 5
    const arrowHW = 2
    const gap     = 4

    const arrowTipY = barTopY - gap
    const pillTopY  = arrowTipY - arrowH - pillH
    const pillBotY  = pillTopY + pillH

    if (textChanged || this.#tipTextW.hover === 0) this.#tipTextW.hover = tip.text.getComputedTextLength()
    const textW = this.#tipTextW.hover
    const pillW = Math.max(textW + padX * 2, 2 * (rx + arrowHW) + 2)
    // Pill stays within the chart area; arrow tracks bar center as closely as geometry allows.
    const pillX     = Math.max(PAD_L, Math.min(this.#svgW - PAD_R - pillW, cx - pillW / 2))
    const arrowXMin = pillX + rx + arrowHW
    const arrowXMax = pillX + pillW - rx - arrowHW
    const arrowX    = Math.max(arrowXMin, Math.min(arrowXMax, cx))

    const d = [
      `M ${pillX + rx} ${pillTopY}`,
      `L ${pillX + pillW - rx} ${pillTopY}`,
      `A ${rx} ${rx} 0 0 1 ${pillX + pillW} ${pillTopY + rx}`,
      `L ${pillX + pillW} ${pillBotY - rx}`,
      `A ${rx} ${rx} 0 0 1 ${pillX + pillW - rx} ${pillBotY}`,
      `L ${arrowX + arrowHW} ${pillBotY}`,
      `L ${arrowX} ${arrowTipY}`,
      `L ${arrowX - arrowHW} ${pillBotY}`,
      `L ${pillX + rx} ${pillBotY}`,
      `A ${rx} ${rx} 0 0 1 ${pillX} ${pillBotY - rx}`,
      `L ${pillX} ${pillTopY + rx}`,
      `A ${rx} ${rx} 0 0 1 ${pillX + rx} ${pillTopY}`,
      "Z"
    ].join(" ")

    tip.path.setAttribute("d", d)
    tip.text.setAttribute("x", String(pillX + pillW / 2))
    tip.text.setAttribute("y", String(pillTopY + pillH / 2 + 2))
  }

  #valToX(val) {
    if (this.#domMax === this.#domMin) return this.#svgW / 2
    const trackW = this.#svgW - PAD_L - PAD_R
    if (trackW <= 0) return PAD_L
    return PAD_L + ((val - this.#domMin) / (this.#domMax - this.#domMin)) * trackW
  }

  #xToVal(x) {
    const trackW = this.#svgW - PAD_L - PAD_R
    if (trackW <= 0) return this.#domMin
    const raw = this.#domMin + ((x - PAD_L) / trackW) * (this.#domMax - this.#domMin)
    return Math.round(Math.max(this.#domMin, Math.min(this.#domMax, raw)))
  }

  #el(tag, attrs = {}) {
    const el = document.createElementNS(NS, tag)
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, String(v))
    return el
  }

  #fmtTextInput(val) {
    const r = Math.round(val)
    const fmt = this.formatValue
    if (fmt === "percent") return `${r}%`
    if (fmt === "percent_change") return `${r > 0 ? "+" : ""}${r}%`
    if (fmt === "currency") return `$${r.toLocaleString("en-US")}`
    return r.toLocaleString("en-US") // default: plain integer (count, score, or unrecognized format)
  }

  // Shows the formatted value when the user has explicitly typed into an input (#minSet / #maxSet),
  // otherwise shows empty so the placeholder appears when the slider is at the domain boundary.
  #syncTextInputs() {
    if (this.hasMinTextInputTarget) {
      this.minTextInputTarget.value = (this.#minSet || this.#curMin !== this.#domMin) ? this.#fmtTextInput(this.#curMin) : ""
    }
    if (this.hasMaxTextInputTarget) {
      this.maxTextInputTarget.value = (this.#maxSet || this.#curMax !== this.#domMax) ? this.#fmtTextInput(this.#curMax) : ""
    }
  }

  #onTextChange(which, event) {
    const raw = event.currentTarget.value.trim()

    if (!raw) {
      // Leave input empty so the placeholder reappears; clear the explicit-set flag.
      if (which === "min") {
        this.#curMin = this.#domMin
        this.minInputTarget.value = this.#curMin
        this.#minSet = false
      } else {
        this.#curMax = this.#domMax
        this.maxInputTarget.value = this.#curMax
        this.#maxSet = false
      }
      this.#raiseAndMoveHandle(which)
      this.#updateAriaHandle(which)
      this.#setHandleActive(which)
      this.#colorBars()
      return
    }

    // Strip formatting including + (displayed in percent_change values like "+75%").
    const parsed = parseFloat(raw.replace(/[$%,\s+]/g, ""))
    if (isNaN(parsed)) {
      event.currentTarget.value = ""
      return
    }

    let clamped
    if (which === "min") {
      // Min may not exceed the current max handle position.
      clamped = Math.round(Math.max(this.#domMin, Math.min(this.#curMax, parsed)))
      this.#curMin = clamped
      this.minInputTarget.value = clamped
      this.#minSet = true
    } else {
      // Max may not go below the current min handle position.
      clamped = Math.round(Math.min(this.#domMax, Math.max(this.#curMin, parsed)))
      this.#curMax = clamped
      this.maxInputTarget.value = clamped
      this.#maxSet = true
    }

    event.currentTarget.value = this.#fmtTextInput(clamped)

    this.#raiseAndMoveHandle(which)
    this.#updateAriaHandle(which)
    this.#setHandleActive(which)
    this.#colorBars()
    this.#syncTextInputs()
  }

  #fmt(n) {
    const fmt = this.formatValue
    const r = Math.round(n)
    if (fmt === "percent" || fmt === "percent_change") {
      const sign = (fmt === "percent_change" && r > 0) ? "+" : ""
      return `${sign}${r.toLocaleString("en-US")}%`
    }
    if (fmt === "currency") return "$" + r.toLocaleString("en-US")
    return r.toLocaleString("en-US") // default: plain integer (count, score, or unrecognized format)
  }
}
