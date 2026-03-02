import type {
  Json,
  JqxResult,
  JqxRuntime,
  JqxRuntimeError,
  QueryAst,
  JqxTypedRuntime,
  MaybePromise,
} from "@shina1024/jqx-adapter-core";

export type {
  InferTypedQueryOutput,
  InferJqOutput,
  InferenceFallbackMode,
  InferredOptions,
  Json,
  Query,
  QueryAst,
  QueryInput,
  QueryOutput,
  JqxRuntime,
  JqxError,
  JqxResult,
  JqxRuntimeError,
  JqxTypedRuntime,
  MaybePromise,
} from "@shina1024/jqx-adapter-core";

export {
  add,
  and_,
  call,
  comma,
  eq,
  fallback,
  field,
  gt,
  identity,
  ifElse,
  index,
  iter,
  literal,
  lt,
  map,
  not_,
  or_,
  pipe,
  select,
  toAst,
  tryCatch,
} from "@shina1024/jqx-adapter-core";

export interface JqxBackend {
  runRaw(filter: string, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxTypedBackend<Q = QueryAst> extends JqxBackend {
  runQueryRaw(query: Q, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxClient extends JqxRuntime {
  run(filter: string, input: unknown): Promise<JqxResult<Json[], JqxRuntimeError>>;
  runRaw(filter: string, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxTypedClient<Q = QueryAst> extends JqxClient, JqxTypedRuntime<Q> {
  query(query: Q, input: unknown): Promise<JqxResult<Json[], JqxRuntimeError>>;
  queryRaw(query: Q, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
}

function toPromise<T>(value: MaybePromise<T>): Promise<T> {
  return Promise.resolve(value);
}

function encodeRuntimeInput(input: unknown): JqxResult<string, JqxRuntimeError> {
  try {
    const encoded = JSON.stringify(input);
    if (typeof encoded !== "string") {
      return {
        ok: false,
        error: "input_stringify failed: JSON.stringify returned undefined",
      };
    }
    return { ok: true, value: encoded };
  } catch (error) {
    return {
      ok: false,
      error: `input_stringify failed: ${error instanceof Error ? error.message : "Failed to stringify input"}`,
    };
  }
}

function decodeRuntimeOutputs(rawValues: string[]): JqxResult<Json[], JqxRuntimeError> {
  const parsed: Json[] = [];
  for (const [index, raw] of rawValues.entries()) {
    try {
      parsed.push(JSON.parse(raw) as Json);
    } catch (error) {
      return {
        ok: false,
        error: `output_parse at index ${index}: ${error instanceof Error ? error.message : "Failed to parse output"}`,
      };
    }
  }
  return { ok: true, value: parsed };
}

function hasTypedBackend<Q>(
  backend: JqxBackend & Partial<JqxTypedBackend<Q>>,
): backend is JqxTypedBackend<Q> {
  return typeof backend.runQueryRaw === "function";
}

export function createJqx<Q>(backend: JqxTypedBackend<Q>): JqxTypedClient<Q>;
export function createJqx(backend: JqxBackend): JqxClient;
export function createJqx<Q>(
  backend: JqxBackend & Partial<JqxTypedBackend<Q>>,
): JqxClient | JqxTypedClient<Q> {
  const client: JqxClient = {
    runRaw(filter, input) {
      return toPromise(backend.runRaw(filter, input));
    },
    async run(filter, input) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return encoded;
      }
      const runtimeOut = await toPromise(backend.runRaw(filter, encoded.value));
      if (!runtimeOut.ok) {
        return runtimeOut;
      }
      return decodeRuntimeOutputs(runtimeOut.value);
    },
  };

  if (hasTypedBackend(backend)) {
    const typedClient: JqxTypedClient<Q> = {
      ...client,
      queryRaw(query, input) {
        return toPromise(backend.runQueryRaw(query, input));
      },
      async query(query, input) {
        const encoded = encodeRuntimeInput(input);
        if (!encoded.ok) {
          return encoded;
        }
        const runtimeOut = await toPromise(backend.runQueryRaw(query, encoded.value));
        if (!runtimeOut.ok) {
          return runtimeOut;
        }
        return decodeRuntimeOutputs(runtimeOut.value);
      },
    };
    return typedClient;
  }

  return client;
}
