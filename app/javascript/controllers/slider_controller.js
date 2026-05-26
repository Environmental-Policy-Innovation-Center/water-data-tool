import { Controller } from "@hotwired/stimulus"

// Histogram data is global (not per-user or per-filter scope), so keying on field is stable.
const CACHE = new Map()
const SVG_W = 200
const SVG_H = 80        // bar + handle area
const X_AXIS_H = 10     // tick lines below the handle baseline
const HANDLE_R = 5
const PAD = HANDLE_R  // track inset so handles don't overflow SVG edges
const HANDLE_Y = SVG_H - HANDLE_R * 2  // handle center on the histogram baseline
const BLUE = "#3B82F6"
const GRAY = "#bfbfbf"
const DARK = "#4b5563"  // neutral-600 — visually consistent as both stroke and filled circle
const NS = "http://www.w3.org/2000/svg"

export default class extends Controller {
  static values = { field: String, url: String, format: String }
  static targets = ["chart", "minLabel", "maxLabel", "minInput", "maxInput", "zeroLabel"]

  #bins = []
  #domMin = 0
  #domMax = 0
  #curMin = 0
  #curMax = 0
  #dragging = null
  #tipMin = null
  #tipMax = null
  #tipText = { min: null, max: null }
  #tipTextW = { min: 0, max: 0 }
  #minHandle = null
  #maxHandle = null
  #svgW = SVG_W
  #ro = null

  async connect() {
    const field = this.fieldValue
    if (!field) return

    this.#ro = new ResizeObserver(entries => {
      const w = Math.round(entries[0]?.contentRect.width ?? 0)
      if (w <= 0 || w === this.#svgW) return
      this.#svgW = w
      if (this.#bins.length) this.#draw()
    })
    this.#ro.observe(this.chartTarget)

    if (!CACHE.has(field)) {
      CACHE.set(field,
        fetch(`${this.urlValue}?field=${encodeURIComponent(field)}`)
          .then(resp => resp.ok ? resp.json() : null)
          .catch(() => null)
      )
    }

    const data = await CACHE.get(field)
    if (!data) return
    this.#init(data)
  }

  disconnect() {
    this.#ro?.disconnect()
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
    if (this.#tipMin) this.#tipMin.style.display = "none"
    if (this.#tipMax) this.#tipMax.style.display = "none"
    this.minInputTarget.value = ""
    this.maxInputTarget.value = ""
  }

  // Called by filter_controller when a health subcat slider panel is revealed.
  // Ensures inputs carry domain defaults so Apply always sends params for checked subcats.
  populateDefaultsIfEmpty() {
    if (!this.#bins.length) return
    if (!this.minInputTarget.value) this.minInputTarget.value = this.#domMin
    if (!this.maxInputTarget.value) this.maxInputTarget.value = this.#domMax
  }

  #init({ bins, domain_min, domain_max }) {
    this.#bins = bins

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
      // Extend to the next nice round boundary so the axis always ends on a clean number.
      domain_max = this.#niceMax(domain_min, domain_max)
    }

    this.#domMin = domain_min
    this.#domMax = domain_max
    this.#curMin = domain_min
    this.#curMax = domain_max

    const minVal = this.minInputTarget.value
    const maxVal = this.maxInputTarget.value

    if (minVal) this.#curMin = parseFloat(minVal)
    if (maxVal) this.#curMax = parseFloat(maxVal)

    if (!minVal) this.minInputTarget.value = this.#curMin
    if (!maxVal) this.maxInputTarget.value = this.#curMax

    this.#draw()
    // SR-only labels for screen readers — visual labels are rendered in the SVG x-axis.
    this.minLabelTarget.textContent = this.#fmt(domain_min)
    this.maxLabelTarget.textContent = this.#fmt(domain_max)
    this.zeroLabelTarget.textContent = "0"
  }

  #draw() {
    const svg = this.chartTarget
    const totalH = SVG_H + X_AXIS_H
    svg.setAttribute("viewBox", `0 0 ${this.#svgW} ${totalH}`)
    svg.setAttribute("height", String(totalH))
    svg.setAttribute("preserveAspectRatio", "none")
    svg.innerHTML = ""
    this.#tipMin = null
    this.#tipMax = null
    this.#tipText = { min: null, max: null }
    this.#tipTextW = { min: 0, max: 0 }
    this.#minHandle = null
    this.#maxHandle = null

    if (!this.#bins.length) return

    if (this.#domMin === this.#domMax) {
      svg.appendChild(this.#el("line", {
        x1: PAD, x2: this.#svgW - PAD,
        y1: HANDLE_Y, y2: HANDLE_Y,
        stroke: BLUE, "stroke-width": 2
      }))
      this.#drawXAxis(svg)
      this.#minHandle = this.#addHandle("min", PAD)
      this.#maxHandle = this.#addHandle("max", this.#svgW - PAD)
      svg.removeEventListener("pointerdown", this.#onDown)
      svg.addEventListener("pointerdown", this.#onDown)
      return
    }

    const maxCount = Math.max(...this.#bins.map(b => b.count))
    const sqrtMax = maxCount ? Math.sqrt(maxCount) : 1
    const barArea = SVG_H - HANDLE_R * 2 - 2
    const trackW = this.#svgW - PAD * 2
    const barW = trackW / this.#bins.length
    const gap = 1
    const drawW = Math.max(1, barW - gap)

    // Using a square root scale for bar heights to give more visual distinction to smaller counts.
    this.#bins.forEach((bin, i) => {
      const h = bin.count > 0 && maxCount ? Math.max(1, (Math.sqrt(bin.count) / sqrtMax) * barArea) : 0
      const bx = PAD + i * barW + gap / 2
      const by = SVG_H - HANDLE_R * 2 - h - 1
      const bw = drawW
      const r  = h > 0 ? Math.min(3, h / 2, bw / 2) : 0
      // Path with rounded top corners only.
      const d  = h > 0
        ? `M ${bx} ${by + h} L ${bx} ${by + r} Q ${bx} ${by} ${bx + r} ${by} L ${bx + bw - r} ${by} Q ${bx + bw} ${by} ${bx + bw} ${by + r} L ${bx + bw} ${by + h} Z`
        : ""
      svg.appendChild(this.#el("path", { d, "data-bin-min": bin.min, "data-bin-max": bin.max }))
    })

    this.#tipMin = this.#makeTip()
    this.#tipMax = this.#makeTip()
    svg.appendChild(this.#tipMin)
    svg.appendChild(this.#tipMax)

    this.#drawXAxis(svg)
    this.#minHandle = this.#addHandle("min", this.#valToX(this.#curMin))
    this.#maxHandle = this.#addHandle("max", this.#valToX(this.#curMax))
    this.#setHandleActive("min")
    this.#setHandleActive("max")
    this.#colorBars()
    svg.removeEventListener("pointerdown", this.#onDown)
    svg.addEventListener("pointerdown", this.#onDown)
  }

  #drawXAxis(svg) {
    // Baseline sits flush at bar bottom; tick marks sit below the handles.
    const baseY = SVG_H - HANDLE_R * 2 - 1
    svg.appendChild(this.#el("line", {
      x1: PAD, x2: this.#svgW - PAD,
      y1: baseY, y2: baseY,
      stroke: DARK, "stroke-width": 0.5
    }))

    const ticks = this.#xTicks()
    const tickTop = baseY
    const tickBot = tickTop + 4

    ticks.forEach(({ value }) => {
      svg.appendChild(this.#el("line", {
        x1: this.#valToX(value), x2: this.#valToX(value),
        y1: tickTop, y2: tickBot,
        stroke: DARK, "stroke-width": 1
      }))
    })
  }

  // Returns tick positions and labels for the x-axis based on format and domain.
  #xTicks() {
    const fmt = this.formatValue

    if (fmt === "percent") {
      return [0, 20, 40, 60, 80, 100].map(v => ({ value: v, label: `${v}%` }))
    }

    if (fmt === "percent_change") {
      return [
        { value: -200, label: "≤−200%" },
        { value: -100, label: "−100%" },
        { value: 0,    label: "0" },
        { value: 100,  label: "+100%" },
        { value: 200,  label: "≥200%" }
      ]
    }

    // count / currency: auto-select up to 5 evenly-spaced round ticks
    return this.#autoTicks(this.#domMin, this.#domMax, 5)
  }

  // Computes up to maxCount nicely-rounded tick values spanning [min, max].
  #autoTicks(min, max, maxCount) {
    const range = max - min
    if (range === 0) return [{ value: min, label: this.#fmtTick(min) }]

    const step  = this.#niceStep(range, maxCount)
    const ticks = []
    const start = Math.ceil(min / step) * step
    for (let v = start; v <= max + step * 0.001; v += step) {
      const rounded = Math.round(v * 1e9) / 1e9
      if (rounded >= min && rounded <= max) {
        ticks.push({ value: rounded, label: this.#fmtTick(rounded) })
      }
    }

    if (!ticks.length || Math.abs(ticks[0].value - min) > step * 0.01)
      ticks.unshift({ value: min, label: this.#fmtTick(min) })
    if (!ticks.length || Math.abs(ticks[ticks.length - 1].value - max) > step * 0.01)
      ticks.push({ value: max, label: this.#fmtTick(max) })

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
    return Math.ceil(max / step) * step
  }

  #fmtTick(v) {
    const r = Math.round(v)
    return this.formatValue === "currency"
      ? "$" + r.toLocaleString("en-US")
      : r.toLocaleString("en-US")
  }

  #makeTip() {
    const g = this.#el("g", { class: "slider-tip", "aria-hidden": "true" })
    g.style.display = "none"
    g.appendChild(this.#el("path", { fill: "white", stroke: "#d1d5db", "stroke-width": 1 }))
    g.appendChild(this.#el("text", {
      "text-anchor": "middle", "font-size": 12, fill: "#4b5563", "dominant-baseline": "middle"
    }))
    return g
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
    g.appendChild(this.#el("circle", { cx: 0, cy: 0, r: HANDLE_R, fill: DARK }))

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
      const curVal = which === "min" ? this.#curMin : this.#curMax
      this.#moveHandle(which, this.#valToX(curVal))
      this.#updateAriaHandle(which)
      this.#setHandleActive(which)
      this.#colorBars()
      this.minInputTarget.value = this.#curMin
      this.maxInputTarget.value = this.#curMax
    })

    this.chartTarget.appendChild(g)
    return g
  }

  #moveHandle(which, x) {
    const h = which === "min" ? this.#minHandle : this.#maxHandle
    if (h) h.setAttribute("transform", `translate(${x}, ${HANDLE_Y})`)
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
    g.appendChild(this.#el("circle", { cx: 0, cy: 0, r: HANDLE_R, fill: DARK }))
  }

  #setHandleActive(which) {
    const cur = which === "min" ? this.#curMin : this.#curMax
    const dom = which === "min" ? this.#domMin : this.#domMax
    if (cur !== dom) this.#activateHandle(which)
    else this.#deactivateHandle(which)
  }

  #hideTip(which) {
    const tip = which === "min" ? this.#tipMin : this.#tipMax
    if (tip) tip.style.display = "none"
  }

  #updateAriaHandle(which) {
    const g = which === "min" ? this.#minHandle : this.#maxHandle
    if (!g) return
    const val = which === "min" ? this.#curMin : this.#curMax
    g.setAttribute("aria-valuenow", String(val))
    g.setAttribute("aria-valuetext", this.#fmt(val))
  }

  #colorBars() {
    this.chartTarget.querySelectorAll("[data-bin-min]").forEach(bar => {
      const inside = +bar.dataset.binMax > this.#curMin && +bar.dataset.binMin <= this.#curMax
      bar.setAttribute("fill", inside ? BLUE : GRAY)
    })
  }

  #onDown = (event) => {
    const handle = event.target.closest("[data-handle]")
    if (!handle) return

    this.#dragging = handle.dataset.handle
    this.#activateHandle(this.#dragging)
    this.chartTarget.setPointerCapture(event.pointerId)
    this.chartTarget.addEventListener("pointermove", this.#onMove)
    this.chartTarget.addEventListener("pointerup", this.#onUp, { once: true })
    event.preventDefault()
  }

  #onMove = (event) => {
    const rect = this.chartTarget.getBoundingClientRect()
    const x = Math.max(0, Math.min(this.#svgW, (event.clientX - rect.left) * (this.#svgW / rect.width)))
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
    this.chartTarget.removeEventListener("pointermove", this.#onMove)
    this.minInputTarget.value = this.#curMin
    this.maxInputTarget.value = this.#curMax
    if (dragged) {
      this.#hideTip(dragged)
      this.#setHandleActive(dragged)
    }
  }

  #showTip(val, x, which) {
    const tip = which === "min" ? this.#tipMin : this.#tipMax
    if (!tip) return

    const tipPath = tip.querySelector("path")
    const text    = tip.querySelector("text")
    const formatted = this.#fmt(val)
    const textChanged = formatted !== this.#tipText[which]
    if (textChanged) {
      text.textContent = formatted
      this.#tipText[which] = formatted
    }
    tip.style.display = ""

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
    const pillW    = Math.max(textW + padX * 2, 2 * (rx + arrowHW) + 2)
    const pillX    = Math.max(0, Math.min(this.#svgW - pillW, x - pillW / 2))
    // Clamp arrow x within the straight bottom segment between the two rounded caps.
    const arrowXMin = pillX + rx + arrowHW
    const arrowXMax = pillX + pillW - rx - arrowHW
    const arrowX    = Math.max(arrowXMin, Math.min(arrowXMax, x))

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

  #valToX(val) {
    if (this.#domMax === this.#domMin) return this.#svgW / 2
    return PAD + ((val - this.#domMin) / (this.#domMax - this.#domMin)) * (this.#svgW - PAD * 2)
  }

  #xToVal(x) {
    const raw = this.#domMin + ((x - PAD) / (this.#svgW - PAD * 2)) * (this.#domMax - this.#domMin)
    return Math.round(Math.max(this.#domMin, Math.min(this.#domMax, raw)))
  }

  #el(tag, attrs = {}) {
    const el = document.createElementNS(NS, tag)
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, String(v))
    return el
  }

  #fmt(n) {
    const fmt = this.formatValue
    const r = Math.round(n)
    if (fmt === "percent" || fmt === "percent_change") {
      const sign = (fmt === "percent_change" && r > 0) ? "+" : ""
      return `${sign}${r.toLocaleString("en-US")}%`
    }
    if (fmt === "currency") return "$" + r.toLocaleString("en-US")
    return r.toLocaleString("en-US")
  }
}
