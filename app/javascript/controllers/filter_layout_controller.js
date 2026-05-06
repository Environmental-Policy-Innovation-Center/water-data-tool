import { Controller } from "@hotwired/stimulus"

// Breakpoints match the legacy app (adjusted for map container width, not window width).
// When a nav button hides, its content is DOM-reparented into the More menu so it remains
// accessible there — same pattern as the legacy scripts-ui.js setLayout().
const RESPONSIVE_FILTERS = [
  { num: 5, breakpoint: 1190 },  // Population
  { num: 4, breakpoint: 1040 },  // Compliance
  { num: 3, breakpoint: 880  },  // Boundaries
  { num: 2, breakpoint: 730  },  // Attributes
  { num: 1, breakpoint: 580  },  // Source
]

export default class extends Controller {
  #resizeObserver = null
  #lastLayoutWidth = null

  connect() {
    this.#resizeObserver = new ResizeObserver(entries => {
      this.#adjustFilterLayout(entries[0].contentRect.width)
    })
    this.#resizeObserver.observe(this.element)
    this.#adjustFilterLayout(this.element.clientWidth)
  }

  disconnect() {
    this.#resizeObserver?.disconnect()
    this.#resizeObserver = null
  }

  #adjustFilterLayout(width) {
    // Skip if no breakpoint was crossed since the last pass — avoids badge recalc on every resize pixel
    const prev = this.#lastLayoutWidth
    const crossed = prev === null || RESPONSIVE_FILTERS.some(({ breakpoint }) =>
      (prev < breakpoint) !== (width < breakpoint)
    )
    if (!crossed) return
    this.#lastLayoutWidth = width
    document.dispatchEvent(new CustomEvent("filter:close-all"))

    for (const { num, breakpoint } of RESPONSIVE_FILTERS) {
      const li = document.querySelector(`.filter-${num}`)
      const items = document.getElementById(`container-menu-${num}-items`)
      const mainGrp = document.getElementById(`main-filter-grp-${num}`)
      const moreGrp = document.getElementById(`more-filter-grp-${num}`)
      if (!li || !items || !mainGrp || !moreGrp) continue

      if (width < breakpoint) {
        li.classList.add("hidden")
        // Nest inside the per-group placeholder so ordering is anchored to the
        // placeholder's position in the More menu, not to sibling iteration order.
        moreGrp.appendChild(items)
      } else {
        li.classList.remove("hidden")
        mainGrp.insertAdjacentElement("afterend", items)
      }
    }
    document.dispatchEvent(new CustomEvent("filter:layout-changed"))
  }
}
