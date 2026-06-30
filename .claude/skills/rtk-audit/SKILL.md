---
name: rtk-audit
description: Run a structured RTK adoption audit on a developer machine or repo — checks hook status (rtk init --show), token savings (rtk gain), missed savings (rtk discover), session adoption (rtk session), and hook/filter integrity (rtk verify), then emits a fixed-section markdown report with a single recommended fix. Use when onboarding a pilot machine, diagnosing "RTK isn't saving tokens" or "no savings on Cursor/Claude", producing a baseline before fleet rollout, comparing adoption across machines, or running the post-ship pilot audit. Pairs with rtk-adoption (setup) and rtk-operations (day-2 work). Aligned to RTK 0.42.x.
---

# RTK Audit (ECI Enterprise)

## Purpose — keep this in mind throughout

Before rolling RTK out fleet-wide, ECI needs comparable, per-machine evidence of what is actually happening: is the hook installed? are savings flowing? what is being missed? **Audit-first** (AHA decision 1D) means we gather that evidence *before* rewriting guidance or forcing init. A consistent report across 5–10 pilot machines is what justifies rollout. Every step below serves a comparable, honest diagnosis — not a sales pitch. A pilot that reports zero savings is a *successful* audit if it pinpoints the missing hook.

Authoritative docs (RTK 0.42.x — verify if anything seems stale):
- Docs: https://www.rtk-ai.app/docs/ · Analytics: /docs/analytics/gain/ , /docs/analytics/discover/
- Repo: https://github.com/rtk-ai/rtk · Filter DSL: https://github.com/rtk-ai/rtk/blob/master/src/filters/README.md

RTK version pinned by this toolkit: see `RTK_VERSION` at the repo root (currently 0.42.4).

## Commands this audit uses (RTK 0.42.x)

There is **no `rtk doctor`** — do not invent one. Use these:

| Command | What it tells you |
|---|---|
| `rtk init --show` | Hook + RTK.md + settings.json status per agent; `[ok]` / `[--]` / `[warn]` / `[err]` markers |
| `rtk gain` | Headline token savings: commands, input/output tokens, % saved |
| `rtk discover` | Commands that ran WITHOUT rtk = missed savings (top N via `--limit`) |
| `rtk session` | RTK adoption rate per Claude Code session |
| `rtk verify` | Hook integrity + TOML filter inline tests (`PASS`/`FAIL` + `N/N tests passed`) |
| `rtk learn` (optional) | Recurring CLI corrections from error history → fix candidates |

Optional machine-readable export for fleet rollup: `rtk gain --all --format json`.

## Step 1 — Capture machine context

Record once at the top so pilot machines are comparable:
- `date -u` — audit timestamp (UTC)
- `rtk --version` — must be `rtk 0.42.x`; if `rtk gain` fails, the wrong crates.io `rtk` ("Rust Type Kit") is installed
- `uname -s` — platform; **native Windows has no auto-rewrite hook — this is expected, not a failure**
- agent in use (Claude Code / Cursor) and whether the tool was restarted after init

If `rtk --version` is missing or `rtk gain` errors (e.g. "Failed to initialize tracking database"), **still produce the report** — record the error verbatim and proceed. "RTK not installed" is a valid audit outcome.

## Step 2 — Run the five probes

Capture stdout AND stderr (some probes print status to stderr). Do not let one failure abort the others — record a non-zero exit, do not crash.

```bash
rtk init --show 2>&1            # hook status (source of truth: [ok]/[--] markers)
rtk gain 2>&1                   # savings (may be 0 if hook missing — that is the finding)
rtk discover --limit 5 2>&1     # top 5 missed-savings commands (current project, last 30d)
rtk session 2>&1                # session adoption rate
rtk verify 2>&1                 # hook integrity + filter inline tests
# optional enrichment:
rtk learn 2>&1                  # CLI correction candidates from error history
rtk gain --all --format json 2>&1   # machine-readable export for fleet rollup
```

Cursor users: read the `Cursor hook:` line specifically — a Claude hook being `[ok]` does **not** mean Cursor is covered (decision 2C: Cursor + Claude Code equal).

## Step 3 — Emit the fixed-section report

Output **exactly these sections, in this order**, as markdown. Same headings on every machine — comparability is the whole point. Date the header.

```markdown
## RTK audit — <YYYY-MM-DD>

### Machine
rtk: <version> | os: <platform> | agent: <claude|cursor> | restarted: <yes|no|?>

### Hook status
[ok] Claude hook | [--] Cursor hook not found
[ok] settings.json | [--] RTK.md missing

### Gain snapshot
commands: <N> | input saved: <tokens> | output saved: <tokens> | saved: <N>%

### Discover top 5 misses
1. <command> — <freq>× (~<tokens> missed)
2. …
(none — hook may be missing)

### Session adoption
sessions: <N> | rtk adoption: <N>% | non-rtk sessions: <N>

### Verify
hook integrity: <PASS|FAIL> | filter tests: <N/N passed>

### Recommended fix
<ONE actionable fix from the ladder below, stated as a runnable command>
```

## Step 4 — Choose the single recommended fix

Pick **exactly one** from this ladder (highest applicable):

1. **RTK not installed / wrong package** → `brew install rtk` (macOS) or `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | RTK_VERSION=v0.42.4 sh` (Linux/WSL). Verify with `rtk --version && rtk gain`.
2. **Hook missing for the agent in use** → `rtk init -g --agent cursor` (Cursor) or `rtk init --global` (Claude Code), then **restart the AI tool**. Re-run `rtk init --show` to confirm `[ok]`.
3. **Hook present, savings still 0** → run a few commands in a fresh agent session, re-check `rtk gain`; if still 0, inspect `rtk discover` (unrewritten commands) and `rtk session` (adoption rate).
4. **Built-in filter misses a recurring command** → wrap with `rtk err <cmd>` / `rtk summary <cmd>` / `rtk proxy <cmd>`, or author a `.rtk/filters.toml` filter (see `rtk-operations`).
5. **Project-local filters not applying** → after cloning or committing `.rtk/filters.toml`, run `rtk trust` in the repo (0.42.x security gate) so project filters are honored.
6. **Read/Grep/Glob bypassing RTK** → expected: the hook covers shell/Bash only. Prefer shell `rg` / `cat` / `find` or `rtk read` / `rtk grep` / `rtk find` in skills and prompts (see bypass guidance in `rtk-adoption` / `rtk-operations`).

If multiple apply, pick the one highest on the ladder — fixing a missing hook subsumes filter work.

## Step 5 — (Optional) fleet rollup

For the post-ship pilot (5–10 machines), also capture `rtk gain --all --format json` and aggregate. RTK has no central server by design; this audit is the collection mechanism. Hand the rollup to `/aha debrief` with the `return_packet`.

## Comparability rules

- Same five probes, same order, same headings on every machine.
- Capture stderr too; record errors verbatim rather than paraphrasing.
- Never abort the whole audit on one probe's failure — a partial report with a recorded error beats no report.
- Native Windows `[--] Cursor hook` / no auto-rewrite is **expected** — note "native Windows: rules-only mode" in Recommended fix rather than treating it as broken.
