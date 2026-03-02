import { z } from "zod";

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

export type AdapterError = CoreAdapterError<z.ZodIssue[]>;

export interface FilterOptions<
  InSchema extends z.ZodType<Json>,
  OutSchema extends z.ZodTypeAny,
> extends CoreFilterOptions<InSchema, OutSchema> {}

export interface QueryOptions<
  Q,
  InSchema extends z.ZodType<Json>,
  OutSchema extends z.ZodTypeAny,
> extends CoreQueryOptions<Q, InSchema, OutSchema> {}

export interface DynamicAdapter {
  filter<InSchema extends z.ZodType<Json>, OutSchema extends z.ZodTypeAny>(
    options: FilterOptions<InSchema, OutSchema>,
  ): Promise<JqxResult<z.output<OutSchema>[], AdapterError>>;
  inferred<
    Filter extends string,
    Input extends Json,
    Mode extends InferenceFallbackMode = "unknown",
  >(
    options: InferredOptions<Filter, Input, Mode>,
  ): Promise<JqxResult<InferJqOutput<Input, Filter, Mode>[], string>>;
}

export interface TypedAdapter<Q> extends DynamicAdapter {
  query<InSchema extends z.ZodType<Json>, OutSchema extends z.ZodTypeAny>(
    options: QueryOptions<Q, InSchema, OutSchema>,
  ): Promise<JqxResult<z.output<OutSchema>[], AdapterError>>;
}

function validateWithZod<TSchema extends z.ZodTypeAny>(
  schema: TSchema,
  input: unknown,
): ValidationResult<z.output<TSchema>, z.ZodIssue[]> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, issues: parsed.error.issues };
  }
  return { ok: true, value: parsed.data };
}

export function createAdapter<Q>(runtime: JqxRuntime & JqxTypedRuntime<Q>): TypedAdapter<Q>;
export function createAdapter(runtime: JqxRuntime): DynamicAdapter;
export function createAdapter<Q>(
  runtime: JqxRuntime & Partial<JqxTypedRuntime<Q>>,
): DynamicAdapter | TypedAdapter<Q> {
  const dynamicAdapter: DynamicAdapter = {
    filter(options) {
      return runFilterWithValidation(runtime, options, {
        validateInput: validateWithZod,
        validateOutput: validateWithZod,
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
          validateInput: validateWithZod,
          validateOutput: validateWithZod,
        });
      },
    };
    return typedAdapter;
  }

  return dynamicAdapter;
}
