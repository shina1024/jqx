import * as assert from "node:assert/strict";
import { test } from "node:test";
import * as yup from "yup";

import { registerAdapterContractCases } from "../../adapter-core/test/adapter_contract_cases.js";
import { createAdapter, createQueryAdapter } from "@shina1024/jqx-yup-adapter";

void test("package-name import resolves standalone adapter entrypoint", async () => {
  const pkg = await import("@shina1024/jqx-yup-adapter");
  assert.equal(typeof pkg.createAdapter, "function");
  assert.equal(typeof pkg.createQueryAdapter, "function");
});

void test("yup adapter preserves native validation issues", async () => {
  const adapter = createAdapter({
    run() {
      return { ok: true, value: [] };
    },
  });

  const result = await adapter.filter({
    filter: ".",
    input: { user: { name: 1 } },
    inputSchema: yup
      .object({
        user: yup
          .object({
            name: yup.string().required(),
          })
          .required(),
      })
      .required(),
    outputSchema: yup.string().required(),
  });

  assert.equal(result.ok, false);
  if (result.ok || result.error.kind !== "input_validation") {
    return;
  }

  assert.equal(result.error.message, "Input does not match schema");
  assert.equal(result.error.issues[0]?.name, "ValidationError");
  assert.equal(result.error.issues[0]?.path, "user.name");
  assert.equal(result.error.issues[0]?.type, "typeError");
});

registerAdapterContractCases({
  label: "yup",
  createDynamicAdapter(runtime) {
    return createAdapter(runtime);
  },
  createQueryAdapter(runtime) {
    return createQueryAdapter(runtime);
  },
  schemas: {
    userNameInput() {
      return yup
        .object({
          user: yup
            .object({
              name: yup.string().required(),
            })
            .required(),
        })
        .required();
    },
    xNumberInput() {
      return yup
        .object({
          x: yup.number().required(),
        })
        .required();
    },
    stringOutput() {
      return yup.string().required();
    },
    numberOutput() {
      return yup.number().required();
    },
  },
});
