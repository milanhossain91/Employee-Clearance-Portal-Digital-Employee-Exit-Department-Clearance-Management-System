import http, { unwrap } from './http'

export async function searchStaff(staffId) {
  const { data } = await http.get('/staff/search', { params: { staff_id: staffId } })
  return unwrap(data)
}

// Live employee lookup against the PIMS master (`sqlsrv2`). Returns up to 5
// permanent + 5 contractual matches on a partial EmpCode. Rows come back in
// PIMS' own casing: { EmpCode, Name, DesgName, DeptCode, JoiningDate } with
// JoiningDate already formatted dd-mm-yyyy.
export async function selectEmployer(empCode) {
  const { data } = await http.get('/select_employer', { params: { EmpCode: empCode } })
  return unwrap(data).employers || []
}

export async function typeaheadStaff(search, { limit = 25, activeOnly = true } = {}) {
  const { data } = await http.get('/staff', {
    params: { search, limit, active_only: activeOnly ? 1 : 0 },
  })
  return unwrap(data)
}
