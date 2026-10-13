import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

test("Windows strftime exceptions remain attached to strftime after fixture sync", () => {
  const cases = JSON.parse(
    readFileSync(new URL("./jq_compat_cases.upstream.json", import.meta.url), "utf8"),
  );
  const exceptions = cases.filter(
    (entry) => entry.compat_ledger_id === "jq-1.8.2-windows-strftime-encoding",
  );
  assert.equal(exceptions.length, 2);
  for (const entry of exceptions) {
    assert.equal(entry.compat_status, "temporary_exception");
    assert.deepEqual(entry.compat_platforms, ["win32"]);
    assert.match(entry.filter, /^strftime\(/);
  }
});

test("case override follows a fixture when upstream inserts lines", () => {
  const directory = mkdtempSync(path.join(tmpdir(), "jq-upstream-import-"));
  try {
    const fixture = path.join(directory, "jq.test");
    const config = path.join(directory, "config.json");
    const output = path.join(directory, "cases.json");
    writeFileSync(
      config,
      JSON.stringify({
        source_root: directory,
        enabled_test_files: ["jq.test"],
        case_overrides: [
          {
            source_file: "jq.test",
            filter: 'strftime("%A")',
            input: "0",
            compat_status: "temporary_exception",
          },
        ],
      }),
    );

    for (const comments of ["", "# new upstream coverage\n# another case\n"]) {
      writeFileSync(fixture, `${comments}strftime("%A")\n0\n"Thursday"\n`);
      const result = spawnSync(
        process.execPath,
        [fileURLToPath(new URL("./jq_upstream_import.mjs", import.meta.url)), "--config", config, "--output", output],
        { encoding: "utf8" },
      );
      assert.equal(result.status, 0, result.stderr);
      const cases = JSON.parse(readFileSync(output, "utf8"));
      assert.equal(cases.length, 1);
      assert.equal(cases[0].compat_status, "temporary_exception");
      assert.equal(cases[0].source_line, comments === "" ? 1 : 3);
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
