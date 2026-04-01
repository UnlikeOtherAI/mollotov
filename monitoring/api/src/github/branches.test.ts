import { buildBranchName, parseBranchName } from './branches.js'

describe('buildBranchName', () => {
  it('builds a release branch name', () => {
    expect(buildBranchName('chromium', 'release', '125.0.6422.142'))
      .toBe('engine-update/chromium-125.0.6422.142')
  })
  it('builds a CVE branch name', () => {
    expect(buildBranchName('gecko', 'cve', 'CVE-2024-2996'))
      .toBe('security/gecko-CVE-2024-2996')
  })
})

describe('parseBranchName', () => {
  it('parses a release branch', () => {
    const result = parseBranchName('engine-update/chromium-125.0.6422.142')
    expect(result).toEqual({ engine: 'chromium', type: 'release', version: '125.0.6422.142' })
  })
  it('parses a CVE branch', () => {
    const result = parseBranchName('security/gecko-CVE-2024-2996')
    expect(result).toEqual({ engine: 'gecko', type: 'cve', version: 'CVE-2024-2996' })
  })
  it('returns null for non-matching branches', () => {
    expect(parseBranchName('feature/some-random-feature')).toBeNull()
  })
})
