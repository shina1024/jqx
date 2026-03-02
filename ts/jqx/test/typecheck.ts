import { expectTypeOf } from "expect-type";

import {
  createJqx,
  field,
  gt,
  identity,
  iter,
  literal,
  pipe,
  select,
  toAst,
} from "../src/index.js";
import type {
  InferTypedQueryOutput,
  JqxBackend,
  Json,
  JqxResult,
  JqxRuntimeError,
  JqxTypedBackend,
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
const runRawOut = jqx.runRaw(".", '{"user":{"name":"a"}}');
expectTypeOf(runRawOut).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();

declare const typedBackend: JqxTypedBackend<QueryAst>;
const typedJqx = createJqx(typedBackend);
const ast = toAst(nameQuery);
const typedOut = typedJqx.query(ast, { user: { name: "a" } });
expectTypeOf(typedOut).toEqualTypeOf<Promise<JqxResult<Json[], JqxRuntimeError>>>();
const typedRawOut = typedJqx.queryRaw(ast, '{"user":{"name":"a"}}');
expectTypeOf(typedRawOut).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();
