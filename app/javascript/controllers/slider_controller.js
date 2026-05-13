import { Controller } from "@hotwired/stimulus"

// Histogram data is global (not per-user or per-filter scope), so keying on field is stable.
const CACHE = new Map()
const SVG_W = 200
const SVG_H = 80
const HANDLE_R = 5
const BLUE = "#3B82F6"
const GRAY = "#bfbfbf"
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
  #tip = null
  #rect = null

  async connect() {
    const field = this.fieldValue
    if (!field) return

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
    this.chartTarget.removeEventListener("pointerdown", this.#onDown)
    this.chartTarget.removeEventListener("pointermove", this.#onMove)
  }

  resetToFullRange() {
    if (!this.#bins.length) return
    this.#curMin = this.#domMin
    this.#curMax = this.#domMax
    this.#moveHandle("min", this.#valToX(this.#domMin))
    this.#moveHandle("max", this.#valToX(this.#domMax))
    this.#colorBars()
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
      domain_min = Math.min(domain_min, -100)
      domain_max = Math.max(domain_max, 100)
    } else {
      // count and currency: floor at 1 so scale always starts at 1 / $1
      domain_min = Math.min(domain_min, 1)
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
    this.minLabelTarget.textContent = this.#fmt(domain_min)
    this.maxLabelTarget.textContent = this.#fmt(domain_max)
    if (this.hasZeroLabelTarget) this.zeroLabelTarget.textContent = "0"
  }

  #draw() {
    const svg = this.chartTarget
    svg.setAttribute("viewBox", `0 0 ${SVG_W} ${SVG_H}`)
    svg.setAttribute("preserveAspectRatio", "none")
    svg.innerHTML = ""
    this.#tip = null

    if (!this.#bins.length) return

    if (this.#domMin === this.#domMax) {
      svg.appendChild(this.#el("line", {
        x1: 0, x2: SVG_W,
        y1: SVG_H - HANDLE_R, y2: SVG_H - HANDLE_R,
        stroke: BLUE, "stroke-width": 2
      }))
      this.#addHandle("min", 0)
      this.#addHandle("max", SVG_W)
      svg.removeEventListener("pointerdown", this.#onDown)
      svg.addEventListener("pointerdown", this.#onDown)
      return
    }

    const maxCount = Math.max(...this.#bins.map(b => b.count))
    const sqrtMax = maxCount ? Math.sqrt(maxCount) : 1
    const barArea = SVG_H - HANDLE_R * 2 - 2
    const barW = SVG_W / this.#bins.length
    const gap = 1
    const drawW = Math.max(1, barW - gap)
    
    // Using a square root scale for bar heights to give more visual distinction to smaller counts.
    this.#bins.forEach((bin, i) => {
      const h = maxCount ? Math.max(1, (Math.sqrt(bin.count) / sqrtMax) * barArea) : 0
      svg.appendChild(this.#el("rect", {
        x: i * barW + gap / 2, y: SVG_H - HANDLE_R * 2 - h - 1,
        width: drawW, height: h, rx: 2, ry: 2,
        "data-bin-min": bin.min, "data-bin-max": bin.max
      }))
    })

    this.#tip = this.#el("text", {
      "text-anchor": "middle", "font-size": 10, fill: "#333", class: "slider-tip"
    })
    this.#tip.style.display = "none"
    svg.appendChild(this.#tip)

    this.#addHandle("min", this.#valToX(this.#curMin))
    this.#addHandle("max", this.#valToX(this.#curMax))
    this.#colorBars()
    svg.removeEventListener("pointerdown", this.#onDown)
    svg.addEventListener("pointerdown", this.#onDown)
  }

  #addHandle(which, x) {
    this.chartTarget.appendChild(this.#el("circle", {
      cx: x, cy: SVG_H - HANDLE_R, r: HANDLE_R,
      fill: "#000", style: "cursor:grab", "data-handle": which
    }))
  }

  #colorBars() {
    this.chartTarget.querySelectorAll("rect[data-bin-min]").forEach(bar => {
      const inside = +bar.dataset.binMax >= this.#curMin && +bar.dataset.binMin <= this.#curMax
      bar.setAttribute("fill", inside ? BLUE : GRAY)
    })
  }

  #onDown = (event) => {
    const handle = event.target.closest("[data-handle]")
    if (!handle) return

    this.#dragging = handle.dataset.handle
    this.#rect = this.chartTarget.getBoundingClientRect()
    this.chartTarget.setPointerCapture(event.pointerId)
    this.chartTarget.addEventListener("pointermove", this.#onMove)
    this.chartTarget.addEventListener("pointerup", this.#onUp, { once: true })
    event.preventDefault()
  }

  #onMove = (event) => {
    const rect = this.#rect
    const x = Math.max(0, Math.min(SVG_W, (event.clientX - rect.left) * (SVG_W / rect.width)))
    const val = this.#xToVal(x)

    if (this.#dragging === "min") {
      this.#curMin = Math.min(val, this.#curMax)
      this.#moveHandle("min", this.#valToX(this.#curMin))
      this.#showTip(this.#curMin, this.#valToX(this.#curMin))
    } else {
      this.#curMax = Math.max(val, this.#curMin)
      this.#moveHandle("max", this.#valToX(this.#curMax))
      this.#showTip(this.#curMax, this.#valToX(this.#curMax))
    }
    this.#colorBars()
  }

  #onUp = () => {
    this.#dragging = null
    this.#rect = null
    this.chartTarget.removeEventListener("pointermove", this.#onMove)
    this.#hideTip()
    this.minInputTarget.value = this.#curMin
    this.maxInputTarget.value = this.#curMax
  }

  #moveHandle(which, x) {
    const h = this.chartTarget.querySelector(`[data-handle="${which}"]`)
    if (h) h.setAttribute("cx", String(x))
  }

  #showTip(val, x) {
    if (!this.#tip) return
    this.#tip.textContent = this.#fmt(val)
    this.#tip.setAttribute("x", String(x))
    this.#tip.setAttribute("y", String(SVG_H - HANDLE_R * 2 - 4))
    this.#tip.style.display = ""
  }

  #hideTip() {
    if (this.#tip) this.#tip.style.display = "none"
  }

  #valToX(val) {
    if (this.#domMax === this.#domMin) return SVG_W / 2
    return ((val - this.#domMin) / (this.#domMax - this.#domMin)) * SVG_W
  }

  #xToVal(x) {
    const raw = this.#domMin + (x / SVG_W) * (this.#domMax - this.#domMin)
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
