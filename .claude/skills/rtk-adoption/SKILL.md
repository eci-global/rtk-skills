---
name: rtk-adoption
description: Install, initialize, and verify RTK (Rust Token Killer) on a developer machine or repository to cut AI-agent token consumption by 60-90% on CLI command output, following ECI enterprise governance defaults. Use this skill whenever the user wants to set up RTK, adopt or roll out RTK globally or for a repo, "enable token savings", "reduce agent token usage / token costs", onboard a new repo or machine to the token-reduction toolchain, or asks how to install RTK for Claude Code or Cursor — even if they don't say "RTK" but describe cutting LLM/API token costs on dev commands.
---

# RTK Adoption (ECI Enterprise)

## Purpose — keep this in mind throughout

RTK exists for one reason at ECI: **AI coding agents burn most of their tokens reading CLI output, not reasoning.** A 30-minute Claude Code session can spend ~118K tokens on git/test/lint output alone; RTK filters that to ~24K (≈80% saved) before it reaches the model. Every step below serves that goal: lower API cost, longer sessions before context limits, more context budget for actual reasoning. When making judgment calls during setup, optimize for *measurable token reduction with zero workflow disruption*.

Authoritative docs (verify against these if anything below seems outdated — RTK moves fast):
- Docs: https://www.rtk-ai.app/docs/
- Repo: https://github.com/rtk-ai/rtk
- Troubleshooting: https://www.rtk-ai.app/guide/troubleshooting
- Filter DSL (0.42.x schema): https://github.com/rtk-ai/rtk/blob/master/src/filters/README.md

This toolkit pins an RTK version — see `RTK_VERSION` at the repo root (currently 0.42.4). For a structured before/after diagnosis across pilot machines, run the companion `rtk-audit` skill (audit-first is the ECI rollout order).

## Step 0 — Detect the situation

Run these checks before changing anything:

```bash
rtk --version 2>/dev/null      # installed? (expect "rtk X.Y.Z")
rtk gain 2>/dev/null            # right package? (a crates.io name-collision
                                #   project "Rust Type Kit" also installs as `rtk`;
                                #   if gain fails, the wrong rtk is installed)
rtk init --show 2>/dev/null     # hook already installed?
uname -s                        # platform (Windows native has limits — see below)
```

Then determine two things from the user/context:
1. **Agent**: Claude Code (ECI default) or Cursor.
2. **Scope**: global (all projects on this machine) or repo (this project only). If unclear, ask — default recommendation at ECI is **global init per machine + repo-level config committed to each repo** (see `references/governance.md`).

## Step 1 — Install (if missing)

```bash
# macOS
brew install rtk

# Linux / WSL (recommended for Windows developers)
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
# installs to ~/.local/bin — ensure it's on PATH
```

```powershell
# Windows native (PowerShell) — download release binary, add to PATH
# https://github.com/rtk-ai/rtk/releases → rtk-x86_64-pc-windows-msvc.zip
# Extract rtk.exe to e.g. $env:USERPROFILE\.local\bin and add that folder to PATH
rtk --version
rtk gain
```

If ECI hosts a pinned internal mirror of the release binary, prefer it over the curl script (supply-chain policy). Always verify with **both** `rtk --version` and `rtk gain`.

**Windows — read `references/windows.md` before proceeding:**
- **WSL2 (ECI default for Windows):** install and init inside WSL — full hook support, same as Linux.
- **Native Windows:** `rtk.exe` and filters work; auto-rewrite hook does **not** (requires Unix shell). Init still applies Cursor rules; agents must prefix commands with `rtk` explicitly. Set that expectation with the user.

## Step 2 — Preview, then initialize

Always dry-run first on a machine you don't own outright — it prints every file init would create or patch and writes nothing:

```bash
rtk init --global --dry-run -v
```

Expect output like (verified on rtk 0.42.x — paths vary by platform):
- **Claude Code:** `~/.claude/RTK.md`, `@RTK.md` in `~/.claude/CLAUDE.md`, hook in `settings.json`, filters template
- **Config/filters template:** Linux/WSL `~/.config/rtk/` · macOS `~/Library/Application Support/rtk/` · Windows `%APPDATA%\rtk\`
- **Cursor:** patch to `~/.cursor/hooks.json` (or WSL equivalent)

Ending with `[dry-run] Nothing written.` RTK releases frequently — if observed behavior differs from this skill, trust the binary and the live docs over this text.

Then initialize for the right agent and scope:

```bash
# Claude Code (ECI default)
rtk init --global              # global: hook in user-level settings, all projects
cd <repo> && rtk init          # repo-scoped: hook in project settings only

# Cursor
rtk init -g --agent cursor     # uses Cursor's preToolUse hook (hooks.json)

# Fleet automation / CI bootstrap (non-interactive)
rtk init -g --auto-patch
```

**The user must restart their AI tool after init** — the hook loads at startup. Remind them explicitly.

## Step 3 — Apply ECI governance defaults

Read `references/governance.md` (and `references/windows.md` on Windows) and apply the baseline `config.toml` (telemetry off, tee policy, ignore lists, command exclusions). This step is what makes the install *enterprise* adoption rather than personal tooling — do not skip it.

## Step 4 — Verify and baseline

```bash
rtk init --show     # hook present and pointing at the right agent
# In a fresh agent session, run a few commands (git status, a test run), then:
rtk gain            # savings counter should be non-zero
```

Record the date and `rtk gain` output — this is the baseline for the team's ROI reporting (handled by the companion `rtk-operations` skill).

## Step 5 — Set expectations (tell the user)

State these honestly at the end of setup:
1. The hook covers **Bash tool calls only**. Claude Code's built-in Read/Grep/Glob and MCP tool outputs bypass RTK. For those paths, prefer shell commands (`cat`, `rg`, `find`) or explicit `rtk read` / `rtk grep` / `rtk find` in skills and prompts.
2. Filtering is lossy on purpose; on command **failure**, RTK saves the full raw output to a tee log and prints the path (`~/.local/share/rtk/tee/` on Linux/macOS/WSL; `%LOCALAPPDATA%\rtk\tee\` on native Windows), so the agent can read details without re-running.
3. Kill switch: `RTK_DISABLED=1 <cmd>` for one command, `[hooks] exclude_commands` for permanent exclusions, `rtk init --uninstall` for full removal.
4. Project-local filters live in `.rtk/filters.toml`, committed to the repo. After cloning or committing one, run `rtk trust` in the repo so the 0.42.x security gate honors it (`rtk untrust` revokes, `rtk trust --list` audits). Validate filters with `rtk verify`.

For day-2 work — savings reports, troubleshooting, writing custom filters for niche toolchains (e.g., BBj/MarkSystems output) — hand off to the `rtk-operations` skill. To baseline a machine before rollout or diagnose "no savings", run `rtk-audit` (`rtk init --show`, `rtk gain`, `rtk discover`, `rtk session`, `rtk verify`, and optional `rtk learn`).
