import { toAst as toQueryAst, toJqxRuntimeError } from "@shina1024/jqx-adapter-core";

import type {
  Json,
  JqxResult,
  JqxResultStream,
  JqxRuntime,
  JqxRuntimeError,
  Query,
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
  QueryAstDocument,
  QueryAstDocumentFormat,
  QueryAstDocumentVersion,
  QueryAstImportError,
  QueryAstImportResult,
  QueryInput,
  QueryOutput,
  JqxRuntime,
  JqxBackendRuntimeError,
  JqxError,
  JqxInputStringifyRuntimeError,
  JqxOutputParseRuntimeError,
  JqxResult,
  JqxResultStream,
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
  exportQueryAstDocument,
  exportTypedQueryDocument,
  fallback,
  field,
  gt,
  identity,
  importQueryAstDocument,
  ifElse,
  index,
  isQueryAst,
  iter,
  literal,
  lt,
  map,
  not_,
  or_,
  parseQueryAstDocument,
  pipe,
  QUERY_AST_DOCUMENT_FORMAT,
  QUERY_AST_DOCUMENT_VERSION,
  select,
  stringifyQueryAstDocument,
  toAst,
  tryCatch,
} from "@shina1024/jqx-adapter-core";

export {
  isJqxError,
  isJqxRuntimeError,
  runtimeErrorToMessage,
  toJqxRuntimeError,
} from "@shina1024/jqx-adapter-core";

export interface JqxBackend {
  runRaw(filter: string, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxStreamingBackend extends JqxBackend {
  runRawStream(
    filter: string,
    input: string,
  ): MaybePromise<JqxResult<AsyncIterable<string>, JqxRuntimeError>>;
}

export interface JqxTypedBackend<Q = QueryAst> extends JqxBackend {
  runQueryRaw(query: Q, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxTypedStreamingBackend<Q = QueryAst>
  extends JqxTypedBackend<Q> {
  runQueryRawStream(
    query: Q,
    input: string,
  ): MaybePromise<JqxResult<AsyncIterable<string>, JqxRuntimeError>>;
}

export interface JqxClient extends JqxRuntime {
  run(filter: string, input: Json): Promise<JqxResult<Json[], JqxRuntimeError>>;
  runRaw(filter: string, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
  runStream(filter: string, input: Json): JqxResultStream<Json, JqxRuntimeError>;
  runRawStream(filter: string, input: string): JqxResultStream<string, JqxRuntimeError>;
}

type TypedDslQuery = Query<unknown, unknown, QueryAst>;

export interface JqxTypedClient<Q = QueryAst> extends JqxClient, JqxTypedRuntime<Q> {
  query(query: Q, input: Json): Promise<JqxResult<Json[], JqxRuntimeError>>;
  queryRaw(query: Q, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
  queryStream(query: Q, input: Json): JqxResultStream<Json, JqxRuntimeError>;
  queryRawStream(query: Q, input: string): JqxResultStream<string, JqxRuntimeError>;
}

export interface JqxAstClient extends JqxTypedClient<QueryAst> {
  query(query: QueryAst | TypedDslQuery, input: Json): Promise<JqxResult<Json[], JqxRuntimeError>>;
  queryRaw(
    query: QueryAst | TypedDslQuery,
    input: string,
  ): Promise<JqxResult<string[], JqxRuntimeError>>;
  queryStream(
    query: QueryAst | TypedDslQuery,
    input: Json,
  ): JqxResultStream<Json, JqxRuntimeError>;
  queryRawStream(
    query: QueryAst | TypedDslQuery,
    input: string,
  ): JqxResultStream<string, JqxRuntimeError>;
}

function toPromise<T>(value: MaybePromise<T>): Promise<T> {
  return Promise.resolve(value);
}

function normalizeRuntimeResult<T>(
  result: JqxResult<T, JqxRuntimeError>,
): JqxResult<T, JqxRuntimeError> {
  if (result.ok) {
    return result;
  }
  return { ok: false, error: toJqxRuntimeError(result.error) };
}

function failResult<T>(error: JqxRuntimeError): JqxResult<T, JqxRuntimeError> {
  return { ok: false, error };
}

function fromArrayRuntimeCall(
  call: MaybePromise<JqxResult<string[], JqxRuntimeError>>,
): JqxResultStream<string, JqxRuntimeError> {
  return (async function* () {
    const runtimeOut = normalizeRuntimeResult(await toPromise(call));
    if (!runtimeOut.ok) {
      yield failResult<string>(runtimeOut.error);
      return;
    }
    for (const value of runtimeOut.value) {
      yield { ok: true, value };
    }
  })();
}

function fromStreamingRuntimeCall(
  call: MaybePromise<JqxResult<AsyncIterable<string>, JqxRuntimeError>>,
): JqxResultStream<string, JqxRuntimeError> {
  return (async function* () {
    const runtimeOut = normalizeRuntimeResult(await toPromise(call));
    if (!runtimeOut.ok) {
      yield failResult<string>(runtimeOut.error);
      return;
    }
    try {
      for await (const value of runtimeOut.value) {
        yield { ok: true, value };
      }
    } catch (error) {
      yield failResult<string>(toJqxRuntimeError(error));
    }
  })();
}

function decodeRawResultStream(
  rawStream: JqxResultStream<string, JqxRuntimeError>,
): JqxResultStream<Json, JqxRuntimeError> {
  return (async function* () {
    let index = 0;
    for await (const item of rawStream) {
      if (!item.ok) {
        yield item;
        return;
      }
      try {
        yield { ok: true, value: JSON.parse(item.value) as Json };
      } catch (error) {
        yield failResult<Json>({
          kind: "output_parse",
          index,
          message: error instanceof Error ? error.message : "Failed to parse output",
        });
        return;
      }
      index += 1;
    }
  })();
}

function singleErrorStream<T>(error: JqxRuntimeError): JqxResultStream<T, JqxRuntimeError> {
  return (async function* () {
    yield failResult<T>(error);
  })();
}

function encodeRuntimeInput(input: Json): JqxResult<string, JqxRuntimeError> {
  try {
    const encoded = JSON.stringify(input);
    if (typeof encoded !== "string") {
      return {
        ok: false,
        error: {
          kind: "input_stringify",
          message: "JSON.stringify returned undefined",
        },
      };
    }
    return { ok: true, value: encoded };
  } catch (error) {
    return {
      ok: false,
      error: {
        kind: "input_stringify",
        message: error instanceof Error ? error.message : "Failed to stringify input",
      },
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
        error: {
          kind: "output_parse",
          index,
          message: error instanceof Error ? error.message : "Failed to parse output",
        },
      };
    }
  }
  return { ok: true, value: parsed };
}

function hasStreamingBackend(
  backend: JqxBackend & Partial<JqxStreamingBackend>,
): backend is JqxStreamingBackend {
  return typeof backend.runRawStream === "function";
}

function hasTypedStreamingBackend<Q>(
  backend: JqxTypedBackend<Q> & Partial<JqxTypedStreamingBackend<Q>>,
): backend is JqxTypedStreamingBackend<Q> {
  return typeof backend.runQueryRawStream === "function";
}

function isTypedDslQuery(value: unknown): value is TypedDslQuery {
  if (typeof value !== "object" || value === null || !("ast" in value)) {
    return false;
  }
  const keys = Object.keys(value as Record<string, unknown>);
  return keys.length === 1 && keys[0] === "ast";
}

function normalizeAstQueryInput(query: QueryAst | TypedDslQuery): QueryAst {
  if (isTypedDslQuery(query)) {
    return toQueryAst(query);
  }
  return query;
}

function createDynamicClient(backend: JqxBackend & Partial<JqxStreamingBackend>): JqxClient {
  return {
    async runRaw(filter, input) {
      const runtimeOut = await toPromise(backend.runRaw(filter, input));
      return normalizeRuntimeResult(runtimeOut);
    },
    async run(filter, input) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return encoded;
      }
      const runtimeOut = await toPromise(backend.runRaw(filter, encoded.value));
      const normalizedOut = normalizeRuntimeResult(runtimeOut);
      if (!normalizedOut.ok) {
        return normalizedOut;
      }
      return decodeRuntimeOutputs(normalizedOut.value);
    },
    runRawStream(filter, input) {
      if (hasStreamingBackend(backend)) {
        return fromStreamingRuntimeCall(backend.runRawStream(filter, input));
      }
      return fromArrayRuntimeCall(backend.runRaw(filter, input));
    },
    runStream(filter, input) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return singleErrorStream(encoded.error);
      }
      const rawStream = hasStreamingBackend(backend)
        ? fromStreamingRuntimeCall(backend.runRawStream(filter, encoded.value))
        : fromArrayRuntimeCall(backend.runRaw(filter, encoded.value));
      return decodeRawResultStream(rawStream);
    },
  };
}

function createTypedClient<Q>(
  backend: JqxTypedBackend<Q> & Partial<JqxStreamingBackend> & Partial<JqxTypedStreamingBackend<Q>>,
): JqxTypedClient<Q> {
  const client = createDynamicClient(backend);
  const typedCore: JqxTypedClient<Q> = {
    ...client,
    queryRaw(query: Q, input: string) {
      return toPromise(backend.runQueryRaw(query, input)).then(normalizeRuntimeResult);
    },
    async query(query: Q, input: Json) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return encoded;
      }
      const runtimeOut = await toPromise(backend.runQueryRaw(query, encoded.value));
      const normalizedOut = normalizeRuntimeResult(runtimeOut);
      if (!normalizedOut.ok) {
        return normalizedOut;
      }
      return decodeRuntimeOutputs(normalizedOut.value);
    },
    queryRawStream(query: Q, input: string) {
      if (hasTypedStreamingBackend(backend)) {
        return fromStreamingRuntimeCall(backend.runQueryRawStream(query, input));
      }
      return fromArrayRuntimeCall(backend.runQueryRaw(query, input));
    },
    queryStream(query: Q, input: Json) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return singleErrorStream<Json>(encoded.error);
      }
      const rawStream = hasTypedStreamingBackend(backend)
        ? fromStreamingRuntimeCall(backend.runQueryRawStream(query, encoded.value))
        : fromArrayRuntimeCall(backend.runQueryRaw(query, encoded.value));
      return decodeRawResultStream(rawStream);
    },
  };
  return typedCore;
}

function createAstClient(
  backend: JqxTypedBackend<QueryAst> &
    Partial<JqxStreamingBackend> &
    Partial<JqxTypedStreamingBackend<QueryAst>>,
): JqxAstClient {
  const typed = createTypedClient<QueryAst>(backend);
  return {
    ...typed,
    queryRaw(query: QueryAst | TypedDslQuery, input: string) {
      return typed.queryRaw(normalizeAstQueryInput(query), input);
    },
    query(query: QueryAst | TypedDslQuery, input: Json) {
      return typed.query(normalizeAstQueryInput(query), input);
    },
    queryRawStream(query: QueryAst | TypedDslQuery, input: string) {
      return typed.queryRawStream(normalizeAstQueryInput(query), input);
    },
    queryStream(query: QueryAst | TypedDslQuery, input: Json) {
      return typed.queryStream(normalizeAstQueryInput(query), input);
    },
  };
}

export function createJqx(backend: JqxBackend & Partial<JqxStreamingBackend>): JqxClient {
  return createDynamicClient(backend);
}

export function createTypedJqx<Q>(
  backend: JqxTypedBackend<Q> & Partial<JqxStreamingBackend> & Partial<JqxTypedStreamingBackend<Q>>,
): JqxTypedClient<Q> {
  return createTypedClient(backend);
}

export function createAstJqx(
  backend: JqxTypedBackend<QueryAst> &
    Partial<JqxStreamingBackend> &
    Partial<JqxTypedStreamingBackend<QueryAst>>,
): JqxAstClient {
  return createAstClient(backend);
}
