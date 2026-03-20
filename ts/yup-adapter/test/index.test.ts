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
