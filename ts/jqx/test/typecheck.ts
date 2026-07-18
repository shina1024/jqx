import { expectTypeOf } from "vite-plus/test";

import {
  compile,
  isValidJson,
  parseJson,
  run,
  runJsonText,
  query,
  queryJsonText,
  queryRuntime,
  runtime,
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
import {
  bindQueryRuntime,
  bindRuntime,
  type JqxJsonTextRuntime,
  type JqxQueryJsonTextRuntime,
} from "../src/bind.js";
import type {
  CompiledFilter,
  InferTypedQueryOutput,
  JqxBackendRuntimeError,
  JqxDirectQueryRuntime,
  JqxDirectRuntime,
  JqxError,
  JqxInputValueRuntimeError,
  JqxOutputValueRuntimeError,
  JqxResult,
  JqxRuntimeError,
  Json,
  QueryAst,
  QueryAstDocument,
  QueryAstImportResult,
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

const directRunOut = run(".", { user: { name: "a" } });
expectTypeOf(directRunOut).toMatchTypeOf<JqxResult<Json[], JqxRuntimeError>>();
const directRunJsonTextOut = runJsonText(".", '{"user":{"name":"a"}}');
expectTypeOf(directRunJsonTextOut).toMatchTypeOf<JqxResult<string[], JqxRuntimeError>>();
const directParseOut = parseJson('{"user":{"name":"a"}}');
expectTypeOf(directParseOut).toMatchTypeOf<JqxResult<Json, JqxRuntimeError>>();
expectTypeOf(isValidJson('{"user":{"name":"a"}}')).toEqualTypeOf<boolean>();

const compiled = compile(".user.name");
expectTypeOf(compiled).toMatchTypeOf<JqxResult<CompiledFilter<".user.name">, JqxRuntimeError>>();
if (compiled.ok) {
  const directCompiledOut = compiled.value.run({ user: { name: "a" } });
  expectTypeOf(directCompiledOut).toMatchTypeOf<JqxResult<string[], JqxRuntimeError>>();
  const directCompiledJsonTextOut = compiled.value.runJsonText('{"user":{"name":"a"}}');
  expectTypeOf(directCompiledJsonTextOut).toMatchTypeOf<JqxResult<string[], JqxRuntimeError>>();
}

const ast = toAst(nameQuery);
const directQueryOut = query(ast, { user: { name: "a" } });
expectTypeOf(directQueryOut).toMatchTypeOf<JqxResult<Json[], JqxRuntimeError>>();
const directQueryOutFromDsl = query(nameQuery, { user: { name: "a" } });
if (directQueryOutFromDsl.ok) {
  expectTypeOf(directQueryOutFromDsl.value).toEqualTypeOf<string[]>();
}
const directQueryJsonTextOut = queryJsonText(ast, '{"user":{"name":"a"}}');
expectTypeOf(directQueryJsonTextOut).toMatchTypeOf<JqxResult<string[], JqxRuntimeError>>();
const directQueryJsonTextOutFromDsl = queryJsonText(nameQuery, '{"user":{"name":"a"}}');
expectTypeOf(directQueryJsonTextOutFromDsl).toMatchTypeOf<JqxResult<string[], JqxRuntimeError>>();

expectTypeOf(runtime).toMatchTypeOf<JqxDirectRuntime>();
expectTypeOf(queryRuntime).toMatchTypeOf<JqxDirectQueryRuntime>();
expectTypeOf<{ user: undefined } extends Json ? true : false>().toEqualTypeOf<false>();

declare const bindingRuntime: JqxJsonTextRuntime;
const jqx = bindRuntime(bindingRuntime);
const runOut = jqx.run(".", { user: { name: "a" } });
expectTypeOf(runOut).toMatchTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
const runJsonTextOut = jqx.runJsonText(".", '{"user":{"name":"a"}}');
expectTypeOf(runJsonTextOut).toMatchTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();
const runStreamOut = jqx.runStream(".", { user: { name: "a" } });
expectTypeOf(runStreamOut).toMatchTypeOf<AsyncIterable<JqxResult<Json, JqxRuntimeError>>>();
const runJsonTextStreamOut = jqx.runJsonTextStream(".", '{"user":{"name":"a"}}');
expectTypeOf(runJsonTextStreamOut).toMatchTypeOf<
  AsyncIterable<JqxResult<string, JqxRuntimeError>>
>();
expectTypeOf<"compile" extends keyof typeof jqx ? true : false>().toEqualTypeOf<false>();

declare const bindingQueryRuntime: JqxQueryJsonTextRuntime<QueryAst>;
const queryJqx = bindQueryRuntime(bindingQueryRuntime);
const boundQueryOut = queryJqx.query(ast, { user: { name: "a" } });
expectTypeOf(boundQueryOut).toMatchTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
const boundQueryOutFromDsl = queryJqx.query(nameQuery, { user: { name: "a" } });
expectTypeOf(boundQueryOutFromDsl).toMatchTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
const boundQueryJsonTextOut = queryJqx.queryJsonText(ast, '{"user":{"name":"a"}}');
expectTypeOf(boundQueryJsonTextOut).toMatchTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();
const boundQueryJsonTextOutFromDsl = queryJqx.queryJsonText(nameQuery, '{"user":{"name":"a"}}');
expectTypeOf(boundQueryJsonTextOutFromDsl).toMatchTypeOf<
  Promise<JqxResult<string[], JqxRuntimeError>>
>();
const boundQueryStreamOut = queryJqx.queryStream(ast, { user: { name: "a" } });
expectTypeOf(boundQueryStreamOut).toMatchTypeOf<AsyncIterable<JqxResult<Json, JqxRuntimeError>>>();
const boundQueryJsonTextStreamOut = queryJqx.queryJsonTextStream(ast, '{"user":{"name":"a"}}');
expectTypeOf(boundQueryJsonTextStreamOut).toMatchTypeOf<
  AsyncIterable<JqxResult<string, JqxRuntimeError>>
>();
expectTypeOf<"compile" extends keyof typeof queryJqx ? true : false>().toEqualTypeOf<false>();

type CustomQuery = { kind: "custom"; key: string };
declare const customRuntime: JqxQueryJsonTextRuntime<CustomQuery>;
const customJqx = bindQueryRuntime(customRuntime);
const customTypedOut = customJqx.query(
  { kind: "custom", key: "user.name" },
  { user: { name: "a" } },
);
expectTypeOf(customTypedOut).toMatchTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
expectTypeOf<
  typeof nameQuery extends Parameters<typeof customJqx.query>[0] ? true : false
>().toEqualTypeOf<false>();

const dynamicFromQuery = bindRuntime(customRuntime);
expectTypeOf<"query" extends keyof typeof dynamicFromQuery ? true : false>().toEqualTypeOf<false>();

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

const inputValueRuntimeError: JqxInputValueRuntimeError = {
  kind: "input_value",
  message: "boom",
  path: "$.value",
};
expectTypeOf(runtimeErrorToMessage(inputValueRuntimeError)).toEqualTypeOf<string>();

const outputValueRuntimeError: JqxOutputValueRuntimeError = {
  kind: "output_value",
  message: "boom",
  index: 0,
  path: "$.value",
};
expectTypeOf(runtimeErrorToMessage(outputValueRuntimeError)).toEqualTypeOf<string>();

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
