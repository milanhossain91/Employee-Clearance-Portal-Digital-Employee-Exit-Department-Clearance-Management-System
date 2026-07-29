import { ref, computed } from 'vue'
import * as authApi from '../services/auth'

const token = ref(localStorage.getItem('aci-token') || '')
const user = ref(JSON.parse(localStorage.getItem('aci-user') || 'null'))
const permissions = ref(JSON.parse(localStorage.getItem('aci-permissions') || '[]'))

function persist() {
  localStorage.setItem('aci-token', token.value)
  localStorage.setItem('aci-user', JSON.stringify(user.value))
  localStorage.setItem('aci-permissions', JSON.stringify(permissions.value))
}

// `POST /login` nests the merged role + direct permissions inside `user` as full
// Spatie Permission models; `GET /loggeduser` returns plain name strings. Flatten
// both shapes down to the names the `can()` gate compares against.
function toPermissionNames(list) {
  if (!Array.isArray(list)) return []
  return list.map((p) => (typeof p === 'string' ? p : p?.name)).filter(Boolean)
}

function clear() {
  token.value = ''
  user.value = null
  permissions.value = []
  localStorage.removeItem('aci-token')
  localStorage.removeItem('aci-user')
  localStorage.removeItem('aci-permissions')
}

export function useAuth() {
  const isAuthed = computed(() => Boolean(token.value))

  async function login(email, password) {
    const body = await authApi.login(email, password)
    token.value = body.token
    user.value = body.user || null
    permissions.value = toPermissionNames(
      body.user?.all_permissions || body.all_permissions
    )
    persist()
  }

  async function logout() {
    try {
      await authApi.logout()
    } catch {
      // token may already be invalid/expired — clear local state regardless
    }
    clear()
  }

  function can(permission) {
    return permissions.value.includes(permission)
  }

  // User administration has no seeded permission of its own — the permission
  // table only covers business, department, form-type, staff and clearance —
  // so those screens gate on the role name instead.
  function hasRole(...names) {
    const held = (user.value?.roles || []).map((r) => (typeof r === 'string' ? r : r?.name))
    return names.some((name) => held.includes(name))
  }

  return { isAuthed, user, permissions, login, logout, can, hasRole }
}
