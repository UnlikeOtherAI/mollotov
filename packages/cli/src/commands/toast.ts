import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerToast(program: Command): void {
  program
    .command("toast <message>")
    .description("Show a toast message overlay on the device")
    .action(async (message: string) => {
      await deviceCommand(program, "toast", { message });
    });
}
