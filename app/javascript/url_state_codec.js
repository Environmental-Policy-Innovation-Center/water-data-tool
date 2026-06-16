import pako from "pako"

export const encodeState = (paramsObj) => {
  const compressed = pako.deflate(JSON.stringify(paramsObj))
  let binary = ""
  compressed.forEach(b => { binary += String.fromCharCode(b) })
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "")
}

export const decodeState = (str) => {
  if (!str) return {}
  try {
    const binary = atob(str.replace(/-/g, "+").replace(/_/g, "/"))
    const bytes = Uint8Array.from(binary, c => c.charCodeAt(0))
    return JSON.parse(pako.inflate(bytes, { to: "string" }))
  } catch {
    return {}
  }
}

export const colsFromUrl = (search = window.location.search) => {
  const blob = new URLSearchParams(search).get("encoded")
  return blob ? (decodeState(blob).cols ?? null) : null
}

export const sortFromUrl = (search = window.location.search) => {
  const sp = new URLSearchParams(search)
  return { sort: sp.get("sort"), direction: sp.get("direction") }
}

export const buildEncodedParam = ({ filters = {}, cols = null } = {}) => {
  const state = {}
  if (Object.keys(filters).length > 0) state.filters = filters
  if (cols !== null) state.cols = cols
  return encodeState(state)
}
