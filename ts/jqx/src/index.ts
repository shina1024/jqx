import { toAst as toQueryAst, toJqxRuntimeError } from "@shina1024/jqx-adapter-core";

import type {
  Json,
  JqxResult,
  JqxResultStream,
  JqxRuntime,
  JqxRuntimeError,
  Query,
  QueryAst,
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
  JqxQueryRuntime,
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

export interface JqxJsonTextRuntime {
  runJsonText(filter: string, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxJsonTextStreamingRuntime extends JqxJsonTextRuntime {
  runJsonTextStream(
    filter: string,
    input: string,
  ): MaybePromise<JqxResult<AsyncIterable<string>, JqxRuntimeError>>;
}

export interface JqxQueryJsonTextRuntime<Q = QueryAst> extends JqxJsonTextRuntime {
  runQueryJsonText(query: Q, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxQueryJsonTextStreamingRuntime<Q = QueryAst>
  extends JqxQueryJsonTextRuntime<Q> {
  runQueryJsonTextStream(
    query: Q,
    input: string,
  ): MaybePromise<JqxResult<AsyncIterable<string>, JqxRuntimeError>>;
}

export interface JqxClient extends JqxRuntime {
  run(filter: string, input: Json): Promise<JqxResult<Json[], JqxRuntimeError>>;
  runJsonText(filter: string, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
  runStream(filter: string, input: Json): JqxResultStream<Json, JqxRuntimeError>;
  runJsonTextStream(filter: string, input: string): JqxResultStream<string, JqxRuntimeError>;
}

type TypedDslQuery = Query<unknown, unknown, QueryAst>;
type QueryInputFor<Q> = Q extends QueryAst ? Q | TypedDslQuery : Q;

export interface JqxQueryClient<Q = QueryAst> extends JqxClient {
  query(query: QueryInputFor<Q>, input: Json): Promise<JqxResult<Json[], JqxRuntimeError>>;
  queryJsonText(query: QueryInputFor<Q>, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
  queryStream(query: QueryInputFor<Q>, input: Json): JqxResultStream<Json, JqxRuntimeError>;
  queryJsonTextStream(query: QueryInputFor<Q>, input: string): JqxResultStream<string, JqxRuntimeError>;
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

function hasStreamingJsonTextRuntime(
  runtime: JqxJsonTextRuntime & Partial<JqxJsonTextStreamingRuntime>,
): runtime is JqxJsonTextStreamingRuntime {
  return typeof runtime.runJsonTextStream === "function";
}

function hasQueryStreamingJsonTextRuntime<Q>(
  runtime: JqxQueryJsonTextRuntime<Q> & Partial<JqxQueryJsonTextStreamingRuntime<Q>>,
): runtime is JqxQueryJsonTextStreamingRuntime<Q> {
  return typeof runtime.runQueryJsonTextStream === "function";
}

function isTypedDslQuery(value: unknown): value is TypedDslQuery {
  if (typeof value !== "object" || value === null || !("ast" in value)) {
    return false;
  }
  const keys = Object.keys(value as Record<string, unknown>);
  return keys.length === 1 && keys[0] === "ast";
}

function normalizeQueryInput<Q>(query: QueryInputFor<Q>): Q {
  if (isTypedDslQuery(query)) {
    return toQueryAst(query) as Q;
  }
  return query as Q;
}

function createDynamicRuntime(runtime: JqxJsonTextRuntime & Partial<JqxJsonTextStreamingRuntime>): JqxClient {
  return {
    async runJsonText(filter, input) {
      const runtimeOut = await toPromise(runtime.runJsonText(filter, input));
      return normalizeRuntimeResult(runtimeOut);
    },
    async run(filter, input) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return encoded;
      }
      const runtimeOut = await toPromise(runtime.runJsonText(filter, encoded.value));
      const normalizedOut = normalizeRuntimeResult(runtimeOut);
      if (!normalizedOut.ok) {
        return normalizedOut;
      }
      return decodeRuntimeOutputs(normalizedOut.value);
    },
    runJsonTextStream(filter, input) {
      if (hasStreamingJsonTextRuntime(runtime)) {
        return fromStreamingRuntimeCall(runtime.runJsonTextStream(filter, input));
      }
      return fromArrayRuntimeCall(runtime.runJsonText(filter, input));
    },
    runStream(filter, input) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return singleErrorStream(encoded.error);
      }
      const rawStream = hasStreamingJsonTextRuntime(runtime)
        ? fromStreamingRuntimeCall(runtime.runJsonTextStream(filter, encoded.value))
        : fromArrayRuntimeCall(runtime.runJsonText(filter, encoded.value));
      return decodeRawResultStream(rawStream);
    },
  };
}

function createQueryRuntimeFromJsonText<Q>(
  runtime: JqxQueryJsonTextRuntime<Q> &
    Partial<JqxJsonTextStreamingRuntime> &
    Partial<JqxQueryJsonTextStreamingRuntime<Q>>,
): JqxQueryClient<Q> {
  const baseRuntime = createDynamicRuntime(runtime);
  const queryRuntime: JqxQueryClient<Q> = {
    ...baseRuntime,
    queryJsonText(query: QueryInputFor<Q>, input: string) {
      const normalized = normalizeQueryInput(query);
      return toPromise(runtime.runQueryJsonText(normalized, input)).then(normalizeRuntimeResult);
    },
    async query(query: QueryInputFor<Q>, input: Json) {
      const normalized = normalizeQueryInput(query);
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return encoded;
      }
      const runtimeOut = await toPromise(runtime.runQueryJsonText(normalized, encoded.value));
      const normalizedOut = normalizeRuntimeResult(runtimeOut);
      if (!normalizedOut.ok) {
        return normalizedOut;
      }
      return decodeRuntimeOutputs(normalizedOut.value);
    },
    queryJsonTextStream(query: QueryInputFor<Q>, input: string) {
      const normalized = normalizeQueryInput(query);
      if (hasQueryStreamingJsonTextRuntime(runtime)) {
        return fromStreamingRuntimeCall(runtime.runQueryJsonTextStream(normalized, input));
      }
      return fromArrayRuntimeCall(runtime.runQueryJsonText(normalized, input));
    },
    queryStream(query: QueryInputFor<Q>, input: Json) {
      const normalized = normalizeQueryInput(query);
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return singleErrorStream<Json>(encoded.error);
      }
      const rawStream = hasQueryStreamingJsonTextRuntime(runtime)
        ? fromStreamingRuntimeCall(runtime.runQueryJsonTextStream(normalized, encoded.value))
        : fromArrayRuntimeCall(runtime.runQueryJsonText(normalized, encoded.value));
      return decodeRawResultStream(rawStream);
    },
  };
  return queryRuntime;
}

export function createRuntime(
  runtime: JqxJsonTextRuntime & Partial<JqxJsonTextStreamingRuntime>,
): JqxClient {
  return createDynamicRuntime(runtime);
}

export function createQueryRuntime<Q>(
  runtime: JqxQueryJsonTextRuntime<Q> &
    Partial<JqxJsonTextStreamingRuntime> &
    Partial<JqxQueryJsonTextStreamingRuntime<Q>>,
): JqxQueryClient<Q> {
  return createQueryRuntimeFromJsonText(runtime);
}
