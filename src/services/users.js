import http, { unwrap } from './http'

// These endpoints predate the clearance module and keep its response envelope
// but not its naming: `role_list` returns an {id: name} map rather than a list,
// and `permission_list` returns the singular key `permission`. Normalise both
// here so callers only deal with arrays of {id, name}.

export async function listUsers() {
  const { data } = await http.get('/user_list')
  return unwrap(data).users || []
}

export async function listRoles() {
  const { data } = await http.get('/role_list')
  const roles = unwrap(data).roles || {}
  return Object.entries(roles).map(([id, name]) => ({ id: Number(id), name }))
}

export async function listPermissions() {
  const { data } = await http.get('/permission_list')
  return unwrap(data).permission || []
}

export async function createUser(payload) {
  const { data } = await http.post('/register', payload)
  return unwrap(data)
}

export async function updateUser(id, payload) {
  const { data } = await http.put(`/user_update/${id}`, payload)
  return unwrap(data)
}

export async function deleteUser(id) {
  const { data } = await http.delete(`/user_delete/${id}`)
  return unwrap(data)
}

// Replaces the user's direct permissions — those granted on top of their role.
export async function assignPermissions(id, permissions) {
  const { data } = await http.put(`/assign_permission/${id}`, { permissions })
  return unwrap(data)
}
