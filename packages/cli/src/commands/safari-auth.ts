import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerSafariAuth(program: Command): void {
  program
    .command("safari-auth [url]")
    .description("Open a Safari-backed authentication session")
    .action(async (url?: string) => {
      await deviceCommand(program, "safariAuth", url ? { url } : undefined);
    });
}
