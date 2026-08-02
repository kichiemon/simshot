#!/usr/bin/env node
"use strict";

const { spawnSync } = require("child_process");
const path = require("path");

const binPath = path.join(__dirname, "bin", "simshot");

const result = spawnSync(binPath, process.argv.slice(2), { stdio: "inherit" });

if (result.error) {
  console.error(`[simshot] failed to run binary at ${binPath}: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
