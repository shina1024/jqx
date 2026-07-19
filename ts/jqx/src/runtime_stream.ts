import { decodeRuntimeOutput } from "./runtime_json.js";
import {
  failRuntimeResult,
  normalizeRuntimeError,
  normalizeRuntimeResult,
} from "./runtime_shared.js";

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

export async function callRuntime<T>(call: RuntimeCall<T>): Promise<JqxResult<T, JqxRuntimeError>> {
  try {
    return normalizeRuntimeResult(await Promise.resolve(call()));
  } catch (error) {
    return failRuntimeResult(normalizeRuntimeError(error, "Runtime call failed"));
  }
}

function fromArrayRuntimeCall(
  call: RuntimeCall<string[]>,
): JqxResultStream<string, JqxRuntimeError> {
  return (async function* () {
    const runtimeOut = await callRuntime(call);
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
    const runtimeOut = await callRuntime(call);
    if (!runtimeOut.ok) {
      yield failRuntimeResult<string>(runtimeOut.error);
      return;
    }
    try {
      for await (const value of runtimeOut.value) yield { ok: true, value };
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
