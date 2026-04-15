// Shared singleton for the most recently applied filter params.
// filter_controller writes here when the user clicks Apply;
// table_controller reads here when DataTables fires its AJAX request.
let current = {}
export const get = () => current
export const set = (params) => { current = { ...params } }

export const toUrlParams = () => {
  const sp = new URLSearchParams()
  Object.entries(current).forEach(([key, value]) => {
    if (Array.isArray(value)) {
      value.forEach(v => sp.append(`${key}[]`, v))
    } else if (value !== "" && value != null) {
      sp.set(key, value)
    }
  })
  return sp
}

export const fromUrlParams = (search) => {
  const sp = new URLSearchParams(search)
  const params = {}

  sp.forEach((value, key) => {
    if (key.endsWith("[]")) {
      const base = key.slice(0, -2)
      if (!params[base]) params[base] = []
      params[base].push(value)
    } else {
      params[key] = value
    }
  })

  return params
}
