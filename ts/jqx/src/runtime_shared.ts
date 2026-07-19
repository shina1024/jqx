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

export function normalizeRuntimeError(error: unknown, fallbackMessage: string): JqxRuntimeError {
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
type JsonPath = { parent: JsonPath; segment: JsonPathSegment } | null;
type JsonValueIssue =
  | { kind: "non_finite"; path: JsonPath }
  | { kind: "unsupported"; message: string };

function appendJsonPath(path: JsonPath, segment: JsonPathSegment): JsonPath {
  return { parent: path, segment };
}

function formatJsonPath(path: JsonPath): string {
  const segments: JsonPathSegment[] = [];
  for (let current = path; current !== null; current = current.parent) {
    segments.push(current.segment);
  }
  let out = "$";
  for (const segment of segments.reverse()) {
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

function inspectJsonValue(value: unknown): JsonValueIssue | null {
  const pending: Array<{ value: unknown; path: JsonPath; exit?: object }> = [{ value, path: null }];
  const ancestors = new WeakSet<object>();
  while (pending.length > 0) {
    const current = pending.pop();
    if (current === undefined) {
      break;
    }
    if (current.exit !== undefined) {
      ancestors.delete(current.exit);
      continue;
    }
    const item = current.value;
    if (item === null || typeof item === "string" || typeof item === "boolean") {
      continue;
    }
    if (typeof item === "number") {
      if (!Number.isFinite(item)) {
        return { kind: "non_finite", path: current.path };
      }
      continue;
    }
    if (typeof item !== "object") {
      return { kind: "unsupported", message: "Value lane input is not JSON data" };
    }
    if (ancestors.has(item)) {
      return { kind: "unsupported", message: "Value lane input contains a cycle" };
    }
    const prototype = Object.getPrototypeOf(item);
    if (!Array.isArray(item) && prototype !== Object.prototype && prototype !== null) {
      return { kind: "unsupported", message: "Value lane input must use plain objects" };
    }
    ancestors.add(item);
    pending.push({ value: null, path: current.path, exit: item });
    const keys = Reflect.ownKeys(item);
    if (Array.isArray(item)) {
      const expectedKeyCount = item.length + 1;
      if (keys.length !== expectedKeyCount || !keys.includes("length")) {
        return { kind: "unsupported", message: "Value lane arrays must be dense JSON arrays" };
      }
      for (let index = item.length - 1; index >= 0; index -= 1) {
        const descriptor = Object.getOwnPropertyDescriptor(item, String(index));
        if (descriptor === undefined || !descriptor.enumerable || !("value" in descriptor)) {
          return { kind: "unsupported", message: "Value lane arrays must contain data values" };
        }
        pending.push({
          value: descriptor.value,
          path: appendJsonPath(current.path, index),
        });
      }
      continue;
    }
    for (let index = keys.length - 1; index >= 0; index -= 1) {
      const key = keys[index];
      if (typeof key !== "string") {
        return { kind: "unsupported", message: "Value lane objects cannot contain symbol keys" };
      }
      const descriptor = Object.getOwnPropertyDescriptor(item, key);
      if (descriptor === undefined || !descriptor.enumerable || !("value" in descriptor)) {
        return { kind: "unsupported", message: "Value lane objects must contain data properties" };
      }
      pending.push({
        value: descriptor.value,
        path: appendJsonPath(current.path, key),
      });
    }
  }
  return null;
}

function inputValueError(path: JsonPath): JqxRuntimeError {
  const renderedPath = formatJsonPath(path);
  return {
    kind: "input_value",
    path: renderedPath,
    message:
      `Value lane only accepts finite JSON numbers; found a non-finite number at ${renderedPath}. ` +
      "Use runJsonText(...) when jq-compatible numeric fidelity matters.",
  };
}

function outputValueError(index: number, path: JsonPath): JqxRuntimeError {
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
  try {
    const issue = inspectJsonValue(input);
    if (issue?.kind === "non_finite") {
      return failRuntimeResult(inputValueError(issue.path));
    }
    if (issue?.kind === "unsupported") {
      return failRuntimeResult({ kind: "input_stringify", message: issue.message });
    }
  } catch (error) {
    return failRuntimeResult({
      kind: "input_stringify",
      message: error instanceof Error ? error.message : "Failed to inspect input",
    });
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

export function decodeRuntimeOutput(raw: string, index: number): JqxResult<Json, JqxRuntimeError> {
  try {
    const parsed = JSON.parse(raw) as Json;
    const issue = inspectJsonValue(parsed);
    if (issue?.kind === "non_finite") {
      return failRuntimeResult(outputValueError(index, issue.path));
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
