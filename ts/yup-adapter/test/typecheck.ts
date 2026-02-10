import { expectTypeOf } from "expect-type";
import * as yup from "yup";

import {
  type InferJqOutput,
  type JqxDynamicRuntime,
  type Json,
  type JqxResult,
  type JqxTypedRuntime,
  type YupAdapterError,
  executeWithYup,
  runWithInferred,
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

type InputData = {
  user: {
    name: string;
    tags: string[];
  };
  list: Array<{ id: number }>;
};

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
