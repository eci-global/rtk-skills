<!-- RTK snippet for product-repo AGENTS.md (Codex / generic agents). -->
<!-- Copy this block into your repo's AGENTS.md and adjust the install line. -->
<!-- Full setup: https://www.rtk-ai.app/docs/  ·  Pinned version: 0.43.0 -->

## RTK token reduction (this repo)

This repo uses [RTK (Rust Token Killer)](https://www.rtk-ai.app/) to cut LLM token use 60–90% on terminal command output.

### Setup (once per machine)
```bash
# macOS
brew install rtk
# Linux / WSL
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | RTK_VERSION=v0.43.0 sh
# verify the RIGHT package (a crates.io "Rust Type Kit" also installs as `rtk`)
rtk --version && rtk gain
# init for your agent, then RESTART the tool
rtk init --global            # Claude Code
rtk init -g --agent cursor   # Cursor
rtk init --codex             # Codex (AGENTS.md + RTK.md)
```

### Running commands
- If the hook is installed, commands are rewritten automatically — run them normally.
- Native Windows: auto-rewrite is unavailable — prefix with `rtk` (`rtk git status`, `rtk test <cmd>`).
- Tests: `rtk test <cmd>` (failures only). Long unknown output: `rtk err <cmd>` or `rtk summary <cmd>`.
- Full list of RTK-filtered commands: see `docs/COMMANDS.md` in the rtk-skills toolkit.

### Bypass — Read/Grep/Glob do NOT go through RTK
The hook covers shell/Bash tool calls only. Built-in Read/Grep/Glob and MCP outputs bypass RTK.
For those paths, prefer shell `rg` / `cat` / `find` or explicit `rtk read` / `rtk grep` / `rtk find`.

### When detail is missing
- After a **failed** command, RTK prints a tee log path — read it instead of re-running
  (Linux/macOS/WSL: `~/.local/share/rtk/tee/`; Windows: `%LOCALAPPDATA%\rtk\tee\`).
- Raw output once: `RTK_DISABLED=1 <cmd>`. Never suggest uninstalling RTK to work around one command.

### Project filters
This repo commits `.rtk/filters.toml`. After cloning, run `rtk trust` once so the project-local
filters are honored (0.43.x security gate). Repo-level filter overrides live in `.rtk/filters.toml`.

### Governance
Telemetry off: `[telemetry] enabled = false` in config.toml + `export RTK_TELEMETRY_DISABLED=1`.
See the ECI governance defaults in the `rtk-skills` toolkit.
