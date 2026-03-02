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

export const QUERY_AST_DOCUMENT_FORMAT = "jqx-query-ast" as const;
export const QUERY_AST_DOCUMENT_VERSION = 1 as const;

export type QueryAstDocumentFormat = typeof QUERY_AST_DOCUMENT_FORMAT;
export type QueryAstDocumentVersion = typeof QUERY_AST_DOCUMENT_VERSION;

export interface QueryAstDocument {
  format: QueryAstDocumentFormat;
  version: QueryAstDocumentVersion;
  ast: QueryAst;
}

export type QueryAstImportError =
  | {
      kind: "invalid_json";
      message: string;
    }
  | {
      kind: "invalid_document";
      path: string;
      message: string;
    }
  | {
      kind: "unsupported_version";
      version: number;
      message: string;
    }
  | {
      kind: "invalid_ast";
      path: string;
      message: string;
    };

export type QueryAstImportResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: QueryAstImportError };

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

function failImport<T>(error: QueryAstImportError): QueryAstImportResult<T> {
  return { ok: false, error };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isJsonValue(value: unknown): value is Json {
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "boolean" ||
    typeof value === "number"
  ) {
    return true;
  }
  if (Array.isArray(value)) {
    return value.every(isJsonValue);
  }
  if (isRecord(value)) {
    return Object.values(value).every(isJsonValue);
  }
  return false;
}

function hasExactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean {
  const actualKeys = Object.keys(value);
  if (actualKeys.length !== expected.length) {
    return false;
  }
  return expected.every((key) => actualKeys.includes(key));
}

function invalidAst(path: string, message: string): QueryAstImportError {
  return { kind: "invalid_ast", path, message };
}

function validateQueryAstNode(value: unknown, path: string): QueryAstImportError | null {
  if (!isRecord(value)) {
    return invalidAst(path, "Expected object");
  }
  const kind = value.kind;
  if (typeof kind !== "string") {
    return invalidAst(`${path}.kind`, "Expected string");
  }

  const validateUnaryNode = (
    fieldName: string,
    expectedKeys: readonly string[],
  ): QueryAstImportError | null => {
    if (!hasExactKeys(value, expectedKeys)) {
      return invalidAst(path, "Unexpected fields");
    }
    return validateQueryAstNode(value[fieldName], `${path}.${fieldName}`);
  };

  const validateBinaryNode = (
    leftField: string,
    rightField: string,
    expectedKeys: readonly string[],
  ): QueryAstImportError | null => {
    if (!hasExactKeys(value, expectedKeys)) {
      return invalidAst(path, "Unexpected fields");
    }
    const leftError = validateQueryAstNode(value[leftField], `${path}.${leftField}`);
    if (leftError !== null) {
      return leftError;
    }
    return validateQueryAstNode(value[rightField], `${path}.${rightField}`);
  };

  switch (kind) {
    case "identity":
    case "iter":
      return hasExactKeys(value, ["kind"]) ? null : invalidAst(path, "Unexpected fields");
    case "field":
      if (!hasExactKeys(value, ["kind", "name"])) {
        return invalidAst(path, "Unexpected fields");
      }
      return typeof value.name === "string" ? null : invalidAst(`${path}.name`, "Expected string");
    case "index":
      if (!hasExactKeys(value, ["kind", "index"])) {
        return invalidAst(path, "Unexpected fields");
      }
      return typeof value.index === "number"
        ? null
        : invalidAst(`${path}.index`, "Expected number");
    case "literal":
      if (!hasExactKeys(value, ["kind", "value"])) {
        return invalidAst(path, "Unexpected fields");
      }
      return isJsonValue(value.value) ? null : invalidAst(`${path}.value`, "Expected Json value");
    case "map":
      return validateUnaryNode("inner", ["kind", "inner"]);
    case "select":
      return validateUnaryNode("predicate", ["kind", "predicate"]);
    case "not":
      return validateUnaryNode("value", ["kind", "value"]);
    case "pipe":
    case "comma":
    case "eq":
    case "lt":
    case "gt":
    case "and":
    case "or":
    case "add":
    case "fallback":
      return validateBinaryNode("left", "right", ["kind", "left", "right"]);
    case "if_else":
      if (!hasExactKeys(value, ["kind", "cond", "then_branch", "else_branch"])) {
        return invalidAst(path, "Unexpected fields");
      }
      {
        const condError = validateQueryAstNode(value.cond, `${path}.cond`);
        if (condError !== null) {
          return condError;
        }
        const thenError = validateQueryAstNode(value.then_branch, `${path}.then_branch`);
        if (thenError !== null) {
          return thenError;
        }
        return validateQueryAstNode(value.else_branch, `${path}.else_branch`);
      }
    case "try_catch":
      return validateBinaryNode("inner", "handler", ["kind", "inner", "handler"]);
    case "call":
      if (!hasExactKeys(value, ["kind", "name", "args"])) {
        return invalidAst(path, "Unexpected fields");
      }
      if (typeof value.name !== "string") {
        return invalidAst(`${path}.name`, "Expected string");
      }
      if (!Array.isArray(value.args)) {
        return invalidAst(`${path}.args`, "Expected array");
      }
      for (const [index, arg] of value.args.entries()) {
        const argError = validateQueryAstNode(arg, `${path}.args[${index}]`);
        if (argError !== null) {
          return argError;
        }
      }
      return null;
    default:
      return invalidAst(`${path}.kind`, `Unsupported kind: ${kind}`);
  }
}

export function isQueryAst(value: unknown): value is QueryAst {
  return validateQueryAstNode(value, "$") === null;
}

export function toAst<I, O, Ast extends QueryAst>(query: Query<I, O, Ast>): Ast {
  return query.ast;
}

/// QueryAst external interchange contract:
/// - Export always emits `{ format: "jqx-query-ast", version: 1, ast }`.
/// - Import accepts only that document format.
/// - Unknown versions are rejected to keep compatibility explicit.
export function exportQueryAstDocument(ast: QueryAst): QueryAstDocument {
  return {
    format: QUERY_AST_DOCUMENT_FORMAT,
    version: QUERY_AST_DOCUMENT_VERSION,
    ast,
  };
}

export function exportTypedQueryDocument<I, O, Ast extends QueryAst>(
  query: Query<I, O, Ast>,
): QueryAstDocument {
  return exportQueryAstDocument(query.ast);
}

export function importQueryAstDocument(input: unknown): QueryAstImportResult<QueryAst> {
  if (!isRecord(input)) {
    return failImport({
      kind: "invalid_document",
      path: "$",
      message: "Expected object",
    });
  }

  if (!("format" in input) || !("version" in input) || !("ast" in input)) {
    return failImport({
      kind: "invalid_document",
      path: "$",
      message: "Expected { format, version, ast } document",
    });
  }

  if (input.format !== QUERY_AST_DOCUMENT_FORMAT) {
    return failImport({
      kind: "invalid_document",
      path: "$.format",
      message: `Expected ${QUERY_AST_DOCUMENT_FORMAT}`,
    });
  }
  if (typeof input.version !== "number") {
    return failImport({
      kind: "invalid_document",
      path: "$.version",
      message: "Expected number",
    });
  }
  if (input.version !== QUERY_AST_DOCUMENT_VERSION) {
    return failImport({
      kind: "unsupported_version",
      version: input.version,
      message: `Unsupported QueryAst document version: ${input.version}`,
    });
  }
  if (!("ast" in input)) {
    return failImport({
      kind: "invalid_document",
      path: "$.ast",
      message: "Missing ast field",
    });
  }

  const astError = validateQueryAstNode(input.ast, "$.ast");
  if (astError !== null) {
    return failImport(astError);
  }
  return { ok: true, value: input.ast as QueryAst };
}

export function parseQueryAstDocument(text: string): QueryAstImportResult<QueryAst> {
  try {
    return importQueryAstDocument(JSON.parse(text));
  } catch (error) {
    return failImport({
      kind: "invalid_json",
      message: error instanceof Error ? error.message : "Invalid JSON",
    });
  }
}

export function stringifyQueryAstDocument(ast: QueryAst): string {
  return JSON.stringify(exportQueryAstDocument(ast));
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
