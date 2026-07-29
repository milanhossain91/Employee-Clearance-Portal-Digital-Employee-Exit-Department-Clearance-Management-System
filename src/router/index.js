import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '../composables/auth'
import LoginPage from '../views/LoginPage.vue'
import ClearanceEntry from '../views/ClearanceEntry.vue'
import ClearanceUpdate from '../views/ClearanceUpdate.vue'
import ClearanceView from '../views/ClearanceView.vue'
import AddFormType from '../views/AddFormType.vue'
import UserManagement from '../views/UserManagement.vue'

// Roles allowed to administer accounts. Both hold all 18 seeded permissions.
export const ADMIN_ROLES = ['Super Admin', 'HR Admin']

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/login', name: 'login', component: LoginPage, meta: { public: true } },
    {
      path: '/',
      name: 'clearance-entry',
      component: ClearanceEntry,
      meta: { permission: 'clearance.create' },
    },
    {
      path: '/update',
      name: 'clearance-update',
      component: ClearanceUpdate,
      meta: { permission: 'clearance.update' },
    },
    {
      path: '/view',
      name: 'clearance-view',
      component: ClearanceView,
      meta: { permission: 'clearance.view' },
    },
    {
      path: '/form-type',
      name: 'add-form-type',
      component: AddFormType,
      meta: { permission: 'form-type.update' },
    },
    {
      // No `user.*` permission is seeded, so this one gates on role.
      path: '/users',
      name: 'user-management',
      component: UserManagement,
      meta: { roles: ADMIN_ROLES },
    },
  ],
})

// The first screen this user is actually allowed to open, in menu order. A
// Viewer, for instance, only holds `clearance.view`, so "/" would 403 on load.
const LANDING_ORDER = [
  ['/', 'clearance.create'],
  ['/update', 'clearance.update'],
  ['/view', 'clearance.view'],
  ['/form-type', 'form-type.update'],
]

function landingRoute(can) {
  return LANDING_ORDER.find(([, permission]) => can(permission))?.[0] || null
}

router.beforeEach((to) => {
  const { isAuthed, can, hasRole } = useAuth()
  if (!to.meta.public && !isAuthed.value) return '/login'

  const landing = landingRoute(can)
  if (to.path === '/login' && isAuthed.value) return landing || '/view'
  // Someone with no portal permission at all has nowhere to be sent, so let the
  // screen load and surface the API's own 403 instead of looping on redirects.
  if (to.meta.permission && !can(to.meta.permission) && landing) return landing
  if (to.meta.roles && !hasRole(...to.meta.roles)) return landing || '/view'
})

export default router
