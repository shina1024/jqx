import * as assert from "node:assert/strict";
import { test } from "node:test";
import * as v from "valibot";

import { registerAdapterContractCases } from "../../adapter-core/test/adapter_contract_cases.js";
import { createAdapter, createQueryAdapter } from "@shina1024/jqx-valibot-adapter";

void test("package-name import resolves standalone adapter entrypoint", async () => {
  const pkg = await import("@shina1024/jqx-valibot-adapter");
  assert.equal(typeof pkg.createAdapter, "function");
  assert.equal(typeof pkg.createQueryAdapter, "function");
});

void test("valibot adapter preserves native validation issues", async () => {
  const adapter = createAdapter({
    run() {
      return { ok: true, value: [] };
    },
  });

  const result = await adapter.filter({
    filter: ".",
    input: { user: { name: 1 } },
    inputSchema: v.object({
      user: v.object({ name: v.string() }),
    }),
    outputSchema: v.string(),
  });

  assert.equal(result.ok, false);
  if (result.ok || result.error.kind !== "input_validation") {
    return;
  }

  assert.equal(result.error.message, "Input does not match schema");
  assert.equal(result.error.issues[0]?.kind, "schema");
  assert.equal(result.error.issues[0]?.type, "string");
  assert.equal(result.error.issues[0]?.path?.[1]?.key, "name");
});

registerAdapterContractCases({
  label: "valibot",
  createDynamicAdapter(runtime) {
    return createAdapter(runtime);
  },
  createQueryAdapter(runtime) {
    return createQueryAdapter(runtime);
  },
  schemas: {
    userNameInput() {
      return v.object({
        user: v.object({
          name: v.string(),
        }),
      });
    },
    xNumberInput() {
      return v.object({
        x: v.number(),
      });
    },
    stringOutput() {
      return v.string();
    },
    numberOutput() {
      return v.number();
    },
  },
});
