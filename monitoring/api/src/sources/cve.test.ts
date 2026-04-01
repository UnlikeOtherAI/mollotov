import { parseCveRecord } from './cve.js'

describe('parseCveRecord', () => {
  const rawVuln = {
    cve: {
      id: 'CVE-2024-2996',
      published: '2024-03-26T18:15:00.000',
      lastModified: '2024-03-28T12:00:00.000',
      descriptions: [
        { lang: 'en', value: 'Use after free in WebAudio in Google Chrome prior to 123.0.6312.86.' },
        { lang: 'es', value: 'Uso después de libre...' },
      ],
      metrics: {
        cvssMetricV31: [{
          cvssData: { baseScore: 9.8, baseSeverity: 'CRITICAL' },
          type: 'Primary',
        }],
      },
    },
  }

  it('extracts id and description', () => {
    const cve = parseCveRecord(rawVuln)
    expect(cve.id).toBe('CVE-2024-2996')
    expect(cve.description).toContain('WebAudio')
  })

  it('picks English description', () => {
    const cve = parseCveRecord(rawVuln)
    expect(cve.description).not.toContain('libre')
  })

  it('extracts CVSS severity', () => {
    const cve = parseCveRecord(rawVuln)
    expect(cve.severity).toBe('Critical')
    expect(cve.cvssScore).toBe(9.8)
  })
})
