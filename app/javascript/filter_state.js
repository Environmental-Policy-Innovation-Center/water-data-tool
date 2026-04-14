// Shared singleton for the most recently applied filter params.
// filter_controller writes here when the user clicks Apply;
// table_controller reads here when DataTables fires its AJAX request.
let current = {}
export const get = () => current
export const set = (params) => { current = { ...params } }
