import * as assert from "node:assert/strict";
import { test } from "node:test";

import * as v from "valibot";

import { createAdapter, type JqxDynamicRuntime, type JqxTypedRuntime } from "../src/index.js";

test("adapter.filter validates input and output", async () => {
  const runtime: JqxDynamicRuntime = {
    run(filter, input) {
      assert.equal(filter, ".user.name");
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true, value: ['"alice"'] };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.filter({
    filter: ".user.name",
    input: { user: { name: "alice" } },
    inputSchema: v.object({
      user: v.object({
        name: v.string(),
      }),
    }),
    outputSchema: v.string(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ["alice"]);
  }
});

test("adapter.filter returns input_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.filter({
    filter: ".",
    input: { x: 1 },
    inputSchema: v.object({
      user: v.object({
        name: v.string(),
      }),
    }),
    outputSchema: v.number(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_validation");
  }
});

test("adapter.filter returns runtime error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: false, error: "boom" };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.filter({
    filter: ".",
    input: { x: 1 },
    inputSchema: v.object({
      x: v.number(),
    }),
    outputSchema: v.number(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "runtime");
    assert.equal(result.error.message, "boom");
  }
});

test("adapter.filter returns output_parse error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["not-json"] };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.filter({
    filter: ".",
    input: { x: 1 },
    inputSchema: v.object({
      x: v.number(),
    }),
    outputSchema: v.number(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_parse");
    if (result.error.kind === "output_parse") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("adapter.filter returns output_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.filter({
    filter: ".",
    input: { x: 1 },
    inputSchema: v.object({
      x: v.number(),
    }),
    outputSchema: v.string(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_validation");
    if (result.error.kind === "output_validation") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("adapter.query validates through typed runtime", async () => {
  const runtime: JqxDynamicRuntime & JqxTypedRuntime<{ kind: "Q" }> = {
    run() {
      return { ok: true, value: [] };
    },
    runQuery(query, input) {
      assert.deepEqual(query, { kind: "Q" });
      assert.equal(input, '{"x":7}');
      return { ok: true, value: ["7"] };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.query({
    query: { kind: "Q" },
    input: { x: 7 },
    inputSchema: v.object({
      x: v.number(),
    }),
    outputSchema: v.number(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [7]);
  }
});

test("adapter.inferred parses JSON outputs", async () => {
  const runtime: JqxDynamicRuntime = {
    run(filter, input) {
      assert.equal(filter, ".user.name");
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true, value: ['"alice"'] };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.inferred({
    filter: ".user.name",
    input: { user: { name: "alice" } },
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ["alice"]);
  }
});

test("adapter.inferred returns output_parse error for invalid JSON", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["not-json"] };
    },
  };
  const adapter = createAdapter(runtime);
  const result = await adapter.inferred({
    filter: ".",
    input: { x: 1 },
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.match(result.error, /output_parse at index 0/);
  }
});
