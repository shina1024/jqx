import { expectTypeOf } from "expect-type";
import * as yup from "yup";

import {
  type AdapterError,
  type FilterOptions,
  type InferJqOutput,
  type InferredOptions,
  type JqxRuntime,
  type JqxResult,
  type JqxQueryRuntime,
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

const inferredIdentity = dynamicAdapter.inferred({
  filter: ".",
  input: {} as InputData,
});
expectTypeOf(inferredIdentity).toEqualTypeOf<Promise<JqxResult<InputData[], string>>>();

const inferredField = dynamicAdapter.inferred({
  filter: ".user.name",
  input: {} as InputData,
});
expectTypeOf(inferredField).toEqualTypeOf<Promise<JqxResult<string[], string>>>();

const inferredIter = dynamicAdapter.inferred({
  filter: ".list[]",
  input: {} as InputData,
});
expectTypeOf(inferredIter).toEqualTypeOf<Promise<JqxResult<Array<{ id: number }>, string>>>();

const inferredFallbackUnknown = dynamicAdapter.inferred({
  filter: ".user | .name",
  input: {} as InputData,
});
expectTypeOf(inferredFallbackUnknown).toEqualTypeOf<Promise<JqxResult<unknown[], string>>>();

const inferredFallbackJson = dynamicAdapter.inferred({
  filter: ".user | .name",
  input: {} as InputData,
  fallback: "json" as const,
});
expectTypeOf(inferredFallbackJson).toEqualTypeOf<Promise<JqxResult<Json[], string>>>();

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
  fallback?: "unknown" | undefined;
}>();

expectTypeOf<InferJqOutput<InputData, ".user.name">>().toEqualTypeOf<string>();
expectTypeOf<InferJqOutput<InputData, ".missing", "json">>().toEqualTypeOf<Json>();
