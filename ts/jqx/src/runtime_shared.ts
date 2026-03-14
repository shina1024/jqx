import { toAst as toQueryAst, toJqxRuntimeError } from "@shina1024/jqx-adapter-core";

import type {
  Json,
  JqxResult,
  JqxRuntimeError,
  Query,
  QueryAst,
} from "@shina1024/jqx-adapter-core";

// Shared JSON-lane helpers keep the direct runtime and /bind surface aligned.
export type TypedDslQuery<Output = unknown> = Query<unknown, Output, QueryAst>;

export function failRuntimeResult<T>(error: JqxRuntimeError): JqxResult<T, JqxRuntimeError> {
  return { ok: false, error };
}

export function normalizeRuntimeError(
  error: unknown,
  fallbackMessage: string,
): JqxRuntimeError {
  const normalized = toJqxRuntimeError(error);
  if (normalized.kind === "backend_runtime" && normalized.message === "Unknown runtime error") {
    return { kind: "backend_runtime", message: fallbackMessage };
  }
  return normalized;
}

export function normalizeRuntimeResult<T>(
  result: JqxResult<T, JqxRuntimeError>,
): JqxResult<T, JqxRuntimeError> {
  if (result.ok) {
    return result;
  }
  return failRuntimeResult(normalizeRuntimeError(result.error, "Unknown runtime error"));
}

export function encodeRuntimeInput(input: Json): JqxResult<string, JqxRuntimeError> {
  try {
    const encoded = JSON.stringify(input);
    if (typeof encoded !== "string") {
      return failRuntimeResult({
        kind: "input_stringify",
        message: "JSON.stringify returned undefined",
      });
    }
    return { ok: true, value: encoded };
  } catch (error) {
    return failRuntimeResult({
      kind: "input_stringify",
      message: error instanceof Error ? error.message : "Failed to stringify input",
    });
  }
}

export function decodeRuntimeOutputs(rawValues: string[]): JqxResult<Json[], JqxRuntimeError> {
  const parsed: Json[] = [];
  for (const [index, raw] of rawValues.entries()) {
    try {
      parsed.push(JSON.parse(raw) as Json);
    } catch (error) {
      return failRuntimeResult({
        kind: "output_parse",
        index,
        message: error instanceof Error ? error.message : "Failed to parse output",
      });
    }
  }
  return { ok: true, value: parsed };
}

export function isTypedDslQuery(value: unknown): value is TypedDslQuery {
  if (typeof value !== "object" || value === null || !("ast" in value)) {
    return false;
  }
  const keys = Object.keys(value as Record<string, unknown>);
  return keys.length === 1 && keys[0] === "ast";
}

export function normalizeTypedDslQuery<Q>(query: Q | TypedDslQuery): Q {
  if (isTypedDslQuery(query)) {
    return toQueryAst(query) as Q;
  }
  return query as Q;
}
