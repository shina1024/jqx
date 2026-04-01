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

type JsonPathSegment = string | number;

function formatJsonPath(path: JsonPathSegment[]): string {
  let out = "$";
  for (const segment of path) {
    if (typeof segment === "number") {
      out += `[${segment}]`;
      continue;
    }
    if (/^[A-Za-z_$][A-Za-z0-9_$]*$/u.test(segment)) {
      out += `.${segment}`;
      continue;
    }
    out += `[${JSON.stringify(segment)}]`;
  }
  return out;
}

function findNonFiniteNumberPath(
  value: Json,
  path: JsonPathSegment[] = [],
  seen: WeakSet<object> = new WeakSet<object>(),
): JsonPathSegment[] | null {
  if (typeof value === "number") {
    return Number.isFinite(value) ? null : path;
  }
  if (value === null || typeof value !== "object") {
    return null;
  }
  if (seen.has(value)) {
    return null;
  }
  seen.add(value);
  if (Array.isArray(value)) {
    for (const [index, item] of value.entries()) {
      const found = findNonFiniteNumberPath(item, [...path, index], seen);
      if (found !== null) {
        return found;
      }
    }
    return null;
  }
  for (const [key, item] of Object.entries(value)) {
    const found = findNonFiniteNumberPath(item, [...path, key], seen);
    if (found !== null) {
      return found;
    }
  }
  return null;
}

function inputValueError(path: JsonPathSegment[]): JqxRuntimeError {
  const renderedPath = formatJsonPath(path);
  return {
    kind: "input_value",
    path: renderedPath,
    message:
      `Value lane only accepts finite JSON numbers; found a non-finite number at ${renderedPath}. ` +
      "Use runJsonText(...) when jq-compatible numeric fidelity matters.",
  };
}

function outputValueError(index: number, path: JsonPathSegment[]): JqxRuntimeError {
  const renderedPath = formatJsonPath(path);
  return {
    kind: "output_value",
    index,
    path: renderedPath,
    message:
      `Output ${index} is not representable in the value lane because it contains a non-finite ` +
      `number at ${renderedPath}. Use runJsonText(...) when jq-compatible numeric fidelity matters.`,
  };
}

export function validateRuntimeInputValue(input: Json): JqxResult<Json, JqxRuntimeError> {
  const found = findNonFiniteNumberPath(input);
  if (found !== null) {
    return failRuntimeResult(inputValueError(found));
  }
  return { ok: true, value: input };
}

export function encodeRuntimeInput(input: Json): JqxResult<string, JqxRuntimeError> {
  const validated = validateRuntimeInputValue(input);
  if (!validated.ok) {
    return validated;
  }
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

export function parseRuntimeJsonText(input: string): JqxResult<Json, JqxRuntimeError> {
  try {
    const parsed = JSON.parse(input) as Json;
    const validated = validateRuntimeInputValue(parsed);
    if (!validated.ok) {
      return validated;
    }
    return { ok: true, value: parsed };
  } catch (error) {
    return failRuntimeResult(normalizeRuntimeError(error, "parseJson failed unexpectedly"));
  }
}

export function decodeRuntimeOutput(
  raw: string,
  index: number,
): JqxResult<Json, JqxRuntimeError> {
  try {
    const parsed = JSON.parse(raw) as Json;
    const found = findNonFiniteNumberPath(parsed);
    if (found !== null) {
      return failRuntimeResult(outputValueError(index, found));
    }
    return { ok: true, value: parsed };
  } catch (error) {
    return failRuntimeResult({
      kind: "output_parse",
      index,
      message: error instanceof Error ? error.message : "Failed to parse output",
    });
  }
}

export function decodeRuntimeOutputs(rawValues: string[]): JqxResult<Json[], JqxRuntimeError> {
  const parsed: Json[] = [];
  for (const [index, raw] of rawValues.entries()) {
    const decoded = decodeRuntimeOutput(raw, index);
    if (!decoded.ok) {
      return decoded;
    }
    parsed.push(decoded.value);
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
