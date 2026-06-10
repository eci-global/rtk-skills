# ECI Governance Defaults for RTK

Apply these when initializing RTK on any ECI machine or repo. They encode decisions already made at the org level so individual developers don't re-litigate them.

## Baseline config.toml

Create with `rtk config --create`, then edit at the platform path:

| Platform | config.toml path |
|----------|------------------|
| Linux / WSL | `~/.config/rtk/config.toml` |
| macOS | `~/Library/Application Support/rtk/config.toml` |
| Windows (native) | `%APPDATA%\rtk\config.toml` |

Full Windows install and WSL guidance: `references/windows.md`.

```toml
[tracking]
enabled = true            # required — feeds rtk gain ROI reporting
history_days = 90

[filters]
# Paths excluded from ls/find/grep/read output — extend per local stack
ignore_dirs  = [".git", "node_modules", "target", "__pycache__", ".venv", "vendor"]
ignore_files = ["*.lock", "*.min.js", "*.min.css"]

[hooks]
# Never auto-rewrite interactive/stateful commands.
# Prefix match (after stripping sudo/VAR= prefixes); patterns starting ^ are regex.
exclude_commands = ["git rebase", "git cherry-pick", "docker exec", "^psql"]

[tee]
enabled = true
mode = "failures"         # raw output saved ONLY on failure (20-file rotation, 1 MB cap)
                          # use "never" in repos handling sensitive data —
                          # tee files contain unfiltered command output on disk

[telemetry]
enabled = false           # ECI policy: no outbound telemetry from dev tooling
```

Also disable telemetry per platform:

```bash
# Linux / macOS / WSL — add to ~/.bashrc, ~/.zshrc, etc.
export RTK_TELEMETRY_DISABLED=1
```

```powershell
# Windows PowerShell — permanent user env var
[Environment]::SetEnvironmentVariable("RTK_TELEMETRY_DISABLED", "1", "User")
```

Why telemetry off: RTK's daily ping is anonymous (device hash, version, OS, command counts, savings %) and contains no file paths or command content — but ECI policy is to disable outbound telemetry from developer tooling by default. Don't present this as the tool being unsafe; it's a policy default.

## Repo-level standardization

Two artifacts belong **in the repository**, so behavior travels with the code:

1. **`.rtk/filters.toml`** — custom filters or overrides of built-ins for this repo's toolchain. This is where niche-toolchain savings live (BBj/MarkSystems build output has no built-in filter). Authoring filters is covered by the `rtk-operations` skill.
2. **CONTRIBUTING/README section** — "AI agent setup": install RTK (see platform table below), `rtk init --global` or `rtk init -g --agent cursor`, restart agent, verify `rtk gain`.

### Platform install quick reference

| Platform | Install | Init (Cursor) | Config path |
|----------|---------|---------------|-------------|
| macOS | `brew install rtk` | `rtk init -g --agent cursor` | `~/Library/Application Support/rtk/config.toml` |
| Linux / WSL | [install.sh](https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh) | `rtk init -g --agent cursor` | `~/.config/rtk/config.toml` |
| Windows (WSL) | install.sh inside WSL | `rtk init -g --agent cursor` (from WSL) | `~/.config/rtk/config.toml` |
| Windows (native) | [GitHub release zip](https://github.com/rtk-ai/rtk/releases) → PATH | `rtk init -g --agent cursor` + explicit `rtk` prefixes | `%APPDATA%\rtk\config.toml` |

See `references/windows.md` for full Windows/WSL setup, PATH, and troubleshooting.

## Tee policy decision table

| Repo sensitivity | tee.mode | Rationale |
|---|---|---|
| Standard product repos | `"failures"` (default) | Agent can self-recover failure detail without re-running |
| Repos touching credentials, customer data, prod configs | `"never"` | Raw output (stack traces, connection strings) never persists to disk |
| Debugging a filter problem temporarily | `"always"` | Maximum recoverability; revert afterward |

`RTK_TEE_DIR` can redirect tee files to a managed/encrypted location if needed.

## Environment variable quick reference

| Variable | Effect |
|---|---|
| `RTK_DISABLED=1` | Bypass RTK for a single command |
| `RTK_TELEMETRY_DISABLED=1` | Disable telemetry |
| `RTK_TEE_DIR` | Override tee directory |
| `RTK_HOOK_AUDIT=1` | Audit-log hook activity (use during security review) |
