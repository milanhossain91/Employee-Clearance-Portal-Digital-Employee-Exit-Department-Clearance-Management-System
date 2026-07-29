<script setup>
import { ref, computed, onMounted } from 'vue'
import { motion } from 'motion-v'
import { useToast } from 'primevue/usetoast'
import { Upload, Search, AlertTriangle } from '@lucide/vue'
import Select from 'primevue/select'
import Checkbox from 'primevue/checkbox'
import InputText from 'primevue/inputtext'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import Button from 'primevue/button'
import {
  listFormTypes,
  getFormType,
  addDepartmentByName,
  saveConfiguration,
  importDepartmentsExcel,
} from '../services/formTypes'
import { friendlyMessage } from '../services/http'

const toast = useToast()

const formTypeOptions = ref([])
const formType = ref(null)
const loadingTypes = ref(true)
const typesError = ref('')

const loadingDetail = ref(false)
const detailError = ref('')
const loaded = ref(false)

// Every active department, attached to this form type or not. `selectedIds`
// holds the ones that belong to the form type — all of them mandatory.
const allDepartments = ref([])
const selectedIds = ref([])
const filter = ref('')

const newDeptName = ref('')
const addingDept = ref(false)

const saving = ref(false)
const importing = ref(false)
const fileInput = ref(null)

function alertError(err, summary) {
  toast.add({ severity: 'error', summary, detail: friendlyMessage(err), life: 6000 })
}

async function loadFormTypes() {
  loadingTypes.value = true
  typesError.value = ''
  try {
    const data = await listFormTypes()
    formTypeOptions.value = data.form_types || []
  } catch (err) {
    typesError.value = friendlyMessage(err)
  } finally {
    loadingTypes.value = false
  }
}

onMounted(loadFormTypes)

async function loadDetail() {
  if (!formType.value) {
    loaded.value = false
    return
  }
  loadingDetail.value = true
  detailError.value = ''
  try {
    const data = await getFormType(formType.value.form_type_id)

    // Attached rows carry the pivot's `department_id`; `available_departments`
    // are plain department rows keyed on `id`. Normalise to one shape.
    const attached = data.form_type?.departments || []
    const available = data.available_departments || []

    allDepartments.value = [
      ...attached.map((d) => ({ department_id: d.department_id, name: d.name })),
      ...available.map((d) => ({ department_id: d.id, name: d.name })),
    ].sort((a, b) => String(a.name).localeCompare(String(b.name)))

    // Anything already on the form type starts ticked, whether it was stored as
    // mandatory or optional — this screen now treats every attachment as
    // mandatory, and Save Configuration rewrites them that way.
    selectedIds.value = attached.map((d) => d.department_id)
    loaded.value = true
  } catch (err) {
    detailError.value = friendlyMessage(err)
    loaded.value = false
  } finally {
    loadingDetail.value = false
  }
}

function onFormTypeChange() {
  filter.value = ''
  loadDetail()
}

const visibleDepartments = computed(() => {
  const term = filter.value.trim().toLowerCase()
  if (!term) return allDepartments.value
  return allDepartments.value.filter((d) => String(d.name).toLowerCase().includes(term))
})

const selectedCount = computed(() => selectedIds.value.length)

function selectAllVisible() {
  const merged = new Set(selectedIds.value)
  visibleDepartments.value.forEach((d) => merged.add(d.department_id))
  selectedIds.value = [...merged]
}

function clearAllVisible() {
  const visible = new Set(visibleDepartments.value.map((d) => d.department_id))
  selectedIds.value = selectedIds.value.filter((id) => !visible.has(id))
}

// Creates the department if the name is new and attaches it to this form type.
// Reloading picks it up as attached, so it comes back already ticked.
async function addDepartment() {
  const name = newDeptName.value.trim()
  if (!name || !formType.value) return
  addingDept.value = true
  try {
    await addDepartmentByName(formType.value.form_type_id, name, true)
    newDeptName.value = ''
    await loadDetail()
    toast.add({
      severity: 'success',
      summary: 'Department added',
      detail: `"${name}" is now mandatory for ${formType.value.name}.`,
      life: 4000,
    })
  } catch (err) {
    alertError(err, 'Could not add department')
  } finally {
    addingDept.value = false
  }
}

async function saveCurrentConfiguration() {
  if (!formType.value) return
  saving.value = true
  try {
    const departments = selectedIds.value.map((id) => ({
      department_id: id,
      is_mandatory: true,
    }))
    await saveConfiguration(formType.value.form_type_id, departments)
    await loadDetail()
    toast.add({
      severity: 'success',
      summary: 'Configuration saved',
      detail: departments.length
        ? `${departments.length} mandatory department${departments.length === 1 ? '' : 's'} saved for ${formType.value.name}.`
        : `All departments removed from ${formType.value.name}.`,
      life: 5000,
    })
  } catch (err) {
    alertError(err, 'Could not save configuration')
  } finally {
    saving.value = false
  }
}

function pickFile() {
  fileInput.value?.click()
}

async function onFileSelected(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file || !formType.value) return
  importing.value = true
  try {
    const data = await importDepartmentsExcel(file, {
      formTypeId: formType.value.form_type_id,
      isMandatory: true,
    })
    const s = data.summary || {}
    await loadDetail()
    toast.add({
      severity: 'success',
      summary: 'Import completed',
      detail: `${s.rows_read ?? 0} rows read · ${s.created ?? 0} created · ${s.already_existing ?? 0} already existing · ${s.attached_to_form ?? 0} attached.`,
      life: 6000,
    })
  } catch (err) {
    alertError(err, 'Import failed')
  } finally {
    importing.value = false
  }
}
</script>

<template>
  <motion.div
    :initial="{ opacity: 0, y: 16 }"
    :animate="{ opacity: 1, y: 0 }"
    :transition="{ duration: 0.45, ease: 'easeOut' }"
  >
    <div class="mb-5">
      <h1 class="page-title">Add Form Type</h1>
      <p class="page-subtitle">Select the mandatory departments for each clearance form type</p>
    </div>

    <motion.div
      class="card"
      :initial="{ opacity: 0, y: 20 }"
      :animate="{ opacity: 1, y: 0 }"
      :transition="{ duration: 0.45, delay: 0.1, ease: 'easeOut' }"
    >
      <div
        v-if="typesError"
        class="mb-4.5 flex items-center gap-2 rounded-lg bg-red-50 px-4 py-3 text-[13px] font-medium text-red-600"
      >
        <AlertTriangle :size="16" />
        {{ typesError }}
      </div>

      <div>
        <label class="field-label">Select Form Type <span class="req">*</span></label>
        <Select
          v-model="formType"
          :options="formTypeOptions"
          optionLabel="name"
          :loading="loadingTypes"
          placeholder="— Select Form Type —"
          class="w-full"
          @change="onFormTypeChange"
        />
      </div>

      <p v-if="detailError" class="mt-4 flex items-center gap-2 text-[13px] font-medium text-red-500">
        <AlertTriangle :size="15" />
        {{ detailError }}
      </p>

      <template v-if="loaded">
        <div class="mt-6 mb-3 flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-2 text-xs font-bold tracking-wider text-red-600 uppercase">
            <span class="h-2 w-2 rounded-full bg-red-600" />
            Mandatory Departments
            <span class="ml-1 rounded-full bg-red-50 px-2 py-0.5 text-[11px] font-bold text-red-600">
              {{ selectedCount }} selected
            </span>
          </div>
          <div class="flex items-center gap-2">
            <Button label="Select All" size="small" severity="secondary" text @click="selectAllVisible" />
            <Button label="Clear" size="small" severity="secondary" text @click="clearAllVisible" />
          </div>
        </div>

        <IconField class="mb-3 w-full">
          <InputIcon>
            <Search :size="15" />
          </InputIcon>
          <InputText v-model="filter" placeholder="Filter departments..." class="w-full" />
        </IconField>

        <div
          class="max-h-96 overflow-y-auto rounded-[10px] border border-slate-200 p-1.5"
          :class="loadingDetail ? 'opacity-50' : ''"
        >
          <label
            v-for="dept in visibleDepartments"
            :key="dept.department_id"
            class="flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2.5 transition-colors hover:bg-slate-50"
          >
            <Checkbox v-model="selectedIds" :value="dept.department_id" />
            <span
              class="text-sm font-medium"
              :class="selectedIds.includes(dept.department_id) ? 'text-red-600' : 'text-slate-700'"
            >
              {{ dept.name }}
              <span v-if="selectedIds.includes(dept.department_id)" class="req">*</span>
            </span>
          </label>

          <p v-if="!visibleDepartments.length" class="px-3 py-6 text-center text-[13px] text-slate-400">
            {{ filter ? 'No department matches that filter.' : 'No departments yet — add one below.' }}
          </p>
        </div>

        <h3 class="mt-6 mb-3 text-[15px] font-semibold text-[#16233c]">Add New Department</h3>
        <div class="flex flex-wrap items-center gap-3">
          <InputText
            v-model="newDeptName"
            placeholder="Department name..."
            class="min-w-50 flex-1"
            @keyup.enter="addDepartment"
          />
          <Button label="Add" severity="secondary" :loading="addingDept" @click="addDepartment" />
        </div>
        <p class="mt-2 text-[12.5px] text-slate-400">
          Added departments are attached to this form type as mandatory straight away.
        </p>

        <input ref="fileInput" type="file" accept=".xlsx,.csv" class="hidden" @change="onFileSelected" />
        <div
          class="my-5 flex cursor-pointer items-center gap-3.5 rounded-[10px] border-2 border-dashed border-slate-300 px-5 py-4 transition-colors hover:border-brand hover:bg-blue-50/40"
          @click="pickFile"
        >
          <span
            class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-slate-100 text-slate-500"
          >
            <Upload :size="18" />
          </span>
          <div>
            <h4 class="text-sm font-semibold text-slate-700">
              {{ importing ? 'Uploading…' : 'Upload Excel for Bulk Import' }}
            </h4>
            <p class="mt-0.5 text-[12.5px] text-slate-400">
              Accepts .xlsx and .csv — one department per row, all imported as mandatory
            </p>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-4">
          <Button label="Save Configuration" :loading="saving" @click="saveCurrentConfiguration" />
          <span class="text-[12.5px] text-slate-400">
            Saves the ticked departments as this form type's mandatory list.
          </span>
        </div>
      </template>
    </motion.div>
  </motion.div>
</template>
