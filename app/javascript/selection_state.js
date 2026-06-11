// Tracks which rows are selected across paginated table navigation.
// Writers: row_selection_controller (toggle/select/deselect), filter_controller (clear on filter change)
// Readers: export_controller (determines what to include in the export)
const excluded = new Set()
const included = new Set()
let mode = "all"

export const isAllChecked = () => mode === "all" && excluded.size === 0
export const isAllMode    = () => mode === "all"

export const selectAll = () => {
  mode = "all"
  excluded.clear()
  included.clear()
}

export const deselectAll = () => {
  mode = "none"
  excluded.clear()
  included.clear()
}

export const toggle = (id) => {
  if (mode === "all") {
    excluded.has(id) ? excluded.delete(id) : excluded.add(id)
  } else {
    included.has(id) ? included.delete(id) : included.add(id)
  }
}

// Called when filters change — reset to "all selected" for the fresh result set
export const clear = selectAll

export const has            = (id) => mode === "all" ? !excluded.has(id) : included.has(id)
export const excludedCount  = ()   => excluded.size
export const getExcludedIds = ()   => [...excluded]
export const getIds         = ()   => [...included]
export const count          = ()   => included.size
