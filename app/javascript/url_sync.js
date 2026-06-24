import * as FilterState from "filter_state"
import * as SearchState from "search_state"
import { buildEncodedParam, colsFromUrl, sortFromUrl } from "url_state_codec"

// Shared URL writer — used by any controller that modifies FilterState or SearchState and needs
// to reflect it in the address bar. Produces the same ?encoded= format that
// filter_controller#restoreFromUrl() reads on page load.
export const syncToUrl = () => {
  const url = new URL(window.location)
  const cols = colsFromUrl(url.search)
  const { sort, direction } = sortFromUrl(url.search)
  const filters = FilterState.get()
  const search = SearchState.get()

  url.search = ""
  if (Object.keys(filters).length > 0 || cols !== null || search) {
    url.searchParams.set("encoded", buildEncodedParam({ filters, cols, search }))
  }
  if (sort) url.searchParams.set("sort", sort)
  if (direction) url.searchParams.set("direction", direction)
  history.replaceState({}, "", url)
}
