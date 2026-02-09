import * as yup from "yup";

export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

export type MaybePromise<T> = T | Promise<T>;

export interface JqxDynamicRuntime {
  run(filter: string, input: string): MaybePromise<JqxResult<string[]>>;
}

export interface JqxTypedRuntime<Q = unknown> {
  runQuery(query: Q, input: string): MaybePromise<JqxResult<string[]>>;
}

export type YupAdapterError =
  | {
      kind: "input_validation";
      message: string;
      issues: string[];
    }
  | {
      kind: "runtime";
      message: string;
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
      issues: string[];
    };

export interface RunWithYupOptions<InSchema extends yup.AnySchema, OutSchema extends yup.AnySchema> {
  filter: string;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

export interface ExecuteWithYupOptions<Q, InSchema extends yup.AnySchema, OutSchema extends yup.AnySchema> {
  query: Q;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

function fail<T>(error: YupAdapterError): JqxResult<T, YupAdapterError> {
  return { ok: false, error };
}

function normalizeYupIssues(error: yup.ValidationError): string[] {
  const issues = error.errors.filter((item): item is string => typeof item === "string" && item.length > 0);
  if (issues.length > 0) {
    return issues;
  }
  if (error.message.length > 0) {
    return [error.message];
  }
  return ["Validation failed"];
}

async function validateWithYup<TSchema extends yup.AnySchema>(
  schema: TSchema,
  input: unknown,
): Promise<{ ok: true; value: yup.InferType<TSchema> } | { ok: false; issues: string[] }> {
  try {
    const value = await schema.validate(input, { abortEarly: false, strict: true });
    return { ok: true, value };
  } catch (error) {
    if (error instanceof yup.ValidationError) {
      return { ok: false, issues: normalizeYupIssues(error) };
    }
    throw error;
  }
}

async function parseAndValidateOutput<OutSchema extends yup.AnySchema>(
  outputSchema: OutSchema,
  rawValues: string[],
): Promise<JqxResult<yup.InferType<OutSchema>[], YupAdapterError>> {
  const validated: yup.InferType<OutSchema>[] = [];
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
    const parsedOut = await validateWithYup(outputSchema, parsed);
    if (!parsedOut.ok) {
      return fail({
        kind: "output_validation",
        index,
        message: "Output does not match schema",
        issues: parsedOut.issues,
      });
    }
    validated.push(parsedOut.value);
  }
  return { ok: true, value: validated };
}

export async function safeRunWithYup<InSchema extends yup.AnySchema, OutSchema extends yup.AnySchema>(
  runtime: JqxDynamicRuntime,
  options: RunWithYupOptions<InSchema, OutSchema>,
): Promise<JqxResult<yup.InferType<OutSchema>[], YupAdapterError>> {
  const parsedIn = await validateWithYup(options.inputSchema, options.input);
  if (!parsedIn.ok) {
    return fail({
      kind: "input_validation",
      message: "Input does not match schema",
      issues: parsedIn.issues,
    });
  }
  const rawInput = JSON.stringify(parsedIn.value);
  const runtimeOut = await runtime.run(options.filter, rawInput);
  if (!runtimeOut.ok) {
    return fail({ kind: "runtime", message: runtimeOut.error });
  }
  return parseAndValidateOutput(options.outputSchema, runtimeOut.value);
}

export async function safeExecuteWithYup<Q, InSchema extends yup.AnySchema, OutSchema extends yup.AnySchema>(
  runtime: JqxTypedRuntime<Q>,
  options: ExecuteWithYupOptions<Q, InSchema, OutSchema>,
): Promise<JqxResult<yup.InferType<OutSchema>[], YupAdapterError>> {
  const parsedIn = await validateWithYup(options.inputSchema, options.input);
  if (!parsedIn.ok) {
    return fail({
      kind: "input_validation",
      message: "Input does not match schema",
      issues: parsedIn.issues,
    });
  }
  const rawInput = JSON.stringify(parsedIn.value);
  const runtimeOut = await runtime.runQuery(options.query, rawInput);
  if (!runtimeOut.ok) {
    return fail({ kind: "runtime", message: runtimeOut.error });
  }
  return parseAndValidateOutput(options.outputSchema, runtimeOut.value);
}

export function withYup(runtime: JqxDynamicRuntime) {
  return {
    safeRunWithYup<InSchema extends yup.AnySchema, OutSchema extends yup.AnySchema>(
      options: RunWithYupOptions<InSchema, OutSchema>,
    ) {
      return safeRunWithYup(runtime, options);
    },
  };
}

export const withY = withYup;

export const runWithYup = safeRunWithYup;
export const executeWithYup = safeExecuteWithYup;
export const runWithY = safeRunWithYup;
export const executeWithY = safeExecuteWithYup;
