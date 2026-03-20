#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function usage() {
  console.error(
    "Usage: node scripts/jq_upstream_import.mjs [--config <path>] [--output <path>]",
  );
}

function parseArgs(argv) {
  let configPath = path.join(__dirname, "jq_upstream_import.json");
  let outputPath = path.join(__dirname, "jq_compat_cases.upstream.json");

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--config") {
      configPath = argv[i + 1];
      i += 1;
      continue;
    }
    if (arg === "--output") {
      outputPath = argv[i + 1];
      i += 1;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return { configPath, outputPath };
}

function resolveRepoPath(value) {
  return path.isAbsolute(value) ? path.resolve(value) : path.resolve(repoRoot, value);
}

function writeJsonFile(filePath, value) {
  mkdirSync(path.dirname(filePath), { recursive: true });
  writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function isSkipLine(line) {
  const trimmed = line.trim();
  return trimmed === "" || trimmed.startsWith("#");
}

function parseJqTestFile(testFilePath, sourceFileName) {
  const lines = readFileSync(testFilePath, "utf8").split(/\r?\n/);
  const cases = [];

  let i = 0;
  let mustFail = false;
  let ignoreMsg = false;

  while (i < lines.length) {
    const line = lines[i] ?? "";
    const lineNo = i + 1;

    if (isSkipLine(line)) {
      i += 1;
      continue;
    }

    if (line === "%%FAIL" || line === "%%FAIL IGNORE MSG") {
      mustFail = true;
      ignoreMsg = line === "%%FAIL IGNORE MSG";
      i += 1;
      continue;
    }

    const program = line;
    const programLine = lineNo;
    i += 1;

    if (mustFail) {
      const errorLines = [];
      while (i < lines.length) {
        const candidate = lines[i] ?? "";
        if (isSkipLine(candidate)) {
          i += 1;
          break;
        }
        errorLines.push(candidate);
        i += 1;
      }

      cases.push({
        source_file: sourceFileName,
        source_line: programLine,
        kind: "compile_fail",
        ignore_msg: ignoreMsg,
        filter: program,
        input: null,
        expected: [],
        expected_error_lines: errorLines,
      });

      mustFail = false;
      ignoreMsg = false;
      continue;
    }

    while (i < lines.length && isSkipLine(lines[i] ?? "")) {
      i += 1;
    }
    if (i >= lines.length) {
      break;
    }

    const input = lines[i] ?? "";
    i += 1;

    const expected = [];
    while (i < lines.length) {
      const candidate = lines[i] ?? "";
      if (isSkipLine(candidate)) {
        i += 1;
        break;
      }
      expected.push(candidate);
      i += 1;
    }

    cases.push({
      source_file: sourceFileName,
      source_line: programLine,
      kind: "runtime",
      ignore_msg: false,
      filter: program,
      input,
      expected,
      expected_error_lines: [],
    });
  }

  return cases;
}

function applyObjectProperties(target, patch) {
  if (!patch || typeof patch !== "object") {
    return;
  }
  for (const [key, value] of Object.entries(patch)) {
    target[key] = value;
  }
}

function main() {
  const { configPath, outputPath } = parseArgs(process.argv.slice(2));
  const resolvedConfigPath = resolveRepoPath(configPath);
  const resolvedOutputPath = resolveRepoPath(outputPath);

  const config = JSON.parse(readFileSync(resolvedConfigPath, "utf8"));
  const sourceRoot = resolveRepoPath(config.source_root);
  const enabledFiles = Array.isArray(config.enabled_test_files)
    ? config.enabled_test_files.map(String)
    : [];
  if (enabledFiles.length === 0) {
    throw new Error(`enabled_test_files is empty in config: ${resolvedConfigPath}`);
  }

  const includeCompileFail = Boolean(config.include_compile_fail);
  const compileFailExpectErrorMode =
    typeof config.compile_fail_expect_error_mode === "string"
      ? config.compile_fail_expect_error_mode.toLowerCase()
      : "any";
  if (!["strict", "any", "ignore_msg"].includes(compileFailExpectErrorMode)) {
    throw new Error(
      "compile_fail_expect_error_mode must be one of: strict, any, ignore_msg",
    );
  }

  const allParsed = [];
  for (const fileName of enabledFiles) {
    const testPath = path.join(sourceRoot, fileName);
    allParsed.push(...parseJqTestFile(testPath, fileName));
  }

  const outputCases = [];
  let statsTotal = 0;
  let statsEmitted = 0;
  let statsCompileFailSkipped = 0;

  for (const item of allParsed) {
    statsTotal += 1;
    if (item.kind === "compile_fail" && !includeCompileFail) {
      statsCompileFailSkipped += 1;
      continue;
    }

    const namePrefix = item.source_file
      .replace(/[^A-Za-z0-9]+/g, "-")
      .toLowerCase()
      .replace(/^-+|-+$/g, "");

    const testCase = {
      name: `upstream-${namePrefix}-l${item.source_line}`,
      filter: String(item.filter),
      input: item.input === null ? "null" : String(item.input),
      source_file: String(item.source_file),
      source_line: Number(item.source_line),
      source_kind: String(item.kind),
    };

    if (item.kind === "compile_fail") {
      testCase.expect_error = true;
      testCase.expect_error_mode = compileFailExpectErrorMode;
      if (item.expected_error_lines.length > 0) {
        testCase.source_error_lines = [...item.expected_error_lines];
      }
    }

    if (item.expected.length > 0) {
      testCase.source_expected_count = item.expected.length;
    }

    if (String(item.filter).startsWith("-")) {
      testCase.jqx_args = ["--"];
    }

    applyObjectProperties(testCase, config.default_case_fields);
    outputCases.push(testCase);
    statsEmitted += 1;
  }

  writeJsonFile(resolvedOutputPath, outputCases);
  console.log(`Generated upstream cases: ${resolvedOutputPath}`);
  console.log(
    `summary total=${statsTotal} emitted=${statsEmitted} compile_fail_skipped=${statsCompileFailSkipped}`,
  );
}

try {
  main();
} catch (error) {
  console.error(
    `[jq-upstream-import] ${error instanceof Error ? error.message : String(error)}`,
  );
  usage();
  process.exit(1);
}
