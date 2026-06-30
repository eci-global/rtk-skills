# AGENTS.md — rtk-skills (ECI distribution toolkit)

Guidance for AI coding agents (Cursor, Codex, generic) working **in this repo**.
Claude Code reads the parallel [`CLAUDE.md`](CLAUDE.md). Pinned RTK version: **0.43.0** (see [`RTK_VERSION`](RTK_VERSION)).

## What this repo is

This is the source-of-truth toolkit ECI uses to roll out [RTK (Rust Token Killer)](https://www.rtk-ai.app/) — skills, Cursor rules, adoption scripts, and dogfood filters that cut AI-agent token use 60–90% on CLI output. It is a *distribution* repo: most files here are copied into product repos or `~/.claude/`.

## Repo map

| Path | What | Edit when |
| --- | --- | --- |
| `.claude/skills/rtk-{adoption,operations,audit}/SKILL.md` | Claude Code skills | RTK behavior or guidance changes |
| `cursor-rtk/.cursor/rules/{rtk,rtk-operations}.mdc` | Cursor rules (parity with the skills) | Always edit alongside the matching skill |
| `.rtk/filters.toml` | This repo's own dogfood filters (0.43.x schema) | New niche CLI in this repo's workflow |
| `examples/filters.toml`, `examples/snippets/` | Starter filter + drop-in AGENTS.md/CLAUDE.md blocks | Schema or guidance changes |
| `scripts/` | `adopt.sh` / `adopt.ps1` (engineer bootstrap) + `validate.sh` / `check-parity.sh` / `check-links.sh` (gates) | Adoption flow or gate changes |
| `RTK_VERSION` | Single source of truth for the pinned version | Bumping RTK (triggers the CI `full` job) |
| `dist/*.skill` | Generated portable zips | Never hand-edit — run `scripts/pack-skills.sh` |

## Keep artifacts in sync (the #1 rule)

A Claude skill and its Cursor rule must agree on RTK facts. When you change one, change its pair and re-run the gates:

```bash
./scripts/validate.sh        # structure + artifacts (no RTK needed)
./scripts/check-parity.sh    # Claude skills ↔ Cursor rules agree (init flags, paths, bypass, schema)
./scripts/check-links.sh     # http(s) links resolve
./scripts/pack-skills.sh     # rebuild dist/ after editing any SKILL.md
```

`check-parity.sh` fails the build if the skill/rule pair drifts or a filter regresses to the legacy `[[filter]]` schema — keep filters on `[filters.<name>]`.

## RTK in this repo

This repo commits `.rtk/filters.toml`, so after cloning run **`rtk trust`** once (0.43.x security gate) to honor the project-local filters.

```bash
# Setup once per machine (see README.md for all platforms)
brew install rtk                          # macOS  (Linux/WSL: install.sh, pin RTK_VERSION=v0.43.0)
rtk --version && rtk gain                 # confirm the RIGHT package (not the crates.io collision)
rtk init -g --agent cursor                # Cursor  ·  rtk init --global for Claude Code
```

- With the hook installed, run commands normally — output is rewritten transparently.
- Read/Grep/Glob and MCP outputs **bypass** RTK (hook covers shell/Bash only); prefer shell `rg`/`cat`/`find` or `rtk read`/`rtk grep`/`rtk find`.
- Need raw output once: `RTK_DISABLED=1 <cmd>`. Never uninstall RTK to work around a single command.
- Governance: telemetry off (`[telemetry] enabled = false` + `export RTK_TELEMETRY_DISABLED=1`).
