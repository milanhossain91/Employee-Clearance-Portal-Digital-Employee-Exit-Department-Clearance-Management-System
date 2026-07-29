<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Menu, LogOut, ChevronDown } from '@lucide/vue'
import { useAuth } from '../composables/auth'

defineEmits(['toggle-sidebar'])

const router = useRouter()
const { user, logout } = useAuth()
const menuOpen = ref(false)

const displayName = computed(() => user.value?.name || 'User')
const roleLabel = computed(() => user.value?.roles?.[0]?.name || user.value?.roles?.[0] || '')
const initials = computed(() =>
  displayName.value
    .split(' ')
    .map((part) => part[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
)

async function handleLogout() {
  menuOpen.value = false
  await logout()
  router.push('/login')
}

const now = new Date()
const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]
const dateLabel = `${days[now.getDay()]}, ${now.getDate()} ${months[now.getMonth()]} ${now.getFullYear()}`
</script>

<template>
  <header
    class="sticky top-0 z-40 flex h-16 items-center justify-between border-b border-slate-200 bg-white px-4 sm:px-6"
  >
    <button
      class="cursor-pointer rounded-lg p-1.5 text-slate-700 hover:bg-slate-100 lg:hidden"
      @click="$emit('toggle-sidebar')"
      aria-label="Toggle menu"
    >
      <Menu :size="22" />
    </button>

    <div class="relative ml-auto">
      <button
        class="flex cursor-pointer items-center gap-3 rounded-full py-1 pr-1.5 pl-3 transition-colors hover:bg-slate-100"
        @click="menuOpen = !menuOpen"
        aria-label="User menu"
      >
        <div class="flex flex-col items-end leading-snug">
          <strong class="text-sm font-bold text-[#16233c]">{{ displayName }}</strong>
          <span class="hidden text-xs text-slate-400 sm:block">{{ dateLabel }}</span>
        </div>
        <div
          class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand text-[13px] font-bold text-white"
        >
          {{ initials }}
        </div>
        <ChevronDown
          :size="15"
          class="mr-1 text-slate-400 transition-transform"
          :class="{ 'rotate-180': menuOpen }"
        />
      </button>

      <div v-if="menuOpen" class="fixed inset-0" @click="menuOpen = false" />

      <Transition
        enter-active-class="transition duration-150 ease-out"
        leave-active-class="transition duration-100 ease-in"
        enter-from-class="scale-95 opacity-0"
        leave-to-class="scale-95 opacity-0"
      >
        <div
          v-if="menuOpen"
          class="absolute top-full right-0 mt-2 w-56 origin-top-right rounded-xl border border-slate-200 bg-white p-1.5 shadow-[0_10px_30px_rgba(15,23,42,0.12)]"
        >
          <div class="border-b border-slate-100 px-3 py-2.5">
            <p class="text-sm font-bold text-[#16233c]">{{ displayName }}</p>
            <p class="text-xs text-slate-400">{{ roleLabel ? `${roleLabel} · ` : '' }}ACI Group</p>
          </div>
          <button
            class="mt-1 flex w-full cursor-pointer items-center gap-2.5 rounded-lg px-3 py-2.5 text-sm font-medium text-red-600 hover:bg-red-50"
            @click="handleLogout"
          >
            <LogOut :size="16" />
            Log Out
          </button>
        </div>
      </Transition>
    </div>
  </header>
</template>
