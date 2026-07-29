<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { ClipboardList, RefreshCcw, Eye, Settings, Users, X } from '@lucide/vue'
import { useAuth } from '../composables/auth'
import { ADMIN_ROLES } from '../router'
import logoUrl from '../assets/logo.png'

defineProps({ open: Boolean })
defineEmits(['close'])

const route = useRoute()
const { can, hasRole } = useAuth()

// `permission` mirrors the middleware guarding each screen's endpoints in
// routes/api.php, so the nav never offers a page that answers 403.
const allGroups = [
  {
    label: 'Employee Clearance Tracking',
    items: [
      { to: '/', label: 'Clearance Entry', icon: ClipboardList, permission: 'clearance.create' },
      { to: '/update', label: 'Clearance Update', icon: RefreshCcw, permission: 'clearance.update' },
      { to: '/view', label: 'Clearance View', icon: Eye, permission: 'clearance.view' },
    ],
  },
  {
    label: 'User Management',
    items: [
      { to: '/form-type', label: 'Add Form Type', icon: Settings, permission: 'form-type.update' },
      // No `user.*` permission exists, so this entry gates on role instead.
      { to: '/users', label: 'Users & Roles', icon: Users, roles: ADMIN_ROLES },
    ],
  },
]

function allowed(item) {
  if (item.roles) return hasRole(...item.roles)
  return can(item.permission)
}

const groups = computed(() =>
  allGroups
    .map((group) => ({ ...group, items: group.items.filter(allowed) }))
    .filter((group) => group.items.length)
)
</script>

<template>
  <Transition
    enter-active-class="transition-opacity duration-200"
    leave-active-class="transition-opacity duration-200"
    enter-from-class="opacity-0"
    leave-to-class="opacity-0"
  >
    <div
      v-if="open"
      class="fixed inset-0 z-50 bg-slate-900/50 lg:hidden"
      @click="$emit('close')"
    />
  </Transition>

  <aside
    class="fixed inset-y-0 left-0 z-60 flex w-62.5 flex-col bg-linear-to-b from-navy to-navy-deep transition-transform duration-300 lg:translate-x-0"
    :class="open ? 'translate-x-0 shadow-[0_0_40px_rgba(0,0,0,0.3)]' : '-translate-x-full'"
  >
    <div class="flex min-h-16 items-center gap-3 border-b border-white/10 px-4.5 py-4">
      <img
        :src="logoUrl"
        alt="ACI logo"
        class="h-9.5 w-9.5 shrink-0 rounded-full bg-white object-contain"
      />
      <div class="flex min-w-0 flex-col leading-snug">
        <strong class="text-[15px] font-bold text-white">ACI Group</strong>
        <span class="text-xs text-[#7fa3e0]">HR Clearance Portal</span>
      </div>
      <button
        class="ml-auto cursor-pointer p-1 text-[#cbd8ef] lg:hidden"
        @click="$emit('close')"
        aria-label="Close menu"
      >
        <X :size="18" />
      </button>
    </div>

    <nav class="flex-1 overflow-y-auto px-3 py-4.5">
      <div v-for="(group, gi) in groups" :key="group.label" :class="gi > 0 ? 'mt-7' : ''">
        <div
          class="mb-2.5 px-2.5 text-[10.5px] leading-normal font-bold tracking-widest text-[#6e8fc9] uppercase"
        >
          {{ group.label }}
        </div>
        <router-link
          v-for="item in group.items"
          :key="item.to"
          :to="item.to"
          class="mb-1 flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors"
          :class="
            route.path === item.to
              ? 'bg-brand text-white shadow-[0_4px_12px_rgba(37,99,235,0.4)]'
              : 'text-[#b7c8e8] hover:bg-white/10 hover:text-white'
          "
        >
          <component :is="item.icon" :size="18" />
          <span>{{ item.label }}</span>
        </router-link>
      </div>
    </nav>

    <div class="border-t border-white/10 px-5 py-4 text-xs text-[#5f7fb8]">v2.4.1 · 2026</div>
  </aside>
</template>
