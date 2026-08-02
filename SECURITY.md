# Security Policy

## Reporting a vulnerability

simshot is a developer tool that only talks to local Apple tooling
(`xcodebuild`, `simctl`). It does not make network requests and holds no
credentials, but we still take security seriously.

Please **do not open a public issue** for security problems. Instead, report
them privately:

- **GitHub Private Vulnerability Reporting** (preferred):
  https://github.com/kichiemon/simshot/security/advisories/new

You can expect:

1. An acknowledgement within 3 business days.
2. A fix and a coordinated disclosure plan.

## Supported versions

Security fixes are backported to the latest minor release when practical.

| Version | Supported |
|---|---|
| latest (0.1.x) | ✅ |
| older | ❌ |

## Scope

Things we consider in scope:

- Malicious input that leads to command injection or arbitrary file access
  through simshot's arguments or config files.
- A hang or unbounded resource use when processing untrusted input.

Out of scope:

- Vulnerabilities in Xcode or the iOS Simulator itself.
- Social engineering against users of the project.

## Security notes

- simshot passes all user-provided values to `Process` as an **argument array**
  (never through a shell), which prevents shell injection.
- Every external command runs with a hard timeout, so a stuck process cannot
  stall a CI job indefinitely.
- If you review the code and find something suspicious, use the reporting
  channel above — we'd rather over-report than miss something.
