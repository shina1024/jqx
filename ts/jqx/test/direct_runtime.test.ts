import * as assert from "node:assert/strict";
import { test } from "vite-plus/test";

import {
  compile,
  literal,
  isValidJson,
  parseJson,
  run,
  runJsonText,
  field,
  query,
  queryJsonText,
  queryRuntime,
  runtime,
  toAst,
  type Json,
  type QueryAst,
} from "../src/index.js";

function nestedJsonArrayText(depth: number, leaf: string): string {
  return "[".repeat(depth) + leaf + "]".repeat(depth);
}

test("root package exposes the canonical direct runtime entrypoints", () => {
  assert.equal(typeof run, "function");
  assert.equal(typeof runJsonText, "function");
  assert.equal(typeof compile, "function");
  assert.equal(typeof parseJson, "function");
  assert.equal(typeof isValidJson, "function");
});

test("runJsonText executes a jq filter on JSON text", () => {
  const result = runJsonText(".foo", '{"foo":1}');
  assert.deepEqual(result, { ok: true, value: ["1"] });
});

test("JSON text preserves integer-like key order while JS values follow ECMAScript order", () => {
  const input = '{"2":"two","1":"one","a":"aye"}';
  assert.deepEqual(runJsonText(".", input), { ok: true, value: [input] });

  const parsed = parseJson(input);
  assert.equal(parsed.ok, true);
  if (parsed.ok) {
    assert.deepEqual(Object.keys(parsed.value as Record<string, Json>), ["1", "2", "a"]);
  }
});

test("runJsonText handles the configured JSON nesting limit without a JS stack overflow", () => {
  const atLimit = nestedJsonArrayText(10_000, "0");
  assert.deepEqual(runJsonText(".", atLimit), { ok: true, value: [atLimit] });

  const beyondLimit = runJsonText(".", nestedJsonArrayText(10_001, "0"));
  assert.equal(beyondLimit.ok, false);
  if (!beyondLimit.ok) {
    assert.equal(beyondLimit.error.kind, "backend_runtime");
  }
});

test("run stringifies input and parses outputs", () => {
  const result = run(".foo", { foo: 1 });
  assert.deepEqual(result, { ok: true, value: [1] });
});

test("run returns input_stringify for unserializable value-lane input", () => {
  const cyclic: Record<string, unknown> = {};
  cyclic.self = cyclic;

  const result = run(".", cyclic as Json);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_stringify");
    assert.equal(typeof result.error.message, "string");
  }
});

test("run contains accessor-driven input failures", () => {
  let getterCalled = false;
  const accessorInput = Object.create(null) as Record<string, unknown>;
  Object.defineProperty(accessorInput, "value", {
    enumerable: true,
    get() {
      getterCalled = true;
      throw new Error("getter should not execute");
    },
  });
  const accessorResult = run(".", accessorInput as Json);
  assert.equal(accessorResult.ok, false);
  assert.equal(getterCalled, false);
});

test("run encodes deeply nested value-lane input without a JS stack overflow", () => {
  let deep: unknown = null;
  for (let depth = 0; depth < 10_000; depth += 1) {
    deep = [deep];
  }
  const deepResult = run(".", deep as Json);
  assert.equal(deepResult.ok, true);
});

test("run rejects non-finite numbers in the value lane", () => {
  const result = run(".", { foo: [1, Number.POSITIVE_INFINITY] } as Json);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_value");
    if (result.error.kind === "input_value") {
      assert.equal(result.error.path, "$.foo[1]");
    }
  }
});

test("run rejects jq-compatible outputs that are not representable in the value lane", () => {
  const result = run("1e309", null);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_value");
    if (result.error.kind === "output_value") {
      assert.equal(result.error.index, 0);
      assert.equal(result.error.path, "$");
    }
  }
});

test("compile returns an opaque compiled filter with run methods", () => {
  const compiled = compile(".items[]");
  assert.equal(compiled.ok, true);
  if (!compiled.ok) {
    return;
  }

  const runtimeText = compiled.value.runJsonText('{"items":[1,2,3]}');
  assert.deepEqual(runtimeText, { ok: true, value: ["1", "2", "3"] });

  const runtimeValue = compiled.value.run({ items: [1, 2, 3] });
  assert.deepEqual(runtimeValue, { ok: true, value: [1, 2, 3] });
});

test("parseJson and isValidJson use strict value-lane JSON semantics", () => {
  const parsed = parseJson('{"foo":[1,true,null]}');
  assert.deepEqual(parsed, {
    ok: true,
    value: { foo: [1, true, null] },
  });

  assert.equal(isValidJson('{"foo":[1,true,null]}'), true);
  assert.equal(isValidJson("{"), false);
  assert.equal(isValidJson("1e309"), false);
  assert.equal(isValidJson("NaN"), false);

  const invalid = parseJson("{");
  assert.equal(invalid.ok, false);
  if (!invalid.ok) {
    assert.equal(invalid.error.kind, "backend_runtime");
    assert.equal(typeof invalid.error.message, "string");
  }

  const overflow = parseJson("1e309");
  assert.equal(overflow.ok, false);
  if (!overflow.ok) {
    assert.equal(overflow.error.kind, "input_value");
    if (overflow.error.kind === "input_value") {
      assert.equal(overflow.error.path, "$");
    }
  }

  const jqExtension = parseJson("NaN");
  assert.equal(jqExtension.ok, false);
  if (!jqExtension.ok) {
    assert.equal(jqExtension.error.kind, "backend_runtime");
    assert.equal(typeof jqExtension.error.message, "string");
  }
});

test("compile surfaces structured backend errors for invalid filters", () => {
  const compiled = compile(".[");
  assert.equal(compiled.ok, false);
  if (!compiled.ok) {
    assert.equal(compiled.error.kind, "backend_runtime");
    assert.equal(typeof compiled.error.details?.code, "string");
  }
});

test("query remains available as a secondary root-package lane", () => {
  const dslQuery = field("user");
  const ast = toAst(dslQuery);

  const textResult = queryJsonText(ast, '{"user":{"name":"alice"}}');
  assert.deepEqual(textResult, {
    ok: true,
    value: ['{"name":"alice"}'],
  });

  const dslResult = query(dslQuery, { user: { name: "alice" } });
  assert.deepEqual(dslResult, {
    ok: true,
    value: [{ name: "alice" }],
  });
});

test("query rejects non-finite literal values in the value lane", () => {
  const result = query(literal(Number.POSITIVE_INFINITY), null);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_value");
    if (result.error.kind === "input_value") {
      assert.equal(result.error.path, "$");
    }
  }
});

test("query rejects cyclic raw ASTs before recursive compilation", () => {
  const cyclic: { kind: "map"; inner: QueryAst } = {
    kind: "map",
    inner: { kind: "identity" },
  };
  cyclic.inner = cyclic;
  const result = queryJsonText(cyclic, "null");
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "backend_runtime");
    assert.match(result.error.message, /Cyclic AST object/u);
  }
});

test("runtime and queryRuntime remain available for adapter integration", () => {
  const runResult = runtime.run(".foo", { foo: 1 });
  assert.deepEqual(runResult, { ok: true, value: [1] });

  const queryResult = queryRuntime.query(toAst(field("foo")), { foo: 1 });
  assert.deepEqual(queryResult, { ok: true, value: [1] });
});
