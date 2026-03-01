import { expectTypeOf } from "expect-type";

import {
  field,
  gt,
  identity,
  iter,
  literal,
  pipe,
  runTypedQuery,
  runTypedQueryAst,
  select,
  toAst,
} from "../src/index.js";
import type {
  InferTypedQueryOutput,
  JqxResult,
  JqxRuntimeError,
  JqxTypedRuntime,
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

declare const typedRuntime: JqxTypedRuntime<QueryAst>;
const typedOut = runTypedQuery(typedRuntime, nameQuery, '{"user":{"name":"a"}}');
expectTypeOf(typedOut).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();

const astOut = runTypedQueryAst(typedRuntime, toAst(nameQuery), '{"user":{"name":"a"}}');
expectTypeOf(astOut).toEqualTypeOf<Promise<JqxResult<string[], JqxRuntimeError>>>();
