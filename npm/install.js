"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const https = require("https");

const REPO = "kichiemon/simshot";
const VERSION = "v0.1.0";
const BIN_NAME = "simshot";

const ARCH_MAP = {
  arm64: "arm64",
  x64: "x64",
};

function fail(message) {
  console.error(`[simshot] ${message}`);
  process.exit(1);
}

function download(url) {
  return new Promise((resolve, reject) => {
    const get = (target) => {
      https
        .get(target, (res) => {
          if (
            res.statusCode >= 300 &&
            res.statusCode < 400 &&
            res.headers.location
          ) {
            res.resume();
            get(res.headers.location);
            return;
          }
          if (res.statusCode !== 200) {
            res.resume();
            reject(new Error(`HTTP ${res.statusCode} for ${target}`));
            return;
          }
          const chunks = [];
          res.on("data", (chunk) => chunks.push(chunk));
          res.on("end", () => resolve(Buffer.concat(chunks)));
        })
        .on("error", reject);
    };
    get(url);
  });
}

async function main() {
  if (process.platform !== "darwin") {
    fail(
      `unsupported platform "${process.platform}". simshot only ships macOS binaries; install via \`brew install simshot\` or build from source instead.`
    );
  }
  const arch = ARCH_MAP[process.arch];
  if (!arch) {
    fail(
      `unsupported architecture "${process.arch}". simshot only ships arm64/x64 binaries; install via \`brew install simshot\` or build from source instead.`
    );
  }

  const binDir = path.join(__dirname, "bin");
  const binPath = path.join(binDir, BIN_NAME);
  const tarballUrl = `https://github.com/${REPO}/releases/download/${VERSION}/simshot-macos-${arch}.tar.gz`;

  if (fs.existsSync(binPath)) {
    console.log(`[simshot] binary already present at ${binPath}`);
    return;
  }

  try {
    const tmp = path.join(os.tmpdir(), `simshot-${VERSION}-${arch}.tar.gz`);
    const tarball = await download(tarballUrl);
    fs.writeFileSync(tmp, tarball);

    fs.mkdirSync(binDir, { recursive: true });
    execFileSync("tar", ["-xzf", tmp, "-C", binDir], { stdio: "inherit" });
    fs.rmSync(tmp, { force: true });

    if (!fs.existsSync(binPath)) {
      fail(`tarball did not contain expected binary at ${binPath}`);
    }
    fs.chmodSync(binPath, 0o755);
    console.log(`[simshot] installed ${BIN_NAME} ${VERSION} (${arch}) at ${binPath}`);
  } catch (err) {
    fail(
      `failed to download ${tarballUrl}: ${err.message}. ` +
        "Check the release exists, or install via `brew install simshot` / build from source."
    );
  }
}

main();
