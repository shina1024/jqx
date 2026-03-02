import * as yup from "yup";

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

export type AdapterError = CoreAdapterError<string[]>;

export interface FilterOptions<
  InSchema extends yup.AnySchema,
  OutSchema extends yup.AnySchema,
> extends CoreFilterOptions<InSchema, OutSchema> {}

export interface QueryOptions<
  Q,
  InSchema extends yup.AnySchema,
  OutSchema extends yup.AnySchema,
> extends CoreQueryOptions<Q, InSchema, OutSchema> {}

export interface DynamicAdapter {
  filter<InSchema extends yup.AnySchema, OutSchema extends yup.AnySchema>(
    options: FilterOptions<InSchema, OutSchema>,
  ): Promise<JqxResult<yup.InferType<OutSchema>[], AdapterError>>;
  inferred<
    Filter extends string,
    Input extends Json,
    Mode extends InferenceFallbackMode = "unknown",
  >(
    options: InferredOptions<Filter, Input, Mode>,
  ): Promise<JqxResult<InferJqOutput<Input, Filter, Mode>[], string>>;
}

export interface TypedAdapter<Q> extends DynamicAdapter {
  query<InSchema extends yup.AnySchema, OutSchema extends yup.AnySchema>(
    options: QueryOptions<Q, InSchema, OutSchema>,
  ): Promise<JqxResult<yup.InferType<OutSchema>[], AdapterError>>;
}

function normalizeYupIssues(error: yup.ValidationError): string[] {
  const issues = error.errors.filter(
    (item): item is string => typeof item === "string" && item.length > 0,
  );
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
): Promise<ValidationResult<yup.InferType<TSchema>, string[]>> {
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

export function createAdapter<Q>(runtime: JqxRuntime & JqxTypedRuntime<Q>): TypedAdapter<Q>;
export function createAdapter(runtime: JqxRuntime): DynamicAdapter;
export function createAdapter<Q>(
  runtime: JqxRuntime & Partial<JqxTypedRuntime<Q>>,
): DynamicAdapter | TypedAdapter<Q> {
  const dynamicAdapter: DynamicAdapter = {
    filter(options) {
      return runFilterWithValidation(runtime, options, {
        validateInput: validateWithYup,
        validateOutput: validateWithYup,
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
          validateInput: validateWithYup,
          validateOutput: validateWithYup,
        });
      },
    };
    return typedAdapter;
  }

  return dynamicAdapter;
}
