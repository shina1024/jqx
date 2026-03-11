import { moonbitRuntime } from "./moonbit_runtime.js";

import { toAst as toQueryAst } from "@shina1024/jqx-adapter-core";

import type {
  InferJqOutput,
  Json,
  JqxBackendRuntimeError,
  JqxQueryRuntime,
  JqxResult,
  JqxRuntime,
  JqxRuntimeError,
  Query,
  QueryAst,
} from "@shina1024/jqx-adapter-core";

type TypedDslQuery<Output = unknown> = Query<unknown, Output, QueryAst>;
type DirectQueryInput = QueryAst | TypedDslQuery;
const compiledFilterRaw = new WeakMap<CompiledFilter, unknown>();

type TypedDslQueryOutput<Q extends TypedDslQuery> = Q extends Query<unknown, infer Output, QueryAst>
  ? Output
  : never;

type MoonBitRuntimeResult<T, E> = { _0: T } | { _0: E };

type MoonBitExports = {
  run_json_text(filter: string, input: string): MoonBitRuntimeResult<string[], unknown>;
  try_compile(filter: string): MoonBitRuntimeResult<unknown, unknown>;
  run_compiled_json_text(filter: unknown, input: string): MoonBitRuntimeResult<string[], unknown>;
  try_parse_json(input: string): MoonBitRuntimeResult<unknown, unknown>;
  is_valid_json(input: string): boolean;
  identity(): unknown;
  field(name: string): unknown;
  index(index: number): unknown;
  pipe(left: unknown, right: unknown): unknown;
  map(inner: unknown): unknown;
  literal(value: unknown): unknown;
  iter(): unknown;
  comma(left: unknown, right: unknown): unknown;
  call(name: string, args: unknown[]): unknown;
  select(predicate: unknown): unknown;
  eq(left: unknown, right: unknown): unknown;
  lt(left: unknown, right: unknown): unknown;
  gt(left: unknown, right: unknown): unknown;
  and_(left: unknown, right: unknown): unknown;
  or_(left: unknown, right: unknown): unknown;
  not_(value: unknown): unknown;
  add(left: unknown, right: unknown): unknown;
  if_else(cond: unknown, thenBranch: unknown, elseBranch: unknown): unknown;
  fallback(left: unknown, right: unknown): unknown;
  try_catch(inner: unknown, handler: unknown): unknown;
  query_json_text(query: unknown, input: string): MoonBitRuntimeResult<string[], unknown>;
};

function normalizeMoonBitModule(
  module: Record<string, unknown> & { default?: Record<string, unknown> },
): MoonBitExports {
  const normalized = (
    "run_json_text" in module
      ? module
      : module.default
  ) as MoonBitExports | undefined;
  if (normalized === undefined) {
    throw new TypeError("Failed to load MoonBit JS runtime");
  }
  return normalized;
}

const moonbit = normalizeMoonBitModule(moonbitRuntime);

function isTypedDslQuery(value: unknown): value is TypedDslQuery {
  if (typeof value !== "object" || value === null || !("ast" in value)) {
    return false;
  }
  const keys = Object.keys(value as Record<string, unknown>);
  return keys.length === 1 && keys[0] === "ast";
}

function toBackendRuntimeError(
  error: unknown,
  fallbackMessage: string,
): JqxBackendRuntimeError {
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    "message" in error &&
    "line" in error &&
    "column" in error &&
    "offset" in error &&
    typeof error.code === "string" &&
    typeof error.message === "string" &&
    typeof error.line === "number" &&
    typeof error.column === "number" &&
    typeof error.offset === "number"
  ) {
    return {
      kind: "backend_runtime",
      message: error.message,
      details: {
        code: error.code,
        message: error.message,
        line: error.line,
        column: error.column,
        offset: error.offset,
      },
    };
  }
  if (typeof error === "string") {
    return { kind: "backend_runtime", message: error };
  }
  if (error instanceof Error) {
    return { kind: "backend_runtime", message: error.message };
  }
  return { kind: "backend_runtime", message: fallbackMessage };
}

function isMoonBitOk<T>(value: unknown): value is { _0: T } {
  return (
    typeof value === "object" &&
    value !== null &&
    "_0" in value &&
    typeof (value as { constructor?: { name?: unknown } }).constructor?.name === "string" &&
    (value as { constructor: { name: string } }).constructor.name.endsWith("Ok")
  );
}

function isMoonBitErr<E>(value: unknown): value is { _0: E } {
  return (
    typeof value === "object" &&
    value !== null &&
    "_0" in value &&
    typeof (value as { constructor?: { name?: unknown } }).constructor?.name === "string" &&
    (value as { constructor: { name: string } }).constructor.name.endsWith("Err")
  );
}

function fromMoonBitResult<T, U>(
  result: unknown,
  mapOk: (value: T) => U,
  context: string,
): JqxResult<U, JqxRuntimeError> {
  if (isMoonBitOk<T>(result)) {
    return { ok: true, value: mapOk(result._0) };
  }
  if (isMoonBitErr(result)) {
    return {
      ok: false,
      error: toBackendRuntimeError(result._0, `${context} failed`),
    };
  }
  return {
    ok: false,
    error: {
      kind: "backend_runtime",
      message: `${context} returned an unexpected result`,
    },
  };
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

function toMoonBitValue(value: Json): unknown {
  const encoded = JSON.stringify(value);
  const parsed = fromMoonBitResult<unknown, unknown>(
    moonbit.try_parse_json(encoded),
    (out) => out,
    "literal",
  );
  if (!parsed.ok) {
    throw parsed.error;
  }
  return parsed.value;
}

function compileDirectQueryAst(ast: QueryAst): unknown {
  switch (ast.kind) {
    case "identity":
      return moonbit.identity();
    case "field":
      return moonbit.field(ast.name);
    case "index":
      return moonbit.index(ast.index);
    case "pipe":
      return moonbit.pipe(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "map":
      return moonbit.map(compileDirectQueryAst(ast.inner));
    case "literal":
      return moonbit.literal(toMoonBitValue(ast.value));
    case "iter":
      return moonbit.iter();
    case "comma":
      return moonbit.comma(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "call":
      return moonbit.call(ast.name, ast.args.map(compileDirectQueryAst));
    case "select":
      return moonbit.select(compileDirectQueryAst(ast.predicate));
    case "eq":
      return moonbit.eq(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "lt":
      return moonbit.lt(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "gt":
      return moonbit.gt(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "and":
      return moonbit.and_(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "or":
      return moonbit.or_(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "not":
      return moonbit.not_(compileDirectQueryAst(ast.value));
    case "add":
      return moonbit.add(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "ifElse":
      return moonbit.if_else(
        compileDirectQueryAst(ast.cond),
        compileDirectQueryAst(ast.thenBranch),
        compileDirectQueryAst(ast.elseBranch),
      );
    case "fallback":
      return moonbit.fallback(compileDirectQueryAst(ast.left), compileDirectQueryAst(ast.right));
    case "tryCatch":
      return moonbit.try_catch(
        compileDirectQueryAst(ast.inner),
        compileDirectQueryAst(ast.handler),
      );
  }
}

function normalizeDirectQueryInput(query: DirectQueryInput): QueryAst {
  if (isTypedDslQuery(query)) {
    return toQueryAst(query);
  }
  return query;
}

function compileDirectQuery(query: DirectQueryInput): JqxResult<unknown, JqxRuntimeError> {
  try {
    return { ok: true, value: compileDirectQueryAst(normalizeDirectQueryInput(query)) };
  } catch (error) {
    if (
      typeof error === "object" &&
      error !== null &&
      "kind" in error &&
      typeof error.kind === "string"
    ) {
      return { ok: false, error: error as JqxRuntimeError };
    }
    return {
      ok: false,
      error: toBackendRuntimeError(error, "Failed to compile direct query"),
    };
  }
}

function runCompiledJsonTextInternal(
  filter: CompiledFilter,
  input: string,
): JqxResult<string[], JqxRuntimeError> {
  try {
    return fromMoonBitResult<string[], string[]>(
      moonbit.run_compiled_json_text(unwrapCompiledFilter(filter), input),
      (value) => value,
      "run_compiled_json_text",
    );
  } catch (error) {
    return {
      ok: false,
      error: toBackendRuntimeError(error, "run_compiled_json_text failed"),
    };
  }
}

function runCompiledInternal(
  filter: CompiledFilter,
  input: Json,
): JqxResult<Json[], JqxRuntimeError> {
  const encoded = encodeRuntimeInput(input);
  if (!encoded.ok) {
    return encoded;
  }
  const runtimeOut = runCompiledJsonTextInternal(filter, encoded.value);
  if (!runtimeOut.ok) {
    return runtimeOut;
  }
  return decodeRuntimeOutputs(runtimeOut.value);
}

export class CompiledFilter<Filter extends string = string> {
  constructor(raw: unknown) {
    compiledFilterRaw.set(this, raw);
  }

  run<Input extends Json>(input: Input): JqxResult<InferJqOutput<Input, Filter, "json">[], JqxRuntimeError>;
  run(input: Json): JqxResult<Json[], JqxRuntimeError>;
  run(input: Json): JqxResult<Json[], JqxRuntimeError> {
    return runCompiledInternal(this, input);
  }

  runJsonText(input: string): JqxResult<string[], JqxRuntimeError> {
    return runCompiledJsonTextInternal(this, input);
  }
}

function unwrapCompiledFilter(filter: CompiledFilter): unknown {
  const raw = compiledFilterRaw.get(filter);
  if (raw === undefined) {
    throw new TypeError("Invalid compiled filter");
  }
  return raw;
}

export interface JqxDirectRuntime extends JqxRuntime {
  runJsonText(filter: string, input: string): JqxResult<string[], JqxRuntimeError>;
  compile<Filter extends string>(filter: Filter): JqxResult<CompiledFilter<Filter>, JqxRuntimeError>;
  compile(filter: string): JqxResult<CompiledFilter, JqxRuntimeError>;
  parseJson(input: string): JqxResult<Json, JqxRuntimeError>;
  isValidJson(input: string): boolean;
}

export interface JqxDirectQueryRuntime extends JqxDirectRuntime, JqxQueryRuntime<QueryAst> {
  queryJsonText(query: DirectQueryInput, input: string): JqxResult<string[], JqxRuntimeError>;
}

export function runJsonText(filter: string, input: string): JqxResult<string[], JqxRuntimeError> {
  return fromMoonBitResult<string[], string[]>(
    moonbit.run_json_text(filter, input),
    (value) => value,
    "run_json_text",
  );
}

export function run<Input extends Json, Filter extends string>(
  filter: Filter,
  input: Input,
): JqxResult<InferJqOutput<Input, Filter, "json">[], JqxRuntimeError>;
export function run(filter: string, input: Json): JqxResult<Json[], JqxRuntimeError>;
export function run(filter: string, input: Json): JqxResult<Json[], JqxRuntimeError> {
  const encoded = encodeRuntimeInput(input);
  if (!encoded.ok) {
    return encoded;
  }
  const runtimeOut = runJsonText(filter, encoded.value);
  if (!runtimeOut.ok) {
    return runtimeOut;
  }
  return decodeRuntimeOutputs(runtimeOut.value);
}

export function compile<Filter extends string>(
  filter: Filter,
): JqxResult<CompiledFilter<Filter>, JqxRuntimeError>;
export function compile(filter: string): JqxResult<CompiledFilter, JqxRuntimeError>;
export function compile<Filter extends string>(
  filter: Filter,
): JqxResult<CompiledFilter<Filter>, JqxRuntimeError> {
  return fromMoonBitResult<unknown, CompiledFilter<Filter>>(
    moonbit.try_compile(filter),
    (value) => new CompiledFilter<Filter>(value),
    "compile",
  );
}

export function parseJson(input: string): JqxResult<Json, JqxRuntimeError> {
  const parsed = fromMoonBitResult<unknown, null>(
    moonbit.try_parse_json(input),
    () => null,
    "parse_json",
  );
  if (!parsed.ok) {
    return parsed;
  }
  try {
    return { ok: true, value: JSON.parse(input) as Json };
  } catch (error) {
    return {
      ok: false,
      error: {
        kind: "backend_runtime",
        message: error instanceof Error ? error.message : "parseJson failed unexpectedly",
      },
    };
  }
}

export function isValidJson(input: string): boolean {
  return moonbit.is_valid_json(input);
}

export function queryJsonText(
  query: DirectQueryInput,
  input: string,
): JqxResult<string[], JqxRuntimeError> {
  const compiled = compileDirectQuery(query);
  if (!compiled.ok) {
    return compiled;
  }
  return fromMoonBitResult<string[], string[]>(
    moonbit.query_json_text(compiled.value, input),
    (value) => value,
    "query_json_text",
  );
}

export function query<Q extends TypedDslQuery>(
  query: Q,
  input: Json,
): JqxResult<TypedDslQueryOutput<Q>[], JqxRuntimeError>;
export function query(query: QueryAst, input: Json): JqxResult<Json[], JqxRuntimeError>;
export function query(query: DirectQueryInput, input: Json): JqxResult<Json[], JqxRuntimeError> {
  const encoded = encodeRuntimeInput(input);
  if (!encoded.ok) {
    return encoded;
  }
  const runtimeOut = queryJsonText(query, encoded.value);
  if (!runtimeOut.ok) {
    return runtimeOut;
  }
  return decodeRuntimeOutputs(runtimeOut.value);
}

export const runtime: JqxDirectRuntime = {
  run,
  runJsonText,
  compile,
  parseJson,
  isValidJson,
};

const directQuery: JqxDirectQueryRuntime["query"] = query;
const directQueryJsonText: JqxDirectQueryRuntime["queryJsonText"] = queryJsonText;

export const queryRuntime: JqxDirectQueryRuntime = {
  ...runtime,
  query: directQuery,
  queryJsonText: directQueryJsonText,
};
