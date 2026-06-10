# Windows Setup for RTK (ECI)

ECI supports Windows developers via two paths. **WSL is the recommended default** — it gets full transparent hook support identical to Linux. Native Windows works but requires explicit `rtk` prefixes when the auto-rewrite hook is unavailable.

## Choose your path

| Path | Hook auto-rewrite | Token savings | ECI recommendation |
|------|-------------------|---------------|-------------------|
| **WSL2** (Ubuntu/etc.) | Yes — full support | 60–90% automatic | **Default for Windows devs** |
| **Native Windows** (PowerShell/CMD) | No — rules/prompts only | Savings when agent prefixes `rtk` | Acceptable; set expectations |

## WSL2 (recommended)

Install and init inside your WSL distro — not from PowerShell:

```bash
# Inside WSL (Ubuntu)
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
# ensure ~/.local/bin is on PATH

rtk --version && rtk gain

# Claude Code
rtk init --global

# Cursor — run from WSL if Cursor's integrated terminal uses WSL, OR from Windows
# if Cursor agent shell is WSL-backed:
rtk init -g --agent cursor

# restart Cursor / Claude Code
rtk init --show
```

Config path (inside WSL): `~/.config/rtk/config.toml` — same as Linux. Apply ECI governance defaults from `governance.md`.

**Cursor + WSL tip:** If the agent's shell is WSL, init the hook from WSL. If the agent runs native PowerShell, use the native Windows path below for that shell — hooks are per-shell environment.

## Native Windows (PowerShell / CMD)

### Install

1. Download `rtk-x86_64-pc-windows-msvc.zip` from [GitHub releases](https://github.com/rtk-ai/rtk/releases).
2. Extract `rtk.exe` to a folder on PATH (e.g. `%USERPROFILE%\.local\bin` or `C:\Tools\rtk`).
3. Run from **PowerShell or Windows Terminal** — do not double-click the `.exe`.

```powershell
# Add to user PATH (example — adjust directory)
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "User") + ";$env:USERPROFILE\.local\bin",
  "User"
)
$env:Path += ";$env:USERPROFILE\.local\bin"

rtk --version
rtk gain          # must show savings dashboard (confirms correct package)
```

Alternative: `winget` or internal ECI mirror if your org hosts a pinned build.

### Initialize (native)

```powershell
rtk init -g --agent cursor --dry-run -v   # preview first
rtk init -g --agent cursor                # may fall back to rules/instructions mode
# restart Cursor
rtk init --show
```

On native Windows, RTK **cannot transparently rewrite** shell commands (the hook script requires a Unix shell). The init still installs Cursor rules/instructions; **agents must prefix commands explicitly**:

```
rtk git status
rtk test npm test
rtk grep pattern .
```

The committed `.cursor/rules/rtk.mdc` in this package covers that fallback behavior.

### Config path (native Windows)

| Artifact | Path |
|----------|------|
| `config.toml` | `%APPDATA%\rtk\config.toml` |
| Tracking DB | `%APPDATA%\rtk\tracking.db` |
| Tee logs (on failure) | `%LOCALAPPDATA%\rtk\tee\` (path also printed in output) |
| Global filters template | `%APPDATA%\rtk\filters.toml` |

Create config: `rtk config --create`, then edit in `%APPDATA%\rtk\`.

Open in Explorer: paste `%APPDATA%\rtk` into the address bar.

### Telemetry off (PowerShell)

Session-only:

```powershell
$env:RTK_TELEMETRY_DISABLED = "1"
```

Permanent (user env var):

```powershell
[Environment]::SetEnvironmentVariable("RTK_TELEMETRY_DISABLED", "1", "User")
```

Also set `[telemetry] enabled = false` in `config.toml`.

### Kill switch (PowerShell)

```powershell
$env:RTK_DISABLED = "1"; git status    # one command, raw output
```

## Verify on Windows

| Check | WSL | Native Windows |
|-------|-----|----------------|
| `rtk --version` | `rtk 0.42.x` | `rtk 0.42.x` |
| `rtk gain` | Dashboard loads | Dashboard loads |
| `rtk git status` vs `git status` | Filtered shorter output | Filtered shorter output |
| Agent `git status` | Compact (hook) | Compact only if agent prefixes `rtk` or rules loaded |
| `rtk init --show` | Cursor hook: installed | May show rules/instructions mode |

## Common Windows issues

| Symptom | Fix |
|---------|-----|
| `rtk` not recognized | PATH not set; reopen terminal after PATH change |
| `rtk gain` fails but `--version` works | Wrong package installed (crates.io collision); reinstall from GitHub release |
| No automatic filtering in Cursor | Expected on native Windows — ensure `rtk.mdc` rules committed; agent prefixes `rtk` |
| Hook works in WSL but not PowerShell | Init separately per shell environment, or standardize team on WSL terminal |
| Codex/sandbox can't write tracking DB | Known on some Windows sandboxes — run `rtk gain` outside sandbox to confirm |
