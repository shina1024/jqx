import { decodeRuntimeOutputs } from "./runtime_json.js";
import { encodeRuntimeInput } from "./runtime_input.js";
import {
  failRuntimeResult,
  normalizeRuntimeError,
  normalizeTypedDslQuery,
  type TypedDslQuery,
} from "./runtime_shared.js";
import {
  callStringArrayRuntime,
  decodeRawResultStream,
  selectJsonTextStream,
  selectQueryJsonTextStream,
  singleErrorStream,
} from "./runtime_stream.js";

import type {
  Json,
  MaybePromise,
  JqxResult,
  JqxResultStream,
  JqxRuntime,
  JqxRuntimeError,
  QueryAst,
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
  JqxInputValueRuntimeError,
  JqxOutputParseRuntimeError,
  JqxOutputValueRuntimeError,
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

// `/bind` deliberately wraps JSON-text backends. Compiled filters stay on the direct runtime.
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

export interface JqxQueryJsonTextStreamingRuntime<Q = QueryAst> extends JqxQueryJsonTextRuntime<Q> {
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

type QueryInputFor<Q> = Q extends QueryAst ? Q | TypedDslQuery : Q;

export interface JqxQueryClient<Q = QueryAst> extends JqxClient {
  query(query: QueryInputFor<Q>, input: Json): Promise<JqxResult<Json[], JqxRuntimeError>>;
  queryJsonText(
    query: QueryInputFor<Q>,
    input: string,
  ): Promise<JqxResult<string[], JqxRuntimeError>>;
  queryStream(query: QueryInputFor<Q>, input: Json): JqxResultStream<Json, JqxRuntimeError>;
  queryJsonTextStream(
    query: QueryInputFor<Q>,
    input: string,
  ): JqxResultStream<string, JqxRuntimeError>;
}

function normalizeQueryInput<Q>(query: QueryInputFor<Q>): JqxResult<Q, JqxRuntimeError> {
  try {
    return { ok: true, value: normalizeTypedDslQuery(query as Q | TypedDslQuery) };
  } catch (error) {
    return failRuntimeResult(normalizeRuntimeError(error, "Unable to inspect query"));
  }
}

function createDynamicRuntime(
  runtime: JqxJsonTextRuntime & Partial<JqxJsonTextStreamingRuntime>,
): JqxClient {
  return {
    async runJsonText(filter, input) {
      return callStringArrayRuntime(() => runtime.runJsonText(filter, input));
    },
    async run(filter, input) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return encoded;
      }
      const normalizedOut = await callStringArrayRuntime(() =>
        runtime.runJsonText(filter, encoded.value),
      );
      if (!normalizedOut.ok) {
        return normalizedOut;
      }
      return decodeRuntimeOutputs(normalizedOut.value);
    },
    runJsonTextStream(filter, input) {
      return selectJsonTextStream(runtime, filter, input);
    },
    runStream(filter, input) {
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return singleErrorStream(encoded.error);
      }
      const rawStream = selectJsonTextStream(runtime, filter, encoded.value);
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
    async queryJsonText(query: QueryInputFor<Q>, input: string) {
      const normalized = normalizeQueryInput(query);
      if (!normalized.ok) {
        return normalized;
      }
      return callStringArrayRuntime(() => runtime.runQueryJsonText(normalized.value, input));
    },
    async query(query: QueryInputFor<Q>, input: Json) {
      const normalized = normalizeQueryInput(query);
      if (!normalized.ok) {
        return normalized;
      }
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return encoded;
      }
      const normalizedOut = await callStringArrayRuntime(() =>
        runtime.runQueryJsonText(normalized.value, encoded.value),
      );
      if (!normalizedOut.ok) {
        return normalizedOut;
      }
      return decodeRuntimeOutputs(normalizedOut.value);
    },
    queryJsonTextStream(query: QueryInputFor<Q>, input: string) {
      const normalized = normalizeQueryInput(query);
      if (!normalized.ok) {
        return singleErrorStream(normalized.error);
      }
      return selectQueryJsonTextStream(runtime, normalized.value, input);
    },
    queryStream(query: QueryInputFor<Q>, input: Json) {
      const normalized = normalizeQueryInput(query);
      if (!normalized.ok) {
        return singleErrorStream(normalized.error);
      }
      const encoded = encodeRuntimeInput(input);
      if (!encoded.ok) {
        return singleErrorStream<Json>(encoded.error);
      }
      const rawStream = selectQueryJsonTextStream(runtime, normalized.value, encoded.value);
      return decodeRawResultStream(rawStream);
    },
  };
  return queryRuntime;
}

export function bindRuntime(
  runtime: JqxJsonTextRuntime & Partial<JqxJsonTextStreamingRuntime>,
): JqxClient {
  return createDynamicRuntime(runtime);
}

export function bindQueryRuntime<Q>(
  runtime: JqxQueryJsonTextRuntime<Q> &
    Partial<JqxJsonTextStreamingRuntime> &
    Partial<JqxQueryJsonTextStreamingRuntime<Q>>,
): JqxQueryClient<Q> {
  return createQueryRuntimeFromJsonText(runtime);
}
