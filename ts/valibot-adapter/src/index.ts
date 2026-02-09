import * as v from "valibot";

export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

export type MaybePromise<T> = T | Promise<T>;

export interface JqxDynamicRuntime {
  run(filter: string, input: string): MaybePromise<JqxResult<string[]>>;
}

export interface JqxTypedRuntime<Q = unknown> {
  runQuery(query: Q, input: string): MaybePromise<JqxResult<string[]>>;
}

export type ValibotSchema =
  | v.BaseSchema<unknown, unknown, v.BaseIssue<unknown>>
  | v.BaseSchemaAsync<unknown, unknown, v.BaseIssue<unknown>>;

export type ValibotAdapterError =
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

export interface RunWithValibotOptions<InSchema extends ValibotSchema, OutSchema extends ValibotSchema> {
  filter: string;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

export interface ExecuteWithValibotOptions<
  Q,
  InSchema extends ValibotSchema,
  OutSchema extends ValibotSchema,
> {
  query: Q;
  input: unknown;
  inputSchema: InSchema;
  outputSchema: OutSchema;
}

function fail<T>(error: ValibotAdapterError): JqxResult<T, ValibotAdapterError> {
  return { ok: false, error };
}

function issueToMessage(issue: v.BaseIssue<unknown>): string {
  if ("message" in issue && typeof issue.message === "string" && issue.message.length > 0) {
    return issue.message;
  }
  return "Validation failed";
}

async function validateWithValibot<TSchema extends ValibotSchema>(
  schema: TSchema,
  input: unknown,
): Promise<{ ok: true; value: v.InferOutput<TSchema> } | { ok: false; issues: string[] }> {
  const result = await v.safeParseAsync(schema, input);
  if (result.success) {
    return { ok: true, value: result.output };
  }
  return {
    ok: false,
    issues: result.issues.map(issueToMessage),
  };
}

async function parseAndValidateOutput<OutSchema extends ValibotSchema>(
  outputSchema: OutSchema,
  rawValues: string[],
): Promise<JqxResult<v.InferOutput<OutSchema>[], ValibotAdapterError>> {
  const validated: v.InferOutput<OutSchema>[] = [];
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
    const parsedOut = await validateWithValibot(outputSchema, parsed);
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

export async function safeRunWithValibot<InSchema extends ValibotSchema, OutSchema extends ValibotSchema>(
  runtime: JqxDynamicRuntime,
  options: RunWithValibotOptions<InSchema, OutSchema>,
): Promise<JqxResult<v.InferOutput<OutSchema>[], ValibotAdapterError>> {
  const parsedIn = await validateWithValibot(options.inputSchema, options.input);
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

export async function safeExecuteWithValibot<
  Q,
  InSchema extends ValibotSchema,
  OutSchema extends ValibotSchema,
>(
  runtime: JqxTypedRuntime<Q>,
  options: ExecuteWithValibotOptions<Q, InSchema, OutSchema>,
): Promise<JqxResult<v.InferOutput<OutSchema>[], ValibotAdapterError>> {
  const parsedIn = await validateWithValibot(options.inputSchema, options.input);
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

export function withValibot(runtime: JqxDynamicRuntime) {
  return {
    safeRunWithValibot<InSchema extends ValibotSchema, OutSchema extends ValibotSchema>(
      options: RunWithValibotOptions<InSchema, OutSchema>,
    ) {
      return safeRunWithValibot(runtime, options);
    },
  };
}

export const withV = withValibot;

export const runWithValibot = safeRunWithValibot;
export const executeWithValibot = safeExecuteWithValibot;
export const runWithV = safeRunWithValibot;
export const executeWithV = safeExecuteWithValibot;
