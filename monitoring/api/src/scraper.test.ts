import { extractCveIds, extractReleaseVersion } from './scraper.js'

describe('extractCveIds', () => {
  it('finds CVE IDs in markdown text', () => {
    const text = 'This release fixes CVE-2024-2996, CVE-2024-3156 and CVE-2024-3249.'
    expect(extractCveIds(text)).toEqual(['CVE-2024-2996', 'CVE-2024-3156', 'CVE-2024-3249'])
  })
  it('deduplicates repeated CVE IDs', () => {
    const text = 'CVE-2024-2996 mentioned twice. CVE-2024-2996 again.'
    expect(extractCveIds(text)).toEqual(['CVE-2024-2996'])
  })
  it('returns empty array when no CVEs found', () => {
    expect(extractCveIds('No vulnerabilities in this update.')).toEqual([])
  })
})

describe('extractReleaseVersion', () => {
  it('extracts a Chrome version number from text', () => {
    const text = 'Chrome 125 (125.0.6422.142) contains security updates.'
    expect(extractReleaseVersion('chromium', text)).toBe('125.0.6422.142')
  })
  it('extracts a Firefox version from text', () => {
    const text = 'Firefox 128.0 is now available'
    expect(extractReleaseVersion('gecko', text)).toBe('128.0')
  })
})
