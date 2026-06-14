import * as FilterState from "filter_state"

export function syncStatsFrame() {
  const frame = document.querySelector("turbo-frame#stats-bar")
  if (!frame) return

  const params = new URLSearchParams(FilterState.toUrlParams())
  const container = document.getElementById("container-map-content-bottom")

  if ([...params.keys()].length === 0) {
    frame.removeAttribute("src")
    frame.innerHTML = ""
    container?.classList.remove("has-stats")
    return
  }

  const newSrc = `/public_water_systems/stats?${params.toString()}`
  if (frame.getAttribute("src") === newSrc) return
  frame.src = newSrc
  container?.classList.add("has-stats")
}
