import axios from 'axios'

const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  headers: { Accept: 'application/json' },
})

http.interceptors.request.use((config) => {
  const token = localStorage.getItem('aci-token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

http.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && !location.pathname.endsWith('/login')) {
      localStorage.removeItem('aci-token')
      localStorage.removeItem('aci-user')
      localStorage.removeItem('aci-permissions')
      location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export class ApiError extends Error {
  constructor(message) {
    super(typeof message === 'string' ? message : 'Request failed')
    this.fieldErrors = typeof message === 'object' && message !== null ? message : null
  }
}

// The backend returns HTTP 200 even for validation failures, signalled only by
// `status: "error"` in the body — route that through the same rejection path
// as real HTTP errors so every caller needs just one catch block.
export function unwrap(data) {
  if (data?.status === 'error') throw new ApiError(data.message)
  return data
}

// Several controllers return a raw `$e->getMessage()` on failure, which for a
// database fault is the driver's SQLSTATE text — connection strings, table and
// column names, fragments of the statement. Never put that in front of a user:
// detect it and swap in something they can act on. Validation messages and the
// backend's own written messages pass through untouched.
const RAW_DRIVER_ERROR = /SQLSTATE|SQL Server|ODBC|PDO|Syntax error|Illuminate\\|\bException\b|\bstack trace\b|\.php\b/i

export function isRawDriverError(message) {
  return typeof message === 'string' && RAW_DRIVER_ERROR.test(message)
}

// The message to show a user — guaranteed free of driver internals.
export function friendlyMessage(err, fallback = 'Something went wrong. Please try again.') {
  const message = errorMessage(err)
  if (!message || isRawDriverError(message)) return fallback
  return message
}

export function errorMessage(err) {
  if (err instanceof ApiError) return err.message
  const data = err?.response?.data
  if (typeof data?.message === 'string') return data.message
  if (data?.message && typeof data.message === 'object') {
    return Object.values(data.message).flat().join(' ')
  }
  return err?.message || 'Something went wrong'
}

export default http
