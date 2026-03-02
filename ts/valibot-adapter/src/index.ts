import * as v from "valibot";

import {
  hasTypedRuntime,
  runFilterWithValidation,
  runInferred,
  runQueryWithValidation,
  type AdapterError as CoreAdapterError,
  type FilterOptions as CoreFilterOptions,
  type InferJqOutput,
  type InferenceFallbackMode,
  type InferredOptions,
  type Json,
  type JqxRuntime,
  type JqxResult,
  type JqxTypedRuntime,
  type QueryOptions as CoreQueryOptions,
  type ValidationResult,
} from "@shina1024/jqx-adapter-core";

export type {
  InferJqOutput,
  InferenceFallbackMode,
  InferredOptions,
  JqxRuntime,
  JqxResult,
  JqxTypedRuntime,
  Json,
  JqxError,
  JqxRuntimeError,
  MaybePromise,
} from "@shina1024/jqx-adapter-core";

export type ValibotSchema =
  | v.BaseSchema<unknown, unknown, v.BaseIssue<unknown>>
  | v.BaseSchemaAsync<unknown, unknown, v.BaseIssue<unknown>>;

export type AdapterError = CoreAdapterError<string[]>;

export interface FilterOptions<
  InSchema extends ValibotSchema,
  OutSchema extends ValibotSchema,
> extends CoreFilterOptions<InSchema, OutSchema> {}

export interface QueryOptions<
  Q,
  InSchema extends ValibotSchema,
  OutSchema extends ValibotSchema,
> extends CoreQueryOptions<Q, InSchema, OutSchema> {}

export interface DynamicAdapter {
  filter<InSchema extends ValibotSchema, OutSchema extends ValibotSchema>(
    options: FilterOptions<InSchema, OutSchema>,
  ): Promise<JqxResult<v.InferOutput<OutSchema>[], AdapterError>>;
  inferred<
    Filter extends string,
    Input extends Json,
    Mode extends InferenceFallbackMode = "unknown",
  >(
    options: InferredOptions<Filter, Input, Mode>,
  ): Promise<JqxResult<InferJqOutput<Input, Filter, Mode>[], string>>;
}

export interface TypedAdapter<Q> extends DynamicAdapter {
  query<InSchema extends ValibotSchema, OutSchema extends ValibotSchema>(
    options: QueryOptions<Q, InSchema, OutSchema>,
  ): Promise<JqxResult<v.InferOutput<OutSchema>[], AdapterError>>;
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
): Promise<ValidationResult<v.InferOutput<TSchema>, string[]>> {
  const result = await v.safeParseAsync(schema, input);
  if (result.success) {
    return { ok: true, value: result.output };
  }
  return {
    ok: false,
    issues: result.issues.map(issueToMessage),
  };
}

export function createAdapter<Q>(runtime: JqxRuntime & JqxTypedRuntime<Q>): TypedAdapter<Q>;
export function createAdapter(runtime: JqxRuntime): DynamicAdapter;
export function createAdapter<Q>(
  runtime: JqxRuntime & Partial<JqxTypedRuntime<Q>>,
): DynamicAdapter | TypedAdapter<Q> {
  const dynamicAdapter: DynamicAdapter = {
    filter(options) {
      return runFilterWithValidation(runtime, options, {
        validateInput: validateWithValibot,
        validateOutput: validateWithValibot,
      });
    },
    inferred(options) {
      return runInferred(runtime, options);
    },
  };

  if (hasTypedRuntime(runtime)) {
    const typedAdapter: TypedAdapter<Q> = {
      ...dynamicAdapter,
      query(options) {
        return runQueryWithValidation(runtime, options, {
          validateInput: validateWithValibot,
          validateOutput: validateWithValibot,
        });
      },
    };
    return typedAdapter;
  }

  return dynamicAdapter;
}
