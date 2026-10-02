import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

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
