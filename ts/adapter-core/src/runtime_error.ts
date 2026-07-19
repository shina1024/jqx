export interface JqxError {
  code: string;
  message: string;
  line: number;
  column: number;
  offset: number;
}

export interface JqxBackendRuntimeError {
  kind: "backend_runtime";
  message: string;
  details?: Partial<JqxError>;
}

export interface JqxInputStringifyRuntimeError {
  kind: "input_stringify";
  message: string;
}

export interface JqxInputValueRuntimeError {
  kind: "input_value";
  message: string;
  path: string;
}

export interface JqxOutputParseRuntimeError {
  kind: "output_parse";
  message: string;
  index: number;
}

export interface JqxOutputValueRuntimeError {
  kind: "output_value";
  message: string;
  index: number;
  path: string;
}

export type JqxRuntimeError =
  | JqxBackendRuntimeError
  | JqxInputStringifyRuntimeError
  | JqxInputValueRuntimeError
  | JqxOutputParseRuntimeError
  | JqxOutputValueRuntimeError;

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function ownDataValue(value: object, key: string): unknown {
  const descriptor = Object.getOwnPropertyDescriptor(value, key);
  return descriptor !== undefined && "value" in descriptor ? descriptor.value : undefined;
}

function snapshotJqxError(value: unknown): JqxError | null {
  if (!isObjectRecord(value)) {
    return null;
  }
  const code = ownDataValue(value, "code");
  const message = ownDataValue(value, "message");
  const line = ownDataValue(value, "line");
  const column = ownDataValue(value, "column");
  const offset = ownDataValue(value, "offset");
  return typeof code === "string" &&
    typeof message === "string" &&
    typeof line === "number" &&
    typeof column === "number" &&
    typeof offset === "number"
    ? { code, message, line, column, offset }
    : null;
}

function snapshotErrorDetails(value: unknown): Partial<JqxError> | undefined {
  if (!isObjectRecord(value)) {
    return undefined;
  }
  const details: Partial<JqxError> = {};
  const code = ownDataValue(value, "code");
  const message = ownDataValue(value, "message");
  const line = ownDataValue(value, "line");
  const column = ownDataValue(value, "column");
  const offset = ownDataValue(value, "offset");
  if (typeof code === "string") details.code = code;
  if (typeof message === "string") details.message = message;
  if (typeof line === "number") details.line = line;
  if (typeof column === "number") details.column = column;
  if (typeof offset === "number") details.offset = offset;
  return details;
}

function snapshotRuntimeError(value: unknown): JqxRuntimeError | null {
  if (!isObjectRecord(value)) {
    return null;
  }
  const kind = ownDataValue(value, "kind");
  const message = ownDataValue(value, "message");
  if (typeof kind !== "string" || typeof message !== "string") {
    return null;
  }
  if (kind === "backend_runtime") {
    const detailsValue = ownDataValue(value, "details");
    if (detailsValue === undefined) return { kind, message };
    const details = snapshotErrorDetails(detailsValue);
    return details === undefined ? null : { kind, message, details };
  }
  if (kind === "input_stringify") return { kind, message };
  if (kind === "input_value") {
    const path = ownDataValue(value, "path");
    return typeof path === "string" ? { kind, message, path } : null;
  }
  if (kind === "output_parse") {
    const index = ownDataValue(value, "index");
    return typeof index === "number" ? { kind, message, index } : null;
  }
  if (kind === "output_value") {
    const index = ownDataValue(value, "index");
    const path = ownDataValue(value, "path");
    return typeof index === "number" && typeof path === "string"
      ? { kind, message, index, path }
      : null;
  }
  return null;
}

export function isJqxError(value: unknown): value is JqxError {
  try {
    return snapshotJqxError(value) !== null;
  } catch {
    return false;
  }
}

export function isJqxRuntimeError(value: unknown): value is JqxRuntimeError {
  try {
    return snapshotRuntimeError(value) !== null;
  } catch {
    return false;
  }
}

export function toJqxRuntimeError(error: unknown): JqxRuntimeError {
  try {
    const runtimeError = snapshotRuntimeError(error);
    if (runtimeError !== null) return runtimeError;
    const jqxError = snapshotJqxError(error);
    if (jqxError !== null) {
      return { kind: "backend_runtime", message: jqxError.message, details: jqxError };
    }
    if (typeof error === "string") return { kind: "backend_runtime", message: error };
    if (isObjectRecord(error)) {
      const message = ownDataValue(error, "message");
      if (typeof message === "string") return { kind: "backend_runtime", message };
    }
  } catch {
    return { kind: "backend_runtime", message: "Unknown runtime error" };
  }
  return { kind: "backend_runtime", message: "Unknown runtime error" };
}

export function runtimeErrorToMessage(error: unknown): string {
  return toJqxRuntimeError(error).message;
}
