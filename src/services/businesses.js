import http, { unwrap } from './http'

export async function listBusinesses(params) {
  const { data } = await http.get('/businesses', { params })
  return unwrap(data)
}

export async function getBusiness(id) {
  const { data } = await http.get(`/businesses/${id}`)
  return unwrap(data)
}

export async function createBusiness(payload) {
  const { data } = await http.post('/businesses', payload)
  return unwrap(data)
}

export async function updateBusiness(id, payload) {
  const { data } = await http.put(`/businesses/${id}`, payload)
  return unwrap(data)
}

export async function deleteBusiness(id) {
  const { data } = await http.delete(`/businesses/${id}`)
  return unwrap(data)
}
