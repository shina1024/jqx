#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

const packageDirs = [
  "ts/adapter-core",
  "ts/zod-adapter",
  "ts/yup-adapter",
  "ts/valibot-adapter",
  "ts/jqx",
];

const actions = new Set(["list", "refresh", "verify"]);

function usage() {
  console.error(
    "Usage: node scripts/ts_packages.mjs <list|refresh|verify> [--frozen-lockfile]",
  );
}

function loadPackageInfo(relPath) {
  const packageJsonPath = path.join(repoRoot, relPath, "package.json");
  const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"));
  return {
    relPath,
    cwd: path.join(repoRoot, relPath),
    name: packageJson.name,
    scripts: packageJson.scripts ?? {},
  };
}

function ensureScript(packageInfo, scriptName) {
  if (typeof packageInfo.scripts[scriptName] !== "string") {
    throw new Error(
      `Missing expected script "${scriptName}" in ${packageInfo.relPath}/package.json`,
    );
  }
}

function groupStart(label) {
  if (process.env.GITHUB_ACTIONS === "true") {
    console.log(`::group::${label}`);
    return;
  }
  console.log(`\n[${label}]`);
}

function groupEnd() {
  if (process.env.GITHUB_ACTIONS === "true") {
    console.log("::endgroup::");
  }
}

function runPnpm(packageInfo, args) {
  const executable = process.platform === "win32" ? "pnpm.cmd" : "pnpm";
  console.log(`$ ${executable} ${args.join(" ")}`);
  const result = spawnSync(executable, args, {
    cwd: packageInfo.cwd,
    env: {
      ...process.env,
      CI: process.env.CI ?? "true",
    },
    stdio: "inherit",
  });

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(
      `Command failed in ${packageInfo.relPath}: ${executable} ${args.join(" ")}`,
    );
  }
}

function installArgs(frozenLockfile) {
  return frozenLockfile ? ["install", "--frozen-lockfile"] : ["install"];
}

function refreshPackage(packageInfo, frozenLockfile) {
  ensureScript(packageInfo, "build");
  runPnpm(packageInfo, installArgs(frozenLockfile));
  runPnpm(packageInfo, ["build"]);
}

function verifyPackage(packageInfo, frozenLockfile) {
  ensureScript(packageInfo, "lint");
  ensureScript(packageInfo, "typecheck");
  ensureScript(packageInfo, "build");

  runPnpm(packageInfo, installArgs(frozenLockfile));
  runPnpm(packageInfo, ["lint"]);
  runPnpm(packageInfo, ["typecheck"]);
  if (typeof packageInfo.scripts.test === "string") {
    runPnpm(packageInfo, ["test"]);
  }
  runPnpm(packageInfo, ["build"]);
}

function main() {
  const [action, ...rest] = process.argv.slice(2);
  if (!action || !actions.has(action)) {
    usage();
    process.exit(2);
  }

  const frozenLockfile = rest.includes("--frozen-lockfile");
  const unknownArgs = rest.filter((arg) => arg !== "--frozen-lockfile");
  if (unknownArgs.length > 0) {
    console.error(`Unknown arguments: ${unknownArgs.join(" ")}`);
    usage();
    process.exit(2);
  }

  if (action === "list") {
    for (const relPath of packageDirs) {
      console.log(relPath);
    }
    return;
  }

  const packages = packageDirs.map(loadPackageInfo);
  for (const packageInfo of packages) {
    groupStart(`${action}: ${packageInfo.relPath} (${packageInfo.name})`);
    try {
      if (action === "refresh") {
        refreshPackage(packageInfo, frozenLockfile);
      } else {
        verifyPackage(packageInfo, frozenLockfile);
      }
    } finally {
      groupEnd();
    }
  }
}

try {
  main();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[ts-packages] ${message}`);
  process.exit(1);
}
