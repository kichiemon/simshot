"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const crypto = require("crypto");
const https = require("https");

const REPO = "kichiemon/simshot";
const VERSION = "v" + require("./package.json").version;
const BIN_NAME = "simshot";

const ARCH_MAP = {
  arm64: "arm64",
  x64: "x86_64",
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

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
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
      `unsupported architecture "${process.arch}". simshot only ships arm64/x86_64 binaries; install via \`brew install simshot\` or build from source instead.`
    );
  }

  const binDir = path.join(__dirname, "bin");
  const binPath = path.join(binDir, BIN_NAME);
  const binaryUrl = `https://github.com/${REPO}/releases/download/${VERSION}/simshot-macos-${arch}`;
  const checksumUrl = `${binaryUrl}.sha256`;

  if (fs.existsSync(binPath)) {
    console.log(`[simshot] binary already present at ${binPath}`);
    return;
  }

  // Unique, 0700 temp dir: no predictable paths, so another user cannot plant
  // a symlink or a file that we would follow or overwrite.
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "simshot-install-"));
  const tmpBinary = path.join(tmpDir, BIN_NAME);
  try {
    const [binary, checksumText] = await Promise.all([
      download(binaryUrl),
      download(checksumUrl),
    ]);

    const expected = checksumText
      .toString("utf8")
      .trim()
      .split(/\s+/)[0]
      .toLowerCase();
    if (!/^[0-9a-f]{64}$/.test(expected)) {
      fail(
        `invalid sha256 checksum file at ${checksumUrl}:\n${checksumText}. ` +
          "Refusing to install from an unverifiable release."
      );
    }
    const actual = sha256(binary);
    if (actual !== expected) {
      fail(
        `sha256 checksum mismatch for ${binaryUrl}:\n  expected ${expected}\n  actual   ${actual}. ` +
          "Refusing to install a tampered or corrupted binary."
      );
    }
    console.log(`[simshot] verified sha256 ${expected}`);

    fs.writeFileSync(tmpBinary, binary);

    fs.mkdirSync(binDir, { recursive: true });
    fs.copyFileSync(tmpBinary, binPath);

    fs.chmodSync(binPath, 0o755);
    console.log(
      `[simshot] installed ${BIN_NAME} ${VERSION} (${arch}) at ${binPath}`
    );
  } catch (err) {
    fail(
      `failed to download ${binaryUrl}: ${err.message}. ` +
        "Check the release exists, or install via `brew install simshot` / build from source."
    );
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

main();
