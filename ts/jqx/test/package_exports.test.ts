import * as assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";

const require = createRequire(import.meta.url);
const packageJson = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as {
  exports: Record<string, { import?: string; require?: string; types?: string }>;
};
const runtimeEntryPoints = [".", "./bind"];
const removedAdapterSubpaths = ["./zod", "./yup", "./valibot"];

void test("root export map stays runtime-only", () => {
  assert.deepEqual(Object.keys(packageJson.exports).sort(), runtimeEntryPoints.slice().sort());
  for (const subpath of removedAdapterSubpaths) {
    assert.equal(subpath in packageJson.exports, false, `Unexpected root adapter export: ${subpath}`);
  }
});

void test("package export map points at built artifact files", () => {
  for (const [subpath, conditions] of Object.entries(packageJson.exports)) {
    for (const target of [conditions.import, conditions.require, conditions.types]) {
      assert.equal(
        typeof target,
        "string",
        `Expected ${subpath} to declare import/require/types targets`,
      );
      assert.equal(
        existsSync(new URL(`..\\${target}`.replaceAll("\\", "/"), import.meta.url)),
        true,
        `Missing built artifact for ${subpath}: ${target}`,
      );
    }
  }
});

void test("package-name ESM imports resolve root and bind entrypoints", async () => {
  const root = await import("@shina1024/jqx");
  assert.equal(typeof root.run, "function");
  assert.equal(typeof root.compile, "function");
  assert.equal(typeof root.parseJson, "function");

  const bind = await import("@shina1024/jqx/bind");
  assert.equal(typeof bind.bindRuntime, "function");
  assert.equal(typeof bind.bindQueryRuntime, "function");
});

void test("package-name CJS requires resolve root and bind entrypoints", () => {
  const root = require("@shina1024/jqx") as {
    run?: unknown;
    compile?: unknown;
    parseJson?: unknown;
  };
  assert.equal(typeof root.run, "function");
  assert.equal(typeof root.compile, "function");
  assert.equal(typeof root.parseJson, "function");

  const bind = require("@shina1024/jqx/bind") as {
    bindRuntime?: unknown;
    bindQueryRuntime?: unknown;
  };
  assert.equal(typeof bind.bindRuntime, "function");
  assert.equal(typeof bind.bindQueryRuntime, "function");
});
