import { expectTypeOf } from "expect-type";

import {
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
  pipe,
  select,
  tryCatch,
} from "../src/index.js";
import type { InferTypedQueryOutput } from "../src/index.js";

type InputData = {
  user: {
    name: string;
    age: number;
    active: boolean;
  };
  list: Array<{
    kind: "ok" | "ng";
    v: number;
  }>;
  a: string | null;
  b: string;
};

const userQuery = pipe(identity<InputData>(), field("user"));
const nameQuery = pipe(userQuery, field("name"));
expectTypeOf<InferTypedQueryOutput<InputData, typeof nameQuery>>().toEqualTypeOf<string>();

const itemsQuery = pipe(identity<{ items: string[] }>(), field("items"));
const indexQuery = pipe(itemsQuery, index(0));
expectTypeOf<
  InferTypedQueryOutput<{ items: string[] }, typeof indexQuery>
>().toEqualTypeOf<string>();

const listQuery = pipe(identity<{ list: Array<{ id: number }> }>(), field("list"));
const mappedIdsQuery = pipe(listQuery, map(field("id")));
expectTypeOf<
  InferTypedQueryOutput<{ list: Array<{ id: number }> }, typeof mappedIdsQuery>
>().toEqualTypeOf<Array<number>>();

const predicateQuery = and_(gt(field("v"), literal(1)), not_(eq(field("kind"), literal("ng"))));
expectTypeOf<
  InferTypedQueryOutput<{ kind: "ok" | "ng"; v: number }, typeof predicateQuery>
>().toEqualTypeOf<boolean>();

const selectQuery = select(gt(field("v"), literal(1)));
expectTypeOf<InferTypedQueryOutput<{ v: number }, typeof selectQuery>>().toEqualTypeOf<{
  v: number;
}>();

const iterQuery = iter();
expectTypeOf<InferTypedQueryOutput<Array<{ v: number }>, typeof iterQuery>>().toEqualTypeOf<{
  v: number;
}>();

const commaQuery = pipe(
  identity<{ left: number; right: string }>(),
  comma(field("left"), field("right")),
);
expectTypeOf<
  InferTypedQueryOutput<{ left: number; right: string }, typeof commaQuery>
>().toEqualTypeOf<number | string>();

const addQuery = pipe(identity<{ x: number }>(), add(field("x"), literal(1)));
expectTypeOf<InferTypedQueryOutput<{ x: number }, typeof addQuery>>().toEqualTypeOf<number>();

const ifElseQuery = ifElse(lt(field("v"), literal(2)), literal("small"), literal("large"));
expectTypeOf<InferTypedQueryOutput<{ v: number }, typeof ifElseQuery>>().toEqualTypeOf<
  "small" | "large"
>();

const fallbackQuery = pipe(identity<InputData>(), fallback(field("a"), field("b")));
expectTypeOf<InferTypedQueryOutput<InputData, typeof fallbackQuery>>().toEqualTypeOf<string>();

const tryCatchQuery = tryCatch(field("name"), literal("fallback"));
expectTypeOf<
  InferTypedQueryOutput<{ name: string }, typeof tryCatchQuery>
>().toEqualTypeOf<string>();

const callFallbackQuery = pipe(identity<{ value: string }>(), call("length", []));
expectTypeOf<
  InferTypedQueryOutput<{ value: string }, typeof callFallbackQuery>
>().toEqualTypeOf<unknown>();
