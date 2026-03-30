import type { Command } from "commander";
import { deviceCommand } from "./helpers.js";

export function registerHome(program: Command): void {
  const home = program
    .command("home")
    .description("Manage the device home page");

  home
    .command("set <url>")
    .description("Set the home page URL")
    .action(async (url: string) => {
      await deviceCommand(program, "setHome", { url });
    });

  home
    .command("get")
    .description("Get the current home page URL")
    .action(async () => {
      await deviceCommand(program, "getHome");
    });
}
