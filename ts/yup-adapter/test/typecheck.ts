import { expectTypeOf } from "expect-type";
import * as yup from "yup";

import {
  type JqxDynamicRuntime,
  type JqxResult,
  type JqxTypedRuntime,
  type YupAdapterError,
  executeWithYup,
  runWithYup,
  safeExecuteWithYup,
  safeRunWithYup,
  withY,
} from "../src/index.js";

const dynamicRuntime: JqxDynamicRuntime = {
  run() {
    return { ok: true, value: ['{"name":"alice"}'] };
  },
};

const typedRuntime: JqxTypedRuntime<{ kind: "query" }> = {
  runQuery() {
    return { ok: true, value: ['{"name":"alice"}'] };
  },
};

const inputSchema = yup
  .object({
    user: yup
      .object({
        name: yup.string().defined(),
      })
      .defined(),
  })
  .defined();

const outputSchema = yup
  .object({
    name: yup.string().defined(),
  })
  .defined();

const runResult = safeRunWithYup(dynamicRuntime, {
  filter: ".user",
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(runResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, YupAdapterError>>
>();

const execResult = safeExecuteWithYup(typedRuntime, {
  query: { kind: "query" },
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(execResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, YupAdapterError>>
>();

const helper = withY(dynamicRuntime);
const helperRunResult = helper.safeRunWithYup({
  filter: ".user",
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(helperRunResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, YupAdapterError>>
>();

expectTypeOf(runWithYup).toEqualTypeOf<typeof safeRunWithYup>();
expectTypeOf(executeWithYup).toEqualTypeOf<typeof safeExecuteWithYup>();
