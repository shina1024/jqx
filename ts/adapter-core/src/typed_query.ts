import type { Json } from "./index.js";

type QueryFallback = unknown;
type FallbackFalsy = false | null;

type AccessField<Input, Name extends string> = Input extends null | undefined
  ? QueryFallback
  : Input extends object
    ? Name extends keyof Input
      ? Input[Name]
      : QueryFallback
    : QueryFallback;

type AccessIndex<Input> = Input extends null | undefined
  ? QueryFallback
  : Input extends ReadonlyArray<infer Item>
    ? Item
    : QueryFallback;

type AddValues<Left, Right> = Left extends number
  ? Right extends number
    ? number
    : QueryFallback
  : Left extends string
    ? Right extends string
      ? string
      : QueryFallback
    : Left extends ReadonlyArray<infer LeftItem>
      ? Right extends ReadonlyArray<infer RightItem>
        ? Array<LeftItem | RightItem>
        : QueryFallback
      : Left extends object
        ? Right extends object
          ? Left & Right
          : QueryFallback
        : QueryFallback;

type FallbackValues<Left, Right> = [Extract<Left, FallbackFalsy>] extends [never]
  ? Left
  : Exclude<Left, FallbackFalsy> | Right;

type PipeValues<LeftAst extends QueryAst, RightAst extends QueryAst, Input> =
  InferQueryAst<LeftAst, Input> extends infer Middle
    ? Middle extends unknown
      ? InferQueryAst<RightAst, Middle>
      : never
    : never;

export type QueryAst =
  | { kind: "identity" }
  | { kind: "field"; name: string }
  | { kind: "index"; index: number }
  | { kind: "pipe"; left: QueryAst; right: QueryAst }
  | { kind: "map"; inner: QueryAst }
  | { kind: "literal"; value: Json }
  | { kind: "iter" }
  | { kind: "comma"; left: QueryAst; right: QueryAst }
  | { kind: "call"; name: string; args: readonly QueryAst[] }
  | { kind: "select"; predicate: QueryAst }
  | { kind: "eq"; left: QueryAst; right: QueryAst }
  | { kind: "lt"; left: QueryAst; right: QueryAst }
  | { kind: "gt"; left: QueryAst; right: QueryAst }
  | { kind: "and"; left: QueryAst; right: QueryAst }
  | { kind: "or"; left: QueryAst; right: QueryAst }
  | { kind: "not"; value: QueryAst }
  | { kind: "add"; left: QueryAst; right: QueryAst }
  | { kind: "if_else"; cond: QueryAst; then_branch: QueryAst; else_branch: QueryAst }
  | { kind: "fallback"; left: QueryAst; right: QueryAst }
  | { kind: "try_catch"; inner: QueryAst; handler: QueryAst };

type InferCallAst<_Name extends string, _Args extends readonly QueryAst[], _Input> = QueryFallback;

export type InferQueryAst<Ast extends QueryAst, Input> = Ast extends { kind: "identity" }
  ? Input
  : Ast extends { kind: "field"; name: infer Name extends string }
    ? AccessField<Input, Name>
    : Ast extends { kind: "index" }
      ? AccessIndex<Input>
      : Ast extends {
            kind: "pipe";
            left: infer Left extends QueryAst;
            right: infer Right extends QueryAst;
          }
        ? PipeValues<Left, Right, Input>
        : Ast extends { kind: "map"; inner: infer Inner extends QueryAst }
          ? Input extends ReadonlyArray<infer Item>
            ? Array<InferQueryAst<Inner, Item>>
            : QueryFallback
          : Ast extends { kind: "literal"; value: infer Value extends Json }
            ? Value
            : Ast extends { kind: "iter" }
              ? AccessIndex<Input>
              : Ast extends {
                    kind: "comma";
                    left: infer Left extends QueryAst;
                    right: infer Right extends QueryAst;
                  }
                ? InferQueryAst<Left, Input> | InferQueryAst<Right, Input>
                : Ast extends {
                      kind: "call";
                      name: infer Name extends string;
                      args: infer Args extends readonly QueryAst[];
                    }
                  ? InferCallAst<Name, Args, Input>
                  : Ast extends { kind: "select" }
                    ? Input
                    : Ast extends { kind: "eq" | "lt" | "gt" | "and" | "or" | "not" }
                      ? boolean
                      : Ast extends {
                            kind: "add";
                            left: infer Left extends QueryAst;
                            right: infer Right extends QueryAst;
                          }
                        ? AddValues<InferQueryAst<Left, Input>, InferQueryAst<Right, Input>>
                        : Ast extends {
                              kind: "if_else";
                              then_branch: infer ThenAst extends QueryAst;
                              else_branch: infer ElseAst extends QueryAst;
                            }
                          ? InferQueryAst<ThenAst, Input> | InferQueryAst<ElseAst, Input>
                          : Ast extends {
                                kind: "fallback";
                                left: infer Left extends QueryAst;
                                right: infer Right extends QueryAst;
                              }
                            ? FallbackValues<
                                InferQueryAst<Left, Input>,
                                InferQueryAst<Right, Input>
                              >
                            : Ast extends {
                                  kind: "try_catch";
                                  inner: infer Inner extends QueryAst;
                                  handler: infer Handler extends QueryAst;
                                }
                              ? InferQueryAst<Inner, Input> | InferQueryAst<Handler, Input>
                              : QueryFallback;

export interface Query<I = Json, O = Json, Ast extends QueryAst = QueryAst> {
  readonly ast: Ast;
  readonly _input?: I;
  readonly _output?: O;
}

export type QueryInput<Q extends Query<unknown, unknown, QueryAst>> =
  Q extends Query<infer Input, unknown, QueryAst> ? Input : never;

export type QueryOutput<Q extends Query<unknown, unknown, QueryAst>> =
  Q extends Query<unknown, infer Output, QueryAst> ? Output : never;

export type InferTypedQueryOutput<
  Input,
  Q extends Query<unknown, unknown, QueryAst>,
> = InferQueryAst<Q["ast"], Input>;

type QueryAstTuple<Queries extends readonly Query<unknown, unknown, QueryAst>[]> = {
  [K in keyof Queries]: Queries[K] extends Query<unknown, unknown, infer Ast extends QueryAst>
    ? Ast
    : never;
};

function queryOfAst<I, O, Ast extends QueryAst>(ast: Ast): Query<I, O, Ast> {
  return { ast };
}

export function toAst<I, O, Ast extends QueryAst>(query: Query<I, O, Ast>): Ast {
  return query.ast;
}

export function identity<Input = Json>(): Query<Input, Input, { kind: "identity" }> {
  return queryOfAst({ kind: "identity" });
}

export function field<Name extends string>(
  name: Name,
): Query<unknown, unknown, { kind: "field"; name: Name }> {
  return queryOfAst({ kind: "field", name });
}

export function index<Value extends number>(
  value: Value,
): Query<unknown, unknown, { kind: "index"; index: Value }> {
  return queryOfAst({ kind: "index", index: value });
}

export function pipe<I, Middle, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<I, Middle, LeftAst>,
  right: Query<unknown, unknown, RightAst>,
): Query<I, InferQueryAst<RightAst, Middle>, { kind: "pipe"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "pipe", left: left.ast, right: right.ast });
}

export function map<InnerAst extends QueryAst>(
  inner: Query<unknown, unknown, InnerAst>,
): Query<unknown, unknown, { kind: "map"; inner: InnerAst }> {
  return queryOfAst({ kind: "map", inner: inner.ast });
}

export function literal<Value extends Json>(
  value: Value,
): Query<unknown, Value, { kind: "literal"; value: Value }> {
  return queryOfAst({ kind: "literal", value });
}

export function iter(): Query<unknown, unknown, { kind: "iter" }> {
  return queryOfAst({ kind: "iter" });
}

export function comma<Input, Left, Right, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, Left, LeftAst>,
  right: Query<Input, Right, RightAst>,
): Query<Input, Left | Right, { kind: "comma"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "comma", left: left.ast, right: right.ast });
}

export function call<
  Name extends string,
  Args extends readonly Query<unknown, unknown, QueryAst>[],
>(
  name: Name,
  args: Args,
): Query<unknown, unknown, { kind: "call"; name: Name; args: QueryAstTuple<Args> }> {
  const callArgs = args.map((query) => query.ast) as QueryAstTuple<Args>;
  return queryOfAst({ kind: "call", name, args: callArgs });
}

export function select<Input, PredAst extends QueryAst>(
  pred: Query<Input, unknown, PredAst>,
): Query<Input, Input, { kind: "select"; predicate: PredAst }> {
  return queryOfAst({ kind: "select", predicate: pred.ast });
}

export function eq<Input, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, unknown, LeftAst>,
  right: Query<Input, unknown, RightAst>,
): Query<Input, boolean, { kind: "eq"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "eq", left: left.ast, right: right.ast });
}

export function lt<Input, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, unknown, LeftAst>,
  right: Query<Input, unknown, RightAst>,
): Query<Input, boolean, { kind: "lt"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "lt", left: left.ast, right: right.ast });
}

export function gt<Input, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, unknown, LeftAst>,
  right: Query<Input, unknown, RightAst>,
): Query<Input, boolean, { kind: "gt"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "gt", left: left.ast, right: right.ast });
}

export function and_<Input, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, unknown, LeftAst>,
  right: Query<Input, unknown, RightAst>,
): Query<Input, boolean, { kind: "and"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "and", left: left.ast, right: right.ast });
}

export function or_<Input, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, unknown, LeftAst>,
  right: Query<Input, unknown, RightAst>,
): Query<Input, boolean, { kind: "or"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "or", left: left.ast, right: right.ast });
}

export function not_<Input, ValueAst extends QueryAst>(
  value: Query<Input, unknown, ValueAst>,
): Query<Input, boolean, { kind: "not"; value: ValueAst }> {
  return queryOfAst({ kind: "not", value: value.ast });
}

export function add<Input, Left, Right, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, Left, LeftAst>,
  right: Query<Input, Right, RightAst>,
): Query<Input, AddValues<Left, Right>, { kind: "add"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "add", left: left.ast, right: right.ast });
}

export function ifElse<
  Input,
  CondAst extends QueryAst,
  ThenAst extends QueryAst,
  ElseAst extends QueryAst,
>(
  cond: Query<Input, unknown, CondAst>,
  then_: Query<Input, unknown, ThenAst>,
  else_: Query<Input, unknown, ElseAst>,
): Query<
  Input,
  InferQueryAst<ThenAst, Input> | InferQueryAst<ElseAst, Input>,
  { kind: "if_else"; cond: CondAst; then_branch: ThenAst; else_branch: ElseAst }
> {
  return queryOfAst({
    kind: "if_else",
    cond: cond.ast,
    then_branch: then_.ast,
    else_branch: else_.ast,
  });
}

export function fallback<Input, Left, Right, LeftAst extends QueryAst, RightAst extends QueryAst>(
  left: Query<Input, Left, LeftAst>,
  right: Query<Input, Right, RightAst>,
): Query<Input, FallbackValues<Left, Right>, { kind: "fallback"; left: LeftAst; right: RightAst }> {
  return queryOfAst({ kind: "fallback", left: left.ast, right: right.ast });
}

export function tryCatch<
  Input,
  Inner,
  Handler,
  InnerAst extends QueryAst,
  HandlerAst extends QueryAst,
>(
  inner: Query<Input, Inner, InnerAst>,
  handler: Query<Input, Handler, HandlerAst>,
): Query<Input, Inner | Handler, { kind: "try_catch"; inner: InnerAst; handler: HandlerAst }> {
  return queryOfAst({ kind: "try_catch", inner: inner.ast, handler: handler.ast });
}
