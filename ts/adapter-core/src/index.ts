export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };
export type JqxResultStream<T, E = string> = AsyncIterable<JqxResult<T, E>>;

export type MaybePromise<T> = T | Promise<T>;

export interface JqxError {
  code: string;
  message: string;
  line: number;
  column: number;
  offset: number;
}

export interface JqxBackendRuntimeError {
  kind: "backend_runtime";
  message: string;
  details?: Partial<JqxError>;
}

export interface JqxInputStringifyRuntimeError {
  kind: "input_stringify";
  message: string;
}

export interface JqxOutputParseRuntimeError {
  kind: "output_parse";
  message: string;
  index: number;
}

export type JqxRuntimeError =
  | JqxBackendRuntimeError
  | JqxInputStringifyRuntimeError
  | JqxOutputParseRuntimeError;

export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

export interface JqxRuntime {
  run(filter: string, input: Json): MaybePromise<JqxResult<Json[], JqxRuntimeError>>;
}

export interface JqxTypedRuntime<Q = unknown> {
  query(query: Q, input: Json): MaybePromise<JqxResult<Json[], JqxRuntimeError>>;
}

export * from "./typed_query.js";

export type InferenceFallbackMode = "unknown" | "json";

type InferenceFallbackValue<Mode extends InferenceFallbackMode> = Mode extends "json"
  ? Json
  : unknown;

type TrimLeft<S extends string> = S extends ` ${infer Rest}` ? TrimLeft<Rest> : S;
type TrimRight<S extends string> = S extends `${infer Rest} ` ? TrimRight<Rest> : S;
type Trim<S extends string> = TrimLeft<TrimRight<S>>;

type HasUnsupportedPathToken<S extends string> =
  S extends `${string}${"|" | "," | "(" | ")" | ":" | ";" | "?" | "+" | "-" | "*" | "/" | "=" | "!" | "<" | ">" | "$" | "@" | '"' | "'" | "`" | " " | "\n" | "\r" | "\t"}${string}`
    ? true
    : false;

type ReadFieldToken<
  Path extends string,
  Acc extends string = "",
> = Path extends `${infer Char}${infer Rest}`
  ? Char extends "." | "["
    ? [Acc, `${Char}${Rest}`]
    : ReadFieldToken<Rest, `${Acc}${Char}`>
  : [Acc, ""];

type ArrayElement<Current, Mode extends InferenceFallbackMode> = Current extends null | undefined
  ? InferenceFallbackValue<Mode>
  : Current extends ReadonlyArray<infer Item>
    ? Item
    : InferenceFallbackValue<Mode>;

type AccessFieldSegment<
  Current,
  Field extends string,
  Mode extends InferenceFallbackMode,
> = Current extends null | undefined
  ? InferenceFallbackValue<Mode>
  : Current extends object
    ? Field extends keyof Current
      ? Current[Field]
      : InferenceFallbackValue<Mode>
    : InferenceFallbackValue<Mode>;

type ParseBracketSegment<
  Current,
  Inner extends string,
  Mode extends InferenceFallbackMode,
> = Inner extends ""
  ? ArrayElement<Current, Mode>
  : Inner extends `${number}`
    ? ArrayElement<Current, Mode>
    : InferenceFallbackValue<Mode>;

type ParsePath<Path extends string, Current, Mode extends InferenceFallbackMode> = Path extends ""
  ? Current
  : Path extends `.${infer Rest}`
    ? ParsePath<Rest, Current, Mode>
    : HasUnsupportedPathToken<Path> extends true
      ? InferenceFallbackValue<Mode>
      : Path extends `[${infer Inner}]${infer Rest}`
        ? ParsePath<Rest, ParseBracketSegment<Current, Inner, Mode>, Mode>
        : ReadFieldToken<Path> extends [infer Field, infer Rest]
          ? Field extends string
            ? Rest extends string
              ? Field extends ""
                ? InferenceFallbackValue<Mode>
                : ParsePath<Rest, AccessFieldSegment<Current, Field, Mode>, Mode>
              : InferenceFallbackValue<Mode>
            : InferenceFallbackValue<Mode>
          : InferenceFallbackValue<Mode>;

type ParseFilter<
  Filter extends string,
  Input,
  Mode extends InferenceFallbackMode,
> = Filter extends "."
  ? Input
  : Filter extends `.${infer Path}`
    ? ParsePath<Path, Input, Mode>
    : InferenceFallbackValue<Mode>;

/// Partial inference for jq string filters.
/// Supported subset: `.`, `.foo`, `.foo.bar`, `.[n]`, `.[]`, and their simple combinations.
/// Unsupported syntax falls back to `unknown` (or `Json` when mode is `"json"`).
export type InferJqOutput<
  Input,
  Filter extends string,
  Mode extends InferenceFallbackMode = "unknown",
> = ParseFilter<Trim<Filter>, Input, Mode>;

export interface InferredOptions<
  Filter extends string,
  Input extends Json,
  Mode extends InferenceFallbackMode = "unknown",
> {
  filter: Filter;
  input: Input;
  fallback?: Mode;
}

export interface FilterOptions<InSchema, OutSchema> {
  filter: string;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

export interface QueryOptions<Q, InSchema, OutSchema> {
  query: Q;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

export type AdapterError<Issues> =
  | {
      kind: "input_validation";
      message: string;
      issues: Issues;
    }
  | {
      kind: "runtime";
      message: string;
      runtimeError: JqxRuntimeError;
    }
  | {
      kind: "output_validation";
      index: number;
      message: string;
      issues: Issues;
    };

export type ValidationResult<Value, Issues> =
  | { ok: true; value: Value }
  | { ok: false; issues: Issues };

export interface ValidationHooks<InSchema, OutSchema, InValue, OutValue, Issues> {
  validateInput: (
    schema: InSchema,
    input: unknown,
  ) => MaybePromise<ValidationResult<InValue, Issues>>;
  validateOutput: (
    schema: OutSchema,
    input: unknown,
  ) => MaybePromise<ValidationResult<OutValue, Issues>>;
  inputValidationMessage?: string;
  outputValidationMessage?: string;
}

function fail<T, E>(error: E): JqxResult<T, E> {
  return { ok: false, error };
}

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function isJqxError(value: unknown): value is JqxError {
  if (!isObjectRecord(value)) {
    return false;
  }
  return (
    typeof value.code === "string" &&
    typeof value.message === "string" &&
    typeof value.line === "number" &&
    typeof value.column === "number" &&
    typeof value.offset === "number"
  );
}

export function isJqxRuntimeError(value: unknown): value is JqxRuntimeError {
  if (
    !isObjectRecord(value) ||
    typeof value.kind !== "string" ||
    typeof value.message !== "string"
  ) {
    return false;
  }
  if (value.kind === "backend_runtime") {
    return value.details === undefined || isObjectRecord(value.details);
  }
  if (value.kind === "input_stringify") {
    return true;
  }
  if (value.kind === "output_parse") {
    return typeof value.index === "number";
  }
  return false;
}

export function toJqxRuntimeError(error: unknown): JqxRuntimeError {
  if (isJqxRuntimeError(error)) {
    return error;
  }
  if (isJqxError(error)) {
    return {
      kind: "backend_runtime",
      message: error.message,
      details: error,
    };
  }
  if (typeof error === "string") {
    return {
      kind: "backend_runtime",
      message: error,
    };
  }
  if (error instanceof Error) {
    return {
      kind: "backend_runtime",
      message: error.message,
    };
  }
  if (isObjectRecord(error) && typeof error.message === "string") {
    return {
      kind: "backend_runtime",
      message: error.message,
    };
  }
  return {
    kind: "backend_runtime",
    message: "Unknown runtime error",
  };
}

export function runtimeErrorToMessage(error: JqxRuntimeError): string {
  return error.message;
}

async function parseAndValidateOutputs<OutSchema, OutValue, Issues>(
  outputSchema: OutSchema,
  values: Json[],
  validateOutput: (
    schema: OutSchema,
    input: unknown,
  ) => MaybePromise<ValidationResult<OutValue, Issues>>,
  outputValidationMessage: string,
): Promise<JqxResult<OutValue[], AdapterError<Issues>>> {
  const validated: OutValue[] = [];
  for (const [index, value] of values.entries()) {
    const parsedOut = await validateOutput(outputSchema, value);
    if (!parsedOut.ok) {
      return fail({
        kind: "output_validation",
        index,
        message: outputValidationMessage,
        issues: parsedOut.issues,
      });
    }
    validated.push(parsedOut.value);
  }
  return { ok: true, value: validated };
}

export async function runFilterWithValidation<
  InSchema,
  OutSchema,
  InValue extends Json,
  OutValue,
  Issues,
>(
  runtime: JqxRuntime,
  options: FilterOptions<InSchema, OutSchema>,
  hooks: ValidationHooks<InSchema, OutSchema, InValue, OutValue, Issues>,
): Promise<JqxResult<OutValue[], AdapterError<Issues>>> {
  const parsedIn = await hooks.validateInput(options.inputSchema, options.input);
  if (!parsedIn.ok) {
    return fail({
      kind: "input_validation",
      message: hooks.inputValidationMessage ?? "Input does not match schema",
      issues: parsedIn.issues,
    });
  }
  const runtimeOut = await runtime.run(options.filter, parsedIn.value);
  if (!runtimeOut.ok) {
    return fail({
      kind: "runtime",
      message: runtimeErrorToMessage(runtimeOut.error),
      runtimeError: runtimeOut.error,
    });
  }
  return parseAndValidateOutputs(
    options.outputSchema,
    runtimeOut.value,
    hooks.validateOutput,
    hooks.outputValidationMessage ?? "Output does not match schema",
  );
}

export async function runQueryWithValidation<
  Q,
  InSchema,
  OutSchema,
  InValue extends Json,
  OutValue,
  Issues,
>(
  runtime: JqxTypedRuntime<Q>,
  options: QueryOptions<Q, InSchema, OutSchema>,
  hooks: ValidationHooks<InSchema, OutSchema, InValue, OutValue, Issues>,
): Promise<JqxResult<OutValue[], AdapterError<Issues>>> {
  const parsedIn = await hooks.validateInput(options.inputSchema, options.input);
  if (!parsedIn.ok) {
    return fail({
      kind: "input_validation",
      message: hooks.inputValidationMessage ?? "Input does not match schema",
      issues: parsedIn.issues,
    });
  }
  const runtimeOut = await runtime.query(options.query, parsedIn.value);
  if (!runtimeOut.ok) {
    return fail({
      kind: "runtime",
      message: runtimeErrorToMessage(runtimeOut.error),
      runtimeError: runtimeOut.error,
    });
  }
  return parseAndValidateOutputs(
    options.outputSchema,
    runtimeOut.value,
    hooks.validateOutput,
    hooks.outputValidationMessage ?? "Output does not match schema",
  );
}

export async function runInferred<
  Filter extends string,
  Input extends Json,
  Mode extends InferenceFallbackMode = "unknown",
>(
  runtime: JqxRuntime,
  options: InferredOptions<Filter, Input, Mode>,
): Promise<JqxResult<InferJqOutput<Input, Filter, Mode>[], string>> {
  const runtimeOut = await runtime.run(options.filter, options.input);
  if (!runtimeOut.ok) {
    return { ok: false, error: runtimeErrorToMessage(runtimeOut.error) };
  }
  return { ok: true, value: runtimeOut.value as InferJqOutput<Input, Filter, Mode>[] };
}

export function hasTypedRuntime<Q>(
  runtime: JqxRuntime & Partial<JqxTypedRuntime<Q>>,
): runtime is JqxRuntime & JqxTypedRuntime<Q> {
  return typeof runtime.query === "function";
}
