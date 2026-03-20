import * as assert from "node:assert/strict";
import { test } from "node:test";
import { z } from "zod";

import { registerAdapterContractCases } from "../../adapter-core/test/adapter_contract_cases.js";
import { createAdapter, createQueryAdapter } from "@shina1024/jqx-zod-adapter";

void test("package-name import resolves standalone adapter entrypoint", async () => {
  const pkg = await import("@shina1024/jqx-zod-adapter");
  assert.equal(typeof pkg.createAdapter, "function");
  assert.equal(typeof pkg.createQueryAdapter, "function");
});

registerAdapterContractCases({
  label: "zod",
  createDynamicAdapter(runtime) {
    return createAdapter(runtime);
  },
  createQueryAdapter(runtime) {
    return createQueryAdapter(runtime);
  },
  schemas: {
    userNameInput() {
      return z.object({
        user: z.object({ name: z.string() }),
      });
    },
    xNumberInput() {
      return z.object({ x: z.number() });
    },
    stringOutput() {
      return z.string();
    },
    numberOutput() {
      return z.number();
    },
  },
});
