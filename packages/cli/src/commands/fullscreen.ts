import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerFullscreen(program: Command): void {
  const fullscreen = program
    .command("fullscreen")
    .description("Manage fullscreen mode (macOS only)");

  fullscreen
    .command("get")
    .description("Get whether the browser window is fullscreen")
    .action(async () => {
      await deviceCommand(program, "getFullscreen");
    });

  fullscreen
    .command("set <enabled>")
    .description("Enable or disable fullscreen (true/false)")
    .action(async (enabled: string) => {
      await deviceCommand(program, "setFullscreen", { enabled: enabled === "true" });
    });
}
