#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";

const args = process.argv.slice(2);

if (args.length === 0) {
  console.error("Usage: node scripts/moon_exec.mjs <moon-args...>");
  process.exit(2);
}

const candidates = [];
if (typeof process.env.MOON_BIN === "string" && process.env.MOON_BIN !== "") {
  candidates.push(process.env.MOON_BIN);
}
candidates.push("moon");
if (process.platform === "win32") {
  candidates.push("moon.exe");
}
const homeDirs = new Set([os.homedir()]);
if (process.platform === "win32") {
  if (process.env.USERPROFILE) {
    homeDirs.add(process.env.USERPROFILE);
  }
  if (process.env.HOMEDRIVE && process.env.HOMEPATH) {
    homeDirs.add(`${process.env.HOMEDRIVE}${process.env.HOMEPATH}`);
  }
  const username = process.env.USERNAME ?? process.env.USER;
  if (username) {
    homeDirs.add(path.win32.join(process.env.SystemDrive ?? "C:", "Users", username));
  }
} else {
  const username = process.env.USERNAME ?? process.env.USER;
  if (username) {
    homeDirs.add(path.posix.join("/mnt/c/Users", username));
  }
}
for (const homeDir of homeDirs) {
  const moonHome = path.join(homeDir, ".moon", "bin");
  for (const fallback of [
    path.join(moonHome, "moon"),
    path.join(moonHome, "moon.exe"),
  ]) {
    if (existsSync(fallback)) {
      candidates.push(fallback);
    }
  }
}

for (const executable of new Set(candidates)) {
  const result = spawnSync(executable, args, {
    env: process.env,
    stdio: "inherit",
  });

  if (result.error) {
    if (result.error.code === "ENOENT") {
      continue;
    }
    console.error(
      `[moon-exec] Failed to start ${executable}: ${result.error.message}`,
    );
    process.exit(1);
  }

  if (result.status === null) {
    console.error(
      `[moon-exec] ${executable} exited without a status code${result.signal ? ` (signal: ${result.signal})` : ""}.`,
    );
    process.exit(1);
  }

  process.exit(result.status);
}

console.error(
  process.env.MOON_BIN
    ? `[moon-exec] Could not find MoonBit executable. MOON_BIN=${process.env.MOON_BIN}`
    : "[moon-exec] Could not find MoonBit executable. Ensure `moon` is on PATH or set MOON_BIN.",
);
process.exit(1);
