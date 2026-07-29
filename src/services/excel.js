// CSV export that Excel opens natively.
//
// Written as CSV rather than a real .xlsx on purpose: xlsx is a zip container
// and would need a third-party writer, and the `xlsx` package on npm is stale
// with an open prototype-pollution advisory. CSV keeps the export dependency
// free; Excel reads it directly.

// RFC 4180: wrap in quotes when the value contains a delimiter, quote or line
// break, and escape embedded quotes by doubling them.
function csvCell(value) {
  if (value === null || value === undefined) return ''
  const text = String(value)
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}

export function toCsv(headerRows, bodyRows) {
  return [...headerRows, ...bodyRows]
    .map((row) => row.map(csvCell).join(','))
    .join('\r\n')
}

export function downloadCsv(filename, csv) {
  // Excel only detects UTF-8 in a CSV when it starts with a BOM. Without it,
  // non-ASCII employee names render as mojibake.
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

export function stampedFilename(prefix, extension = 'csv') {
  const now = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  const stamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
  return `${prefix}-${stamp}.${extension}`
}
