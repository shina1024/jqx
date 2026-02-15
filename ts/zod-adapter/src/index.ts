import { z } from "zod";

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

export type AdapterError =
  | {
      kind: "input_validation";
      message: string;
      issues: z.ZodIssue[];
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
      issues: z.ZodIssue[];
    };

export interface FilterOptions<InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny> {
  filter: string;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

export interface QueryOptions<Q, InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny> {
  query: Q;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

export interface DynamicAdapter {
  filter<InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny>(
    options: FilterOptions<InSchema, OutSchema>,
  ): Promise<JqxResult<z.output<OutSchema>[], AdapterError>>;
  inferred<Filter extends string, Input, Mode extends InferenceFallbackMode = "unknown">(
    options: InferredOptions<Filter, Input, Mode>,
  ): Promise<JqxResult<InferJqOutput<Input, Filter, Mode>[], string>>;
}

export interface TypedAdapter<Q> extends DynamicAdapter {
  query<InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny>(
    options: QueryOptions<Q, InSchema, OutSchema>,
  ): Promise<JqxResult<z.output<OutSchema>[], AdapterError>>;
}

function fail<T>(error: AdapterError): JqxResult<T, AdapterError> {
  return { ok: false, error };
}

function runtimeErrorToMessage(error: JqxRuntimeError): string {
  return typeof error === "string" ? error : error.message;
}

function parseRuntimeJsonOutputs(rawValues: string[]): JqxResult<unknown[]> {
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

function parseAndValidateOutput<OutSchema extends z.ZodTypeAny>(
  outputSchema: OutSchema,
  rawValues: string[],
): JqxResult<z.output<OutSchema>[], AdapterError> {
  const validated: z.output<OutSchema>[] = [];
  for (const [index, raw] of rawValues.entries()) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch (err) {
      return fail({
        kind: "output_parse",
        index,
        raw,
        message: err instanceof Error ? err.message : "Failed to parse output",
      });
    }
    const parsedOut = outputSchema.safeParse(parsed);
    if (!parsedOut.success) {
      return fail({
        kind: "output_validation",
        index,
        message: "Output does not match schema",
        issues: parsedOut.error.issues,
      });
    }
    validated.push(parsedOut.data);
  }
  return { ok: true, value: validated };
}

async function runFilterInternal<InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny>(
  runtime: JqxDynamicRuntime,
  options: FilterOptions<InSchema, OutSchema>,
): Promise<JqxResult<z.output<OutSchema>[], AdapterError>> {
  const parsedIn = options.inputSchema.safeParse(options.input);
  if (!parsedIn.success) {
    return fail({
      kind: "input_validation",
      message: "Input does not match schema",
      issues: parsedIn.error.issues,
    });
  }
  const rawInput = JSON.stringify(parsedIn.data);
  const runtimeOut = await runtime.run(options.filter, rawInput);
  if (!runtimeOut.ok) {
    return fail({
      kind: "runtime",
      message: runtimeErrorToMessage(runtimeOut.error),
      runtimeError: runtimeOut.error,
    });
  }
  return parseAndValidateOutput(options.outputSchema, runtimeOut.value);
}

async function runInferredInternal<
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

async function runQueryInternal<Q, InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny>(
  runtime: JqxTypedRuntime<Q>,
  options: QueryOptions<Q, InSchema, OutSchema>,
): Promise<JqxResult<z.output<OutSchema>[], AdapterError>> {
  const parsedIn = options.inputSchema.safeParse(options.input);
  if (!parsedIn.success) {
    return fail({
      kind: "input_validation",
      message: "Input does not match schema",
      issues: parsedIn.error.issues,
    });
  }
  const rawInput = JSON.stringify(parsedIn.data);
  const runtimeOut = await runtime.runQuery(options.query, rawInput);
  if (!runtimeOut.ok) {
    return fail({
      kind: "runtime",
      message: runtimeErrorToMessage(runtimeOut.error),
      runtimeError: runtimeOut.error,
    });
  }
  return parseAndValidateOutput(options.outputSchema, runtimeOut.value);
}

export function createAdapter<Q>(runtime: JqxDynamicRuntime & JqxTypedRuntime<Q>): TypedAdapter<Q>;
export function createAdapter(runtime: JqxDynamicRuntime): DynamicAdapter;
export function createAdapter<Q>(
  runtime: JqxDynamicRuntime & Partial<JqxTypedRuntime<Q>>,
): DynamicAdapter | TypedAdapter<Q> {
  const dynamicAdapter: DynamicAdapter = {
    filter(options) {
      return runFilterInternal(runtime, options);
    },
    inferred(options) {
      return runInferredInternal(runtime, options);
    },
  };

  if (typeof runtime.runQuery === "function") {
    const typedAdapter: TypedAdapter<Q> = {
      ...dynamicAdapter,
      query(options) {
        return runQueryInternal(runtime as JqxTypedRuntime<Q>, options);
      },
    };
    return typedAdapter;
  }

  return dynamicAdapter;
}
