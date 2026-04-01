import { Hono } from 'hono'
import { Octokit } from '@octokit/rest'
import { searchIssues, parseMonitoringMetadata } from './github/issues.js'
import { seedLabels } from './github/labels.js'
import { runMonitoringAgent } from './agent/loop.js'
import type { AgentDeps } from './agent/loop.js'

export function createServer(deps: AgentDeps & { owner: string; repo: string }) {
  const app = new Hono()

  app.get('/api/v1/health', c => c.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    owner: deps.owner,
    repo: deps.repo,
  }))

  app.get('/api/v1/status', async c => {
    const issues = await searchIssues(deps.octokit, deps.owner, deps.repo, [], '')
    const records = issues
      .map(i => ({ ...parseMonitoringMetadata(i.body), issueNumber: i.number, title: i.title }))
      .filter(Boolean)
    return c.json({ issues: records, fetchedAt: new Date().toISOString() })
  })

  app.post('/api/v1/check', async c => {
    const result = await runMonitoringAgent(deps)
    return c.json(result)
  })

  app.post('/api/v1/seed-labels', async c => {
    await seedLabels(deps.octokit, deps.owner, deps.repo)
    return c.json({ seeded: true })
  })

  return app
}
