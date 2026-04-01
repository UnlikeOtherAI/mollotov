export interface GeckoRelease {
  engine: 'gecko'
  version: string
  releaseDate: string
  deadline: string
  nextReleaseDate: string
  esr: string
  upstreamUrl: string
}

const GECKO_API = 'https://product-details.mozilla.org/1.0/firefox_versions.json'
const ADVISORIES_URL = 'https://www.mozilla.org/security/advisories/'
const DEADLINE_DAYS = 15

export function parseGeckoRelease(raw: any): GeckoRelease {
  const releaseDate = raw.LAST_RELEASE_DATE as string
  // Parse as UTC midnight to avoid timezone-dependent date shifts
  const releaseDateMs = new Date(releaseDate + 'T00:00:00Z').getTime()
  const deadline = new Date(releaseDateMs + DEADLINE_DAYS * 864e5)
    .toISOString().slice(0, 10)

  return {
    engine: 'gecko',
    version: raw.LATEST_FIREFOX_VERSION,
    releaseDate,
    deadline,
    nextReleaseDate: raw.NEXT_RELEASE_DATE,
    esr: raw.FIREFOX_ESR,
    upstreamUrl: ADVISORIES_URL,
  }
}

export async function fetchLatestGeckoRelease(): Promise<GeckoRelease> {
  const res = await fetch(GECKO_API)
  if (!res.ok) throw new Error(`Mozilla product-details returned ${res.status}`)
  const data = await res.json()
  return parseGeckoRelease(data)
}
