#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { cpSync, existsSync, readdirSync, rmSync } from "node:fs";
import path from "node:path";

const entryPoints = process.argv.slice(2);

if (entryPoints.length === 0) {
  console.error("Usage: node ../../scripts/ts_package_build.mjs <entry> [entry...]");
  process.exit(2);
}

const packageDir = process.cwd();
const distDir = path.join(packageDir, "dist");
const binExt = process.platform === "win32" ? ".cmd" : "";
let repairedInstall = false;

function binPath(name) {
  const candidate = path.join(packageDir, "node_modules", ".bin", `${name}${binExt}`);
  if (!existsSync(candidate) && !repairedInstall) {
    repairedInstall = true;
    console.warn(
      `[ts-package-build] Missing ${path.basename(candidate)}; running pnpm install --frozen-lockfile to repair local package tools.`,
    );
    run("pnpm", ["install", "--frozen-lockfile"]);
  }
  if (!existsSync(candidate)) {
    throw new Error(
      `Missing ${path.basename(candidate)}. Reinstall package dependencies for this checkout before building package artifacts.`,
    );
  }
  return candidate;
}

function run(command, args) {
  console.log(`$ ${path.basename(command)} ${args.join(" ")}`);
  const sharedOptions = {
    cwd: packageDir,
    env: {
      ...process.env,
      CI: process.env.CI ?? "true",
    },
    stdio: "inherit",
  };
  const result =
    process.platform === "win32"
      ? spawnSync(process.env.ComSpec ?? "cmd.exe", [
          "/d",
          "/s",
          "/c",
          `${command} ${args.join(" ")}`,
        ], sharedOptions)
      : spawnSync(command, args, sharedOptions);

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`Command failed: ${path.basename(command)} ${args.join(" ")}`);
  }
}

function syncDcts(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      syncDcts(fullPath);
      continue;
    }
    if (!entry.name.endsWith(".d.ts")) {
      continue;
    }
    cpSync(fullPath, fullPath.slice(0, -".d.ts".length) + ".d.cts");
  }
}

try {
  rmSync(distDir, { recursive: true, force: true });

  const sharedArgs = [
    ...entryPoints,
    "--bundle",
    "--platform=node",
    "--target=es2022",
    "--packages=external",
    "--outbase=src",
    "--outdir=dist",
  ];

  run(binPath("esbuild"), [...sharedArgs, "--format=esm"]);
  run(binPath("esbuild"), [
    ...sharedArgs,
    "--format=cjs",
    "--out-extension:.js=.cjs",
  ]);
  run(binPath("tsgo"), [
    "-p",
    "tsconfig.build.json",
    "--emitDeclarationOnly",
    "--declaration",
    "--rootDir",
    "src",
    "--declarationDir",
    "dist",
  ]);

  syncDcts(distDir);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[ts-package-build] ${message}`);
  process.exit(1);
}
