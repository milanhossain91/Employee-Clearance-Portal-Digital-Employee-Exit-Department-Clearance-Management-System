<script setup>
import { ref, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import Toast from 'primevue/toast'
import AppSidebar from './components/AppSidebar.vue'
import AppTopbar from './components/AppTopbar.vue'

const route = useRoute()
const sidebarOpen = ref(false)
const isPublic = computed(() => Boolean(route.meta.public))

watch(() => route.path, () => {
  sidebarOpen.value = false
})
</script>

<template>
  <!-- Single mount point for the app's pop-up alerts. -->
  <Toast position="top-right" />

  <router-view v-if="isPublic" :key="route.path" />

  <div v-else class="min-h-screen">
    <AppSidebar :open="sidebarOpen" @close="sidebarOpen = false" />
    <div class="flex min-h-screen flex-col lg:ml-62.5">
      <AppTopbar @toggle-sidebar="sidebarOpen = !sidebarOpen" />
      <main class="flex-1 p-4 pb-10 sm:p-6 sm:pb-12 lg:px-7">
        <router-view v-slot="{ Component }">
          <component :is="Component" :key="route.path" />
        </router-view>
      </main>
    </div>
  </div>
</template>
