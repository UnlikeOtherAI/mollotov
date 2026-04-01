import { parseChromiumRelease } from './chromium.js'

describe('parseChromiumRelease', () => {
  const raw = [{
    version: '125.0.6422.142',
    milestone: 125,
    time: 1711584000000,
    channel: 'Stable',
    platform: 'Linux',
    previous_version: '125.0.6422.138',
    hashes: { chromium: 'abc123' },
    chromium_main_branch_position: 1234567,
  }]

  it('extracts version and milestone', () => {
    const release = parseChromiumRelease(raw)
    expect(release.version).toBe('125.0.6422.142')
    expect(release.milestone).toBe(125)
  })

  it('converts ms timestamp to ISO date string', () => {
    const release = parseChromiumRelease(raw)
    expect(release.releaseDate).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  it('computes 15-day deadline', () => {
    const release = parseChromiumRelease(raw)
    const deadline = new Date(release.deadline)
    const releaseDate = new Date(release.releaseDate)
    const diff = (deadline.getTime() - releaseDate.getTime()) / (1000 * 60 * 60 * 24)
    expect(diff).toBe(15)
  })
})
