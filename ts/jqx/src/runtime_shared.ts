import { toAst as toQueryAst, toJqxRuntimeError } from "@shina1024/jqx-adapter-core";

import type { JqxResult, JqxRuntimeError, Query, QueryAst } from "@shina1024/jqx-adapter-core";

export type TypedDslQuery<Output = unknown> = Query<unknown, Output, QueryAst>;

export function failRuntimeResult<T>(error: JqxRuntimeError): JqxResult<T, JqxRuntimeError> {
  return { ok: false, error };
}

export function normalizeRuntimeError(error: unknown, fallbackMessage: string): JqxRuntimeError {
  try {
    const normalized = toJqxRuntimeError(error);
    if (normalized.kind === "backend_runtime" && normalized.message === "Unknown runtime error") {
      return { kind: "backend_runtime", message: fallbackMessage };
    }
    return normalized;
  } catch {
    return { kind: "backend_runtime", message: fallbackMessage };
  }
}

export function isTypedDslQuery(value: unknown): value is TypedDslQuery {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  return Object.getOwnPropertySymbols(value).includes(Symbol.for("@shina1024/jqx/typed-dsl-query"));
}

export function normalizeTypedDslQuery<Q>(query: Q | TypedDslQuery): Q {
  if (isTypedDslQuery(query)) {
    return toQueryAst(query) as Q;
  }
  return query as Q;
}
