import http, { unwrap } from './http'

export async function listFormTypes(params) {
  const { data } = await http.get('/form-types', { params })
  return unwrap(data)
}

export async function getFormType(id) {
  const { data } = await http.get(`/form-types/${id}`)
  return unwrap(data)
}

export async function createFormType(payload) {
  const { data } = await http.post('/form-types', payload)
  return unwrap(data)
}

export async function updateFormType(id, payload) {
  const { data } = await http.put(`/form-types/${id}`, payload)
  return unwrap(data)
}

export async function saveConfiguration(id, departments) {
  const { data } = await http.post(`/form-types/${id}/configuration`, { departments })
  return unwrap(data)
}

export async function addDepartmentByName(formTypeId, name, isMandatory) {
  const { data } = await http.post(`/form-types/${formTypeId}/departments`, {
    name,
    is_mandatory: isMandatory,
  })
  return unwrap(data)
}

export async function addExistingDepartment(formTypeId, departmentId, isMandatory) {
  const { data } = await http.post(`/form-types/${formTypeId}/departments`, {
    department_id: departmentId,
    is_mandatory: isMandatory,
  })
  return unwrap(data)
}

export async function removeDepartment(formTypeId, departmentId) {
  const { data } = await http.delete(`/form-types/${formTypeId}/departments/${departmentId}`)
  return unwrap(data)
}

export async function deleteFormType(id) {
  const { data } = await http.delete(`/form-types/${id}`)
  return unwrap(data)
}

export async function importDepartmentsExcel(file, { formTypeId, isMandatory } = {}) {
  const form = new FormData()
  form.append('file', file)
  if (formTypeId) form.append('form_type_id', formTypeId)
  if (isMandatory !== undefined) form.append('is_mandatory', isMandatory ? 1 : 0)
  const { data } = await http.post('/departments/import', form)
  return unwrap(data)
}
