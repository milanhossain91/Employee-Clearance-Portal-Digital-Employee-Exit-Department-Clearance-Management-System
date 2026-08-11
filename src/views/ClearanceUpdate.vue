<script setup>
import { ref, reactive } from 'vue'
import { motion } from 'motion-v'
import { useToast } from 'primevue/usetoast'
import { Search, CheckCircle2 } from '@lucide/vue'
import AutoComplete from 'primevue/autocomplete'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import Textarea from 'primevue/textarea'
import SelectButton from 'primevue/selectbutton'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import {
  searchClearance,
  listClearances,
  getClearance,
  saveDepartments,
  updateHeader,
} from '../services/clearances'
import { friendlyMessage } from '../services/http'

const toast = useToast()

// Searches that match nothing and saves that do not land are announced as
// pop-ups rather than inline text, so they cannot be missed further down a long
// department grid.
function notify(severity, summary, detail, life = 5000) {
  toast.add({ severity, summary, detail, life })
}

// AutoComplete binds free text while typing and the picked clearance once chosen.
const query = ref('')
const suggestions = ref([])
const searched = ref(false)
const searching = ref(false)
const saving = ref(false)
const saved = ref(false)

const clearanceId = ref(null)
const header = reactive({
  business: '',
  staffId: '',
  staffName: '',
  resignedDate: '',
  onlineSubmission: '',
  pendingAt: '',
  status: '',
})

const employeeFields = [
  { label: 'Business', key: 'business' },
  { label: 'Staff ID', key: 'staffId' },
  { label: 'Staff Name', key: 'staffName' },
  { label: 'Resignation Effective Date', key: 'resignedDate' },
  { label: 'Online Submission', key: 'onlineSubmission' },
  { label: 'Pending At', key: 'pendingAt' },
  { label: 'Status', key: 'status' },
]

const deptState = reactive([])

// One note for the whole clearance, stored on `clearances.remarks`. Distinct
// from the per-department remarks held on each Section 2 card.
const overallRemarks = ref('')

// The API sends plain calendar dates ("2026-07-01"). `new Date(...)` would read
// those as UTC midnight, which lands on the previous day in any timezone behind
// UTC and would show — then save — a date one day earlier. Build from the parts
// so the value stays the day the server actually stored.
function parseDate(value) {
  if (!value) return null
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(value))
  if (match) {
    const [, year, month, day] = match
    return new Date(Number(year), Number(month) - 1, Number(day))
  }
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? null : d
}

function formatDate(date) {
  if (!date) return null
  const d = date instanceof Date ? date : new Date(date)
  const yyyy = d.getFullYear()
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  return `${yyyy}-${mm}-${dd}`
}

function applyClearance(clearance) {
  clearanceId.value = clearance.id
  header.business = clearance.business?.name ?? clearance.business_id ?? '—'
  // `staff` is Staff::toStaffArray() — the human readable code is `staff_code`;
  // `clearance.staff_id` is the numeric HR key and only a last resort.
  header.staffId = clearance.staff?.staff_code ?? clearance.staff_id ?? '—'
  header.staffName = clearance.staff?.name ?? clearance.staff_name ?? '—'
  header.resignedDate = clearance.resign_date ?? '—'
  header.onlineSubmission = clearance.online_submission_date ?? '—'
  header.pendingAt = clearance.pending_at?.name ?? '—'
  header.status = clearance.status ? clearance.status[0].toUpperCase() + clearance.status.slice(1) : '—'
  overallRemarks.value = clearance.remarks ?? ''

  deptState.length = 0
  for (const d of clearance.departments || []) {
    deptState.push({
      department_id: d.department_id,
      name: d.name,
      mandatory: Boolean(d.is_mandatory),
      submission: parseDate(d.submission_date),
      received: parseDate(d.received_date),
      resubmission: parseDate(d.resubmission_date),
      // Server-computed: days the form has been with this department. Read-only.
      dayCount: d.day_count,
      returned: d.is_returned ? 'Yes' : 'No',
      remarks: d.remarks ?? '',
    })
  }
}

// Live lookup over existing clearances. The register endpoint matches a partial
// staff id as well as an employee name (resolved through PIMS), which is
// exactly the "staff id and name wise" search this box needs.
async function searchClearances({ query: term }) {
  const text = (term || '').trim()
  if (!text) {
    suggestions.value = []
    return
  }
  searching.value = true
  try {
    const data = await listClearances({ search: text, per_page: 10 })
    suggestions.value = data.clearances || []
    if (!suggestions.value.length) {
      notify('warn', 'No match found', `No clearance matches "${text}".`)
    }
  } catch (err) {
    suggestions.value = []
    notify('error', 'Search failed', friendlyMessage(err), 6000)
  } finally {
    searching.value = false
  }
}

function clearanceLabel(row) {
  if (!row) return ''
  const code = row.staff?.staff_code ?? row.staff_id ?? ''
  const name = row.staff?.name
  return name ? `${code} - ${name}` : String(code)
}

// The register rows carry a trimmed department list (no mandatory flag, no
// remarks), so load the full record before filling Section 2.
async function loadClearance(id) {
  searching.value = true
  saved.value = false
  try {
    const data = await getClearance(id)
    applyClearance(data.clearance)
    searched.value = true
  } catch (err) {
    notify('error', 'Could not open clearance', friendlyMessage(err), 6000)
    searched.value = false
  } finally {
    searching.value = false
  }
}

function onClearanceSelected({ value }) {
  return loadClearance(value.id)
}

// Enter without picking a suggestion — fall back to the single-result endpoint
// so typing a full staff id and hitting Enter still works.
async function search() {
  const text = typeof query.value === 'string' ? query.value.trim() : ''
  if (!text) return
  searching.value = true
  saved.value = false
  try {
    const data = await searchClearance(text)
    applyClearance(data.clearance)
    searched.value = true
  } catch (err) {
    // The endpoint 404s when nothing matches, so this is the "no data" path
    // as much as the failure path.
    notify('warn', 'No match found', `No clearance matches "${text}".`)
    searched.value = false
  } finally {
    searching.value = false
  }
}

// The API drops `received_date` whenever a card is flagged Returned, so the two
// fields can never hold a value at the same time. Mirror that rule the moment
// the toggle moves, rather than letting a date the user picked disappear on
// save with no explanation.
function onReturnedChange(dept, value) {
  if (value === 'Yes') dept.received = null
}

// Recording a received date means the form came back in, so the card is no
// longer returned. Without this the save would wipe the date just entered.
function onReceivedChange(dept, value) {
  if (value && dept.returned === 'Yes') dept.returned = 'No'
}

// `departmentRowError()` on the API refuses a returned department that has no
// resubmission date or no remarks, and rejects the whole request on the first
// bad row. Mirror both rules here so the problem is named per department up
// front, instead of coming back one row at a time.
function returnedIssues() {
  const issues = []
  for (const d of deptState) {
    if (d.returned !== 'Yes') continue
    const missing = []
    if (!d.resubmission) missing.push('Resubmission Date')
    if (!String(d.remarks || '').trim()) missing.push('Remarks')
    if (missing.length) issues.push(`${d.name} (${missing.join(' + ')})`)
  }
  return issues
}

async function saveUpdate() {
  if (!clearanceId.value) return

  const issues = returnedIssues()
  if (issues.length) {
    notify(
      'warn',
      'Update not saved',
      `Returned departments need a Resubmission Date and Remarks — ${issues.join('; ')}.`,
      8000
    )
    return
  }

  saving.value = true
  saved.value = false
  try {
    const payload = deptState.map((d) => ({
      department_id: d.department_id,
      submission_date: formatDate(d.submission),
      received_date: formatDate(d.received),
      resubmission_date: formatDate(d.resubmission),
      is_returned: d.returned === 'Yes',
      remarks: d.remarks?.trim() || null,
    }))
    // The overall note lives on the clearance itself, so it saves through the
    // header endpoint. Do it first: the department save recalculates status and
    // returns the full record, so applying that response last leaves the form
    // showing exactly what was stored.
    await updateHeader(clearanceId.value, { remarks: overallRemarks.value.trim() || null })

    const data = await saveDepartments(clearanceId.value, payload)
    // Re-seed the form from the saved record rather than leaving local state in
    // place, so the dates on screen are exactly what the server stored and the
    // next save starts from the truth.
    applyClearance(data.clearance)
    saved.value = true
    toast.add({
      severity: 'success',
      summary: 'Clearance updated',
      detail: `Saved ${payload.length} department${payload.length === 1 ? '' : 's'} — status is now ${data.clearance?.status ?? 'updated'}.`,
      life: 5000,
    })
  } catch (err) {
    // Nothing was written — the department save runs in a transaction and the
    // API rolls it back on any error.
    notify('error', 'Update not saved', friendlyMessage(err), 7000)
  } finally {
    saving.value = false
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
      <h1 class="page-title">Clearance Update</h1>
      <p class="page-subtitle">Search a Staff ID or name to update department clearance status</p>
    </div>

    <motion.div
      class="card"
      :initial="{ opacity: 0, y: 20 }"
      :animate="{ opacity: 1, y: 0 }"
      :transition="{ duration: 0.45, delay: 0.1, ease: 'easeOut' }"
    >
      <div>
        <IconField class="w-full">
          <InputIcon>
            <Search :size="16" />
          </InputIcon>
          <AutoComplete
            v-model="query"
            :suggestions="suggestions"
            :optionLabel="clearanceLabel"
            :delay="300"
            :minLength="1"
            :loading="searching"
            placeholder="Search by Staff ID or Name..."
            class="w-full [&_input]:w-full [&_input]:pl-10"
            @complete="searchClearances"
            @item-select="onClearanceSelected"
            @keyup.enter="search"
          >
            <template #option="{ option }">
              <div class="flex flex-col">
                <span class="text-sm font-semibold text-[#16233c]">
                  {{ clearanceLabel(option) }}
                </span>
                <span class="text-[11.5px] text-slate-400">
                  {{ option.business?.name || '—' }} ·
                  {{ option.form_type?.name || '—' }} ·
                  {{ option.status }}
                </span>
              </div>
            </template>
            <template #empty>
              <span class="px-3 py-2 text-[13px] text-slate-400">No clearance found</span>
            </template>
          </AutoComplete>
        </IconField>
      </div>
    </motion.div>

    <motion.div
      v-if="!searched"
      class="px-5 py-16 text-center text-slate-500"
      :initial="{ opacity: 0 }"
      :animate="{ opacity: 1 }"
      :transition="{ duration: 0.4, delay: 0.2 }"
    >
      <div
        class="mb-4 inline-flex h-14 w-14 items-center justify-center rounded-full bg-slate-200 text-slate-400"
      >
        <Search :size="24" />
      </div>
      <h3 class="text-[15.5px] font-semibold text-slate-700">
        Search a Staff ID or name to view clearance details
      </h3>
      <p class="mt-1.5 text-[13px] text-slate-400">
        Start typing above, then pick an employee from the list
      </p>
    </motion.div>

    <template v-else>
      <motion.section
        class="card mt-5 border-l-4 border-l-brand"
        :initial="{ opacity: 0, y: 16 }"
        :animate="{ opacity: 1, y: 0 }"
        :transition="{ duration: 0.4, ease: 'easeOut' }"
      >
        <h2 class="section-title">Section 1 — Employee Information</h2>
        <div class="mt-3.5 grid grid-cols-1 gap-3.5 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7">
          <div v-for="f in employeeFields" :key="f.key">
            <label class="readonly-label">{{ f.label }}</label>
            <div class="readonly-value">{{ header[f.key] }}</div>
          </div>
        </div>
      </motion.section>

      <motion.section
        class="card mt-5"
        :initial="{ opacity: 0, y: 16 }"
        :animate="{ opacity: 1, y: 0 }"
        :transition="{ duration: 0.4, delay: 0.08, ease: 'easeOut' }"
      >
        <h2 class="section-title">Section 2 — Department Clearance Details</h2>
        <p class="mb-4 text-[13px] text-slate-400">
          Fill in clearance dates and return status for each department
        </p>

        <div class="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-4.5">
          <motion.div
            v-for="(dept, i) in deptState"
            :key="dept.department_id"
            class="rounded-[10px] border border-slate-200 bg-white p-4.5 transition-shadow hover:border-blue-200 hover:shadow-[0_4px_14px_rgba(37,99,235,0.08)]"
            :initial="{ opacity: 0, y: 18 }"
            :animate="{ opacity: 1, y: 0 }"
            :transition="{ duration: 0.35, delay: 0.05 * i, ease: 'easeOut' }"
          >
            <div class="mb-3.5 flex items-center justify-between gap-2">
              <span class="flex items-center gap-2 text-[14.5px] font-semibold text-[#16233c]">
                <span
                  class="h-2 w-2 shrink-0 rounded-full"
                  :class="dept.mandatory ? 'bg-brand' : 'bg-slate-300'"
                />
                {{ dept.name }}
              </span>
              <span
                v-if="dept.mandatory"
                class="rounded-full bg-blue-50 px-2.5 py-0.75 text-[11px] font-semibold whitespace-nowrap text-brand"
              >
                Mandatory
              </span>
            </div>

            <!-- Server-computed: days from submission to receipt, or to today
                 while still outstanding. Null until the form is submitted. -->
            <div
              v-if="dept.dayCount !== null && dept.dayCount !== undefined"
              class="mb-3 flex items-center justify-between rounded-lg bg-slate-50 px-3 py-2"
            >
              <span class="text-[12.5px] text-slate-500">Days with department</span>
              <span
                class="text-[13px] font-semibold"
                :class="dept.received ? 'text-green-600' : 'text-slate-700'"
              >
                {{ dept.dayCount }}
              </span>
            </div>

            <div class="mb-3">
              <label class="mb-1.5 block text-[12.5px] font-medium text-slate-600">
                Date of Submission
              </label>
              <DatePicker
                v-model="dept.submission"
                dateFormat="mm/dd/yy"
                placeholder="mm/dd/yyyy"
                showIcon
                iconDisplay="input"
                class="w-full"
              />
            </div>

            <div class="mb-3">
              <label class="mb-1.5 block text-[12.5px] font-medium text-slate-600">
                Date of Received
              </label>
              <DatePicker
                v-model="dept.received"
                dateFormat="mm/dd/yy"
                placeholder="mm/dd/yyyy"
                showIcon
                iconDisplay="input"
                class="w-full"
                @update:modelValue="onReceivedChange(dept, $event)"
              />
              <p v-if="dept.returned === 'Yes'" class="mt-1.5 text-[11.5px] text-amber-600">
                Marked Returned — a received date will clear that flag.
              </p>
            </div>

            <div class="mt-3.5 flex items-center justify-between">
              <span class="text-[13px] text-slate-500">Returned</span>
              <SelectButton
                v-model="dept.returned"
                :options="['No', 'Yes']"
                :allowEmpty="false"
                size="small"
                @update:modelValue="onReturnedChange(dept, $event)"
              />
            </div>

            <!-- Only meaningful once the form has come back to the employee. -->
            <template v-if="dept.returned === 'Yes'">
              <div class="mt-3.5">
                <label class="mb-1.5 block text-[12.5px] font-medium text-slate-600">
                  Date of Resubmission <span class="req">*</span>
                </label>
                <DatePicker
                  v-model="dept.resubmission"
                  dateFormat="mm/dd/yy"
                  placeholder="mm/dd/yyyy"
                  showIcon
                  iconDisplay="input"
                  class="w-full"
                  :invalid="!dept.resubmission"
                  :minDate="dept.submission || undefined"
                />
                <p v-if="!dept.resubmission" class="mt-1.5 text-[11.5px] font-medium text-red-500">
                  Required for a returned department.
                </p>
              </div>

              <div class="mt-3">
                <label class="mb-1.5 block text-[12.5px] font-medium text-slate-600">
                  Remarks <span class="req">*</span>
                </label>
                <Textarea
                  v-model="dept.remarks"
                  rows="2"
                  maxlength="255"
                  class="w-full"
                  :invalid="!String(dept.remarks || '').trim()"
                  placeholder="Why was this form returned?"
                />
                <p
                  v-if="!String(dept.remarks || '').trim()"
                  class="mt-1.5 text-[11.5px] font-medium text-red-500"
                >
                  Required for a returned department.
                </p>
              </div>
            </template>
          </motion.div>
        </div>

        <div class="mt-6">
          <label class="field-label" for="overall-remarks">Overall Remarks</label>
          <Textarea
            id="overall-remarks"
            v-model="overallRemarks"
            rows="3"
            maxlength="500"
            class="w-full"
            placeholder="A note covering the whole clearance — visible on Clearance View and in the Excel export."
          />
          <p class="mt-1.5 text-[12px] text-slate-400">
            {{ overallRemarks.length }}/500 · applies to the whole clearance, not one department.
          </p>
        </div>


        <div class="mt-5.5 flex flex-wrap items-center gap-4">
          <Button label="Save Update" :loading="saving" @click="saveUpdate" />
          <motion.span
            v-if="saved"
            class="success-inline"
            :initial="{ opacity: 0, x: -8 }"
            :animate="{ opacity: 1, x: 0 }"
            :transition="{ duration: 0.3 }"
          >
            <CheckCircle2 :size="18" />
            Clearance updated successfully
          </motion.span>
        </div>
      </motion.section>
    </template>
  </motion.div>
</template>
