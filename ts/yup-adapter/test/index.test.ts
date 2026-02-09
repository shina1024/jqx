import * as assert from "node:assert/strict";
import { test } from "node:test";

import * as yup from "yup";

import {
  type JqxDynamicRuntime,
  type JqxTypedRuntime,
  safeExecuteWithYup,
  safeRunWithYup,
  withY,
} from "../src/index.js";

test("safeRunWithYup validates input and output", async () => {
  const runtime: JqxDynamicRuntime = {
    run(filter, input) {
      assert.equal(filter, ".user.name");
      assert.equal(input, '{"user":{"name":"alice"}}');
      return { ok: true, value: ['"alice"'] };
    },
  };
  const result = await safeRunWithYup(runtime, {
    filter: ".user.name",
    input: { user: { name: "alice" } },
    inputSchema: yup
      .object({
        user: yup
          .object({
            name: yup.string().required(),
          })
          .required(),
      })
      .required(),
    outputSchema: yup.string().required(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, ["alice"]);
  }
});

test("safeRunWithYup returns input_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const result = await safeRunWithYup(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: yup
      .object({
        user: yup
          .object({
            name: yup.string().required(),
          })
          .required(),
      })
      .required(),
    outputSchema: yup.number().required(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "input_validation");
  }
});

test("safeRunWithYup returns runtime error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: false, error: "boom" };
    },
  };
  const result = await safeRunWithYup(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: yup
      .object({
        x: yup.number().required(),
      })
      .required(),
    outputSchema: yup.number().required(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "runtime");
    assert.equal(result.error.message, "boom");
  }
});

test("safeRunWithYup returns output_parse error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["not-json"] };
    },
  };
  const result = await safeRunWithYup(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: yup
      .object({
        x: yup.number().required(),
      })
      .required(),
    outputSchema: yup.number().required(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_parse");
    if (result.error.kind === "output_parse") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("safeRunWithYup returns output_validation error", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["1"] };
    },
  };
  const result = await safeRunWithYup(runtime, {
    filter: ".",
    input: { x: 1 },
    inputSchema: yup
      .object({
        x: yup.number().required(),
      })
      .required(),
    outputSchema: yup.string().required(),
  });
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.kind, "output_validation");
    if (result.error.kind === "output_validation") {
      assert.equal(result.error.index, 0);
    }
  }
});

test("safeExecuteWithYup validates through typed runtime", async () => {
  const runtime: JqxTypedRuntime<{ kind: "Q" }> = {
    runQuery(query, input) {
      assert.deepEqual(query, { kind: "Q" });
      assert.equal(input, '{"x":7}');
      return { ok: true, value: ["7"] };
    },
  };
  const result = await safeExecuteWithYup(runtime, {
    query: { kind: "Q" },
    input: { x: 7 },
    inputSchema: yup
      .object({
        x: yup.number().required(),
      })
      .required(),
    outputSchema: yup.number().required(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [7]);
  }
});

test("withY helper delegates to safeRunWithYup", async () => {
  const runtime: JqxDynamicRuntime = {
    run() {
      return { ok: true, value: ["2"] };
    },
  };
  const helper = withY(runtime);
  const result = await helper.safeRunWithYup({
    filter: ".",
    input: { x: 1 },
    inputSchema: yup
      .object({
        x: yup.number().required(),
      })
      .required(),
    outputSchema: yup.number().required(),
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.deepEqual(result.value, [2]);
  }
});
