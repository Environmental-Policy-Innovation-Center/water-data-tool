import { Controller } from "@hotwired/stimulus"

const CACHE = new Map()
const SVG_W = 200
const SVG_H = 80
const HANDLE_R = 5
const BLUE = "#1054A8"
const GRAY = "#bfbfbf"
const NS = "http://www.w3.org/2000/svg"

export default class extends Controller {
  static values = { field: String, url: String }
  static targets = ["chart", "minLabel", "maxLabel", "minInput", "maxInput"]

  #bins = []
  #domMin = 0
  #domMax = 0
  #curMin = 0
  #curMax = 0
  #dragging = null
  #tip = null

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

  #init({ bins, domain_min, domain_max }) {
    this.#bins = bins
    this.#domMin = domain_min
    this.#domMax = domain_max
    this.#curMin = domain_min
    this.#curMax = domain_max

    const minVal = this.minInputTarget.value
    const maxVal = this.maxInputTarget.value
    if (minVal) this.#curMin = parseInt(minVal, 10)
    if (maxVal) this.#curMax = parseInt(maxVal, 10)

    this.#draw()
    this.minLabelTarget.textContent = this.#fmt(domain_min)
    this.maxLabelTarget.textContent = this.#fmt(domain_max)
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
    const barArea = SVG_H - HANDLE_R * 2 - 2
    const barW = SVG_W / this.#bins.length

    this.#bins.forEach((bin, i) => {
      const h = maxCount ? Math.max(1, (bin.count / maxCount) * barArea) : 0
      svg.appendChild(this.#el("rect", {
        x: i * barW, y: SVG_H - HANDLE_R * 2 - h - 1,
        width: barW, height: h,
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
    this.chartTarget.setPointerCapture(event.pointerId)
    this.chartTarget.addEventListener("pointermove", this.#onMove)
    this.chartTarget.addEventListener("pointerup", this.#onUp, { once: true })
    event.preventDefault()
  }

  #onMove = (event) => {
    const rect = this.chartTarget.getBoundingClientRect()
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
    return Number(n).toLocaleString("en-US")
  }
}
