import { expectTypeOf } from "expect-type";

import {
  createJqx,
  createQueryJqx,
  exportQueryAstDocument,
  exportTypedQueryDocument,
  field,
  gt,
  identity,
  importQueryAstDocument,
  isJqxRuntimeError,
  isQueryAst,
  iter,
  literal,
  parseQueryAstDocument,
  pipe,
  QUERY_AST_DOCUMENT_FORMAT,
  QUERY_AST_DOCUMENT_VERSION,
  runtimeErrorToMessage,
  select,
  stringifyQueryAstDocument,
  toAst,
  toJqxRuntimeError,
} from "../src/index.js";
import type {
  InferTypedQueryOutput,
  JqxBackend,
  JqxBackendRuntimeError,
  JqxError,
  Json,
  JqxResult,
  JqxQueryBackend,
  JqxRuntimeError,
  QueryAstDocument,
  QueryAstImportResult,
  QueryAst,
} from "../src/index.js";

type InputData = {
  user: {
    name: string;
  };
  list: Array<{ v: number }>;
};

const userQuery = pipe(identity<InputData>(), field("user"));
const nameQuery = pipe(userQuery, field("name"));
expectTypeOf<InferTypedQueryOutput<InputData, typeof nameQuery>>().toEqualTypeOf<string>();

const listQuery = pipe(identity<InputData>(), field("list"));
const gtQuery = gt(field("v"), literal(1));
const selectQuery = select(gtQuery);
const iterAndSelectQuery = pipe(iter(), selectQuery);
const selectedQuery = pipe(listQuery, iterAndSelectQuery);
expectTypeOf<InferTypedQueryOutput<InputData, typeof selectedQuery>>().toEqualTypeOf<{
  v: number;
}>();

declare const backend: JqxBackend;
const jqx = createJqx(backend);
const runOut = jqx.run(".", { user: { name: "a" } });
expectTypeOf(runOut).toEqualTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
const runJsonTextOut = jqx.runJsonText(".", '{"user":{"name":"a"}}');
expectTypeOf(runJsonTextOut).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();
const runStreamOut = jqx.runStream(".", { user: { name: "a" } });
expectTypeOf(runStreamOut).toEqualTypeOf<AsyncIterable<JqxResult<Json, JqxRuntimeError>>>();
const runJsonTextStreamOut = jqx.runJsonTextStream(".", '{"user":{"name":"a"}}');
expectTypeOf(runJsonTextStreamOut).toEqualTypeOf<AsyncIterable<JqxResult<string, JqxRuntimeError>>>();
// @ts-expect-error `undefined` is not a JSON value.
jqx.run(".", { user: undefined });

declare const queryBackend: JqxQueryBackend<QueryAst>;
const queryJqx = createQueryJqx(queryBackend);
const ast = toAst(nameQuery);
const queryOut = queryJqx.query(ast, { user: { name: "a" } });
expectTypeOf(queryOut).toEqualTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
const queryOutFromDsl = queryJqx.query(nameQuery, { user: { name: "a" } });
expectTypeOf(queryOutFromDsl).toEqualTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
const queryJsonTextOut = queryJqx.queryJsonText(ast, '{"user":{"name":"a"}}');
expectTypeOf(queryJsonTextOut).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();
const queryJsonTextOutFromDsl = queryJqx.queryJsonText(nameQuery, '{"user":{"name":"a"}}');
expectTypeOf(queryJsonTextOutFromDsl).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();
const queryStreamOut = queryJqx.queryStream(ast, { user: { name: "a" } });
expectTypeOf(queryStreamOut).toEqualTypeOf<AsyncIterable<JqxResult<Json, JqxRuntimeError>>>();
const queryJsonTextStreamOut = queryJqx.queryJsonTextStream(ast, '{"user":{"name":"a"}}');
expectTypeOf(queryJsonTextStreamOut).toEqualTypeOf<AsyncIterable<JqxResult<string, JqxRuntimeError>>>();
// @ts-expect-error `undefined` is not a JSON value.
queryJqx.query(ast, { user: undefined });

type CustomQuery = { kind: "custom"; key: string };
declare const customBackend: JqxQueryBackend<CustomQuery>;
const customJqx = createQueryJqx(customBackend);
const customTypedOut = customJqx.query(
  { kind: "custom", key: "user.name" },
  { user: { name: "a" } },
);
expectTypeOf(customTypedOut).toEqualTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
// @ts-expect-error Typed DSL query input is only available when query type is QueryAst.
customJqx.query(nameQuery, { user: { name: "a" } });

const dynamicFromQuery = createJqx(customBackend);
// @ts-expect-error query is only available on createQueryJqx.
dynamicFromQuery.query({ kind: "custom", key: "user.name" }, { user: { name: "a" } });

const normalizedRuntimeError = toJqxRuntimeError("boom");
expectTypeOf(normalizedRuntimeError).toEqualTypeOf<JqxRuntimeError>();
if (isJqxRuntimeError(normalizedRuntimeError)) {
  expectTypeOf(normalizedRuntimeError).toEqualTypeOf<JqxRuntimeError>();
}

const backendRuntimeError: JqxBackendRuntimeError = {
  kind: "backend_runtime",
  message: "boom",
  details: {
    code: "E",
    message: "boom",
    line: 1,
    column: 1,
    offset: 0,
  } satisfies JqxError,
};
expectTypeOf(runtimeErrorToMessage(backendRuntimeError)).toEqualTypeOf<string>();

const exportedAstDoc = exportTypedQueryDocument(nameQuery);
expectTypeOf(exportedAstDoc).toEqualTypeOf<QueryAstDocument>();

const astDocFromAst = exportQueryAstDocument(ast);
expectTypeOf(astDocFromAst).toEqualTypeOf<QueryAstDocument>();

const importedAst = importQueryAstDocument(astDocFromAst);
expectTypeOf(importedAst).toEqualTypeOf<QueryAstImportResult<QueryAst>>();

const parsedAst = parseQueryAstDocument(stringifyQueryAstDocument(ast));
expectTypeOf(parsedAst).toEqualTypeOf<QueryAstImportResult<QueryAst>>();

expectTypeOf(QUERY_AST_DOCUMENT_FORMAT).toEqualTypeOf<"jqx-query-ast">();
expectTypeOf(QUERY_AST_DOCUMENT_VERSION).toEqualTypeOf<1>();

if (importedAst.ok) {
  expectTypeOf(importedAst.value).toEqualTypeOf<QueryAst>();
  expectTypeOf(isQueryAst(importedAst.value)).toEqualTypeOf<boolean>();
}
