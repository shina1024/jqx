import { z } from "zod";

export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

export type MaybePromise<T> = T | Promise<T>;

export interface JqxDynamicRuntime {
  run(filter: string, input: string): MaybePromise<JqxResult<string[]>>;
}

export interface JqxTypedRuntime<Q = unknown> {
  runQuery(query: Q, input: string): MaybePromise<JqxResult<string[]>>;
}

export type ZodAdapterError =
  | {
      kind: "input_validation";
      message: string;
      issues: z.ZodIssue[];
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
      issues: z.ZodIssue[];
    };

export interface RunWithZodOptions<InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny> {
  filter: string;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

export interface ExecuteWithZodOptions<
  Q,
  InSchema extends z.ZodTypeAny,
  OutSchema extends z.ZodTypeAny,
> {
  query: Q;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

function fail<T>(error: ZodAdapterError): JqxResult<T, ZodAdapterError> {
  return { ok: false, error };
}

function parseAndValidateOutput<OutSchema extends z.ZodTypeAny>(
  outputSchema: OutSchema,
  rawValues: string[],
): JqxResult<z.output<OutSchema>[], ZodAdapterError> {
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

export async function safeRunWithZod<InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny>(
  runtime: JqxDynamicRuntime,
  options: RunWithZodOptions<InSchema, OutSchema>,
): Promise<JqxResult<z.output<OutSchema>[], ZodAdapterError>> {
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
    return fail({ kind: "runtime", message: runtimeOut.error });
  }
  return parseAndValidateOutput(options.outputSchema, runtimeOut.value);
}

export async function safeExecuteWithZod<
  Q,
  InSchema extends z.ZodTypeAny,
  OutSchema extends z.ZodTypeAny,
>(
  runtime: JqxTypedRuntime<Q>,
  options: ExecuteWithZodOptions<Q, InSchema, OutSchema>,
): Promise<JqxResult<z.output<OutSchema>[], ZodAdapterError>> {
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
    return fail({ kind: "runtime", message: runtimeOut.error });
  }
  return parseAndValidateOutput(options.outputSchema, runtimeOut.value);
}

export function withZod(runtime: JqxDynamicRuntime) {
  return {
    safeRunWithZod<InSchema extends z.ZodTypeAny, OutSchema extends z.ZodTypeAny>(
      options: RunWithZodOptions<InSchema, OutSchema>,
    ) {
      return safeRunWithZod(runtime, options);
    },
  };
}

export const withZ = withZod;

export const runWithZod = safeRunWithZod;
export const executeWithZod = safeExecuteWithZod;
export const runWithZ = safeRunWithZod;
export const executeWithZ = safeExecuteWithZod;
