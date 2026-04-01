import { parseGeckoRelease } from './gecko.js'

describe('parseGeckoRelease', () => {
  const raw = {
    LATEST_FIREFOX_VERSION: '128.0',
    LAST_RELEASE_DATE: '2026-04-01',
    NEXT_RELEASE_DATE: '2026-05-13',
    FIREFOX_ESR: '115.13.0esr',
  }

  it('extracts the stable version', () => {
    const release = parseGeckoRelease(raw)
    expect(release.version).toBe('128.0')
  })

  it('uses LAST_RELEASE_DATE as the release date', () => {
    const release = parseGeckoRelease(raw)
    expect(release.releaseDate).toBe('2026-04-01')
  })

  it('computes 15-day deadline from releaseDate', () => {
    const release = parseGeckoRelease(raw)
    const deadline = new Date(release.deadline)
    const releaseDate = new Date(release.releaseDate)
    const diff = (deadline.getTime() - releaseDate.getTime()) / (1000 * 60 * 60 * 24)
    expect(diff).toBe(15)
  })
})
