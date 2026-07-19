import type { Json, JqxResult, JqxRuntimeError } from "@shina1024/jqx-adapter-core";

import { failRuntimeResult } from "./runtime_shared.js";
import {
  appendJsonPath,
  formatJsonPath,
  getArrayLength,
  inspectJsonValue,
  safeErrorMessage,
  type JsonPath,
} from "./runtime_value.js";

type EncodeFrame =
  | { kind: "value"; value: unknown; path: JsonPath }
  | { kind: "text"; value: string }
  | { kind: "exit"; value: object };

export function inputValueError(path: JsonPath): JqxRuntimeError {
  const renderedPath = formatJsonPath(path);
  return {
    kind: "input_value",
    path: renderedPath,
    message:
      `Value lane only accepts finite JSON numbers; found a non-finite number at ${renderedPath}. ` +
      "Use runJsonText(...) when jq-compatible numeric fidelity matters.",
  };
}

export function validateRuntimeInputValue(input: Json): JqxResult<Json, JqxRuntimeError> {
  try {
    const issue = inspectJsonValue(input);
    if (issue?.kind === "non_finite") return failRuntimeResult(inputValueError(issue.path));
    if (issue?.kind === "unsupported") {
      return failRuntimeResult({ kind: "input_stringify", message: issue.message });
    }
    return { ok: true, value: input };
  } catch {
    return failRuntimeResult({ kind: "input_stringify", message: "Failed to inspect input" });
  }
}

export function encodeRuntimeInput(input: Json): JqxResult<string, JqxRuntimeError> {
  try {
    const chunks: string[] = [];
    const ancestors = new WeakSet<object>();
    const pending: EncodeFrame[] = [{ kind: "value", value: input, path: null }];
    while (pending.length > 0) {
      const frame = pending.pop();
      if (frame === undefined) break;
      if (frame.kind === "text") {
        chunks.push(frame.value);
        continue;
      }
      if (frame.kind === "exit") {
        ancestors.delete(frame.value);
        continue;
      }
      const item = frame.value;
      if (item === null || typeof item === "boolean" || typeof item === "string") {
        chunks.push(JSON.stringify(item));
        continue;
      }
      if (typeof item === "number") {
        if (!Number.isFinite(item)) return failRuntimeResult(inputValueError(frame.path));
        chunks.push(JSON.stringify(item));
        continue;
      }
      if (typeof item !== "object") {
        return failRuntimeResult({
          kind: "input_stringify",
          message: "Value lane input is not JSON data",
        });
      }
      if (ancestors.has(item)) {
        return failRuntimeResult({
          kind: "input_stringify",
          message: "Value lane input contains a cycle",
        });
      }
      const isArray = Array.isArray(item);
      const prototype = Object.getPrototypeOf(item);
      if (!isArray && prototype !== Object.prototype && prototype !== null) {
        return failRuntimeResult({
          kind: "input_stringify",
          message: "Value lane input must use plain objects",
        });
      }
      ancestors.add(item);
      pending.push({ kind: "exit", value: item });
      const keys = Reflect.ownKeys(item);
      if (isArray) {
        const length = getArrayLength(item);
        if (length === null || keys.length !== length + 1 || !keys.includes("length")) {
          return failRuntimeResult({
            kind: "input_stringify",
            message: "Value lane arrays must be dense JSON arrays",
          });
        }
        chunks.push("[");
        pending.push({ kind: "text", value: "]" });
        for (let index = length - 1; index >= 0; index -= 1) {
          const descriptor = Object.getOwnPropertyDescriptor(item, String(index));
          if (descriptor === undefined || !descriptor.enumerable || !("value" in descriptor)) {
            return failRuntimeResult({
              kind: "input_stringify",
              message: "Value lane arrays must contain data values",
            });
          }
          pending.push({
            kind: "value",
            value: descriptor.value,
            path: appendJsonPath(frame.path, index),
          });
          if (index > 0) pending.push({ kind: "text", value: "," });
        }
        continue;
      }
      chunks.push("{");
      pending.push({ kind: "text", value: "}" });
      for (let index = keys.length - 1; index >= 0; index -= 1) {
        const key = keys[index];
        if (typeof key !== "string") {
          return failRuntimeResult({
            kind: "input_stringify",
            message: "Value lane objects cannot contain symbol keys",
          });
        }
        const descriptor = Object.getOwnPropertyDescriptor(item, key);
        if (descriptor === undefined || !descriptor.enumerable || !("value" in descriptor)) {
          return failRuntimeResult({
            kind: "input_stringify",
            message: "Value lane objects must contain data properties",
          });
        }
        pending.push({
          kind: "value",
          value: descriptor.value,
          path: appendJsonPath(frame.path, key),
        });
        pending.push({ kind: "text", value: ":" });
        pending.push({ kind: "text", value: JSON.stringify(key) });
        if (index > 0) pending.push({ kind: "text", value: "," });
      }
    }
    return { ok: true, value: chunks.join("") };
  } catch (error) {
    return failRuntimeResult({
      kind: "input_stringify",
      message: safeErrorMessage(error, "Failed to stringify input"),
    });
  }
}
