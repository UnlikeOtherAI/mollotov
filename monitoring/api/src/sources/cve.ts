export interface CveRecord {
  id: string
  description: string
  severity: 'Critical' | 'High' | 'Medium' | 'Low' | 'Unknown'
  cvssScore: number | null
  publishedDate: string
  url: string
}

const NVD_BASE = 'https://services.nvd.nist.gov/rest/json/cves/2.0'

function normalizeSeverity(s?: string): CveRecord['severity'] {
  switch (s?.toUpperCase()) {
    case 'CRITICAL': return 'Critical'
    case 'HIGH':     return 'High'
    case 'MEDIUM':   return 'Medium'
    case 'LOW':      return 'Low'
    default:         return 'Unknown'
  }
}

export function parseCveRecord(vuln: any): CveRecord {
  const cve = vuln.cve
  const desc = cve.descriptions.find((d: any) => d.lang === 'en')?.value ?? ''

  // Try CVSS v3.1 first, fall back to v3.0, then v2
  const metrics =
    cve.metrics?.cvssMetricV31?.[0] ??
    cve.metrics?.cvssMetricV30?.[0] ??
    cve.metrics?.cvssMetricV2?.[0] ?? null

  const score = metrics?.cvssData?.baseScore ?? null
  const severity = normalizeSeverity(
    metrics?.cvssData?.baseSeverity ?? metrics?.baseSeverity
  )

  return {
    id: cve.id,
    description: desc,
    severity,
    cvssScore: score,
    publishedDate: cve.published.slice(0, 10),
    url: `https://nvd.nist.gov/vuln/detail/${cve.id}`,
  }
}

export async function fetchCve(cveId: string, apiKey?: string): Promise<CveRecord> {
  const url = `${NVD_BASE}?cveId=${encodeURIComponent(cveId)}`
  const headers: Record<string, string> = {}
  if (apiKey) headers['apiKey'] = apiKey

  const res = await fetch(url, { headers })
  if (!res.ok) throw new Error(`NVD returned ${res.status} for ${cveId}`)

  const data = await res.json()
  if (!data.vulnerabilities?.length) throw new Error(`CVE ${cveId} not found in NVD`)

  return parseCveRecord(data.vulnerabilities[0])
}

export async function searchRecentCves(engine: 'chromium' | 'gecko', apiKey?: string): Promise<CveRecord[]> {
  const keyword = engine === 'chromium' ? 'Google Chrome' : 'Firefox'
  const since = new Date(Date.now() - 30 * 864e5).toISOString()
  const url = `${NVD_BASE}?keywordSearch=${encodeURIComponent(keyword)}&resultsPerPage=20&pubStartDate=${since}`

  const headers: Record<string, string> = {}
  if (apiKey) headers['apiKey'] = apiKey

  const res = await fetch(url, { headers })
  if (!res.ok) throw new Error(`NVD search returned ${res.status}`)

  const data = await res.json()
  return (data.vulnerabilities ?? []).map(parseCveRecord)
}
