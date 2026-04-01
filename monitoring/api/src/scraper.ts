import FirecrawlApp from '@mendable/firecrawl-js'

const CVE_PATTERN = /CVE-\d{4}-\d{4,}/g
const CHROMIUM_VERSION_PATTERN = /\b(\d{3,}\.0\.\d{4,}\.\d+)\b/
const GECKO_VERSION_PATTERN = /Firefox\s+(\d+\.\d+(?:\.\d+)?)/i

export function extractCveIds(text: string): string[] {
  return [...new Set(text.match(CVE_PATTERN) ?? [])]
}

export function extractReleaseVersion(engine: 'chromium' | 'gecko', text: string): string | null {
  const pattern = engine === 'chromium' ? CHROMIUM_VERSION_PATTERN : GECKO_VERSION_PATTERN
  return text.match(pattern)?.[1] ?? null
}

export async function scrapeReleaseNotes(url: string, apiKey: string): Promise<string> {
  const app = new FirecrawlApp({ apiKey })
  const result = await app.scrapeUrl(url, { formats: ['markdown'] })
  if (!result.success) throw new Error(`Firecrawl failed for ${url}: ${result.error}`)
  return result.markdown ?? ''
}

export async function scrapeAndExtractCves(url: string, apiKey: string): Promise<string[]> {
  const markdown = await scrapeReleaseNotes(url, apiKey)
  return extractCveIds(markdown)
}
