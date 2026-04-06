import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerRenderer(program: Command): void {
  const renderer = program
    .command("renderer")
    .description("Manage the rendering engine (macOS only)");

  renderer
    .command("get")
    .description("Get the current rendering engine and available engines")
    .action(async () => {
      await deviceCommand(program, "getRenderer");
    });

  renderer
    .command("set <engine>")
    .description("Switch rendering engine (webkit, chromium, gecko)")
    .action(async (engine: string) => {
      await deviceCommand(program, "setRenderer", { engine });
    });
}
