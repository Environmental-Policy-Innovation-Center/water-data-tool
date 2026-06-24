// Shared singleton for the active table search term.
// table_search_controller writes here on input; url_sync reads here to encode into ?encoded=.
let current = null
export const get = () => current
export const set = (term) => { current = term || null }
export const clear = () => { current = null }
