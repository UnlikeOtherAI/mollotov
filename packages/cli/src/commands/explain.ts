import type { Command } from "commander";
import { explainCommand } from "../help/explain.js";

export function registerExplain(program: Command): void {
  program
    .command("explain <command>")
    .description("Explain a command in natural language (for LLMs)")
    .action((command: string) => {
      console.log(explainCommand(command));
    });
}
