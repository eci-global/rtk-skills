<!-- RTK snippet for product-repo CLAUDE.md (Claude Code). -->
<!-- Copy this block into your repo's CLAUDE.md (or ~/.claude/CLAUDE.md for global). -->
<!-- Full setup: https://www.rtk-ai.app/docs/  ·  Pinned version: 0.42.4 -->

## RTK token reduction (this repo)

This repo uses [RTK (Rust Token Killer)](https://www.rtk-ai.app/) to cut LLM token use 60–90% on terminal command output.

### Setup (once per machine)
```bash
# macOS
brew install rtk
# Linux / WSL
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | RTK_VERSION=v0.42.4 sh
# verify the RIGHT package (a crates.io "Rust Type Kit" also installs as `rtk`)
rtk --version && rtk gain
# init for Claude Code, then RESTART Claude Code
rtk init --global
```

### Running commands
- If the hook is installed, commands are rewritten automatically — run them normally.
- Native Windows: auto-rewrite is unavailable — prefix with `rtk` (`rtk git status`, `rtk test <cmd>`).
- Tests: `rtk test <cmd>` (failures only). Long unknown output: `rtk err <cmd>` or `rtk summary <cmd>`.

### Bypass — Read/Grep/Glob do NOT go through RTK
The hook covers shell/Bash tool calls only. Claude Code's built-in Read/Grep/Glob and MCP tool
outputs bypass RTK. For those paths, prefer shell `rg` / `cat` / `find` or explicit
`rtk read` / `rtk grep` / `rtk find` so the output is filtered and counted toward savings.

### When detail is missing
- After a **failed** command, RTK prints a tee log path — read it instead of re-running
  (Linux/macOS/WSL: `~/.local/share/rtk/tee/`; Windows: `%LOCALAPPDATA%\rtk\tee\`).
- Raw output once: `RTK_DISABLED=1 <cmd>`. Never suggest uninstalling RTK to work around one command.

### Project filters
This repo commits `.rtk/filters.toml`. After cloning, run `rtk trust` once so the project-local
filters are honored (0.42.x security gate). Repo-level filter overrides live in `.rtk/filters.toml`.

### Governance
Telemetry off: `[telemetry] enabled = false` in config.toml + `export RTK_TELEMETRY_DISABLED=1`.
See the ECI governance defaults in the `rtk-skills` toolkit.
