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
