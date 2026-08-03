# AI Agents

simshot is installable as a reusable **agent skill**, so skill-aware assistants can capture App Store screenshots for you automatically — you just ask, and the agent assembles and runs `simshot shoot`.

```bash
npx skills add kichiemon/simshot
```

Once installed, skill-aware agents (Claude Code, opencode, and others) pick it up automatically. Just ask for "App Store screenshots" and the agent will run `simshot shoot` for you.

## Target a specific agent

The skill is kept in sync across three locations so all skill-aware agents get identical instructions:

| Agent | Install | Location |
|---|---|---|
| Claude Code | `npx skills add kichiemon/simshot` | `.claude/skills/` |
| opencode | `npx skills add kichiemon/simshot` | `.agents/skills/` (auto) |
| OpenAI Codex | `npx skills add kichiemon/simshot -a codex` | `.agents/skills/` |

For **OpenAI Codex**, use the explicit flag:

```bash
npx skills add kichiemon/simshot -a codex
```

This installs the skill into `.agents/skills/` (Codex's project skill directory). The skill is mirrored across `skills/simshot/SKILL.md` (canonical), `.claude/skills/simshot/SKILL.md`, and `.agents/skills/simshot/SKILL.md` — all identical.

## What the skill teaches agents

- Which commands to run: `simshot doctor` / `simshot devices` / `simshot shoot` / `simshot init`.
- How to build the shot matrix (`--devices`, `--langs`, `--scenes` / `--shots`).
- The [scene launch-argument protocol](./scene-protocol) your app must implement.
- How to handle common failures (black screens, hangs, unknown devices).

See the [Quick Start](./quickstart) to get a capture running with your own app.
