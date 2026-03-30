import { browserTools, cliTools } from "../mcp/tools.js";
import { commandMetadata } from "./command-metadata.js";
import type { BrowserToolDef, CliToolDef } from "../mcp/tools.js";

interface ParamInfo {
  name: string;
  type: string;
  required: boolean;
  description?: string;
}

interface CommandHelpOutput {
  command: string;
  purpose: string;
  when: string;
  params: ParamInfo[];
  errors?: string[];
  related?: string[];
}

/** Convert a MCP tool name to CLI kebab-case command name */
function mcpToCommand(name: string): string {
  return name
    .replace(/^mollotov_/, "")
    .replace(/^group_/, "group ")
    .replace(/_/g, "-");
}

function extractParams(schema: Record<string, unknown>): ParamInfo[] {
  return Object.entries(schema).map(([name, zodType]) => {
    const z = zodType as { _def?: { typeName?: string; description?: string; innerType?: unknown }; isOptional?: () => boolean; description?: string };
    const isOptional = z._def?.typeName === "ZodOptional" || z._def?.typeName === "ZodDefault";
    const desc = z._def?.description ?? z.description;
    const innerType = z._def?.innerType as { _def?: { typeName?: string } } | undefined;
    const baseType = isOptional ? innerType?._def?.typeName ?? "string" : z._def?.typeName ?? "string";
    return { name, type: baseType.replace("Zod", "").toLowerCase(), required: !isOptional, description: desc ?? undefined };
  });
}

function toolToHelp(tool: BrowserToolDef | CliToolDef): CommandHelpOutput {
  const cmd = mcpToCommand(tool.name);
  const meta = commandMetadata[cmd];
  return {
    command: cmd,
    purpose: meta?.purpose ?? tool.description,
    when: meta?.when ?? "",
    params: extractParams(tool.schema),
    errors: meta?.errors,
    related: meta?.related,
  };
}

/** Generate help for a specific command or all commands. */
export function generateLlmHelp(commandFilter?: string): string {
  if (commandFilter) {
    const all = [...browserTools, ...cliTools];
    const match = all.find((t) => mcpToCommand(t.name) === commandFilter || t.name === commandFilter);
    if (match) {
      return JSON.stringify(toolToHelp(match), null, 2);
    }
    // Try prefix match for group commands
    const prefix = commandFilter.replace(/-/g, "_");
    const groupMatch = all.filter((t) => t.name.startsWith(`mollotov_${prefix}`));
    if (groupMatch.length > 0) {
      return JSON.stringify(groupMatch.map(toolToHelp), null, 2);
    }
    return JSON.stringify({ error: `Unknown command: ${commandFilter}` });
  }

  // All commands
  const allHelp = [...browserTools, ...cliTools].map(toolToHelp);
  return JSON.stringify(allHelp, null, 2);
}
