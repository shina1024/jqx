import type { Json, JqxResult, JqxRuntimeError } from "@shina1024/jqx-adapter-core";

import { validateRuntimeInputValue } from "./runtime_input.js";
import { failRuntimeResult, normalizeRuntimeError } from "./runtime_shared.js";
import {
  formatJsonPath,
  inspectJsonValue,
  safeErrorMessage,
  type JsonPath,
} from "./runtime_value.js";

export function parseRuntimeJsonText(input: string): JqxResult<Json, JqxRuntimeError> {
  try {
    const parsed: Json = JSON.parse(input);
    const validated = validateRuntimeInputValue(parsed);
    return validated.ok ? { ok: true, value: parsed } : validated;
  } catch (error) {
    return failRuntimeResult(normalizeRuntimeError(error, "parseJson failed unexpectedly"));
  }
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

export function decodeRuntimeOutput(raw: string, index: number): JqxResult<Json, JqxRuntimeError> {
  try {
    const parsed: Json = JSON.parse(raw);
    const issue = inspectJsonValue(parsed);
    if (issue?.kind === "non_finite") return failRuntimeResult(outputValueError(index, issue.path));
    return { ok: true, value: parsed };
  } catch (error) {
    return failRuntimeResult({
      kind: "output_parse",
      index,
      message: safeErrorMessage(error, "Failed to parse output"),
    });
  }
}

export function decodeRuntimeOutputs(rawValues: string[]): JqxResult<Json[], JqxRuntimeError> {
  const parsed: Json[] = [];
  for (const [index, raw] of rawValues.entries()) {
    const decoded = decodeRuntimeOutput(raw, index);
    if (!decoded.ok) return decoded;
    parsed.push(decoded.value);
  }
  return { ok: true, value: parsed };
}
