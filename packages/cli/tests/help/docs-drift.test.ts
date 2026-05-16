import { describe, it, expect } from "vitest";
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Documentation drift guard.
 *
 * For every `program.command(...)` / `<group>.command(...)` call in
 * `packages/cli/src/commands/`, this test asserts that the resulting CLI
 * command phrase (e.g. `discover`, `tab new`, `viewport-preset list`) is
 * documented in `docs/cli.md` as either a section heading or backtick-quoted
 * text following the literal token `kelpie `.
 *
 * The intent is to catch drift cheaply, not to enforce one canonical format.
 * The check is a substring match on `kelpie <phrase>` (with adjacent space,
 * end-of-line, or backtick allowed afterwards) so command tables and
 * inline mentions both count.
 */

const here = dirname(fileURLToPath(import.meta.url));
const commandsDir = join(here, "..", "..", "src", "commands");
const docsPath = join(here, "..", "..", "..", "..", "docs", "cli.md");

/** Pattern: `name.command("phrase ...` — captures the variable name and the literal command head. */
const COMMAND_CALL = /(\w+)\s*\.command\(\s*["']([a-z][^"'<\s]*)/g;

/** Pattern: `const NAME = program.command("phrase")` — captures the variable that aliases a top-level group. */
const GROUP_DECL = /(?:const|let|var)\s+(\w+)\s*=\s*program\s*\.command\(\s*["']([a-z][^"'<\s]*)/g;

interface CommandPhrase {
  phrase: string;
  sourceFile: string;
}

function loadSourceFiles(): { name: string; content: string }[] {
  return readdirSync(commandsDir)
    .filter((name) => name.endsWith(".ts") && !name.endsWith(".d.ts"))
    .filter((name) => name !== "index.ts" && name !== "helpers.ts")
    .map((name) => ({
      name,
      content: readFileSync(join(commandsDir, name), "utf8"),
    }));
}

function extractCommandPhrases(source: string, fileName: string): CommandPhrase[] {
  // First pass: collect group variables in this file and their command heads.
  const groupVarToHead = new Map<string, string>();
  for (const match of source.matchAll(GROUP_DECL)) {
    groupVarToHead.set(match[1], match[2]);
  }

  // Second pass: every .command("...") becomes a phrase. If the receiver is a
  // known group var, prefix with its head. Otherwise it is a top-level command.
  const phrases: CommandPhrase[] = [];
  for (const match of source.matchAll(COMMAND_CALL)) {
    const receiver = match[1];
    const head = match[2];
    const groupHead = groupVarToHead.get(receiver);
    // Skip the group-declaration line itself when we re-encounter it here:
    // commander treats `program.command("geo")` as both the group definition
    // and a usable command (e.g. `kelpie geo --help`). We still want it
    // documented somewhere, so keep it as a phrase.
    if (groupHead && receiver !== "program") {
      phrases.push({ phrase: `${groupHead} ${head}`, sourceFile: fileName });
    } else {
      phrases.push({ phrase: head, sourceFile: fileName });
    }
  }
  return phrases;
}

function docMentions(doc: string, phrase: string): boolean {
  // Allow `kelpie <phrase>` followed by space, end-of-line, backtick, hyphen-arg, etc.
  const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`kelpie\\s+${escaped}(?:[\\s\`<\\-]|$)`, "m");
  return pattern.test(doc);
}

describe("docs/cli.md is in sync with CLI command surface", () => {
  const doc = readFileSync(docsPath, "utf8");
  const sourceFiles = loadSourceFiles();
  const allPhrases = sourceFiles.flatMap((f) => extractCommandPhrases(f.content, f.name));

  it("sanity: extracted at least 40 command phrases", () => {
    expect(allPhrases.length).toBeGreaterThanOrEqual(40);
  });

  for (const { phrase, sourceFile } of allPhrases) {
    it(`docs/cli.md documents \`kelpie ${phrase}\` (from ${sourceFile})`, () => {
      expect(docMentions(doc, phrase), `Expected docs/cli.md to mention 'kelpie ${phrase}'`).toBe(true);
    });
  }
});
