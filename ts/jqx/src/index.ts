// Canonical direct-use runtime surface.
export {
  compile,
  isValidJson,
  parseJson,
  run,
  runJsonText,
} from "./direct_runtime.js";

export {
  CompiledFilter,
  runtime,
} from "./direct_runtime.js";

export type {
  JqxDirectRuntime,
} from "./direct_runtime.js";

// Secondary root-package lanes: query helpers and adapter-facing runtime objects.
export {
  query,
  queryJsonText,
  queryRuntime,
} from "./direct_runtime.js";

export type {
  JqxDirectQueryRuntime,
} from "./direct_runtime.js";

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
  JqxRuntimeError,
  JqxQueryRuntime,
} from "@shina1024/jqx-adapter-core";

export {
  isJqxError,
  isJqxRuntimeError,
  runtimeErrorToMessage,
  toJqxRuntimeError,
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
  ifElse,
  importQueryAstDocument,
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
