import { z } from "zod";

import { registerAdapterContractCases } from "../../adapter-core/test/adapter_contract_cases.js";
import { createAdapter } from "../src/index.js";

registerAdapterContractCases({
  label: "zod",
  createDynamicAdapter(runtime) {
    return createAdapter(runtime);
  },
  createTypedAdapter(runtime) {
    return createAdapter(runtime);
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
