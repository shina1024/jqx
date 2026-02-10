import * as assert from "node:assert/strict";
import { test } from "node:test";

import { z } from "zod";

import {
  type JqxDynamicRuntime,
  type JqxTypedRuntime,
  runWithInferred,
  safeExecuteWithZod,
  safeRunWithZod,
  withZ,
} from "../src/index.js";

test("safeRunWithZod validates input and output", async () => {
  const runtime: JqxDynamicRuntime = {
    run(filter, input) {
      assert.equal(filter, ".user.name");
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true, value: ['"alice"'] };
    },
  };
  const result = await safeRunWithZod(runtime, {
    filter: ".user.name",
    input: { user: { name: "alice" } },
    inputSchema: z.object({
      user: z.object({ name: z.string() }),
    }),
    outputSchema: z.string(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ["alice"]);
  }
});

test("safeRunWithZod returns input_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const result = await safeRunWithZod(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: z.object({ user: z.object({ name: z.string() }) }),
    outputSchema: z.number(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_validation");
  }
});

test("safeRunWithZod returns runtime error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: false, error: "boom" };
    },
  };
  const result = await safeRunWithZod(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: z.object({ x: z.number() }),
    outputSchema: z.number(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "runtime");
    assert.equal(result.error.message, "boom");
  }
});

test("safeRunWithZod returns output_parse error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["not-json"] };
    },
  };
  const result = await safeRunWithZod(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: z.object({ x: z.number() }),
    outputSchema: z.number(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_parse");
    if (result.error.kind === "output_parse") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("safeRunWithZod returns output_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const result = await safeRunWithZod(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: z.object({ x: z.number() }),
    outputSchema: z.string(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_validation");
    if (result.error.kind === "output_validation") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("safeExecuteWithZod validates through typed runtime", async () => {
  const runtime: JqxTypedRuntime<{ kind: "Q" }> = {
    runQuery(query, input) {
      assert.deepEqual(query, { kind: "Q" });
      assert.equal(input, '{"x":7}');
      return { ok: true, value: ["7"] };
    },
  };
  const result = await safeExecuteWithZod(runtime, {
    query: { kind: "Q" },
    input: { x: 7 },
    inputSchema: z.object({ x: z.number() }),
    outputSchema: z.number(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [7]);
  }
});

test("withZ helper delegates to safeRunWithZod", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["2"] };
    },
  };
  const helper = withZ(runtime);
  const result = await helper.safeRunWithZod({
    filter: ".",
    input: { x: 1 },
    inputSchema: z.object({ x: z.number() }),
    outputSchema: z.number(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [2]);
  }
});

test("runWithInferred parses JSON outputs", async () => {
  const runtime: JqxDynamicRuntime = {
    run(filter, input) {
      assert.equal(filter, ".user.name");
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true, value: ['"alice"'] };
    },
  };
  const result = await runWithInferred(runtime, {
    filter: ".user.name",
    input: { user: { name: "alice" } },
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ["alice"]);
  }
});

test("runWithInferred returns output_parse error for invalid JSON", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["not-json"] };
    },
  };
  const result = await runWithInferred(runtime, {
    filter: ".",
    input: { x: 1 },
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.match(result.error, /output_parse at index 0/);
  }
});
