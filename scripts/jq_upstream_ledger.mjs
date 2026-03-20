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
    "Usage: node scripts/jq_upstream_ledger.mjs [--cases <path>] [--maintained-cases <path>] [--failure-snapshot <path>] [--ledger <path>] [--verify] [--skip-differential]",
  );
}

function parseArgs(argv) {
  const options = {
    casesPath: path.join(__dirname, "jq_compat_cases.upstream.json"),
    maintainedCasesPath: path.join(__dirname, "jq_compat_cases.json"),
    failureSnapshotPath: path.join(__dirname, "jq_upstream_failures.snapshot.json"),
    ledgerPath: path.join(__dirname, "jq_upstream_diff_ledger.md"),
    verify: false,
    skipDifferential: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case "--cases":
        options.casesPath = argv[++i];
        break;
      case "--maintained-cases":
        options.maintainedCasesPath = argv[++i];
        break;
      case "--failure-snapshot":
        options.failureSnapshotPath = argv[++i];
        break;
      case "--ledger":
        options.ledgerPath = argv[++i];
        break;
      case "--verify":
        options.verify = true;
        break;
      case "--skip-differential":
        options.skipDifferential = true;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function resolveRepoPath(value) {
  return path.isAbsolute(value) ? path.resolve(value) : path.resolve(repoRoot, value);
}

function toPosixRelative(filePath) {
  return path.relative(repoRoot, filePath).split(path.sep).join("/");
}

function readJsonArrayFromText(raw) {
  if (raw == null || raw.trim() === "") {
    return [];
  }
  const parsed = JSON.parse(raw);
  return Array.isArray(parsed) ? parsed : [parsed];
}

function readJsonArrayFromFile(filePath) {
  if (!existsSync(filePath)) {
    return [];
  }
  return readJsonArrayFromText(readFileSync(filePath, "utf8"));
}

function readHeadFileRaw(repoRelativePath) {
  const result = spawnSync("git", ["-C", repoRoot, "show", `HEAD:${repoRelativePath}`], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    return null;
  }
  return result.stdout;
}

function readJsonArrayFromHead(repoRelativePath) {
  return readJsonArrayFromText(readHeadFileRaw(repoRelativePath));
}

function readHeadTextLine(repoRelativePath) {
  const raw = readHeadFileRaw(repoRelativePath);
  return raw == null ? "" : raw.trim();
}

function canonicalJson(value) {
  return JSON.stringify(value);
}

function getCompatStatus(testCase) {
  return typeof testCase.compat_status === "string"
    ? testCase.compat_status.toLowerCase()
    : "pass";
}

function getCompatField(testCase, name) {
  return testCase[name] == null ? "" : String(testCase[name]);
}

function getCaseSkipReason(testCase) {
  return getCompatField(testCase, "skip_reason");
}

function buildCaseComparableRecord(testCase) {
  return {
    name: String(testCase.name),
    filter: String(testCase.filter),
    input: String(testCase.input),
    source_file: testCase.source_file == null ? "" : String(testCase.source_file),
    source_line: testCase.source_line == null ? 0 : Number(testCase.source_line),
    source_kind: testCase.source_kind == null ? "" : String(testCase.source_kind),
    expect_error: Boolean(testCase.expect_error),
    expect_error_mode:
      testCase.expect_error_mode == null ? "" : String(testCase.expect_error_mode),
    expect_status:
      testCase.expect_status == null ? null : Number(testCase.expect_status),
    source_expected_count:
      testCase.source_expected_count == null ? null : Number(testCase.source_expected_count),
    source_error_lines: Array.isArray(testCase.source_error_lines)
      ? [...testCase.source_error_lines]
      : [],
    jq_args: Array.isArray(testCase.jq_args) ? [...testCase.jq_args] : [],
    jqx_args: Array.isArray(testCase.jqx_args) ? [...testCase.jqx_args] : [],
    jqx_use_stdin:
      testCase.jqx_use_stdin == null ? true : Boolean(testCase.jqx_use_stdin),
    skip_reason: getCaseSkipReason(testCase),
    compat_status: getCompatStatus(testCase),
    compat_ledger_id: getCompatField(testCase, "compat_ledger_id"),
    compat_reason: getCompatField(testCase, "compat_reason"),
    compat_removal_condition: getCompatField(testCase, "compat_removal_condition"),
  };
}

function buildDiffComparableRecord(record) {
  return {
    name: record.name == null ? "" : String(record.name),
    category: record.category == null ? "" : String(record.category),
    compat_status: record.compat_status == null ? "" : String(record.compat_status),
    compat_ledger_id: record.compat_ledger_id == null ? "" : String(record.compat_ledger_id),
    compat_reason: record.compat_reason == null ? "" : String(record.compat_reason),
    compat_removal_condition:
      record.compat_removal_condition == null
        ? ""
        : String(record.compat_removal_condition),
    jq_status: record.jq_status == null ? "" : String(record.jq_status),
    jqx_status: record.jqx_status == null ? "" : String(record.jqx_status),
    jq_out: record.jq_out == null ? "" : String(record.jq_out),
    jqx_out: record.jqx_out == null ? "" : String(record.jqx_out),
  };
}

function getChangedFields(oldRecord, newRecord) {
  return Object.keys(oldRecord).filter(
    (key) => canonicalJson(oldRecord[key]) !== canonicalJson(newRecord[key]),
  );
}

function buildMap(records) {
  return new Map(records.map((record) => [String(record.name), record]));
}

function validateCaseMetadata(cases, corpusName) {
  const errors = [];
  const seen = new Set();

  for (const testCase of cases) {
    const name = testCase.name == null ? "" : String(testCase.name);
    if (name === "") {
      errors.push(`${corpusName} case is missing a name`);
      continue;
    }
    if (seen.has(name)) {
      errors.push(`${corpusName} case name is duplicated: ${name}`);
    } else {
      seen.add(name);
    }

    const compatStatus = getCompatStatus(testCase);
    const compatLedgerId = getCompatField(testCase, "compat_ledger_id");
    const compatReason = getCompatField(testCase, "compat_reason");
    const compatRemovalCondition = getCompatField(testCase, "compat_removal_condition");
    const skipReason = getCaseSkipReason(testCase);

    if (!["pass", "temporary_exception"].includes(compatStatus)) {
      errors.push(`${corpusName} case ${name} has invalid compat_status: ${compatStatus}`);
    }

    if (compatStatus === "temporary_exception") {
      if (compatLedgerId.trim() === "") {
        errors.push(`${corpusName} case ${name} is missing compat_ledger_id`);
      }
      if (compatReason.trim() === "") {
        errors.push(`${corpusName} case ${name} is missing compat_reason`);
      }
      if (compatRemovalCondition.trim() === "") {
        errors.push(`${corpusName} case ${name} is missing compat_removal_condition`);
      }
    } else {
      if (
        compatLedgerId.trim() !== "" ||
        compatReason.trim() !== "" ||
        compatRemovalCondition.trim() !== ""
      ) {
        errors.push(`${corpusName} case ${name} has exception metadata but compat_status=pass`);
      }
      if (skipReason.trim() !== "") {
        errors.push(
          `${corpusName} case ${name} uses skip_reason without compat_status=temporary_exception`,
        );
      }
    }
  }

  return errors;
}

function resolveDiffCommand() {
  return { command: "node", args: [path.join(__dirname, "jq_diff.mjs")] };
}

function runDiffSnapshot(casesPath) {
  const tempSnapshot = path.join(
    os.tmpdir(),
    `jq-diff-${Math.random().toString(36).slice(2)}.json`,
  );
  const diffCommand = resolveDiffCommand();
  const result = spawnSync(
    diffCommand.command,
    [...diffCommand.args, casesPath, "--snapshot", tempSnapshot],
    {
      cwd: repoRoot,
      encoding: "utf8",
      stdio: "inherit",
      env: {
        ...process.env,
        CI: process.env.CI ?? "true",
      },
    },
  );

  const exitCode = result.status ?? 1;
  if (exitCode !== 0 && exitCode !== 1) {
    throw new Error(`jq_diff failed with unexpected exit code: ${exitCode}`);
  }

  return { exitCode, records: readJsonArrayFromFile(tempSnapshot) };
}

function newSnapshotContent(records) {
  return `${JSON.stringify(records, null, 2)}\n`;
}

function writeTextFileIfChanged(filePath, content) {
  const existing = existsSync(filePath) ? readFileSync(filePath, "utf8") : "";
  if (existing === content) {
    return false;
  }
  mkdirSync(path.dirname(filePath), { recursive: true });
  writeFileSync(filePath, content, "utf8");
  return true;
}

function getCorpusStatus(corpusName, cases, diffRecords) {
  const caseMap = buildMap(cases);
  const recordMap = buildMap(diffRecords);
  const activeTemporary = [];
  const staleTemporary = [];
  const broken = [];

  for (const testCase of cases) {
    if (getCompatStatus(testCase) !== "temporary_exception") {
      continue;
    }
    const name = String(testCase.name);
    const record = recordMap.get(name);
    const skipReason = getCaseSkipReason(testCase);

    if (!record) {
      (skipReason.trim() !== "" ? activeTemporary : staleTemporary).push({
        case: testCase,
        record: null,
        corpus: corpusName,
      });
      continue;
    }

    if (String(record.category) === "temporary-exception") {
      activeTemporary.push({ case: testCase, record, corpus: corpusName });
    } else {
      staleTemporary.push({ case: testCase, record, corpus: corpusName });
    }
  }

  for (const record of diffRecords) {
    const category = String(record.category ?? "");
    if (category === "temporary-exception" || category === "stale-temporary-exception") {
      continue;
    }
    broken.push({
      case: caseMap.get(String(record.name)) ?? null,
      record,
      corpus: corpusName,
    });
  }

  return {
    corpus: corpusName,
    total: cases.length,
    passingCount: cases.length - activeTemporary.length - staleTemporary.length - broken.length,
    activeTemporary,
    staleTemporary,
    broken,
  };
}

function addListSection(lines, title, entries) {
  lines.push(`## ${title}`, "");
  if (entries.length === 0) {
    lines.push("- none");
  } else {
    lines.push(...entries.map((entry) => `- ${entry}`));
  }
  lines.push("");
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const maintainedCasesPath = resolveRepoPath(options.maintainedCasesPath);
  const upstreamCasesPath = resolveRepoPath(options.casesPath);
  const failureSnapshotPath = resolveRepoPath(options.failureSnapshotPath);
  const ledgerPath = resolveRepoPath(options.ledgerPath);

  const maintainedCasesRel = toPosixRelative(maintainedCasesPath);
  const upstreamCasesRel = toPosixRelative(upstreamCasesPath);
  const failureSnapshotRel = toPosixRelative(failureSnapshotPath);
  const ledgerRel = toPosixRelative(ledgerPath);

  const maintainedCases = readJsonArrayFromFile(maintainedCasesPath);
  const upstreamCases = readJsonArrayFromFile(upstreamCasesPath);

  const metadataErrors = [
    ...validateCaseMetadata(maintainedCases, "maintained"),
    ...validateCaseMetadata(upstreamCases, "upstream"),
  ];
  if (metadataErrors.length > 0) {
    throw new Error(`compatibility metadata validation failed:\n- ${metadataErrors.join("\n- ")}`);
  }

  const upstreamDiffResult = options.skipDifferential
    ? { exitCode: 0, records: readJsonArrayFromFile(failureSnapshotPath) }
    : runDiffSnapshot(upstreamCasesPath);
  const maintainedDiffResult = options.skipDifferential
    ? { exitCode: 0, records: [] }
    : runDiffSnapshot(maintainedCasesPath);

  const upstreamRecords = [...upstreamDiffResult.records].sort((a, b) =>
    String(a.name).localeCompare(String(b.name)) ||
    String(a.category ?? "").localeCompare(String(b.category ?? "")),
  );
  const maintainedRecords = [...maintainedDiffResult.records].sort((a, b) =>
    String(a.name).localeCompare(String(b.name)) ||
    String(a.category ?? "").localeCompare(String(b.category ?? "")),
  );

  const snapshotContent = newSnapshotContent(upstreamRecords);
  const maintainedStatus = getCorpusStatus("maintained", maintainedCases, maintainedRecords);
  const upstreamStatus = getCorpusStatus("upstream", upstreamCases, upstreamRecords);

  const oldUpstreamCases = readJsonArrayFromHead(upstreamCasesRel);
  const oldUpstreamCaseMap = buildMap(oldUpstreamCases);
  const newUpstreamCaseMap = buildMap(upstreamCases);
  const addedCaseNames = [...newUpstreamCaseMap.keys()]
    .filter((name) => !oldUpstreamCaseMap.has(name))
    .sort();
  const removedCaseNames = [...oldUpstreamCaseMap.keys()]
    .filter((name) => !newUpstreamCaseMap.has(name))
    .sort();
  const changedCases = [...newUpstreamCaseMap.keys()]
    .filter((name) => oldUpstreamCaseMap.has(name))
    .sort()
    .map((name) => ({
      name,
      changed_fields: getChangedFields(
        buildCaseComparableRecord(oldUpstreamCaseMap.get(name)),
        buildCaseComparableRecord(newUpstreamCaseMap.get(name)),
      ),
    }))
    .filter((item) => item.changed_fields.length > 0);

  const oldUpstreamRecords = readJsonArrayFromHead(failureSnapshotRel);
  const oldUpstreamRecordMap = buildMap(oldUpstreamRecords);
  const newUpstreamRecordMap = buildMap(upstreamRecords);
  const newDifferenceNames = [...newUpstreamRecordMap.keys()]
    .filter((name) => !oldUpstreamRecordMap.has(name))
    .sort();
  const resolvedDifferenceNames = [...oldUpstreamRecordMap.keys()]
    .filter((name) => !newUpstreamRecordMap.has(name))
    .sort();
  const changedDifferenceNames = [...newUpstreamRecordMap.keys()]
    .filter((name) => oldUpstreamRecordMap.has(name))
    .sort()
    .filter(
      (name) =>
        canonicalJson(buildDiffComparableRecord(oldUpstreamRecordMap.get(name))) !==
        canonicalJson(buildDiffComparableRecord(newUpstreamRecordMap.get(name))),
    );

  const headUpstreamCommit = readHeadTextLine("third_party/jq-tests/UPSTREAM_COMMIT");
  const currentCommitPath = path.join(repoRoot, "third_party/jq-tests/UPSTREAM_COMMIT");
  const currentUpstreamCommit = existsSync(currentCommitPath)
    ? readFileSync(currentCommitPath, "utf8").trim()
    : "";

  const lines = [];
  lines.push("# jq Compatibility Diff Ledger", "");
  lines.push(`- maintained cases: \`${maintainedCasesRel}\``);
  lines.push(`- upstream cases: \`${upstreamCasesRel}\``);
  lines.push(`- upstream diff snapshot: \`${failureSnapshotRel}\``);
  lines.push(`- upstream commit (HEAD): \`${headUpstreamCommit}\``);
  lines.push(`- upstream commit (current): \`${currentUpstreamCommit}\``);
  lines.push("", "## Corpus Status", "");
  lines.push("| Corpus | Total | Passing | Temporary Exceptions | Broken | Stale Exception Metadata |");
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: |");
  lines.push(
    `| maintained | ${maintainedStatus.total} | ${maintainedStatus.passingCount} | ${maintainedStatus.activeTemporary.length} | ${maintainedStatus.broken.length} | ${maintainedStatus.staleTemporary.length} |`,
  );
  lines.push(
    `| upstream | ${upstreamStatus.total} | ${upstreamStatus.passingCount} | ${upstreamStatus.activeTemporary.length} | ${upstreamStatus.broken.length} | ${upstreamStatus.staleTemporary.length} |`,
  );
  lines.push("");

  addListSection(
    lines,
    "Temporary Exceptions",
    [...maintainedStatus.activeTemporary, ...upstreamStatus.activeTemporary]
      .sort((a, b) => a.corpus.localeCompare(b.corpus) || String(a.case.name).localeCompare(String(b.case.name)))
      .map(
        (item) =>
          `[${item.corpus}] ${String(item.case.name)} (\`${getCompatField(item.case, "compat_ledger_id")}\`): ${getCompatField(item.case, "compat_reason")}. Remove when ${getCompatField(item.case, "compat_removal_condition")}`,
      ),
  );
  addListSection(
    lines,
    "Broken Cases",
    [...maintainedStatus.broken, ...upstreamStatus.broken]
      .sort((a, b) => a.corpus.localeCompare(b.corpus) || String(a.record.name).localeCompare(String(b.record.name)))
      .map((item) => `[${item.corpus}] ${String(item.record.name)} (\`${String(item.record.category)}\`)`),
  );
  addListSection(
    lines,
    "Stale Exception Metadata",
    [...maintainedStatus.staleTemporary, ...upstreamStatus.staleTemporary]
      .sort((a, b) => a.corpus.localeCompare(b.corpus) || String(a.case.name).localeCompare(String(b.case.name)))
      .map(
        (item) =>
          `[${item.corpus}] ${String(item.case.name)} (\`${getCompatField(item.case, "compat_ledger_id")}\`)`,
      ),
  );
  addListSection(lines, "Upstream Drift Summary", [
    `upstream cases old/new: ${oldUpstreamCases.length} -> ${upstreamCases.length}`,
    `upstream cases added/removed/changed: ${addedCaseNames.length} / ${removedCaseNames.length} / ${changedCases.length}`,
    `upstream differences old/new: ${oldUpstreamRecords.length} -> ${upstreamRecords.length}`,
    `upstream differences new/resolved/changed: ${newDifferenceNames.length} / ${resolvedDifferenceNames.length} / ${changedDifferenceNames.length}`,
  ]);
  addListSection(
    lines,
    "New Upstream Differences",
    newDifferenceNames.map(
      (name) => `${name} (\`${String(newUpstreamRecordMap.get(name).category)}\`)`,
    ),
  );
  addListSection(lines, "Resolved Upstream Differences", resolvedDifferenceNames);
  addListSection(
    lines,
    "Upstream Difference Behavior Changes",
    changedDifferenceNames.map((name) => {
      const oldCategory = String(oldUpstreamRecordMap.get(name).category);
      const newCategory = String(newUpstreamRecordMap.get(name).category);
      return `${name} (\`${oldCategory}\` -> \`${newCategory}\`)`;
    }),
  );
  addListSection(
    lines,
    "Upstream Case Behavior Changes",
    changedCases.map((item) => `${item.name}: ${item.changed_fields.join(", ")}`),
  );
  addListSection(lines, "Added Upstream Cases", addedCaseNames);
  addListSection(lines, "Removed Upstream Cases", removedCaseNames);

  const ledgerContent = `${lines.join("\n")}\n`;

  if (options.verify) {
    const existingSnapshotContent = existsSync(failureSnapshotPath)
      ? readFileSync(failureSnapshotPath, "utf8")
      : "";
    if (existingSnapshotContent !== snapshotContent) {
      throw new Error(`upstream diff snapshot is out of date: ${failureSnapshotRel}`);
    }

    const existingLedgerContent = existsSync(ledgerPath)
      ? readFileSync(ledgerPath, "utf8")
      : "";
    if (existingLedgerContent !== ledgerContent) {
      throw new Error(`compatibility ledger is out of date: ${ledgerRel}`);
    }

    console.log(`Verified upstream diff snapshot: ${failureSnapshotPath}`);
    console.log(`Verified compatibility ledger: ${ledgerPath}`);
  } else {
    writeTextFileIfChanged(failureSnapshotPath, snapshotContent);
    writeTextFileIfChanged(ledgerPath, ledgerContent);
    console.log(`Wrote upstream diff snapshot: ${failureSnapshotPath}`);
    console.log(`Wrote compatibility ledger: ${ledgerPath}`);
  }

  console.log(
    `summary maintained_temp=${maintainedStatus.activeTemporary.length} maintained_broken=${maintainedStatus.broken.length} upstream_temp=${upstreamStatus.activeTemporary.length} upstream_broken=${upstreamStatus.broken.length}`,
  );
}

try {
  main();
} catch (error) {
  console.error(
    `[jq-upstream-ledger] ${error instanceof Error ? error.message : String(error)}`,
  );
  usage();
  process.exit(1);
}
