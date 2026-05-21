// Shared singleton for row selection state across paginated table navigation.
// row_selection_controller writes here; export_controller reads here.
const selected = new Set()

export const toggle = (id) => {
  if (selected.has(id)) {
    selected.delete(id)
  } else {
    selected.add(id)
  }
}

export const selectPage = (ids) => ids.forEach(id => selected.add(id))
export const deselectPage = (ids) => ids.forEach(id => selected.delete(id))
export const clear = () => selected.clear()
export const has = (id) => selected.has(id)
export const getIds = () => [...selected]
export const count = () => selected.size
