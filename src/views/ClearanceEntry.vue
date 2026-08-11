<script setup>
import { ref, watch, onMounted } from 'vue'
import { motion } from 'motion-v'
import { useToast } from 'primevue/usetoast'
import { CheckCircle2, AlertTriangle } from '@lucide/vue'
import Select from 'primevue/select'
import AutoComplete from 'primevue/autocomplete'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import {
  entryFormData,
  createClearance as createClearanceApi,
  searchClearance,
} from '../services/clearances'
import { selectEmployer } from '../services/staff'
import { friendlyMessage } from '../services/http'

const toast = useToast()

// Transient outcomes — a lookup that found nothing, a failed insert — are
// announced as pop-ups. Only the standing staff warning stays inline, because
// it describes the currently selected employee rather than a one-off event.
function notify(severity, summary, detail, life = 5000) {
  toast.add({ severity, summary, detail, life })
}

const businesses = ref([])
const formTypes = ref([])
const loadingOptions = ref(true)
const optionsError = ref('')

const business = ref(null)
const staffId = ref('')
const formType = ref(null)
const hrsReceivingDate = ref(null)
const resignDate = ref(null)

// AutoComplete binds free text while typing and the picked row once chosen.
const employerOptions = ref([])
const staffInfo = ref(null)
const staffWarning = ref('')
const staffBlocked = ref(false)
const searching = ref(false)

const creating = ref(false)
const created = ref(false)

function formatDate(date) {
  if (!date) return null
  const d = date instanceof Date ? date : new Date(date)
  const yyyy = d.getFullYear()
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  return `${yyyy}-${mm}-${dd}`
}

async function loadOptions() {
  loadingOptions.value = true
  optionsError.value = ''
  try {
    const data = await entryFormData()
    businesses.value = data.businesses || []
    formTypes.value = data.form_types || []
  } catch (err) {
    optionsError.value = friendlyMessage(err)
    notify('error', 'Could not load form options', friendlyMessage(err), 6000)
  } finally {
    loadingOptions.value = false
  }
}

onMounted(loadOptions)

// Type-ahead over PIMS. AutoComplete already debounces via `:delay`, so this
// only guards the empty term the endpoint would reject.
async function searchEmployers({ query }) {
  const term = (query || '').trim()
  if (!term) {
    employerOptions.value = []
    return
  }
  searching.value = true
  try {
    employerOptions.value = await selectEmployer(term)
    if (!employerOptions.value.length) {
      notify('warn', 'No match found', `No employee in PIMS matches "${term}".`)
    }
  } catch (err) {
    employerOptions.value = []
    notify('error', 'Employee lookup failed', friendlyMessage(err), 6000)
  } finally {
    searching.value = false
  }
}

// Serial order of the read-only employee panel.
const employeeFields = [
  { label: 'Staff Name', key: 'name' },
  { label: 'Business', key: 'business' },
  { label: 'Designation', key: 'designation' },
  { label: 'Department', key: 'department' },
  { label: 'Joining Date', key: 'joiningDate' },
]

function employerLabel(row) {
  return row ? `${row.EmpCode} - ${row.Name}` : ''
}

// PIMS sends JoiningDate as dd-mm-yyyy (SQL Server CONVERT style 105), which is
// display-ready — it is shown, never posted.
async function onEmployerSelected({ value }) {
  staffWarning.value = ''
  staffBlocked.value = false
  staffInfo.value = {
    empCode: value.EmpCode,
    name: value.Name || '—',
    // PIMS resolves the business through the employee's department. Contractual
    // staff sit in `contEmpHist`, which has no department master to join to, so
    // it comes back null for them.
    business: value.BusinessName || '—',
    designation: value.DesgName || '—',
    department: value.DeptName || value.DeptCode || '—',
    joiningDate: value.JoiningDate || '—',
  }
  await checkExistingClearance(value.EmpCode)
}

function clearStaff() {
  staffInfo.value = null
  staffWarning.value = ''
  staffBlocked.value = false
}

// Typing after a selection puts a plain string back into the model. Drop the
// resolved employee then, so edited text can never submit under the previously
// picked EmpCode.
watch(staffId, (value) => {
  if (typeof value === 'string' && staffInfo.value) clearStaff()
})

// `/clearances/search` 404s when the employee has no clearance at all — that is
// the normal path for a new entry, so a miss is not an error worth surfacing.
async function checkExistingClearance(empCode) {
  try {
    const data = await searchClearance(empCode)
    const existing = data.clearance
    if (!existing) return
    if (existing.status !== 'cleared') {
      staffBlocked.value = true
      staffWarning.value = `This employee already has an open clearance (#${existing.id}) — status: ${existing.status}.`
    } else {
      staffWarning.value = 'This employee has a previous clearance, already cleared.'
    }
  } catch {
    // no prior clearance — nothing to warn about
  }
}

// Mirrors the `required` rules in ClearanceController::store, but names the
// field that is actually missing — "Staff ID" is the usual culprit, because it
// only counts as filled once Search has resolved it to a numeric employee key.
function missingFields() {
  const missing = []
  if (!business.value) missing.push('Business Name')
  if (!staffInfo.value) {
    missing.push(
      typeof staffId.value === 'string' && staffId.value.trim()
        ? 'Staff ID (pick an employee from the list)'
        : 'Staff ID'
    )
  }
  if (!formType.value) missing.push('Form Type')
  if (!hrsReceivingDate.value) missing.push('HRS Receiving Date')
  if (!resignDate.value) missing.push('Resignation Effective Date')
  return missing
}

async function submitClearance() {

  const missing = missingFields()
  if (missing.length) {
    notify('warn', 'Clearance not created', `Please fill in: ${missing.join(', ')}.`, 6000)
    return
  }
  if (staffBlocked.value) {
    notify('warn', 'Clearance not created', staffWarning.value, 6000)
    return
  }
  creating.value = true
  created.value = false
  try {
    await createClearanceApi({
      business_id: business.value.id,
      // Sent verbatim — `clearances.staff_id` is varchar(50), so zero-padded
      // ("00133") and contractual ("C00001") EmpCodes must keep their exact
      // PIMS form to stay joinable back to the employee master.
      staff_id: staffInfo.value.empCode,
      form_type_id: formType.value.form_type_id,
      hrs_receiving_date: formatDate(hrsReceivingDate.value),
      resign_date: formatDate(resignDate.value),
      // omitted on purpose — the backend defaults it to the server's today
    })
    const staffLabel = `${staffInfo.value.empCode} - ${staffInfo.value.name}`
    created.value = true
    business.value = null
    staffId.value = ''
    formType.value = null
    hrsReceivingDate.value = null
    resignDate.value = null
    employerOptions.value = []
    clearStaff()
    notify('success', 'Clearance created', `Clearance opened for ${staffLabel}.`)
  } catch (err) {
    // Covers the API's own refusals too — a form type with no departments, or
    // an employee whose previous clearance is still open. Nothing was inserted.
    notify('error', 'Clearance not created', friendlyMessage(err), 7000)
  } finally {
    creating.value = false
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
      <h1 class="page-title">Clearance Entry</h1>
      <p class="page-subtitle">Initiate a new employee exit clearance</p>
    </div>

    <motion.div
      class="card"
      :initial="{ opacity: 0, y: 20 }"
      :animate="{ opacity: 1, y: 0 }"
      :transition="{ duration: 0.45, delay: 0.1, ease: 'easeOut' }"
    >
      <div v-if="optionsError" class="mb-4.5 flex items-center gap-2 rounded-lg bg-red-50 px-4 py-3 text-[13px] font-medium text-red-600">
        <AlertTriangle :size="16" />
        {{ optionsError }}
      </div>

      <div class="mb-4.5">
        <label class="field-label">Select Business Name <span class="req">*</span></label>
        <Select
          v-model="business"
          :options="businesses"
          optionLabel="name"
          :loading="loadingOptions"
          placeholder="— Select Business Unit —"
          class="w-full"
        />
      </div>

      <div class="mb-4.5">
        <label class="field-label">Staff ID <span class="req">*</span></label>
        <AutoComplete
          v-model="staffId"
          :suggestions="employerOptions"
          :optionLabel="employerLabel"
          :delay="300"
          :minLength="1"
          :loading="searching"
          placeholder="Start typing an Employee Code — e.g. 001"
          class="w-full"
          inputClass="w-full"
          @complete="searchEmployers"
          @item-select="onEmployerSelected"
          @clear="clearStaff"
        >
          <template #option="{ option }">
            <div class="flex flex-col">
              <span class="text-sm font-semibold text-[#16233c]">
                {{ option.EmpCode }} - {{ option.Name }}
              </span>
              <span class="text-[11.5px] text-slate-400">
                {{ option.DesgName || '—' }} · Joined {{ option.JoiningDate || '—' }}
              </span>
            </div>
          </template>
          <template #empty>
            <span class="px-3 py-2 text-[13px] text-slate-400">No employee found</span>
          </template>
        </AutoComplete>
      </div>

      <!-- Order fixed by the form: name, business, designation, department,
           joining date. All read-only — they come from PIMS, not the operator. -->
      <div v-for="field in employeeFields" :key="field.key" class="mb-4.5">
        <label class="readonly-label">{{ field.label }}</label>
        <div class="readonly-value">{{ staffInfo?.[field.key] || '' }}</div>
      </div>

      <p
        v-if="staffWarning"
        class="mb-4.5 flex items-center gap-2 rounded-lg px-4 py-3 text-[13px] font-medium"
        :class="staffBlocked ? 'bg-red-50 text-red-600' : 'bg-amber-50 text-amber-700'"
      >
        <AlertTriangle :size="16" />
        {{ staffWarning }}
      </p>

      <div class="mb-4.5">
        <label class="field-label">Select Form Type <span class="req">*</span></label>
        <Select
          v-model="formType"
          :options="formTypes"
          optionLabel="name"
          :loading="loadingOptions"
          placeholder="— Select Form Type —"
          class="w-full"
        />
      </div>

      <div class="mb-5 grid grid-cols-1 gap-4.5 md:grid-cols-2">
        <div>
          <label class="field-label">HRS Receiving Date <span class="req">*</span></label>
          <DatePicker
            v-model="hrsReceivingDate"
            dateFormat="mm/dd/yy"
            placeholder="mm/dd/yyyy"
            showIcon
            iconDisplay="input"
            class="w-full"
          />
        </div>
        <div>
          <label class="field-label">Resignation Effective Date <span class="req">*</span></label>
          <DatePicker
            v-model="resignDate"
            dateFormat="mm/dd/yy"
            placeholder="mm/dd/yyyy"
            showIcon
            iconDisplay="input"
            class="w-full"
          />
        </div>
      </div>


      <div class="flex flex-wrap items-center gap-4">
        <Button label="Create Clearance" :loading="creating" @click="submitClearance" />
        <motion.span
          v-if="created"
          class="success-inline"
          :initial="{ opacity: 0, x: -8 }"
          :animate="{ opacity: 1, x: 0 }"
          :transition="{ duration: 0.3 }"
        >
          <CheckCircle2 :size="18" />
          Clearance created successfully
        </motion.span>
      </div>
    </motion.div>
  </motion.div>
</template>
