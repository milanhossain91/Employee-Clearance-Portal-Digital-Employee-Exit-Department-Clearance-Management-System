import http, { unwrap } from './http'

export async function listDepartments(params) {
  const { data } = await http.get('/departments', { params })
  return unwrap(data)
}

export async function getDepartment(id) {
  const { data } = await http.get(`/departments/${id}`)
  return unwrap(data)
}

export async function createDepartment(payload) {
  const { data } = await http.post('/departments', payload)
  return unwrap(data)
}

export async function updateDepartment(id, payload) {
  const { data } = await http.put(`/departments/${id}`, payload)
  return unwrap(data)
}

export async function deleteDepartment(id) {
  const { data } = await http.delete(`/departments/${id}`)
  return unwrap(data)
}
