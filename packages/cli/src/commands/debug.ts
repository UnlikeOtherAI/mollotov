import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerDebug(program: Command): void {
  program
    .command("debug-screens")
    .description("Get connected screen and scene diagnostics")
    .action(async () => {
      await deviceCommand(program, "debugScreens");
    });

  const debugOverlay = program
    .command("debug-overlay")
    .description("Manage the on-screen debug overlay");

  debugOverlay
    .command("get")
    .description("Get the current debug overlay state")
    .action(async () => {
      await deviceCommand(program, "getDebugOverlay");
    });

  debugOverlay
    .command("set <enabled>")
    .description("Enable or disable the debug overlay")
    .action(async (enabled: string) => {
      await deviceCommand(program, "setDebugOverlay", { enabled: enabled.toLowerCase() === "true" });
    });
}
