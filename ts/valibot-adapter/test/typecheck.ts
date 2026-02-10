import { expectTypeOf } from "expect-type";
import * as v from "valibot";

import {
  type InferJqOutput,
  type JqxDynamicRuntime,
  type Json,
  type JqxResult,
  type JqxTypedRuntime,
  type ValibotAdapterError,
  executeWithValibot,
  runWithInferred,
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

type InputData = {
  user: {
    name: string;
    tags: string[];
  };
  list: Array<{ id: number }>;
};

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

const inferredIdentity = runWithInferred(dynamicRuntime, {
  filter: ".",
  input: {} as InputData,
});
expectTypeOf(inferredIdentity).toEqualTypeOf<Promise<JqxResult<InputData[], string>>>();

const inferredField = runWithInferred(dynamicRuntime, {
  filter: ".user.name",
  input: {} as InputData,
});
expectTypeOf(inferredField).toEqualTypeOf<Promise<JqxResult<string[], string>>>();

const inferredIter = runWithInferred(dynamicRuntime, {
  filter: ".list[]",
  input: {} as InputData,
});
expectTypeOf(inferredIter).toEqualTypeOf<Promise<JqxResult<Array<{ id: number }>, string>>>();

const inferredFallbackUnknown = runWithInferred(dynamicRuntime, {
  filter: ".user | .name",
  input: {} as InputData,
});
expectTypeOf(inferredFallbackUnknown).toEqualTypeOf<Promise<JqxResult<unknown[], string>>>();

const inferredFallbackJson = runWithInferred(dynamicRuntime, {
  filter: ".user | .name",
  input: {} as InputData,
  fallback: "json" as const,
});
expectTypeOf(inferredFallbackJson).toEqualTypeOf<Promise<JqxResult<Json[], string>>>();

expectTypeOf<InferJqOutput<InputData, ".user.name">>().toEqualTypeOf<string>();
expectTypeOf<InferJqOutput<InputData, ".missing", "json">>().toEqualTypeOf<Json>();
