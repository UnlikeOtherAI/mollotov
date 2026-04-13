import type { Command } from "commander";
import { sendCommand } from "../client/http-client.js";
import { saveFeedbackReport, summarizeFeedbackReports } from "../feedback/store.js";
import { print } from "../output/formatter.js";
import { getGlobals, requireDevice } from "./helpers.js";

interface ReportIssueOptions {
  category: string;
  command: string;
  error?: string;
  context?: string;
  url?: string;
  params?: string;
  diagnostics?: string;
  screenshotBase64?: string;
}

export function registerFeedback(program: Command): void {
  program
    .command("report-issue")
    .description("Report an automation failure with structured context")
    .requiredOption("--category <category>", "Failure category")
    .requiredOption("--command <command>", "Command that failed")
    .option("--error <code>", "Error code")
    .option("--context <text>", "Human or LLM explanation of what failed")
    .option("--url <url>", "Page URL where the failure occurred")
    .option("--params <json>", "JSON object with command params")
    .option("--diagnostics <json>", "JSON object with structured diagnostics")
    .option("--screenshot-base64 <data>", "Optional screenshot payload")
    .action(async (options: ReportIssueOptions) => {
      const globals = getGlobals(program);
      const device = await requireDevice(program);
      if (!device) {
        return;
      }

      const params = parseJsonOption(options.params, "params");
      const diagnostics = parseJsonOption(options.diagnostics, "diagnostics");
      if (params === null || diagnostics === null) {
        process.exitCode = 1;
        return;
      }

      const payload = {
        category: options.category,
        command: options.command,
        error: options.error,
        context: options.context,
        url: options.url,
        params: params ?? undefined,
        diagnostics: diagnostics ?? undefined,
        screenshotBase64: options.screenshotBase64,
        platform: device.platform,
      };

      const result = await sendCommand(device, "reportIssue", payload, globals.timeout);
      if (result.ok && (result.data as { success?: boolean }).success === true) {
        const remote = result.data as {
          reportId?: string;
          storedAt?: string;
        };
        const local = await saveFeedbackReport(payload, {
          deviceId: device.id,
          deviceName: device.name,
          remoteReportId: remote.reportId,
          remoteStoredAt: remote.storedAt,
        });
        print({ ...(result.data as Record<string, unknown>), localReportId: local.id, localStoredAt: local.createdAt }, globals.format);
        return;
      }

      print(result.data, globals.format);
      if (!result.ok) {
        process.exitCode = 1;
      }
    });

  program
    .command("feedback-summary")
    .description("Summarize locally stored feedback reports")
    .option("--limit <count>", "How many recent reports to include", "10")
    .action(async (options: { limit?: string }) => {
      const globals = getGlobals(program);
      const limit = options.limit ? Number(options.limit) : 10;
      const summary = await summarizeFeedbackReports(Number.isFinite(limit) ? limit : 10);
      print(summary, globals.format);
    });
}

function parseJsonOption(value: string | undefined, label: string): Record<string, unknown> | undefined | null {
  if (!value) {
    return undefined;
  }
  try {
    const parsed = JSON.parse(value) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error(`${label} must be a JSON object`);
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    print(
      {
        success: false,
        error: {
          code: "INVALID_PARAMS",
          message: error instanceof Error ? error.message : `${label} must be valid JSON`,
        },
      },
      "json",
    );
    return null;
  }
}
