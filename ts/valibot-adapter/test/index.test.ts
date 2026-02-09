import * as assert from "node:assert/strict";
import { test } from "node:test";

import * as v from "valibot";

import {
  type JqxDynamicRuntime,
  type JqxTypedRuntime,
  safeExecuteWithValibot,
  safeRunWithValibot,
  withV,
} from "../src/index.js";

test("safeRunWithValibot validates input and output", async () => {
  const runtime: JqxDynamicRuntime = {
    run(filter, input) {
      assert.equal(filter, ".user.name");
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true, value: ['"alice"'] };
    },
  };
  const result = await safeRunWithValibot(runtime, {
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

test("safeRunWithValibot returns input_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const result = await safeRunWithValibot(runtime, {
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

test("safeRunWithValibot returns runtime error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: false, error: "boom" };
    },
  };
  const result = await safeRunWithValibot(runtime, {
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

test("safeRunWithValibot returns output_parse error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["not-json"] };
    },
  };
  const result = await safeRunWithValibot(runtime, {
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

test("safeRunWithValibot returns output_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const result = await safeRunWithValibot(runtime, {
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

test("safeExecuteWithValibot validates through typed runtime", async () => {
  const runtime: JqxTypedRuntime<{ kind: "Q" }> = {
    runQuery(query, input) {
      assert.deepEqual(query, { kind: "Q" });
      assert.equal(input, '{"x":7}');
      return { ok: true, value: ["7"] };
    },
  };
  const result = await safeExecuteWithValibot(runtime, {
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

test("withV helper delegates to safeRunWithValibot", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["2"] };
    },
  };
  const helper = withV(runtime);
  const result = await helper.safeRunWithValibot({
    filter: ".",
    input: { x: 1 },
    inputSchema: v.object({
      x: v.number(),
    }),
    outputSchema: v.number(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [2]);
  }
});
