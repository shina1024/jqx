import { expectTypeOf } from "expect-type";
import * as v from "valibot";

import {
  type AdapterError,
  type FilterOptions,
  type InferJqOutput,
  type InferredOptions,
  type JqxRuntime,
  type JqxResult,
  type JqxQueryRuntime,
  type JqxRuntimeError,
  type Json,
  type QueryOptions,
  createAdapter,
  createQueryAdapter,
} from "../src/index.js";

type InputData = {
  user: {
    name: string;
    tags: string[];
  };
  list: Array<{ id: number }>;
};

const inputSchema = v.object({
  user: v.object({ name: v.string() }),
});

const outputSchema = v.object({
  name: v.string(),
});

const dynamicRuntime: JqxRuntime = {
  run() {
    return { ok: true, value: [{ name: "alice" }] };
  },
};

const dynamicAdapter = createAdapter(dynamicRuntime);
const runResult = dynamicAdapter.filter({
  filter: ".user",
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(runResult).toEqualTypeOf<Promise<JqxResult<Array<{ name: string }>, AdapterError>>>();

const inferredIdentity = dynamicAdapter.infer({
  filter: ".",
  input: {} as InputData,
});
expectTypeOf(inferredIdentity).toEqualTypeOf<Promise<JqxResult<InputData[], JqxRuntimeError>>>();

const inferredField = dynamicAdapter.infer({
  filter: ".user.name",
  input: {} as InputData,
});
expectTypeOf(inferredField).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();

const inferredIter = dynamicAdapter.infer({
  filter: ".list[]",
  input: {} as InputData,
});
expectTypeOf(inferredIter).toEqualTypeOf<
  Promise<JqxResult<Array<{ id: number }>, JqxRuntimeError>>
>();

const inferredFallbackUnknown = dynamicAdapter.infer({
  filter: ".user | .name",
  input: {} as InputData,
});
expectTypeOf(inferredFallbackUnknown).toEqualTypeOf<
  Promise<JqxResult<unknown[], JqxRuntimeError>>
>();

const inferredFallbackJson = dynamicAdapter.infer({
  filter: ".user | .name",
  input: {} as InputData,
  fallback: "json" as const,
});
expectTypeOf(inferredFallbackJson).toEqualTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();

const queryRuntime: JqxRuntime & JqxQueryRuntime<{ kind: "query" }> = {
  run() {
    return { ok: true, value: [] };
  },
  query() {
    return { ok: true, value: [{ name: "alice" }] };
  },
};

const queryAdapter = createQueryAdapter(queryRuntime);
const queryResult = queryAdapter.query({
  query: { kind: "query" },
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});
expectTypeOf(queryResult).toEqualTypeOf<
  Promise<JqxResult<Array<{ name: string }>, AdapterError>>
>();

const dynamicFromQuery = createAdapter(queryRuntime);
// @ts-expect-error query is only available from createQueryAdapter.
dynamicFromQuery.query({
  query: { kind: "query" },
  input: { user: { name: "alice" } },
  inputSchema,
  outputSchema,
});

expectTypeOf<FilterOptions<typeof inputSchema, typeof outputSchema>>().toEqualTypeOf<{
  filter: string;
  input: unknown;
  inputSchema: typeof inputSchema;
  outputSchema: typeof outputSchema;
}>();

expectTypeOf<
  QueryOptions<{ kind: "query" }, typeof inputSchema, typeof outputSchema>
>().toEqualTypeOf<{
  query: { kind: "query" };
  input: unknown;
  inputSchema: typeof inputSchema;
  outputSchema: typeof outputSchema;
}>();

expectTypeOf<InferredOptions<".user.name", InputData>>().toEqualTypeOf<{
  filter: ".user.name";
  input: InputData;
  fallback?: "unknown";
}>();

expectTypeOf<InferJqOutput<InputData, ".user.name">>().toEqualTypeOf<string>();
expectTypeOf<InferJqOutput<InputData, ".missing", "json">>().toEqualTypeOf<Json>();
expectTypeOf<Extract<AdapterError, { kind: "input_validation" }>["issues"]>().toEqualTypeOf<
  v.BaseIssue<unknown>[]
>();
expectTypeOf<Extract<AdapterError, { kind: "output_validation" }>["issues"]>().toEqualTypeOf<
  v.BaseIssue<unknown>[]
>();
