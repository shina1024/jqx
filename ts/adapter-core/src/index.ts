export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

export type MaybePromise<T> = T | Promise<T>;

export interface JqxError {
  code: string;
  message: string;
  line: number;
  column: number;
  offset: number;
}

export type JqxRuntimeError = string | JqxError;

export interface JqxDynamicRuntime {
  run(filter: string, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export interface JqxTypedRuntime<Q = unknown> {
  runQuery(query: Q, input: string): MaybePromise<JqxResult<string[], JqxRuntimeError>>;
}

export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

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
  Input,
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
      kind: "output_parse";
      index: number;
      raw: string;
      message: string;
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

export function runtimeErrorToMessage(error: JqxRuntimeError): string {
  return typeof error === "string" ? error : error.message;
}

export function parseRuntimeJsonOutputs(rawValues: string[]): JqxResult<unknown[]> {
  const parsed: unknown[] = [];
  for (const [index, raw] of rawValues.entries()) {
    try {
      parsed.push(JSON.parse(raw));
    } catch (error) {
      return {
        ok: false,
        error: `output_parse at index ${index}: ${error instanceof Error ? error.message : "Failed to parse output"}`,
      };
    }
  }
  return { ok: true, value: parsed };
}

async function parseAndValidateOutputs<OutSchema, OutValue, Issues>(
  outputSchema: OutSchema,
  rawValues: string[],
  validateOutput: (
    schema: OutSchema,
    input: unknown,
  ) => MaybePromise<ValidationResult<OutValue, Issues>>,
  outputValidationMessage: string,
): Promise<JqxResult<OutValue[], AdapterError<Issues>>> {
  const validated: OutValue[] = [];
  for (const [index, raw] of rawValues.entries()) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch (error) {
      return fail({
        kind: "output_parse",
        index,
        raw,
        message: error instanceof Error ? error.message : "Failed to parse output",
      });
    }
    const parsedOut = await validateOutput(outputSchema, parsed);
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

export async function runFilterWithValidation<InSchema, OutSchema, InValue, OutValue, Issues>(
  runtime: JqxDynamicRuntime,
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
  const runtimeOut = await runtime.run(options.filter, JSON.stringify(parsedIn.value));
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

export async function runQueryWithValidation<Q, InSchema, OutSchema, InValue, OutValue, Issues>(
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
  const runtimeOut = await runtime.runQuery(options.query, JSON.stringify(parsedIn.value));
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
  Input,
  Mode extends InferenceFallbackMode = "unknown",
>(
  runtime: JqxDynamicRuntime,
  options: InferredOptions<Filter, Input, Mode>,
): Promise<JqxResult<InferJqOutput<Input, Filter, Mode>[], string>> {
  const runtimeOut = await runtime.run(options.filter, JSON.stringify(options.input));
  if (!runtimeOut.ok) {
    return { ok: false, error: runtimeErrorToMessage(runtimeOut.error) };
  }
  const parsed = parseRuntimeJsonOutputs(runtimeOut.value);
  if (!parsed.ok) {
    return parsed;
  }
  return { ok: true, value: parsed.value as InferJqOutput<Input, Filter, Mode>[] };
}

export function hasTypedRuntime<Q>(
  runtime: JqxDynamicRuntime & Partial<JqxTypedRuntime<Q>>,
): runtime is JqxDynamicRuntime & JqxTypedRuntime<Q> {
  return typeof runtime.runQuery === "function";
}
