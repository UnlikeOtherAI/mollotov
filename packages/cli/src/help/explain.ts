import { commandMetadata } from "./command-metadata.js";
import { browserTools, cliTools } from "../mcp/tools.js";

const defaultPlatforms = ["ios", "android", "macos", "linux", "windows"] as const;

/** Generate a natural language explanation for a command. */
export function explainCommand(command: string): string {
  // Try direct lookup
  const meta = commandMetadata[command];
  if (meta) {
    return formatExplanation(command, meta.explanation, meta.related, meta.platforms ?? defaultPlatforms);
  }

  // Try MCP tool name match
  const mcpName = `kelpie_${command.replace(/-/g, "_")}`;
  const tool = [...browserTools, ...cliTools].find((t) => t.name === mcpName);
  if (tool) {
    const m = commandMetadata[command];
    return formatExplanation(
      command,
      m?.explanation ?? tool.description,
      m?.related,
      m?.platforms ?? tool.platforms ?? defaultPlatforms,
    );
  }

  return `Unknown command: ${command}\n\nRun 'kelpie --help' to see all available commands.`;
}

function formatExplanation(
  command: string,
  explanation: string,
  related?: string[],
  platforms?: readonly string[],
): string {
  let output = `${command}\n${"─".repeat(command.length)}\n\n${explanation}`;
  if (platforms?.length) {
    output += `\n\nPlatforms: ${platforms.join(", ")}`;
  }
  if (related?.length) {
    output += `\n\nRelated: ${related.join(", ")}`;
  }
  return output;
}
