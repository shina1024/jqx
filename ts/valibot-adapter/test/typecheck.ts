import { expectTypeOf } from "expect-type";
import * as v from "valibot";

import {
  type JqxDynamicRuntime,
  type JqxResult,
  type JqxTypedRuntime,
  type ValibotAdapterError,
  executeWithValibot,
  runWithValibot,
  safeExecuteWithValibot,
  safeRunWithValibot,
  withV,
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

const inputSchema = v.object({
  user: v.object({ name: v.string() }),
});

const outputSchema = v.object({
  name: v.string(),
});

const runResult = safeRunWithValibot(dynamicRuntime, {
  filter: ".user",
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(runResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, ValibotAdapterError>>
>();

const execResult = safeExecuteWithValibot(typedRuntime, {
  query: { kind: "query" },
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(execResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, ValibotAdapterError>>
>();

const helper = withV(dynamicRuntime);
const helperRunResult = helper.safeRunWithValibot({
  filter: ".user",
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(helperRunResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, ValibotAdapterError>>
>();

expectTypeOf(runWithValibot).toEqualTypeOf<typeof safeRunWithValibot>();
expectTypeOf(executeWithValibot).toEqualTypeOf<typeof safeExecuteWithValibot>();
