import http, { unwrap } from './http'

export async function login(email, password) {
  const { data } = await http.post('/login', { email, password })
  return unwrap(data)
}

export async function logout() {
  const { data } = await http.post('/logout')
  return unwrap(data)
}

export async function loggedUser() {
  const { data } = await http.get('/loggeduser')
  return unwrap(data)
}
