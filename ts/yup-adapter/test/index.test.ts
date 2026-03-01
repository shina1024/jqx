import * as yup from "yup";

import { registerAdapterContractCases } from "../../adapter-core/test/adapter_contract_cases.js";
import { createAdapter } from "../src/index.js";

registerAdapterContractCases({
  label: "yup",
  createDynamicAdapter(runtime) {
    return createAdapter(runtime);
  },
  createTypedAdapter(runtime) {
    return createAdapter(runtime);
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
