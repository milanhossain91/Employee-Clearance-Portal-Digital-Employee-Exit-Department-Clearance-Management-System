<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { motion } from 'motion-v'
import { User, Lock, Eye, EyeOff, CheckCircle2, ShieldCheck, Clock } from '@lucide/vue'
import InputText from 'primevue/inputtext'
import Button from 'primevue/button'
import { useAuth } from '../composables/auth'
import { friendlyMessage } from '../services/http'
import logoUrl from '../assets/logo.png'

const router = useRouter()
const { login } = useAuth()

const email = ref('')
const password = ref('')
const showPassword = ref(false)
const error = ref('')
const loading = ref(false)

async function submit() {
  if (!email.value.trim() || !password.value) {
    error.value = 'Please enter your email and password'
    return
  }
  error.value = ''
  loading.value = true
  try {
    await login(email.value.trim(), password.value)
    // the router guard forwards this to whichever screen the permissions allow
    router.push('/')
  } catch (err) {
    error.value = friendlyMessage(err)
  } finally {
    loading.value = false
  }
}

const deptStatus = [
  { name: 'Corporate Admin', done: true },
  { name: 'People Team', done: true },
  { name: 'MIS', done: false },
]
</script>

<template>
  <div class="min-h-screen bg-white">
    <motion.div
      class="grid min-h-screen w-full lg:grid-cols-2"
      :initial="{ opacity: 0, y: 20 }"
      :animate="{ opacity: 1, y: 0 }"
      :transition="{ duration: 0.55, ease: 'easeOut' }"
    >
      <!-- Left: form -->
      <div class="flex min-h-screen flex-col p-7 sm:p-10">
        <motion.div
          class="flex w-fit items-center gap-2.5 rounded-full border border-slate-200 py-1.5 pr-4 pl-1.5"
          :initial="{ opacity: 0, y: -10 }"
          :animate="{ opacity: 1, y: 0 }"
          :transition="{ duration: 0.4, delay: 0.15 }"
        >
          <img :src="logoUrl" alt="ACI logo" class="h-8 w-8 rounded-full object-contain" />
          <span class="text-sm font-bold text-[#16233c]">ACI Group</span>
        </motion.div>

        <form class="mx-auto my-auto w-full max-w-sm py-10" @submit.prevent="submit">
          <motion.div
            :initial="{ opacity: 0, y: 14 }"
            :animate="{ opacity: 1, y: 0 }"
            :transition="{ duration: 0.45, delay: 0.2 }"
          >
            <h1 class="text-center text-3xl font-bold tracking-tight text-[#16233c]">
              Welcome Back
            </h1>
            <p class="mt-2 text-center text-sm text-slate-400">
              Sign in to the HR Clearance Portal
            </p>
          </motion.div>

          <motion.div
            class="mt-9"
            :initial="{ opacity: 0, y: 14 }"
            :animate="{ opacity: 1, y: 0 }"
            :transition="{ duration: 0.45, delay: 0.3 }"
          >
            <label class="field-label" for="email">Email</label>
            <div class="relative">
              <User
                :size="16"
                class="pointer-events-none absolute top-1/2 left-4.5 -translate-y-1/2 text-slate-400"
              />
              <InputText
                id="email"
                v-model="email"
                type="email"
                placeholder="you@acibd.com"
                class="w-full rounded-full pl-11"
                autocomplete="username"
                @keyup.enter="submit"
              />
            </div>
          </motion.div>

          <motion.div
            class="mt-4.5"
            :initial="{ opacity: 0, y: 14 }"
            :animate="{ opacity: 1, y: 0 }"
            :transition="{ duration: 0.45, delay: 0.38 }"
          >
            <label class="field-label" for="password">Password</label>
            <div class="relative">
              <Lock
                :size="16"
                class="pointer-events-none absolute top-1/2 left-4.5 -translate-y-1/2 text-slate-400"
              />
              <InputText
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                placeholder="••••••••••••"
                class="w-full rounded-full pr-12 pl-11"
                autocomplete="current-password"
                @keyup.enter="submit"
              />
              <button
                type="button"
                class="absolute top-1/2 right-4 -translate-y-1/2 cursor-pointer text-slate-400 hover:text-slate-600"
                @click="showPassword = !showPassword"
                :aria-label="showPassword ? 'Hide password' : 'Show password'"
              >
                <component :is="showPassword ? EyeOff : Eye" :size="17" />
              </button>
            </div>
          </motion.div>

          <motion.p
            v-if="error"
            class="mt-3 text-center text-[13px] text-red-500"
            :initial="{ opacity: 0 }"
            :animate="{ opacity: 1 }"
          >
            {{ error }}
          </motion.p>

          <motion.div
            class="mt-7"
            :initial="{ opacity: 0, y: 14 }"
            :animate="{ opacity: 1, y: 0 }"
            :transition="{ duration: 0.45, delay: 0.46 }"
          >
            <Button
              type="submit"
              label="Sign In"
              class="w-full rounded-full py-3"
              :loading="loading"
            />
            <p class="mt-5 text-center text-xs text-slate-400">
              Forgot password?
              <a href="#" class="font-semibold text-brand hover:underline">Contact MIS Support</a>
            </p>
          </motion.div>
        </form>

        <div class="flex items-center justify-between text-xs text-slate-400">
          <span>v2.4.1 · 2026</span>
          <span class="flex items-center gap-1.5">
            <ShieldCheck :size="14" />
            Authorized personnel only
          </span>
        </div>
      </div>

      <!-- Right: visual panel -->
      <div class="relative m-4 hidden overflow-hidden rounded-3xl lg:block">
        <img
          src="https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1200&q=80"
          alt=""
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div class="absolute inset-0 bg-linear-to-t from-navy/80 via-navy/30 to-navy/20" />

        <!-- floating: exit interview -->
        <motion.div
          class="float-slow absolute top-8 left-8 rounded-2xl bg-amber-300/95 px-5 py-4 shadow-lg backdrop-blur"
          :initial="{ opacity: 0, y: -16 }"
          :animate="{ opacity: 1, y: 0 }"
          :transition="{ duration: 0.5, delay: 0.55 }"
        >
          <p class="text-[13px] font-bold text-slate-900">Exit Interview</p>
          <p class="mt-0.5 text-[11px] font-medium text-slate-700">
            Tasnim Hossain · Today, 11:00am
          </p>
        </motion.div>

        <!-- floating: department status -->
        <motion.div
          class="float-mid absolute right-8 bottom-44 rounded-2xl bg-white/95 px-5 py-4 shadow-xl backdrop-blur"
          :initial="{ opacity: 0, y: 16 }"
          :animate="{ opacity: 1, y: 0 }"
          :transition="{ duration: 0.5, delay: 0.7 }"
        >
          <p class="text-[13px] font-bold text-slate-900">Department Status</p>
          <div class="mt-2.5 space-y-2">
            <div
              v-for="dept in deptStatus"
              :key="dept.name"
              class="flex items-center justify-between gap-6"
            >
              <span class="text-xs font-medium text-slate-600">{{ dept.name }}</span>
              <span
                class="flex items-center gap-1 text-[10.5px] font-semibold"
                :class="dept.done ? 'text-green-600' : 'text-amber-600'"
              >
                <component :is="dept.done ? CheckCircle2 : Clock" :size="13" />
                {{ dept.done ? 'Cleared' : 'Pending' }}
              </span>
            </div>
          </div>
        </motion.div>

        <!-- floating: clearance progress -->
        <motion.div
          class="float-fast absolute bottom-10 left-8 w-64 rounded-2xl bg-white/95 px-5 py-4 shadow-xl backdrop-blur"
          :initial="{ opacity: 0, y: 16 }"
          :animate="{ opacity: 1, y: 0 }"
          :transition="{ duration: 0.5, delay: 0.85 }"
        >
          <p class="text-[13px] font-bold text-slate-900">Clearance Progress</p>
          <p class="mt-0.5 text-[11px] font-medium text-slate-500">
            Imran Hossain · 5 of 7 departments cleared
          </p>
          <div class="mt-2.5 h-1.5 overflow-hidden rounded-full bg-slate-100">
            <motion.div
              class="h-full rounded-full bg-brand"
              :initial="{ width: '0%' }"
              :animate="{ width: '71%' }"
              :transition="{ duration: 0.9, delay: 1.1, ease: 'easeOut' }"
            />
          </div>
          <div class="mt-3 flex -space-x-2">
            <span
              v-for="(initials, i) in ['IH', 'FA', 'NR', 'RK']"
              :key="initials"
              class="flex h-7 w-7 items-center justify-center rounded-full border-2 border-white text-[9.5px] font-bold text-white"
              :class="['bg-brand', 'bg-indigo-500', 'bg-sky-500', 'bg-navy'][i]"
            >
              {{ initials }}
            </span>
          </div>
        </motion.div>
      </div>
    </motion.div>
  </div>
</template>

<style scoped>
@keyframes floaty {
  0%,
  100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-10px);
  }
}

.float-slow {
  animation: floaty 6s ease-in-out infinite;
}

.float-mid {
  animation: floaty 5s ease-in-out 0.8s infinite;
}

.float-fast {
  animation: floaty 4.5s ease-in-out 1.6s infinite;
}
</style>
