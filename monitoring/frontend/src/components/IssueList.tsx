import type { MonitoringMetadata } from '../App.js'

const STATUS_LABELS: Record<MonitoringMetadata['status'], string> = {
  pending: 'Pending',
  'pr-open': 'PR Open',
  'pr-merged': 'PR Merged',
  shipped: 'Shipped',
  dismissed: 'Dismissed',
}

const STATUS_COLORS: Record<MonitoringMetadata['status'], string> = {
  pending: '#8b949e',
  'pr-open': '#388bfd',
  'pr-merged': '#8957e5',
  shipped: '#3fb950',
  dismissed: '#6e7681',
}

const CVE_SEVERITY_COLORS: Record<string, string> = {
  Critical: '#f85149',
  High: '#d29922',
  Medium: '#e3b341',
  Low: '#3fb950',
}

interface Props {
  issues: MonitoringMetadata[]
}

export function IssueList({ issues }: Props) {
  if (issues.length === 0) {
    return (
      <div
        style={{
          background: '#161b22',
          border: '1px solid #30363d',
          borderRadius: 8,
          padding: '20px 24px',
          color: '#8b949e',
          fontSize: 14,
        }}
      >
        No issues to display.
      </div>
    )
  }

  return (
    <div
      style={{
        background: '#161b22',
        border: '1px solid #30363d',
        borderRadius: 8,
        overflow: 'hidden',
      }}
    >
      {issues.map((issue, idx) => (
        <div
          key={issue.issueNumber}
          style={{
            display: 'flex',
            alignItems: 'center',
            padding: '12px 20px',
            borderBottom: idx < issues.length - 1 ? '1px solid #30363d' : 'none',
            gap: 12,
          }}
        >
          <span style={{ fontSize: 13, color: '#8b949e', flexShrink: 0 }}>
            #{issue.issueNumber}
          </span>

          <span
            style={{
              fontSize: 14,
              color: '#e6edf3',
              flex: 1,
              minWidth: 0,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {issue.title}
          </span>

          {issue.cves.length > 0 && (
            <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
              {issue.cves.map((cve) => (
                <span
                  key={cve.id}
                  style={{
                    fontSize: 11,
                    fontWeight: 600,
                    color: CVE_SEVERITY_COLORS[cve.severity] ?? '#8b949e',
                    background: `${CVE_SEVERITY_COLORS[cve.severity] ?? '#8b949e'}1a`,
                    border: `1px solid ${CVE_SEVERITY_COLORS[cve.severity] ?? '#8b949e'}4d`,
                    borderRadius: 4,
                    padding: '1px 6px',
                  }}
                >
                  {cve.severity}
                </span>
              ))}
            </div>
          )}

          <span
            style={{
              fontSize: 12,
              fontWeight: 600,
              color: STATUS_COLORS[issue.status],
              flexShrink: 0,
            }}
          >
            {STATUS_LABELS[issue.status]}
          </span>
        </div>
      ))}
    </div>
  )
}
