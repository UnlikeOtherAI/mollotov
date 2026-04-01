import { Octokit } from '@octokit/rest'

export const BRANCH_PATTERNS = {
  release: /^engine-update\/(chromium|gecko)-([\d.]+)$/,
  cve:     /^security\/(chromium|gecko)-(CVE-\d{4}-\d+)$/,
}

export function buildBranchName(
  engine: 'chromium' | 'gecko',
  type: 'release' | 'cve',
  version: string
): string {
  return type === 'release'
    ? `engine-update/${engine}-${version}`
    : `security/${engine}-${version}`
}

export function parseBranchName(branch: string): {
  engine: 'chromium' | 'gecko'
  type: 'release' | 'cve'
  version: string
} | null {
  let m = branch.match(BRANCH_PATTERNS.release)
  if (m) return { engine: m[1] as 'chromium' | 'gecko', type: 'release', version: m[2] }

  m = branch.match(BRANCH_PATTERNS.cve)
  if (m) return { engine: m[1] as 'chromium' | 'gecko', type: 'cve', version: m[2] }

  return null
}

export async function findPrForBranch(
  octokit: Octokit,
  owner: string,
  repo: string,
  branchName: string
): Promise<{ number: number; state: string; merged: boolean } | null> {
  const res = await octokit.pulls.list({
    owner,
    repo,
    head: `${owner}:${branchName}`,
    state: 'all',
    per_page: 5,
  })

  const pr = res.data[0]
  if (!pr) return null

  return {
    number: pr.number,
    state: pr.state,
    merged: !!pr.merged_at,
  }
}
