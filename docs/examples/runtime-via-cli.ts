import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { bindRuntime, type JqxRuntimeBinding } from "jqx";

const execFileAsync = promisify(execFile);
const MAX_BUFFER_BYTES = 10 * 1024 * 1024;

function splitJsonLines(stdout: string): string[] {
  return stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

// Real runtime bridge for examples:
// delegates filter execution to jqx CLI via `moon run --target native cmd`.
export function createMoonCliRuntime(repoRoot: string) {
  const binding: JqxRuntimeBinding = {
    async run(filter, input) {
      try {
        const out = await execFileAsync(
          "moon",
          ["run", "--target", "native", "cmd", "--", filter, input],
          {
            cwd: repoRoot,
            maxBuffer: MAX_BUFFER_BYTES,
          },
        );
        return { ok: true as const, value: splitJsonLines(out.stdout) };
      } catch (error) {
        return { ok: false as const, error: toErrorMessage(error) };
      }
    },
  };
  return bindRuntime(binding);
}
