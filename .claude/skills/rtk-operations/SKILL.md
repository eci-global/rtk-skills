---
name: rtk-operations
description: Operate RTK day-to-day after adoption — produce token-savings and ROI reports (rtk gain/discover/session), troubleshoot commands that misbehave under RTK filtering, manage exclusions and the kill switch, and author custom per-repo filters (.rtk/filters.toml) for niche toolchains. Use this skill whenever the user asks about RTK savings, token-reduction metrics or reports, says RTK broke/filtered/ate a command's output, wants to exclude a command from RTK, asks to write or tune an RTK filter, mentions missed savings, or wants to uninstall/disable RTK — and for any "how much are we saving on agent tokens" question.
---

# RTK Operations (ECI Enterprise)

## Purpose — keep this in mind throughout

RTK was adopted to cut AI-agent token spend 60-90% on CLI output. Operations work protects that ROI in both directions: **maximize savings** (find uncovered commands, write filters) and **protect trust** (when a filter hides something an agent needed, fix it fast so teams don't disable RTK wholesale). A disabled RTK saves zero tokens — keeping developers confident in it is part of the cost-reduction mission.

Authoritative docs (verify if anything seems stale):
- Analytics: https://www.rtk-ai.app/docs/analytics/gain/ and /docs/analytics/discover/
- Config: https://www.rtk-ai.app/docs/getting-started/configuration/
- Troubleshooting: https://www.rtk-ai.app/guide/troubleshooting
- Filter DSL: https://github.com/rtk-ai/rtk/blob/master/src/filters/README.md

## Task 0 — Platform setup (if RTK is missing)

| Platform | Install | Config path |
|----------|---------|-------------|
| macOS | `brew install rtk` | `~/Library/Application Support/rtk/config.toml` |
| Linux / WSL | [install.sh](https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh) | `~/.config/rtk/config.toml` |
| Windows (WSL) | install.sh inside WSL | `~/.config/rtk/config.toml` |
| Windows (native) | [GitHub release zip](https://github.com/rtk-ai/rtk/releases) → PATH | `%APPDATA%\rtk\config.toml` |

Verify: `rtk --version` AND `rtk gain`. Preview init: `rtk init -g --agent cursor --dry-run -v`.

**Windows:** WSL = full hook support. Native Windows = filters work but agents must prefix `rtk` explicitly (no auto-rewrite). Full guide: adoption skill `references/windows.md`.

Apply ECI governance defaults from `rtk-adoption/references/governance.md` after install.

## Task 1 — Savings & ROI reporting

```bash
rtk gain                        # headline: commands, input/output tokens, % saved
rtk gain --daily                # day-by-day trend
rtk gain --weekly               # weekly aggregation
rtk gain --graph                # ASCII trend, last 30 days
rtk gain --history              # recent command-level history
rtk gain --all --format json    # machine-readable export for dashboards
```

To turn this into an ROI statement: `tokens_saved × blended input-token price` for the team's model mix. Report both **$ saved** and **context headroom** (saved tokens ≈ longer sessions before compaction/limits — often the bigger productivity win). When asked for a team rollup, collect each machine's `rtk gain --all --format json` and aggregate; RTK has no central server by design.

## Task 2 — Find missed savings

```bash
rtk discover                    # commands that ran WITHOUT rtk in this project
rtk discover --all --since 7    # all projects, last 7 days
rtk session                     # RTK adoption rate per Claude Code session
```

Triage `discover` output by `frequency × output size`. Remedies, in order:
1. Built-in filter exists but hook missed it → check hook health (`rtk init --show`, restart agent).
2. No built-in filter, generic shape → wrap: `rtk test <cmd>` (failures only), `rtk err <cmd>` (errors only), `rtk summary <cmd>` (heuristic summary), `rtk proxy <cmd>` (passthrough + tracking).
3. No built-in filter, recurring + high-volume → write a custom filter (Task 4).

## Task 3 — Troubleshoot "RTK broke / hid something"

Work this ladder top-down; prefer the least-destructive fix:

| Symptom | Fix |
|---|---|
| Agent missing detail after a **failed** command | Read the tee file path printed in output (Linux/macOS/WSL: `~/.local/share/rtk/tee/`; Windows: `%LOCALAPPDATA%\rtk\tee\`). No re-run needed. |
| One command needs raw output **once** | `RTK_DISABLED=1 <command>` |
| A command class repeatedly misbehaves (interactive, stateful) | Add to `[hooks] exclude_commands` in config.toml (prefix match; `^pattern` = regex) |
| A built-in filter is too aggressive for **this repo** | Override it in the repo's `.rtk/filters.toml` (Task 4) |
| Suspected RTK-caused agent failure, need isolation | `rtk init --uninstall`, restart agent, reproduce. Re-enable after diagnosis — report findings so the filter gets fixed rather than RTK abandoned |
| Need an audit trail of what the hook rewrote | `RTK_HOOK_AUDIT=1` |
| Native Windows: no automatic filtering | Expected — use WSL for hooks, or ensure rules/skills tell agent to prefix `rtk` on every command |

Remember the structural limits before blaming a filter: the hook only covers **shell/Bash tool calls** — built-in Read/Grep/Glob and MCP tool outputs never pass through RTK. On native Windows, hooks do not auto-rewrite at all.

## Task 4 — Author custom per-repo filters

Custom filters exist at two scopes — mirror the adoption scopes:
- **Global**: `~/.config/rtk/filters.toml` (template created by `rtk init`) — personal/machine-wide tweaks.
- **Repo**: `.rtk/filters.toml` at the repo root, **committed to version control** — the ECI-preferred scope, because behavior travels with the code to every developer and CI runner.

This is the highest-leverage operation at ECI: niche toolchains (BBj/MarkSystems build and test output, proprietary CLIs) have no built-in coverage, so their savings are 0% until a filter exists.

Process:
1. **Fetch the authoritative DSL reference first** — https://github.com/rtk-ai/rtk/blob/master/src/filters/README.md — and follow its current syntax exactly. The DSL evolves between versions; do not write filter TOML from memory.
2. Capture 2-3 **real raw output samples** of the target command (success + failure cases).
3. Decide what the *agent* actually needs from that output (usually: what changed, what failed, where). Everything else is filterable noise.
4. Write the filter, then validate by running the command through rtk and comparing: signal preserved? failure detail still identifiable (or recoverable via tee)?
5. Commit `.rtk/filters.toml` with a short comment naming the command, expected savings, and the samples used.

Safety rule for filters: when in doubt, keep failure-path information and cut success-path verbosity. A filter that hides a passing test costs nothing; a filter that hides a failing assertion costs trust.

## Task 5 — Version upgrades

Pin versions fleet-wide. Before bumping: upgrade on one pilot repo, run `rtk gain --daily` for a few days, scan team channels for "RTK ate my output" reports, then roll out. Filters change between releases — treat upgrades like dependency upgrades, not auto-updates.
