import { decodeRuntimeOutput } from "./runtime_json.js";
import { failRuntimeResult, normalizeRuntimeError } from "./runtime_shared.js";

import type {
  Json,
  JqxResult,
  JqxResultStream,
  JqxRuntimeError,
  MaybePromise,
} from "@shina1024/jqx-adapter-core";
import type {
  JqxJsonTextRuntime,
  JqxJsonTextStreamingRuntime,
  JqxQueryJsonTextRuntime,
  JqxQueryJsonTextStreamingRuntime,
} from "./bind.js";

type RuntimeCall<T> = () => MaybePromise<JqxResult<T, JqxRuntimeError>>;

async function callRuntime<T, Normalized>(
  call: RuntimeCall<T>,
  normalizeValue: (value: T) => Normalized,
): Promise<JqxResult<Normalized, JqxRuntimeError>> {
  try {
    const result = await Promise.resolve(call());
    if (!result.ok) {
      return failRuntimeResult(normalizeRuntimeError(result.error, "Unknown runtime error"));
    }
    return { ok: true, value: normalizeValue(result.value) };
  } catch (error) {
    return failRuntimeResult(normalizeRuntimeError(error, "Runtime call failed"));
  }
}

function snapshotStringArray(values: string[]): string[] {
  if (!Array.isArray(values)) {
    throw new TypeError("Runtime output must be an array");
  }
  const lengthDescriptor = Object.getOwnPropertyDescriptor(values, "length");
  if (
    lengthDescriptor === undefined ||
    !("value" in lengthDescriptor) ||
    typeof lengthDescriptor.value !== "number" ||
    !Number.isSafeInteger(lengthDescriptor.value) ||
    lengthDescriptor.value < 0
  ) {
    throw new TypeError("Runtime output array has an invalid length");
  }
  const keys = Reflect.ownKeys(values);
  if (keys.length !== lengthDescriptor.value + 1 || !keys.includes("length")) {
    throw new TypeError("Runtime output must be a dense string array");
  }
  const snapshot: string[] = [];
  for (let index = 0; index < lengthDescriptor.value; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(values, String(index));
    if (
      descriptor === undefined ||
      !descriptor.enumerable ||
      !("value" in descriptor) ||
      typeof descriptor.value !== "string"
    ) {
      throw new TypeError("Runtime output array must contain string data values");
    }
    snapshot.push(descriptor.value);
  }
  return snapshot;
}

export function callStringArrayRuntime(
  call: RuntimeCall<string[]>,
): Promise<JqxResult<string[], JqxRuntimeError>> {
  return callRuntime(call, snapshotStringArray);
}

function fromArrayRuntimeCall(
  call: RuntimeCall<string[]>,
): JqxResultStream<string, JqxRuntimeError> {
  return (async function* () {
    const runtimeOut = await callStringArrayRuntime(call);
    if (!runtimeOut.ok) {
      yield failRuntimeResult<string>(runtimeOut.error);
      return;
    }
    for (const value of runtimeOut.value) yield { ok: true, value };
  })();
}

function fromStreamingRuntimeCall(
  call: RuntimeCall<AsyncIterable<string>>,
): JqxResultStream<string, JqxRuntimeError> {
  return (async function* () {
    const runtimeOut = await callRuntime(call, (value) => value);
    if (!runtimeOut.ok) {
      yield failRuntimeResult<string>(runtimeOut.error);
      return;
    }
    try {
      for await (const value of runtimeOut.value) {
        if (typeof value !== "string") {
          throw new TypeError("Runtime output stream must contain strings");
        }
        yield { ok: true, value };
      }
    } catch (error) {
      yield failRuntimeResult<string>(normalizeRuntimeError(error, "Stream iteration failed"));
    }
  })();
}

export function decodeRawResultStream(
  rawStream: JqxResultStream<string, JqxRuntimeError>,
): JqxResultStream<Json, JqxRuntimeError> {
  return (async function* () {
    let index = 0;
    for await (const item of rawStream) {
      if (!item.ok) {
        yield item;
        return;
      }
      const decoded = decodeRuntimeOutput(item.value, index);
      if (!decoded.ok) {
        yield decoded;
        return;
      }
      yield decoded;
      index += 1;
    }
  })();
}

export function singleErrorStream<T>(error: JqxRuntimeError): JqxResultStream<T, JqxRuntimeError> {
  return (async function* () {
    yield failRuntimeResult<T>(error);
  })();
}

export function selectJsonTextStream(
  runtime: JqxJsonTextRuntime & Partial<JqxJsonTextStreamingRuntime>,
  filter: string,
  input: string,
): JqxResultStream<string, JqxRuntimeError> {
  try {
    const runStream = runtime.runJsonTextStream;
    return typeof runStream === "function"
      ? fromStreamingRuntimeCall(() => runStream.call(runtime, filter, input))
      : fromArrayRuntimeCall(() => runtime.runJsonText(filter, input));
  } catch (error) {
    return singleErrorStream(normalizeRuntimeError(error, "Unable to inspect streaming runtime"));
  }
}

export function selectQueryJsonTextStream<Q>(
  runtime: JqxQueryJsonTextRuntime<Q> & Partial<JqxQueryJsonTextStreamingRuntime<Q>>,
  query: Q,
  input: string,
): JqxResultStream<string, JqxRuntimeError> {
  try {
    const runStream = runtime.runQueryJsonTextStream;
    return typeof runStream === "function"
      ? fromStreamingRuntimeCall(() => runStream.call(runtime, query, input))
      : fromArrayRuntimeCall(() => runtime.runQueryJsonText(query, input));
  } catch (error) {
    return singleErrorStream(
      normalizeRuntimeError(error, "Unable to inspect query streaming runtime"),
    );
  }
}
