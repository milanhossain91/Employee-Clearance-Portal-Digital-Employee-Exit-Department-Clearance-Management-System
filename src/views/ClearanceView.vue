<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { motion } from 'motion-v'
import { useToast } from 'primevue/usetoast'
import { Search, Download } from '@lucide/vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import Paginator from 'primevue/paginator'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import ColumnGroup from 'primevue/columngroup'
import Row from 'primevue/row'
import { listClearances, listAllClearances } from '../services/clearances'
import { listBusinesses } from '../services/businesses'
import { listDepartments } from '../services/departments'
import { friendlyMessage } from '../services/http'
import { toCsv, downloadCsv, stampedFilename } from '../services/excel'

const ALL_BUSINESSES = { id: null, name: 'All Businesses' }
const ALL_DEPARTMENTS = { id: null, name: 'All Departments' }
const statusOptions = [
  { label: 'All Status', value: null },
  { label: 'Pending', value: 'pending' },
  { label: 'Cleared', value: 'cleared' },
  { label: 'Returned', value: 'returned' },
]

const query = ref('')
const businessOptions = ref([ALL_BUSINESSES])
const businessFilter = ref(ALL_BUSINESSES)
const departmentOptions = ref([ALL_DEPARTMENTS])
const departmentFilter = ref(ALL_DEPARTMENTS)
const statusFilter = ref(statusOptions[0])

const first = ref(0)
const rows = 10
const totalRecords = ref(0)

const rowsData = ref([])
const departmentColumns = ref([])
const counts = reactive({ cleared: 0, pending: 0, returned: 0 })

const loading = ref(false)
const exporting = ref(false)

const toast = useToast()

// Every failure surfaces as a pop-up alert carrying a sanitised message, so a
// database fault never puts SQL on the screen.
function alertError(err, summary = 'Could not load records') {
  toast.add({
    severity: 'error',
    summary,
    detail: friendlyMessage(err),
    life: 6000,
  })
}

let searchTimer = null

async function loadBusinesses() {
  try {
    const data = await listBusinesses()
    businessOptions.value = [ALL_BUSINESSES, ...(data.businesses || [])]
  } catch {
    // register still works with just the search box if this fails
  }
}

async function loadDepartments() {
  try {
    const data = await listDepartments()
    departmentOptions.value = [ALL_DEPARTMENTS, ...(data.departments || [])]
  } catch {
    // same — the other filters still work
  }
}

// The filters as the API expects them — shared by the table and the export so
// the downloaded file always matches what is on screen.
function activeFilters() {
  const params = {}
  if (query.value.trim()) params.search = query.value.trim()
  if (businessFilter.value?.id) params.business_id = businessFilter.value.id
  if (departmentFilter.value?.id) params.department_id = departmentFilter.value.id
  if (statusFilter.value?.value) params.status = statusFilter.value.value
  return params
}

// The register opens empty and only loads once something has been asked for —
// a staff id or name, a department, a business or a status.
const hasFilters = computed(() => Object.keys(activeFilters()).length > 0)

async function fetchRegister() {
  if (!hasFilters.value) {
    rowsData.value = []
    departmentColumns.value = []
    totalRecords.value = 0
    counts.cleared = 0
    counts.pending = 0
    counts.returned = 0
    return
  }
  loading.value = true
  try {
    const data = await listClearances({
      ...activeFilters(),
      page: Math.floor(first.value / rows) + 1,
      per_page: rows,
    })
    rowsData.value = data.clearances || []
    departmentColumns.value = data.department_columns || []
    counts.cleared = data.summary?.cleared ?? 0
    counts.pending = data.summary?.pending ?? 0
    counts.returned = data.summary?.returned ?? 0
    totalRecords.value = data.pagination?.total ?? rowsData.value.length
  } catch (err) {
    alertError(err)
    rowsData.value = []
    totalRecords.value = 0
  } finally {
    loading.value = false
  }
}

// `department_columns` and each row's departments come from two different
// queries, and the sqlsrv driver is not guaranteed to type both ids the same
// way — a string/number mismatch under `===` silently blanks every cell.
// Compare as strings so the match holds either way.
function departmentCell(row, columnId) {
  const key = String(columnId)
  return (row.departments || []).find((d) => String(d.department_id) === key) || null
}

// A department counts as cleared once it has been received back. Counted over
// the clearance's own department list, so it matches the cards on Clearance
// Update rather than the pivoted column set.
function clearedTally(row) {
  const departments = row.departments || []
  const cleared = departments.filter((d) => d.received_date).length
  return { cleared, total: departments.length }
}

function overallStatusLabel(row) {
  const { cleared, total } = clearedTally(row)
  return `${cleared} of ${total} department${total === 1 ? '' : 's'} cleared`
}

const EMPLOYEE_HEADERS = [
  'Sl.',
  'Clearance ID',
  'Business',
  'Form Type',
  'Staff ID',
  'Staff Name',
  'Designation',
  'Resignation Effective Date',
  'HRS Receiving Date',
  'Online Submission Date',
  'Status',
  'Pending At',
]

function employeeCells(row, index) {
  return [
    index + 1,
    row.id ?? '',
    row.business?.name ?? '',
    row.form_type?.name ?? '',
    row.staff?.staff_code ?? row.staff_id ?? '',
    row.staff?.name ?? '',
    row.staff?.designation ?? '',
    row.resign_date ?? '',
    row.hrs_receiving_date ?? '',
    row.online_submission_date ?? '',
    row.status ?? '',
    row.pending_at?.name ?? '',
  ]
}

// Exports the whole filtered register, not just the visible page, and lays the
// department columns out exactly as the table groups them: one banner row of
// department names spanning four sub-columns each, then the sub-headings.
async function exportToExcel() {
  exporting.value = true
  try {
    const data = await listAllClearances(activeFilters())
    const columns = data.department_columns.length
      ? data.department_columns
      : departmentColumns.value

    const bannerRow = [
      ...Array(EMPLOYEE_HEADERS.length).fill(''),
      ...columns.flatMap((d) => [d.name, '', '', '']),
      'Summary',
      '',
    ]
    bannerRow[0] = 'Employee Details'

    const headingRow = [
      ...EMPLOYEE_HEADERS,
      ...columns.flatMap(() => ['Submitted', 'Received', 'Returned', 'Remarks']),
      'Overall Status',
      'Overall Remarks',
    ]

    const body = data.clearances.map((row, index) => [
      ...employeeCells(row, index),
      ...columns.flatMap((d) => {
        const cell = departmentCell(row, d.id)
        return [
          cell?.submission_date ?? '',
          cell?.received_date ?? '',
          cell?.is_returned ? 'Yes' : 'No',
          cell?.remarks ?? '',
        ]
      }),
      overallStatusLabel(row),
      row.remarks ?? '',
    ])

    if (!body.length) {
      toast.add({
        severity: 'warn',
        summary: 'Nothing to export',
        detail: 'No records match the current filters.',
        life: 5000,
      })
      return
    }

    downloadCsv(stampedFilename('clearance-register'), toCsv([bannerRow, headingRow], body))

    toast.add({
      severity: 'success',
      summary: 'Excel file downloaded',
      detail: data.truncated
        ? `Exported the first ${body.length} of ${data.total} records.`
        : `Exported ${body.length} record${body.length === 1 ? '' : 's'}.`,
      life: 5000,
    })
  } catch (err) {
    alertError(err, 'Export failed')
  } finally {
    exporting.value = false
  }
}

function resetAndFetch() {
  first.value = 0
  fetchRegister()
}

function onSearchInput() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(resetAndFetch, 350)
}

// Only the filter dropdowns load up front — the register itself waits for a
// search.
onMounted(() => {
  loadBusinesses()
  loadDepartments()
})

watch(first, fetchRegister)

const showingLabel = computed(() => {
  if (!hasFilters.value) return ''
  if (!totalRecords.value) return 'No records found'
  const from = first.value + 1
  const to = Math.min(first.value + rows, totalRecords.value)
  return `Showing ${from}–${to} of ${totalRecords.value} records`
})
</script>

<template>
  <motion.div
    :initial="{ opacity: 0, y: 16 }"
    :animate="{ opacity: 1, y: 0 }"
    :transition="{ duration: 0.45, ease: 'easeOut' }"
  >
    <div class="mb-5">
      <h1 class="page-title">Clearance View</h1>
      <p class="page-subtitle">Read-only register of all employee clearance records</p>
    </div>

    <motion.div
      class="card"
      :initial="{ opacity: 0, y: 20 }"
      :animate="{ opacity: 1, y: 0 }"
      :transition="{ duration: 0.45, delay: 0.1, ease: 'easeOut' }"
    >
      <div class="flex flex-wrap gap-3">
        <IconField class="min-w-60 flex-1">
          <InputIcon>
            <Search :size="16" />
          </InputIcon>
          <InputText
            v-model="query"
            placeholder="Search by Staff ID, Clearance ID or Name..."
            class="w-full"
            @input="onSearchInput"
          />
        </IconField>
        <Select
          v-model="businessFilter"
          :options="businessOptions"
          optionLabel="name"
          @change="resetAndFetch"
        />
        <Select
          v-model="departmentFilter"
          :options="departmentOptions"
          optionLabel="name"
          filter
          @change="resetAndFetch"
        />
        <Select
          v-model="statusFilter"
          :options="statusOptions"
          optionLabel="label"
          @change="resetAndFetch"
        />
        <Button
          severity="secondary"
          outlined
          :loading="exporting"
          :disabled="!totalRecords"
          @click="exportToExcel"
        >
          <Download :size="16" />
          <span class="ml-2">Export to Excel</span>
        </Button>
      </div>

      <motion.div
        v-if="!hasFilters"
        class="px-5 py-16 text-center"
        :initial="{ opacity: 0 }"
        :animate="{ opacity: 1 }"
        :transition="{ duration: 0.35 }"
      >
        <div
          class="mb-4 inline-flex h-14 w-14 items-center justify-center rounded-full bg-slate-100 text-slate-400"
        >
          <Search :size="24" />
        </div>
        <h3 class="text-[15.5px] font-semibold text-slate-700">Search to view clearance records</h3>
        <p class="mt-1.5 text-[13px] text-slate-400">
          Filter by Staff ID or name, department, business or status — then export exactly what you
          see.
        </p>
      </motion.div>

      <template v-else>
      <div class="my-4 flex flex-wrap gap-2.5">
        <span
          class="rounded-full border border-slate-200 bg-white px-3.5 py-1.25 text-[12.5px] font-semibold text-slate-600"
        >
          Cleared: <b class="font-bold">{{ counts.cleared }}</b>
        </span>
        <span
          class="rounded-full border border-slate-200 bg-white px-3.5 py-1.25 text-[12.5px] font-semibold text-slate-600"
        >
          Pending: <b class="font-bold">{{ counts.pending }}</b>
        </span>
        <span
          class="rounded-full border border-slate-200 bg-white px-3.5 py-1.25 text-[12.5px] font-semibold text-slate-600"
        >
          Returned: <b class="font-bold">{{ counts.returned }}</b>
        </span>
      </div>

      <DataTable :value="rowsData" :loading="loading" scrollable class="clearance-table" showGridlines>
        <ColumnGroup type="header">
          <Row>
            <Column header="Employee Details" :colspan="12" headerClass="group-head" />
            <Column
              v-for="d in departmentColumns"
              :key="d.id"
              :header="d.name"
              :colspan="3"
              headerClass="group-head"
            />
            <Column header="Summary" :colspan="2" headerClass="group-head" />
          </Row>
          <Row>
            <Column header="Sl." />
            <Column header="Clearance ID" />
            <Column header="Business" />
            <Column header="Form Type" />
            <Column header="Staff ID" />
            <Column header="Staff Name" />
            <Column header="Designation" />
            <Column header="Resignation Effective Date" />
            <Column header="HRS Receiving" />
            <Column header="Submission" />
            <Column header="Status" />
            <Column header="Pending At" />
            <template v-for="d in departmentColumns" :key="d.id">
              <Column header="Submitted" />
              <Column header="Received" />
              <Column header="Returned" />
            </template>
            <Column header="Overall Status" />
            <Column header="Overall Remarks" />
          </Row>
        </ColumnGroup>

        <Column header="Sl.">
          <template #body="{ index }">{{ first + index + 1 }}</template>
        </Column>
        <Column header="Clearance ID">
          <template #body="{ data }">{{ data.id ?? '—' }}</template>
        </Column>
        <Column header="Business">
          <template #body="{ data }">{{ data.business?.name ?? data.business_id ?? '—' }}</template>
        </Column>
        <Column header="Form Type">
          <template #body="{ data }">{{ data.form_type?.name ?? '—' }}</template>
        </Column>
        <Column header="Staff ID">
          <template #body="{ data }">
            <span class="font-mono text-[12.5px]">{{ data.staff?.staff_code ?? data.staff_id ?? '—' }}</span>
          </template>
        </Column>
        <Column header="Staff Name">
          <template #body="{ data }">{{ data.staff?.name ?? data.staff_name ?? '—' }}</template>
        </Column>
        <Column header="Designation">
          <template #body="{ data }">{{ data.staff?.designation ?? '—' }}</template>
        </Column>
        <Column header="Resignation Effective Date">
          <template #body="{ data }">{{ data.resign_date ?? '—' }}</template>
        </Column>
        <Column header="HRS Receiving">
          <template #body="{ data }">{{ data.hrs_receiving_date ?? '—' }}</template>
        </Column>
        <Column header="Submission">
          <template #body="{ data }">{{ data.online_submission_date ?? '—' }}</template>
        </Column>
        <Column header="Status">
          <template #body="{ data }">
            <span class="status-badge" :class="data.status">{{ data.status }}</span>
          </template>
        </Column>
        <Column header="Pending At">
          <template #body="{ data }">{{ data.pending_at?.name ?? '—' }}</template>
        </Column>

        <!-- Submitted / Received / Returned only. Department remarks are still
             carried in the Excel export, just not shown here. All three render
             in the default body colour — no muting, no red highlight. -->
        <template v-for="d in departmentColumns" :key="d.id">
          <Column>
            <template #body="{ data }">
              <span class="text-slate-900">
                {{ departmentCell(data, d.id)?.submission_date || '—' }}
              </span>
            </template>
          </Column>
          <Column>
            <template #body="{ data }">
              <span class="text-slate-900">
                {{ departmentCell(data, d.id)?.received_date || '—' }}
              </span>
            </template>
          </Column>
          <Column>
            <template #body="{ data }">
              <span class="text-slate-900">
                {{ departmentCell(data, d.id)?.is_returned ? 'Yes' : 'No' }}
              </span>
            </template>
          </Column>
        </template>

        <Column header="Overall Status">
          <template #body="{ data }">
            <span
              class="whitespace-nowrap text-[12.5px] font-medium"
              :class="
                clearedTally(data).total && clearedTally(data).cleared === clearedTally(data).total
                  ? 'text-green-600'
                  : 'text-slate-600'
              "
            >
              {{ overallStatusLabel(data) }}
            </span>
          </template>
        </Column>
        <Column header="Overall Remarks">
          <template #body="{ data }">
            <span
              class="block max-w-56 truncate"
              :class="data.remarks ? '' : 'text-slate-300'"
              :title="data.remarks || ''"
            >
              {{ data.remarks || '—' }}
            </span>
          </template>
        </Column>

        <template #empty>
          <div class="py-6 text-center text-slate-400">No records found</div>
        </template>
      </DataTable>

      <div class="mt-3.5 flex flex-wrap items-center justify-between gap-3">
        <span class="text-[13px] text-slate-500">{{ showingLabel }}</span>
        <Paginator
          v-model:first="first"
          :rows="rows"
          :totalRecords="totalRecords"
          template="PrevPageLink PageLinks NextPageLink"
        />
      </div>
      </template>
    </motion.div>
  </motion.div>
</template>
