import * as assert from "node:assert/strict";
import { test } from "node:test";

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
} from "../src/index.js";

function nestedJsonArrayText(depth: number, leaf: string): string {
  return "[".repeat(depth) + leaf + "]".repeat(depth);
}

void test("root package exposes the canonical direct runtime entrypoints", () => {
  assert.equal(typeof run, "function");
  assert.equal(typeof runJsonText, "function");
  assert.equal(typeof compile, "function");
  assert.equal(typeof parseJson, "function");
  assert.equal(typeof isValidJson, "function");
});

void test("runJsonText executes a jq filter on JSON text", () => {
  const result = runJsonText(".foo", '{"foo":1}');
  assert.deepEqual(result, { ok: true, value: ["1"] });
});

void test("runJsonText matches jq 1.8.1 print depth truncation", () => {
  const input = nestedJsonArrayText(257, "0");
  const expected = nestedJsonArrayText(257, "<skipped: too deep>");
  const result = runJsonText(".", input);
  assert.deepEqual(result, { ok: true, value: [expected] });
});

void test("run stringifies input and parses outputs", () => {
  const result = run(".foo", { foo: 1 });
  assert.deepEqual(result, { ok: true, value: [1] });
});

void test("run returns input_stringify for unserializable value-lane input", () => {
  const cyclic: Record<string, unknown> = {};
  cyclic.self = cyclic;

  const result = run(".", cyclic as Json);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_stringify");
    assert.equal(typeof result.error.message, "string");
  }
});

void test("run rejects non-finite numbers in the value lane", () => {
  const result = run(".", { foo: [1, Number.POSITIVE_INFINITY] } as Json);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_value");
    if (result.error.kind === "input_value") {
      assert.equal(result.error.path, "$.foo[1]");
    }
  }
});

void test("run rejects jq-compatible outputs that are not representable in the value lane", () => {
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

void test("compile returns an opaque compiled filter with run methods", () => {
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

void test("parseJson and isValidJson use strict value-lane JSON semantics", () => {
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

void test("compile surfaces structured backend errors for invalid filters", () => {
  const compiled = compile(".[");
  assert.equal(compiled.ok, false);
  if (!compiled.ok) {
    assert.equal(compiled.error.kind, "backend_runtime");
    assert.equal(typeof compiled.error.details?.code, "string");
  }
});

void test("query remains available as a secondary root-package lane", () => {
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

void test("query rejects non-finite literal values in the value lane", () => {
  const result = query(literal(Number.POSITIVE_INFINITY), null);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_value");
    if (result.error.kind === "input_value") {
      assert.equal(result.error.path, "$");
    }
  }
});

void test("runtime and queryRuntime remain available for adapter integration", () => {
  const runResult = runtime.run(".foo", { foo: 1 });
  assert.deepEqual(runResult, { ok: true, value: [1] });

  const queryResult = queryRuntime.query(toAst(field("foo")), { foo: 1 });
  assert.deepEqual(queryResult, { ok: true, value: [1] });
});
