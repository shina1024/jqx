import { toAst as toQueryAst } from "@shina1024/jqx-adapter-core";
import type {
  Json,
  JqxDynamicRuntime,
  JqxError,
  JqxResult,
  JqxRuntimeError,
  Query,
  QueryAst,
  JqxTypedRuntime,
  MaybePromise,
} from "@shina1024/jqx-adapter-core";

export type {
  InferTypedQueryOutput,
  InferJqOutput,
  InferenceFallbackMode,
  InferredOptions,
  Json,
  Query,
  QueryAst,
  QueryInput,
  QueryOutput,
  JqxDynamicRuntime,
  JqxError,
  JqxResult,
  JqxRuntimeError,
  JqxTypedRuntime,
  MaybePromise,
} from "@shina1024/jqx-adapter-core";

export {
  add,
  and_,
  call,
  comma,
  eq,
  fallback,
  field,
  gt,
  identity,
  ifElse,
  index,
  iter,
  literal,
  lt,
  map,
  not_,
  or_,
  pipe,
  select,
  toAst,
  tryCatch,
} from "@shina1024/jqx-adapter-core";

export interface JqxRuntimeBinding extends JqxDynamicRuntime {
  runCompat?: JqxDynamicRuntime["run"];
  runValues?: (filter: string, input: string) => MaybePromise<JqxResult<Json[], JqxRuntimeError>>;
}

export interface JqxRuntime {
  run(filter: string, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
  runCompat(filter: string, input: string): Promise<JqxResult<string[], JqxRuntimeError>>;
  runValues(filter: string, input: string): Promise<JqxResult<Json[], JqxRuntimeError>>;
}

export type JqxQueryAstRuntime = JqxTypedRuntime<QueryAst>;

const RUN_VALUES_UNSUPPORTED_ERROR = "runValues is not available on the bound runtime";

function toPromise<T>(value: MaybePromise<T>): Promise<T> {
  return Promise.resolve(value);
}

export function runTypedQuery<I, O, Ast extends QueryAst>(
  runtime: JqxQueryAstRuntime,
  query: Query<I, O, Ast>,
  input: string,
): Promise<JqxResult<string[], JqxRuntimeError>> {
  return toPromise(runtime.runQuery(toQueryAst(query), input));
}

export function runTypedQueryAst(
  runtime: JqxQueryAstRuntime,
  query: QueryAst,
  input: string,
): Promise<JqxResult<string[], JqxRuntimeError>> {
  return toPromise(runtime.runQuery(query, input));
}

export function bindRuntime(runtime: JqxRuntimeBinding): JqxRuntime {
  return {
    run(filter, input) {
      return toPromise(runtime.run(filter, input));
    },
    runCompat(filter, input) {
      if (runtime.runCompat) {
        return toPromise(runtime.runCompat(filter, input));
      }
      return toPromise(runtime.run(filter, input));
    },
    runValues(filter, input) {
      if (runtime.runValues) {
        return toPromise(runtime.runValues(filter, input));
      }
      return Promise.resolve({
        ok: false,
        error: RUN_VALUES_UNSUPPORTED_ERROR,
      });
    },
  };
}

export const createRuntime = bindRuntime;
export const RUNTIME_UNSUPPORTED_ERRORS = {
  runValues: RUN_VALUES_UNSUPPORTED_ERROR,
} as const;
