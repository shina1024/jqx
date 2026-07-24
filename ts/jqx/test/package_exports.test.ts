import * as assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { test } from "vite-plus/test";

const packageJson = JSON.parse(
  readFileSync(new URL("../package.json", import.meta.url), "utf8"),
) as {
  exports: Record<string, { import?: string; types?: string }>;
};
const runtimeEntryPoints = [".", "./bind"];
const removedAdapterSubpaths = ["./zod", "./yup", "./valibot"];

test("root export map stays runtime-only", () => {
  assert.deepEqual(Object.keys(packageJson.exports).sort(), runtimeEntryPoints.slice().sort());
  for (const subpath of removedAdapterSubpaths) {
    assert.equal(
      subpath in packageJson.exports,
      false,
      `Unexpected root adapter export: ${subpath}`,
    );
  }
});

test("package export map points at built artifact files", () => {
  for (const [subpath, conditions] of Object.entries(packageJson.exports)) {
    for (const target of [conditions.import, conditions.types]) {
      assert.equal(
        typeof target,
        "string",
        `Expected ${subpath} to declare import/types targets`,
      );
      assert.equal(
        existsSync(new URL(`..\\${target}`.replaceAll("\\", "/"), import.meta.url)),
        true,
        `Missing built artifact for ${subpath}: ${target}`,
      );
    }
  }
});

test("package-name ESM imports resolve root and bind entrypoints", async () => {
  const root = await import("@shina1024/jqx");
  assert.equal(typeof root.run, "function");
  assert.equal(typeof root.compile, "function");
  assert.equal(typeof root.parseJson, "function");

  const bind = await import("@shina1024/jqx/bind");
  assert.equal(typeof bind.bindRuntime, "function");
  assert.equal(typeof bind.bindQueryRuntime, "function");
});
