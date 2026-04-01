import { Octokit } from '@octokit/rest'

export interface MonitoringMetadata {
  engine: 'chromium' | 'gecko'
  type: 'release' | 'cve'
  version: string
  milestone?: number
  releaseDate: string
  deadline: string
  cves: Array<{ id: string; severity: string; description: string }>
  upstreamUrl: string
  branchName: string
  prNumber: number | null
  status: 'pending' | 'pr-open' | 'pr-merged' | 'shipped' | 'dismissed'
}

const METADATA_START = '<!-- MONITORING_METADATA'
const METADATA_END = '-->'

export function buildIssueTitle(meta: MonitoringMetadata): string {
  if (meta.type === 'cve') {
    const severity = meta.cves[0]?.severity ?? 'Unknown'
    const desc = meta.cves[0]?.description ?? ''
    return `[${meta.engine}] ${meta.version} — ${severity}: ${desc}`
  }
  return `[${meta.engine}] Release v${meta.version}`
}

export function buildIssueBody(meta: MonitoringMetadata, summary: string): string {
  const cveList = meta.cves.length > 0
    ? meta.cves.map(c => `- ${c.id} (${c.severity}) — ${c.description}`).join('\n')
    : '_No CVEs listed for this release._'

  const prLink = meta.prNumber
    ? `[PR #${meta.prNumber}](https://github.com/${process.env.GITHUB_OWNER}/${process.env.GITHUB_REPO}/pull/${meta.prNumber})`
    : '_No PR yet_'

  const daysLeft = Math.ceil(
    (new Date(meta.deadline).getTime() - Date.now()) / 864e5
  )
  const deadlineNote = daysLeft > 0 ? `(${daysLeft} days remaining)` : `(OVERDUE by ${-daysLeft} days)`

  return `## Engine Update: ${meta.engine === 'chromium' ? 'Chromium' : 'Gecko/Firefox'} v${meta.version}

**Release Date:** ${meta.releaseDate}
**Deadline:** ${meta.deadline} ${deadlineNote}
**Status:** ${meta.status}

${summary}

### Security Fixes

${cveList}

### Links

- [Upstream release notes](${meta.upstreamUrl})
- PR: ${prLink}

---

${METADATA_START}
${JSON.stringify(meta, null, 2)}
${METADATA_END}`
}

export function parseMonitoringMetadata(body: string): MonitoringMetadata | null {
  const start = body.indexOf(METADATA_START)
  if (start === -1) return null

  const jsonStart = start + METADATA_START.length
  const end = body.indexOf(METADATA_END, jsonStart)
  if (end === -1) return null

  try {
    return JSON.parse(body.slice(jsonStart, end).trim())
  } catch {
    return null
  }
}

export async function searchIssues(
  octokit: Octokit,
  owner: string,
  repo: string,
  labels: string[],
  title?: string
): Promise<Array<{ number: number; title: string; body: string; labels: string[] }>> {
  const labelQuery = labels.map(l => `label:"${l}"`).join(' ')
  const titleQuery = title ? `"${title}" in:title` : ''
  const q = `repo:${owner}/${repo} is:issue ${labelQuery} ${titleQuery}`.trim()

  const res = await octokit.search.issuesAndPullRequests({ q, per_page: 20 })
  return res.data.items.map(item => ({
    number: item.number,
    title: item.title,
    body: item.body ?? '',
    labels: (item.labels as any[]).map(l => (typeof l === 'string' ? l : l.name ?? '')),
  }))
}

export async function createIssue(
  octokit: Octokit,
  owner: string,
  repo: string,
  title: string,
  body: string,
  labels: string[]
): Promise<number> {
  const res = await octokit.issues.create({ owner, repo, title, body, labels })
  return res.data.number
}

export async function updateIssue(
  octokit: Octokit,
  owner: string,
  repo: string,
  issueNumber: number,
  patch: { body?: string; labels?: string[]; state?: 'open' | 'closed' }
): Promise<void> {
  await octokit.issues.update({ owner, repo, issue_number: issueNumber, ...patch })
}

export async function addComment(
  octokit: Octokit,
  owner: string,
  repo: string,
  issueNumber: number,
  body: string
): Promise<void> {
  await octokit.issues.createComment({ owner, repo, issue_number: issueNumber, body })
}
