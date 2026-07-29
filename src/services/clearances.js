import http, { unwrap } from './http'

export async function entryFormData() {
  const { data } = await http.get('/clearances/create')
  return unwrap(data)
}

export async function createClearance(payload) {
  const { data } = await http.post('/clearances', payload)
  return unwrap(data)
}

export async function searchClearance(q) {
  const { data } = await http.get('/clearances/search', { params: { q } })
  return unwrap(data)
}

export async function getClearance(id) {
  const { data } = await http.get(`/clearances/${id}`)
  return unwrap(data)
}

export async function updateHeader(id, payload) {
  const { data } = await http.put(`/clearances/${id}`, payload)
  return unwrap(data)
}

export async function saveDepartments(id, departments) {
  const { data } = await http.put(`/clearances/${id}/departments`, { departments })
  return unwrap(data)
}

export async function saveOneDepartment(clearanceId, departmentId, payload) {
  const { data } = await http.put(`/clearances/${clearanceId}/departments/${departmentId}`, payload)
  return unwrap(data)
}

export async function markDepartmentReturned(clearanceId, departmentId, isReturned, remarks) {
  return saveOneDepartment(clearanceId, departmentId, { is_returned: isReturned, remarks })
}

export async function deleteClearance(id) {
  const { data } = await http.delete(`/clearances/${id}`)
  return unwrap(data)
}

export async function listClearances(params) {
  const { data } = await http.get('/clearances', { params })
  return unwrap(data)
}

// Every row matching the current filters, for the Excel export — the register
// endpoint is paginated (200 max per page), so walk the pages. `last_page` from
// the first response bounds the loop, and the row cap is a safety net so a bad
// filter can never spin here indefinitely.
export async function listAllClearances(params, { maxRows = 10000 } = {}) {
  const perPage = 200
  const first = await listClearances({ ...params, page: 1, per_page: perPage })
  const rows = [...(first.clearances || [])]
  const lastPage = first.pagination?.last_page ?? 1

  for (let page = 2; page <= lastPage && rows.length < maxRows; page++) {
    const next = await listClearances({ ...params, page, per_page: perPage })
    rows.push(...(next.clearances || []))
  }

  return {
    clearances: rows.slice(0, maxRows),
    department_columns: first.department_columns || [],
    truncated: rows.length > maxRows,
    total: first.pagination?.total ?? rows.length,
  }
}

export async function summary() {
  const { data } = await http.get('/clearances/summary')
  return unwrap(data)
}
