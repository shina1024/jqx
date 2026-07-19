import { runtimeErrorToMessage } from "./runtime_error.js";

import type { InferJqOutput, InferenceFallbackMode, InferredOptions } from "./inference.js";
import type { JqxRuntimeError } from "./runtime_error.js";

export * from "./inference.js";
export * from "./runtime_error.js";
export * from "./typed_query.js";

export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };
export type JqxResultStream<T, E = string> = AsyncIterable<JqxResult<T, E>>;

export type MaybePromise<T> = T | Promise<T>;

export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

export interface JqxRuntime {
  run(filter: string, input: Json): MaybePromise<JqxResult<Json[], JqxRuntimeError>>;
}

export interface JqxQueryRuntime<Q = unknown> {
  query(query: Q, input: Json): MaybePromise<JqxResult<Json[], JqxRuntimeError>>;
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
