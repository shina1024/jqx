#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function usage() {
  console.error(
    "Usage: node scripts/jq_diff.mjs [<cases-path>] [--snapshot <path>]",
  );
}

function parseArgs(argv) {
  const defaultsPath = path.join(__dirname, "jq_compat_cases.json");
  const options = {
    casesPath: defaultsPath,
    snapshotPath: "",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--snapshot") {
      options.snapshotPath = argv[++i];
      continue;
    }
    if (arg.startsWith("--")) {
      throw new Error(`Unknown argument: ${arg}`);
    }
    if (options.casesPath !== defaultsPath) {
      throw new Error(`Unexpected positional argument: ${arg}`);
    }
    options.casesPath = arg;
  }

  return options;
}

function resolveRepoPath(value) {
  return path.isAbsolute(value) ? path.resolve(value) : path.resolve(repoRoot, value);
}

function commandExists(command) {
  const result = spawnSync(command, ["--version"], { encoding: "utf8" });
  return result.status === 0 || result.error == null;
}

function resolveJqCommand() {
  const preferred = process.env.JQ_BIN ?? "jq";
  if (commandExists(preferred)) {
    return preferred;
  }

  for (const miseCommand of ["mise", "mise.exe"]) {
    const probe = spawnSync(miseCommand, ["which", "jq"], { encoding: "utf8" });
    if (probe.status !== 0) {
      continue;
    }
    const candidate = probe.stdout.trim();
    if (candidate !== "") {
      return candidate;
    }
  }

  throw new Error(`jq binary not found: ${preferred} (also checked mise)`);
}

function resolveMoonCommand() {
  const preferred = process.env.MOON_BIN ?? "moon";
  for (const candidate of [preferred, "moon.exe"]) {
    if (candidate && commandExists(candidate)) {
      return candidate;
    }
  }

  const homeMoon =
    process.platform === "win32"
      ? path.join(os.homedir(), ".moon", "bin", "moon.exe")
      : path.join(os.homedir(), ".moon", "bin", "moon");
  if (existsSync(homeMoon)) {
    return homeMoon;
  }

  throw new Error(`moon command not found: ${preferred}`);
}

function resolveJqxProfile() {
  const profile = (process.env.JQX_PROFILE ?? "release").toLowerCase();
  if (!["debug", "release"].includes(profile)) {
    throw new Error(`invalid JQX_PROFILE: ${profile} (expected debug or release)`);
  }
  return profile;
}

function resolveJqxRunner() {
  const runner = process.env.JQX_RUNNER ?? "native";
  if (!["native", "moon-run"].includes(runner)) {
    throw new Error(`invalid JQX_RUNNER: ${runner} (expected moon-run or native)`);
  }
  return runner;
}

function resolveNativeJqxBinary(profile) {
  const preferred = process.env.JQX_BIN ?? "";
  if (preferred !== "") {
    const absolute = path.isAbsolute(preferred) ? preferred : path.resolve(repoRoot, preferred);
    if (existsSync(absolute)) {
      return absolute;
    }
    throw new Error(`jqx executable not found: ${absolute}`);
  }

  const candidates =
    profile === "release"
      ? [
          path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd"),
          path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd.exe"),
          path.join(repoRoot, "_build", "native", "debug", "build", "cmd", "cmd"),
          path.join(repoRoot, "_build", "native", "debug", "build", "cmd", "cmd.exe"),
        ]
      : [
          path.join(repoRoot, "_build", "native", "debug", "build", "cmd", "cmd"),
          path.join(repoRoot, "_build", "native", "debug", "build", "cmd", "cmd.exe"),
          path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd"),
          path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd.exe"),
        ];

  for (const candidate of candidates) {
    if (existsSync(candidate)) {
      return candidate;
    }
  }

  throw new Error("jqx native executable not found under _build/native/{release,debug}/build/cmd");
}

function runCommand(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
    input: options.input ?? undefined,
    env: options.env ?? process.env,
  });
  return {
    status: result.status ?? 1,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
    error: result.error ?? null,
  };
}

function cleanOutput(text) {
  return text
    .replace(/\r/g, "")
    .split("\n")
    .filter((line) => !line.startsWith("Blocking waiting for file lock "))
    .join("\n")
    .replace(/\n+$/g, "");
}

function normalizeErrorMessage(text) {
  return text
    .trim()
    .replace(/^jq: error(?: \(at <stdin>:[0-9:]+\))?:\s*/, "")
    .replace(/^jqx: error(?: \(at <stdin>:[0-9:]+\))?:\s*/, "");
}

function isCompilerSummaryLine(line) {
  return /^jqx?:\s*[0-9]+\s+compile error(s)?$/.test(line);
}

function classifyRunOutput(stdoutText, stderrText) {
  const valueLines = [];
  const debugLines = [];
  const errorLines = [];
  const stderrOtherLines = [];

  const classifyLine = (line, plainBucket) => {
    if (line === "" || isCompilerSummaryLine(line)) {
      return;
    }
    if (/^\["DEBUG:",/.test(line)) {
      debugLines.push(line);
      return;
    }
    if (/^jqx?: error/.test(line)) {
      errorLines.push(line);
      return;
    }
    plainBucket.push(line);
  };

  for (const line of stdoutText === "" ? [] : stdoutText.split("\n")) {
    classifyLine(line, valueLines);
  }
  for (const line of stderrText === "" ? [] : stderrText.split("\n")) {
    classifyLine(line, stderrOtherLines);
  }

  return {
    valueText: valueLines.join("\n"),
    debugText: debugLines.join("\n"),
    errorText: errorLines.map(normalizeErrorMessage).join("\n").trim(),
    hasErrorLine: errorLines.length > 0,
    stderrOtherText: stderrOtherLines.join("\n"),
    mergedText: [...valueLines, ...debugLines, ...errorLines, ...stderrOtherLines].join("\n"),
  };
}

function classifyFailure({ jqStatus, jqxStatus, jqxOut }) {
  if (jqxOut.includes("Invalid character ")) {
    return "parser-invalid-character";
  }
  if (jqxOut.includes("Invalid number")) {
    return "parser-invalid-number";
  }
  if (jqxOut.includes("Unknown function: ")) {
    return "unknown-function";
  }
  if (jqxOut.includes("Unknown variable: ")) {
    return "unknown-variable";
  }
  if (jqStatus === 0 && (jqxOut.startsWith("jqx: error") || jqxStatus !== 0)) {
    return "runtime-error-vs-jq-success";
  }
  return "output-mismatch";
}

function getCompatStatus(testCase) {
  return typeof testCase.compat_status === "string"
    ? testCase.compat_status.toLowerCase()
    : "pass";
}

function getCompatField(testCase, name) {
  return testCase[name] == null ? "" : String(testCase[name]);
}

function readCases(filePath) {
  const raw = readFileSync(filePath, "utf8");
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed)) {
    throw new Error("invalid cases file format: expected top-level array");
  }
  return parsed;
}

function warmupJqx({ moonCommand, runner, profile }) {
  if (runner === "native") {
    const buildArgs = ["build", "--target", "native"];
    if (profile === "release") {
      buildArgs.push("--release");
    }
    buildArgs.push("cmd");
    const build = runCommand(moonCommand, buildArgs);
    if (build.status !== 0) {
      throw new Error(`failed to build native jqx executable: ${cleanOutput(build.stderr || build.stdout)}`);
    }
    const jqxBinary = resolveNativeJqxBinary(profile);
    const warmup = runCommand(jqxBinary, [".", "null"]);
    if (warmup.status !== 0) {
      throw new Error("failed to warm up jqx native executable");
    }
    return { jqxCommand: jqxBinary, jqxPrefixArgs: [] };
  }

  const warmup = runCommand(moonCommand, ["run", "--target", "native", "cmd", "--", ".", "null"]);
  if (warmup.status !== 0) {
    throw new Error("failed to warm up jqx command via moon run");
  }
  return {
    jqxCommand: moonCommand,
    jqxPrefixArgs: ["run", "--target", "native", "cmd", "--"],
  };
}

function ensureValidMetadata(testCase) {
  const compatStatus = getCompatStatus(testCase);
  const name = String(testCase.name ?? "");
  if (!["pass", "temporary_exception"].includes(compatStatus)) {
    throw new Error(`invalid compat_status for case ${name}: ${compatStatus}`);
  }
  if (
    compatStatus === "temporary_exception" &&
    ["compat_ledger_id", "compat_reason", "compat_removal_condition"].some(
      (key) => getCompatField(testCase, key).trim() === "",
    )
  ) {
    throw new Error(
      `temporary_exception case ${name} must set compat_ledger_id, compat_reason, and compat_removal_condition`,
    );
  }
}

function writeSnapshot(snapshotPath, records) {
  const absolutePath = resolveRepoPath(snapshotPath);
  mkdirSync(path.dirname(absolutePath), { recursive: true });
  writeFileSync(absolutePath, `${JSON.stringify(records, null, 2)}\n`, "utf8");
  console.log(`Wrote snapshot: ${absolutePath}`);
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const casesPath = resolveRepoPath(options.casesPath);
  if (!existsSync(casesPath)) {
    throw new Error(`cases file not found: ${casesPath}`);
  }

  const jqCommand = resolveJqCommand();
  const moonCommand = resolveMoonCommand();
  const profile = resolveJqxProfile();
  const runner = resolveJqxRunner();
  const cases = readCases(casesPath);
  const pager = process.env.PAGER;
  delete process.env.PAGER;

  try {
    const { jqxCommand, jqxPrefixArgs } = warmupJqx({ moonCommand, runner, profile });

    let total = 0;
    let passed = 0;
    let failed = 0;
    let skipped = 0;
    let temporary = 0;
    const diffRecords = [];

    for (const testCase of cases) {
      total += 1;
      ensureValidMetadata(testCase);

      const name = String(testCase.name);
      const filter = String(testCase.filter);
      const input = String(testCase.input);
      const expectError = Boolean(testCase.expect_error);
      const expectErrorMode = String(testCase.expect_error_mode ?? "strict").toLowerCase();
      const sourceKind = String(testCase.source_kind ?? "").toLowerCase();
      const expectStatus =
        testCase.expect_status == null ? null : Number(testCase.expect_status);
      const skipReason = getCompatField(testCase, "skip_reason");
      const compatStatus = getCompatStatus(testCase);
      const compatLedgerId = getCompatField(testCase, "compat_ledger_id");
      const compatReason = getCompatField(testCase, "compat_reason");
      const compatRemovalCondition = getCompatField(
        testCase,
        "compat_removal_condition",
      );
      const jqArgs = Array.isArray(testCase.jq_args) ? [...testCase.jq_args].map(String) : [];
      const jqxArgs = Array.isArray(testCase.jqx_args)
        ? [...testCase.jqx_args].map(String)
        : [];
      const jqxUseStdin =
        testCase.jqx_use_stdin == null ? true : Boolean(testCase.jqx_use_stdin);

      if (skipReason !== "") {
        skipped += 1;
        console.log(`[SKIP] ${name} (${skipReason})`);
        continue;
      }

      const jqRun = runCommand(jqCommand, ["-c", ...jqArgs, filter], { input });
      const jqStdout = cleanOutput(jqRun.stdout);
      const jqStderr = cleanOutput(jqRun.stderr);
      const jqClass = classifyRunOutput(jqStdout, jqStderr);

      const jqxRunArgs = [...jqxPrefixArgs, ...jqxArgs, filter];
      if (!jqxUseStdin) {
        jqxRunArgs.push(input);
      }
      const jqxRun = runCommand(jqxCommand, jqxRunArgs, jqxUseStdin ? { input } : {});
      const jqxStdout = cleanOutput(jqxRun.stdout);
      const jqxStderr = cleanOutput(jqxRun.stderr);
      const jqxClass = classifyRunOutput(jqxStdout, jqxStderr);

      let ok = false;
      if (expectError) {
        const jqHasError = jqRun.status !== 0 || jqClass.hasErrorLine;
        const jqxHasError = jqxRun.status !== 0 || jqxClass.hasErrorLine;
        if (expectErrorMode === "any" || expectErrorMode === "ignore_msg") {
          if (sourceKind === "compile_fail") {
            ok = jqHasError && jqxHasError;
          } else {
            ok =
              jqHasError &&
              jqxHasError &&
              jqClass.valueText === jqxClass.valueText &&
              jqClass.debugText === jqxClass.debugText &&
              jqClass.stderrOtherText === jqxClass.stderrOtherText;
          }
        } else if (sourceKind === "compile_fail") {
          ok =
            jqHasError &&
            jqxHasError &&
            jqClass.errorText === jqxClass.errorText;
        } else {
          ok =
            jqHasError &&
            jqxHasError &&
            jqClass.errorText === jqxClass.errorText &&
            jqClass.valueText === jqxClass.valueText &&
            jqClass.debugText === jqxClass.debugText &&
            jqClass.stderrOtherText === jqxClass.stderrOtherText;
        }
      } else if (expectStatus != null) {
        ok =
          jqRun.status === expectStatus &&
          jqxRun.status === expectStatus &&
          jqClass.valueText === jqxClass.valueText &&
          jqClass.debugText === jqxClass.debugText &&
          jqClass.errorText === jqxClass.errorText &&
          jqClass.stderrOtherText === jqxClass.stderrOtherText;
      } else if (
        jqRun.status === 0 &&
        jqxRun.status === 0 &&
        jqClass.valueText === jqxClass.valueText &&
        jqClass.debugText === jqxClass.debugText &&
        jqClass.errorText === jqxClass.errorText &&
        jqClass.stderrOtherText === jqxClass.stderrOtherText
      ) {
        ok = true;
      } else if (jqRun.status !== 0) {
        const jqxHasError = jqxRun.status !== 0 || jqxClass.hasErrorLine;
        ok =
          jqxHasError &&
          jqClass.errorText === jqxClass.errorText &&
          jqClass.valueText === jqxClass.valueText &&
          jqClass.debugText === jqxClass.debugText &&
          jqClass.stderrOtherText === jqxClass.stderrOtherText;
      }

      if (compatStatus === "temporary_exception") {
        if (ok) {
          failed += 1;
          diffRecords.push({
            name,
            category: "stale-temporary-exception",
            compat_status: compatStatus,
            compat_ledger_id: compatLedgerId,
            compat_reason: compatReason,
            compat_removal_condition: compatRemovalCondition,
            jq_status: String(jqRun.status),
            jqx_status: String(jqxRun.status),
            jq_out: jqClass.mergedText,
            jqx_out: jqxClass.mergedText,
            jq_stdout: jqStdout,
            jq_stderr: jqStderr,
            jqx_stdout: jqxStdout,
            jqx_stderr: jqxStderr,
          });
          console.log(`[FAIL] ${name}`);
          console.log(
            `  documented temporary exception no longer reproduces: ${compatLedgerId}`,
          );
          console.log(`  removal_condition: ${compatRemovalCondition}`);
        } else {
          temporary += 1;
          diffRecords.push({
            name,
            category: "temporary-exception",
            compat_status: compatStatus,
            compat_ledger_id: compatLedgerId,
            compat_reason: compatReason,
            compat_removal_condition: compatRemovalCondition,
            jq_status: String(jqRun.status),
            jqx_status: String(jqxRun.status),
            jq_out: jqClass.mergedText,
            jqx_out: jqxClass.mergedText,
            jq_stdout: jqStdout,
            jq_stderr: jqStderr,
            jqx_stdout: jqxStdout,
            jqx_stderr: jqxStderr,
          });
          console.log(`[TEMP] ${name} (${compatLedgerId})`);
          console.log(`  reason: ${compatReason}`);
          console.log(`  removal_condition: ${compatRemovalCondition}`);
        }
        continue;
      }

      if (ok) {
        passed += 1;
        console.log(`[PASS] ${name}`);
        continue;
      }

      failed += 1;
      diffRecords.push({
        name,
        category: classifyFailure({
          jqStatus: jqRun.status,
          jqxStatus: jqxRun.status,
          jqxOut: jqxClass.mergedText,
        }),
        compat_status: compatStatus,
        compat_ledger_id: compatLedgerId,
        compat_reason: compatReason,
        compat_removal_condition: compatRemovalCondition,
        jq_status: String(jqRun.status),
        jqx_status: String(jqxRun.status),
        jq_out: jqClass.mergedText,
        jqx_out: jqxClass.mergedText,
        jq_stdout: jqStdout,
        jq_stderr: jqStderr,
        jqx_stdout: jqxStdout,
        jqx_stderr: jqxStderr,
      });
      console.log(`[FAIL] ${name}`);
      console.log(`  filter: ${filter}`);
      console.log(`  input: ${input}`);
      if (expectError) {
        console.log(`  expect_error_mode=${expectErrorMode}`);
      }
      console.log(`  jq status=${jqRun.status} stdout=${jqStdout} stderr=${jqStderr}`);
      console.log(
        `  jqx status=${jqxRun.status} stdout=${jqxStdout} stderr=${jqxStderr}`,
      );
    }

    console.log("");
    console.log(
      `Summary: total=${total} passed=${passed} temporary=${temporary} failed=${failed} skipped=${skipped}`,
    );
    if (options.snapshotPath !== "") {
      writeSnapshot(options.snapshotPath, diffRecords);
    }
    process.exit(failed === 0 ? 0 : 1);
  } finally {
    if (pager == null) {
      delete process.env.PAGER;
    } else {
      process.env.PAGER = pager;
    }
  }
}

try {
  main();
} catch (error) {
  console.error(`[jq-diff] ${error instanceof Error ? error.message : String(error)}`);
  usage();
  process.exit(1);
}
