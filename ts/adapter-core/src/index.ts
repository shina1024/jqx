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

export interface JqxInputValueRuntimeError {
  kind: "input_value";
  message: string;
  path: string;
}

export interface JqxOutputParseRuntimeError {
  kind: "output_parse";
  message: string;
  index: number;
}

export interface JqxOutputValueRuntimeError {
  kind: "output_value";
  message: string;
  index: number;
  path: string;
}

export type JqxRuntimeError =
  | JqxBackendRuntimeError
  | JqxInputStringifyRuntimeError
  | JqxInputValueRuntimeError
  | JqxOutputParseRuntimeError
  | JqxOutputValueRuntimeError;

export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

export interface JqxRuntime {
  run(filter: string, input: Json): MaybePromise<JqxResult<Json[], JqxRuntimeError>>;
}

export interface JqxQueryRuntime<Q = unknown> {
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

function ownDataValue(value: object, key: string): unknown {
  const descriptor = Object.getOwnPropertyDescriptor(value, key);
  return descriptor !== undefined && "value" in descriptor ? descriptor.value : undefined;
}

function snapshotJqxError(value: unknown): JqxError | null {
  if (!isObjectRecord(value)) {
    return null;
  }
  const code = ownDataValue(value, "code");
  const message = ownDataValue(value, "message");
  const line = ownDataValue(value, "line");
  const column = ownDataValue(value, "column");
  const offset = ownDataValue(value, "offset");
  return typeof code === "string" &&
    typeof message === "string" &&
    typeof line === "number" &&
    typeof column === "number" &&
    typeof offset === "number"
    ? { code, message, line, column, offset }
    : null;
}

function snapshotErrorDetails(value: unknown): Partial<JqxError> | undefined {
  if (!isObjectRecord(value)) {
    return undefined;
  }
  const details: Partial<JqxError> = {};
  const code = ownDataValue(value, "code");
  const message = ownDataValue(value, "message");
  const line = ownDataValue(value, "line");
  const column = ownDataValue(value, "column");
  const offset = ownDataValue(value, "offset");
  if (typeof code === "string") details.code = code;
  if (typeof message === "string") details.message = message;
  if (typeof line === "number") details.line = line;
  if (typeof column === "number") details.column = column;
  if (typeof offset === "number") details.offset = offset;
  return details;
}

function snapshotRuntimeError(value: unknown): JqxRuntimeError | null {
  if (!isObjectRecord(value)) {
    return null;
  }
  const kind = ownDataValue(value, "kind");
  const message = ownDataValue(value, "message");
  if (typeof kind !== "string" || typeof message !== "string") {
    return null;
  }
  if (kind === "backend_runtime") {
    const detailsValue = ownDataValue(value, "details");
    if (detailsValue === undefined) return { kind, message };
    const details = snapshotErrorDetails(detailsValue);
    return details === undefined ? null : { kind, message, details };
  }
  if (kind === "input_stringify") return { kind, message };
  if (kind === "input_value") {
    const path = ownDataValue(value, "path");
    return typeof path === "string" ? { kind, message, path } : null;
  }
  if (kind === "output_parse") {
    const index = ownDataValue(value, "index");
    return typeof index === "number" ? { kind, message, index } : null;
  }
  if (kind === "output_value") {
    const index = ownDataValue(value, "index");
    const path = ownDataValue(value, "path");
    return typeof index === "number" && typeof path === "string"
      ? { kind, message, index, path }
      : null;
  }
  return null;
}

export function isJqxError(value: unknown): value is JqxError {
  try {
    return snapshotJqxError(value) !== null;
  } catch {
    return false;
  }
}

export function isJqxRuntimeError(value: unknown): value is JqxRuntimeError {
  try {
    return snapshotRuntimeError(value) !== null;
  } catch {
    return false;
  }
}

export function toJqxRuntimeError(error: unknown): JqxRuntimeError {
  try {
    const runtimeError = snapshotRuntimeError(error);
    if (runtimeError !== null) return runtimeError;
    const jqxError = snapshotJqxError(error);
    if (jqxError !== null) {
      return { kind: "backend_runtime", message: jqxError.message, details: jqxError };
    }
    if (typeof error === "string") return { kind: "backend_runtime", message: error };
    if (isObjectRecord(error)) {
      const message = ownDataValue(error, "message");
      if (typeof message === "string") return { kind: "backend_runtime", message };
    }
  } catch {
    return { kind: "backend_runtime", message: "Unknown runtime error" };
  }
  return { kind: "backend_runtime", message: "Unknown runtime error" };
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
  runtime: JqxQueryRuntime<Q>,
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
): Promise<JqxResult<InferJqOutput<Input, Filter, Mode>[], JqxRuntimeError>> {
  const runtimeOut = await runtime.run(options.filter, options.input);
  if (!runtimeOut.ok) {
    return { ok: false, error: runtimeOut.error };
  }
  return { ok: true, value: runtimeOut.value as InferJqOutput<Input, Filter, Mode>[] };
}
