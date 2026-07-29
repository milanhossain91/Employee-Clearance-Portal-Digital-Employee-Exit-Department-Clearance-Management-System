<script setup>
import { ref, computed, onMounted } from 'vue'
import { motion } from 'motion-v'
import { useToast } from 'primevue/usetoast'
import { Search, Plus, Pencil, Trash2, ShieldCheck } from '@lucide/vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Dialog from 'primevue/dialog'
import Select from 'primevue/select'
import MultiSelect from 'primevue/multiselect'
import InputText from 'primevue/inputtext'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import Button from 'primevue/button'
import Tag from 'primevue/tag'
import {
  listUsers,
  listRoles,
  listPermissions,
  createUser,
  updateUser,
  deleteUser,
  assignPermissions,
} from '../services/users'
import { friendlyMessage } from '../services/http'
import { useAuth } from '../composables/auth'

const toast = useToast()
const { user: currentUser } = useAuth()

const users = ref([])
const roles = ref([])
const permissions = ref([])
const loading = ref(false)
const filter = ref('')

const dialogOpen = ref(false)
const saving = ref(false)
const editing = ref(null)
const form = ref({ name: '', email: '', password: '', role: null, permissions: [] })
const formError = ref('')

const deleteTarget = ref(null)
const deleting = ref(false)

function alertError(err, summary) {
  toast.add({ severity: 'error', summary, detail: friendlyMessage(err), life: 6000 })
}

async function loadAll() {
  loading.value = true
  try {
    const [u, r, p] = await Promise.all([listUsers(), listRoles(), listPermissions()])
    users.value = u
    roles.value = r
    permissions.value = p
  } catch (err) {
    alertError(err, 'Could not load users')
    users.value = []
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)

const visibleUsers = computed(() => {
  const term = filter.value.trim().toLowerCase()
  if (!term) return users.value
  return users.value.filter((u) =>
    [u.name, u.email, roleNameOf(u)].some((v) => String(v || '').toLowerCase().includes(term))
  )
})

function roleNameOf(user) {
  return user.roles?.[0]?.name || ''
}

// Permissions the role already grants — shown separately from direct grants so
// it is obvious which ones were added on top.
function rolePermissionCount(user) {
  return user.roles?.[0]?.permissions?.length ?? 0
}

function openCreate() {
  editing.value = null
  formError.value = ''
  form.value = { name: '', email: '', password: '', role: null, permissions: [] }
  dialogOpen.value = true
}

function openEdit(user) {
  editing.value = user
  formError.value = ''
  form.value = {
    name: user.name || '',
    email: user.email || '',
    password: '',
    role: roles.value.find((r) => r.name === roleNameOf(user)) || null,
    permissions: (user.permissions || []).map((p) => p.name),
  }
  dialogOpen.value = true
}

function validate() {
  if (!form.value.name.trim()) return 'Name is required.'
  if (!form.value.email.trim()) return 'Email is required.'
  if (!editing.value && !form.value.password) return 'Password is required for a new user.'
  if (!form.value.role) return 'Role is required.'
  return ''
}

async function save() {
  formError.value = validate()
  if (formError.value) return

  saving.value = true
  try {
    if (editing.value) {
      // `user_update` handles name, email and roles; direct permissions are a
      // separate endpoint, so only call it when they actually changed.
      await updateUser(editing.value.id, {
        name: form.value.name.trim(),
        email: form.value.email.trim(),
        roles: [form.value.role.name],
      })

      const before = [...(editing.value.permissions || []).map((p) => p.name)].sort()
      const after = [...form.value.permissions].sort()
      if (JSON.stringify(before) !== JSON.stringify(after)) {
        await assignPermissions(editing.value.id, form.value.permissions)
      }

      toast.add({
        severity: 'success',
        summary: 'User updated',
        detail: `${form.value.name} saved as ${form.value.role.name}.`,
        life: 5000,
      })
    } else {
      const created = await createUser({
        name: form.value.name.trim(),
        email: form.value.email.trim(),
        password: form.value.password,
        roles: [form.value.role.name],
      })

      // `register` does not accept direct permissions, so apply them after the
      // user exists. Re-read the list to find the new id.
      if (form.value.permissions.length) {
        const fresh = await listUsers()
        const match = fresh.find((u) => u.email === form.value.email.trim())
        if (match) await assignPermissions(match.id, form.value.permissions)
      }

      toast.add({
        severity: 'success',
        summary: 'User created',
        detail: created?.message || `${form.value.name} added as ${form.value.role.name}.`,
        life: 5000,
      })
    }

    dialogOpen.value = false
    await loadAll()
  } catch (err) {
    formError.value = friendlyMessage(err)
  } finally {
    saving.value = false
  }
}

async function confirmDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await deleteUser(deleteTarget.value.id)
    toast.add({
      severity: 'success',
      summary: 'User deleted',
      detail: `${deleteTarget.value.name} was removed.`,
      life: 5000,
    })
    deleteTarget.value = null
    await loadAll()
  } catch (err) {
    alertError(err, 'Could not delete user')
  } finally {
    deleting.value = false
  }
}

// Deleting yourself would log you out of an account you may not be able to get
// back into, so the action is blocked for the signed-in user.
function isSelf(user) {
  return currentUser.value?.id === user.id
}
</script>

<template>
  <motion.div
    :initial="{ opacity: 0, y: 16 }"
    :animate="{ opacity: 1, y: 0 }"
    :transition="{ duration: 0.45, ease: 'easeOut' }"
  >
    <div class="mb-5">
      <h1 class="page-title">Users, Roles &amp; Permissions</h1>
      <p class="page-subtitle">Manage portal accounts, their role and any extra permissions</p>
    </div>

    <motion.div
      class="card"
      :initial="{ opacity: 0, y: 20 }"
      :animate="{ opacity: 1, y: 0 }"
      :transition="{ duration: 0.45, delay: 0.1, ease: 'easeOut' }"
    >
      <div class="mb-4 flex flex-wrap gap-3">
        <IconField class="min-w-60 flex-1">
          <InputIcon>
            <Search :size="16" />
          </InputIcon>
          <InputText v-model="filter" placeholder="Search by name, email or role..." class="w-full" />
        </IconField>
        <Button @click="openCreate">
          <Plus :size="16" />
          <span class="ml-2">Add User</span>
        </Button>
      </div>

      <DataTable :value="visibleUsers" :loading="loading" showGridlines>
        <Column header="Name">
          <template #body="{ data }">
            <span class="font-medium text-[#16233c]">{{ data.name }}</span>
            <span v-if="isSelf(data)" class="ml-2 text-[11px] text-slate-400">(you)</span>
          </template>
        </Column>
        <Column header="Email">
          <template #body="{ data }">{{ data.email }}</template>
        </Column>
        <Column header="Role">
          <template #body="{ data }">
            <Tag v-if="roleNameOf(data)" :value="roleNameOf(data)" severity="info" />
            <span v-else class="text-slate-300">— none —</span>
          </template>
        </Column>
        <Column header="Permissions">
          <template #body="{ data }">
            <span class="text-[12.5px] text-slate-600">
              {{ rolePermissionCount(data) }} from role
              <span v-if="data.permissions?.length" class="font-semibold text-brand">
                · +{{ data.permissions.length }} direct
              </span>
            </span>
          </template>
        </Column>
        <Column header="Actions" style="width: 8rem">
          <template #body="{ data }">
            <div class="flex items-center gap-1">
              <Button severity="secondary" text size="small" @click="openEdit(data)" aria-label="Edit">
                <Pencil :size="16" />
              </Button>
              <Button
                severity="danger"
                text
                size="small"
                :disabled="isSelf(data)"
                :title="isSelf(data) ? 'You cannot delete your own account' : 'Delete user'"
                @click="deleteTarget = data"
                aria-label="Delete"
              >
                <Trash2 :size="16" />
              </Button>
            </div>
          </template>
        </Column>

        <template #empty>
          <div class="py-6 text-center text-slate-400">No users found</div>
        </template>
      </DataTable>
    </motion.div>

    <!-- Create / edit -->
    <Dialog
      v-model:visible="dialogOpen"
      modal
      :header="editing ? 'Edit User' : 'Add User'"
      :style="{ width: '32rem' }"
    >
      <div class="mb-4">
        <label class="field-label">Name <span class="req">*</span></label>
        <InputText v-model="form.name" class="w-full" placeholder="Full name" />
      </div>

      <div class="mb-4">
        <label class="field-label">Email <span class="req">*</span></label>
        <InputText v-model="form.email" type="email" class="w-full" placeholder="name@acibd.com" />
      </div>

      <div v-if="!editing" class="mb-4">
        <label class="field-label">Password <span class="req">*</span></label>
        <InputText v-model="form.password" type="password" class="w-full" placeholder="••••••••" />
      </div>

      <div class="mb-4">
        <label class="field-label">Role <span class="req">*</span></label>
        <Select
          v-model="form.role"
          :options="roles"
          optionLabel="name"
          placeholder="— Select Role —"
          class="w-full"
        />
        <p class="mt-1.5 text-[12px] text-slate-400">
          The role grants a set of permissions. Add extras below only if this person needs more.
        </p>
      </div>

      <div class="mb-2">
        <label class="field-label">Extra Permissions</label>
        <MultiSelect
          v-model="form.permissions"
          :options="permissions"
          optionLabel="name"
          optionValue="name"
          display="chip"
          filter
          placeholder="— None —"
          class="w-full"
        />
      </div>

      <p v-if="formError" class="mt-3 text-[13px] font-medium text-red-500">{{ formError }}</p>

      <template #footer>
        <Button label="Cancel" severity="secondary" text @click="dialogOpen = false" />
        <Button :label="editing ? 'Save Changes' : 'Create User'" :loading="saving" @click="save" />
      </template>
    </Dialog>

    <!-- Delete confirmation -->
    <Dialog
      :visible="Boolean(deleteTarget)"
      modal
      header="Delete User"
      :style="{ width: '26rem' }"
      @update:visible="deleteTarget = null"
    >
      <div class="flex items-start gap-3">
        <span class="mt-0.5 text-red-500"><ShieldCheck :size="20" /></span>
        <p class="text-[13.5px] text-slate-600">
          Delete <b>{{ deleteTarget?.name }}</b> ({{ deleteTarget?.email }})? They will lose access
          to the portal immediately. This cannot be undone.
        </p>
      </div>
      <template #footer>
        <Button label="Cancel" severity="secondary" text @click="deleteTarget = null" />
        <Button label="Delete" severity="danger" :loading="deleting" @click="confirmDelete" />
      </template>
    </Dialog>
  </motion.div>
</template>
