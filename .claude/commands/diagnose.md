---
description: RTK live troubleshooting — check install, hooks, version, savings, and wrong-package; suggest fixes
---

# /diagnose

Live RTK environment diagnostic for "RTK broken / no savings / command not rewritten." Run mid-session when something feels off. It **complements** the `rtk-audit` skill: audit produces a comparable *baseline report*; diagnose is the *interactive troubleshooting* sibling that ends with a single suggested fix.

Aligned to RTK 0.43.x + ECI governance (telemetry off). The hook in 0.43.x is a **native binary** registered by `rtk init` (not a `.claude/hooks/rtk-rewrite.sh` file) — so check `rtk init --show`, not the filesystem.

## When to use

- **Auto-suggest** when these patterns appear in the session:
  - `rtk: command not found` → not installed or not on PATH
  - `Failed to initialize tracking database` → read-only DB (sandbox) or wrong package
  - `rtk gain` fails but `rtk --version` works → wrong crates.io `rtk` ("Rust Type Kit")
  - `untrusted project filters skipped` → `.rtk/filters.toml` edited but not re-trusted
  - Commands run unrewritten → hook not installed for the agent in use, or Read/Grep/Glob bypass (expected)
- **Manually** after install, an RTK version bump, or suspicious behavior.

## Run these checks

Capture stdout AND stderr on each; do not let one failure abort the rest.

```bash
# 1. Binary + correct package (the #1 failure: wrong rtk)
command -v rtk && rtk --version || echo "MISSING: rtk not on PATH"
rtk gain >/dev/null 2>&1 && echo "OK: correct package (rtk gain works)" \
  || echo "FAIL: wrong package — crates.io 'Rust Type Kit' is installed"

# 2. Hook status for the agent in use (0.43.x native binary hook)
rtk init --show 2>&1 | grep -E '\[ok\] Hook:|\[ok\] Cursor hook:|\[--\]|warn|err'

# 3. Savings flowing
rtk gain 2>&1 | head -12

# 4. Missed savings (commands running WITHOUT rtk)
rtk discover --limit 5 2>&1

# 5. Filter integrity + project trust
rtk verify 2>&1 | tail -4

# 6. Project filters trusted? (0.43.x security gate)
rtk trust --list 2>&1 | grep "$(pwd -P)" && echo "OK: this repo is trusted" \
  || echo "MISSING: run 'rtk trust' in this repo"
```

Platform: `uname -s`. On native Windows, no auto-rewrite hook is expected (rules-only mode) — that is not a failure.

## Output format

```
RTK diagnostic
  Binary:        OK (rtk 0.43.0) | MISSING | WRONG PACKAGE
  Hook:          OK (Claude + Cursor) | MISSING for <agent>
  Savings:       OK (N% / Nk tokens) | ZERO | rtk gain failed
  Discover:      top misses: <cmd> xN, ...
  Verify:        PASS (N/N tests) | FAIL
  Project trust: OK | run 'rtk trust'
```

## Suggested fix (pick one, highest applicable)

1. **`rtk` not on PATH or not installed** → `brew install rtk` (macOS) or
   `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | RTK_VERSION=v0.43.0 sh` (Linux/WSL).
   Ensure `~/.local/bin` (Linux/WSL) or Homebrew prefix is on PATH.
2. **Wrong package** (`rtk --version` works but `rtk gain` fails) → uninstall the crates.io
   "Rust Type Kit": `cargo uninstall rtk`, then reinstall from Homebrew or GitHub releases. Verify with `rtk --version && rtk gain`.
3. **Hook missing for the agent in use** → `rtk init --global` (Claude Code) or
   `rtk init -g --agent cursor` (Cursor), then **restart the AI tool**. Re-check `rtk init --show` for `[ok]`.
4. **`rtk gain` fails with "Failed to initialize tracking database"** → usually a read-only DB
   (sandbox/locked filesystem). Re-run outside the sandbox; if it persists, check the config path is writable:
   macOS `~/Library/Application Support/rtk/`, Linux/WSL `~/.config/rtk/`, Windows `%APPDATA%\rtk\`.
5. **`untrusted project filters skipped`** → run `rtk trust` in the repo (0.43.x security gate).
   Editing `.rtk/filters.toml` invalidates trust; re-trust after every edit.
6. **Commands run unrewritten but hook is `[ok]`** → expected for built-in Read/Grep/Glob and MCP
   outputs (hook covers shell/Bash only). Prefer shell `rg`/`cat`/`find` or `rtk read`/`rtk grep`/`rtk find`.
7. **Zero savings, hook `[ok]`** → run a few real commands in a fresh session, then re-check `rtk gain`;
   inspect `rtk discover` for unrewritten commands and `rtk session` for adoption rate.

Use `AskUserQuestion` to offer the applicable fix(es) as multi-select when more than one is relevant.
