import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerOrientation(program: Command): void {
  const orientation = program
    .command("orientation")
    .description("Manage device orientation");

  orientation
    .command("get")
    .description("Get the current orientation and lock state")
    .action(async () => {
      await deviceCommand(program, "getOrientation");
    });

  orientation
    .command("set <mode>")
    .description("Set orientation (portrait, landscape, auto)")
    .action(async (mode: string) => {
      await deviceCommand(program, "setOrientation", { orientation: mode });
    });
}
