import * as v from "valibot";

import { registerAdapterContractCases } from "../../adapter-core/test/adapter_contract_cases.js";
import { createAdapter, createQueryAdapter } from "../src/index.js";

registerAdapterContractCases({
  label: "valibot",
  createDynamicAdapter(runtime) {
    return createAdapter(runtime);
  },
  createTypedAdapter(runtime) {
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
