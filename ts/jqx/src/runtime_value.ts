export type JsonPathSegment = string | number;
export type JsonPath = { parent: JsonPath; segment: JsonPathSegment } | null;
export type JsonValueIssue =
  | { kind: "non_finite"; path: JsonPath }
  | { kind: "unsupported"; message: string };

export function appendJsonPath(path: JsonPath, segment: JsonPathSegment): JsonPath {
  return { parent: path, segment };
}

export function formatJsonPath(path: JsonPath): string {
  const segments: JsonPathSegment[] = [];
  for (let current = path; current !== null; current = current.parent) {
    segments.push(current.segment);
  }
  let out = "$";
  for (const segment of segments.reverse()) {
    if (typeof segment === "number") {
      out += `[${segment}]`;
    } else if (/^[A-Za-z_$][A-Za-z0-9_$]*$/u.test(segment)) {
      out += `.${segment}`;
    } else {
      out += `[${JSON.stringify(segment)}]`;
    }
  }
  return out;
}

export function getArrayLength(value: unknown[]): number | null {
  const descriptor = Object.getOwnPropertyDescriptor(value, "length");
  if (
    descriptor === undefined ||
    !("value" in descriptor) ||
    typeof descriptor.value !== "number" ||
    !Number.isSafeInteger(descriptor.value) ||
    descriptor.value < 0
  ) {
    return null;
  }
  return descriptor.value;
}

export function inspectJsonValue(value: unknown): JsonValueIssue | null {
  const pending: Array<{ value: unknown; path: JsonPath; exit?: object }> = [{ value, path: null }];
  const ancestors = new WeakSet<object>();
  while (pending.length > 0) {
    const current = pending.pop();
    if (current === undefined) break;
    if (current.exit !== undefined) {
      ancestors.delete(current.exit);
      continue;
    }
    const item = current.value;
    if (item === null || typeof item === "string" || typeof item === "boolean") continue;
    if (typeof item === "number") {
      if (!Number.isFinite(item)) return { kind: "non_finite", path: current.path };
      continue;
    }
    if (typeof item !== "object") {
      return { kind: "unsupported", message: "Value lane input is not JSON data" };
    }
    if (ancestors.has(item)) {
      return { kind: "unsupported", message: "Value lane input contains a cycle" };
    }
    const isArray = Array.isArray(item);
    const prototype = Object.getPrototypeOf(item);
    if (!isArray && prototype !== Object.prototype && prototype !== null) {
      return { kind: "unsupported", message: "Value lane input must use plain objects" };
    }
    ancestors.add(item);
    pending.push({ value: null, path: current.path, exit: item });
    const keys = Reflect.ownKeys(item);
    if (isArray) {
      const length = getArrayLength(item);
      if (length === null || keys.length !== length + 1 || !keys.includes("length")) {
        return { kind: "unsupported", message: "Value lane arrays must be dense JSON arrays" };
      }
      for (let index = length - 1; index >= 0; index -= 1) {
        const descriptor = Object.getOwnPropertyDescriptor(item, String(index));
        if (descriptor === undefined || !descriptor.enumerable || !("value" in descriptor)) {
          return { kind: "unsupported", message: "Value lane arrays must contain data values" };
        }
        pending.push({ value: descriptor.value, path: appendJsonPath(current.path, index) });
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
      pending.push({ value: descriptor.value, path: appendJsonPath(current.path, key) });
    }
  }
  return null;
}

export function safeErrorMessage(error: unknown, fallback: string): string {
  try {
    if (typeof error === "object" && error !== null) {
      const descriptor = Object.getOwnPropertyDescriptor(error, "message");
      if (
        descriptor !== undefined &&
        "value" in descriptor &&
        typeof descriptor.value === "string"
      ) {
        return descriptor.value;
      }
    }
  } catch {
    return fallback;
  }
  return fallback;
}
