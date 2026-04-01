export interface ChromiumRelease {
  engine: 'chromium'
  version: string
  milestone: number
  releaseDate: string     // YYYY-MM-DD
  deadline: string        // YYYY-MM-DD (releaseDate + 15 days)
  previousVersion: string
  upstreamUrl: string
}

const CHROMIUM_API = 'https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux&num=3&offset=0'
const RELEASE_NOTES_BASE = 'https://chromereleases.googleblog.com/'
const DEADLINE_DAYS = 15

export function parseChromiumRelease(raw: any[]): ChromiumRelease {
  const r = raw[0]
  const releaseDate = new Date(r.time).toISOString().slice(0, 10)
  const releaseDateMs = new Date(releaseDate + 'T00:00:00Z').getTime()
  const deadline = new Date(releaseDateMs + DEADLINE_DAYS * 864e5).toISOString().slice(0, 10)

  return {
    engine: 'chromium',
    version: r.version,
    milestone: r.milestone,
    releaseDate,
    deadline,
    previousVersion: r.previous_version,
    upstreamUrl: RELEASE_NOTES_BASE,
  }
}

export async function fetchLatestChromiumRelease(): Promise<ChromiumRelease> {
  const res = await fetch(CHROMIUM_API)
  if (!res.ok) throw new Error(`Chromium Dash returned ${res.status}`)
  const data = await res.json()
  return parseChromiumRelease(data)
}
