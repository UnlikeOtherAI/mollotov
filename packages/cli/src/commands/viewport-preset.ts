import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerViewportPreset(program: Command): void {
  const preset = program
    .command("viewport-preset")
    .description("Manage named viewport presets");

  preset
    .command("list")
    .description("List available viewport presets")
    .action(async () => {
      await deviceCommand(program, "getViewportPresets");
    });

  preset
    .command("set <name>")
    .description("Activate a named viewport preset")
    .action(async (name: string) => {
      await deviceCommand(program, "setViewportPreset", { presetId: name });
    });
}
