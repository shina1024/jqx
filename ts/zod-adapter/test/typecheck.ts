import { expectTypeOf } from "expect-type";
import { z } from "zod";

import {
  type JqxDynamicRuntime,
  type JqxResult,
  type JqxTypedRuntime,
  type ZodAdapterError,
  executeWithZod,
  runWithZod,
  safeExecuteWithZod,
  safeRunWithZod,
  withZ,
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

const inputSchema = z.object({
  user: z.object({ name: z.string() }),
});
const outputSchema = z.object({
  name: z.string(),
});

const runResult = safeRunWithZod(dynamicRuntime, {
  filter: ".user",
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(runResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, ZodAdapterError>>
>();

const execResult = safeExecuteWithZod(typedRuntime, {
  query: { kind: "query" },
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(execResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, ZodAdapterError>>
>();

const helper = withZ(dynamicRuntime);
const helperRunResult = helper.safeRunWithZod({
  filter: ".user",
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(helperRunResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, ZodAdapterError>>
>();

expectTypeOf(runWithZod).toEqualTypeOf<typeof safeRunWithZod>();
expectTypeOf(executeWithZod).toEqualTypeOf<typeof safeExecuteWithZod>();
