import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { randomUUID } from "node:crypto";

export interface FeedbackReportPayload {
  category: string;
  command: string;
  params?: Record<string, unknown>;
  error?: string;
  context?: string;
  url?: string;
  platform?: string;
  diagnostics?: Record<string, unknown>;
  screenshotBase64?: string;
}

export interface FeedbackReportRecord extends FeedbackReportPayload {
  id: string;
  createdAt: string;
  deviceId?: string;
  deviceName?: string;
  remoteReportId?: string;
  remoteStoredAt?: string;
}

export interface FeedbackSummary {
  success: true;
  total: number;
  byCategory: Record<string, number>;
  byCommand: Record<string, number>;
  byPlatform: Record<string, number>;
  byError: Record<string, number>;
  recent: FeedbackReportRecord[];
}

export function feedbackDirectory(): string {
  return join(homedir(), ".kelpie", "feedback");
}

export async function saveFeedbackReport(
  payload: FeedbackReportPayload,
  extra: Partial<FeedbackReportRecord> = {},
): Promise<FeedbackReportRecord> {
  const record: FeedbackReportRecord = {
    id: extra.id ?? randomUUID(),
    createdAt: extra.createdAt ?? new Date().toISOString(),
    ...payload,
    ...extra,
  };
  const filePath = feedbackFilePath(record.id);
  await mkdir(dirname(filePath), { recursive: true });
  await writeFile(filePath, `${JSON.stringify(record, null, 2)}\n`, "utf8");
  return record;
}

export async function listFeedbackReports(): Promise<FeedbackReportRecord[]> {
  const directory = feedbackDirectory();
  try {
    const entries = await readdir(directory, { withFileTypes: true });
    const reports = await Promise.all(
      entries
        .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
        .map(async (entry) => loadFeedbackReport(join(directory, entry.name))),
    );
    return reports
      .filter((report): report is FeedbackReportRecord => report !== null)
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  } catch {
    return [];
  }
}

export async function summarizeFeedbackReports(limit = 10): Promise<FeedbackSummary> {
  const reports = await listFeedbackReports();
  return {
    success: true,
    total: reports.length,
    byCategory: countBy(reports, (report) => report.category),
    byCommand: countBy(reports, (report) => report.command),
    byPlatform: countBy(reports, (report) => report.platform ?? "unknown"),
    byError: countBy(reports, (report) => report.error ?? "unknown"),
    recent: reports.slice(0, Math.max(limit, 0)),
  };
}

function feedbackFilePath(id: string): string {
  return join(feedbackDirectory(), `${id}.json`);
}

async function loadFeedbackReport(filePath: string): Promise<FeedbackReportRecord | null> {
  try {
    const raw = await readFile(filePath, "utf8");
    return JSON.parse(raw) as FeedbackReportRecord;
  } catch {
    return null;
  }
}

function countBy<T>(items: T[], keyFor: (item: T) => string): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const item of items) {
    const key = keyFor(item);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
