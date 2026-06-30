# RTK built-in commands — quick reference

Canonical list of commands RTK 0.43.x filters, so skills, snippets, and the `/test-routing` command cite them accurately. Adapted from the upstream `what-rtk-covers` guide and the `src/cmds/` audit.

RTK has two filter layers: **Rust handlers** (Clap-routed, structured parsing) and **TOML built-ins** (63+ filters matched on the full command string when Clap doesn't claim it). Lookup priority: `.rtk/filters.toml` → `~/.config/rtk/filters.toml` → built-ins → passthrough. First match wins; a same-named project filter shadows a built-in and warns.

## First-class (Rust-filtered) — cite as `rtk <cmd>`

| Category | Commands |
|----------|----------|
| **Git ecosystem** | `git` (status/log/diff/show/add/commit/push/pull/branch/fetch/stash/worktree; other subcommands passthrough), `gh` (pr/issue/run/repo), `glab` (mr/issue/ci/pipeline/api), `gt` (log/submit/sync/restack/create/branch) |
| **Rust** | `cargo` (build/test/check/clippy/install/nextest; other passthrough) |
| **JS/TS** | `npm`, `npx`, `pnpm` (list/outdated/install/typecheck), `jest`, `vitest`, `tsc`, `lint` (ESLint; routes to ruff/mypy on Python), `prettier`, `next`, `playwright`, `prisma` (generate/migrate/db push) |
| **Python** | `ruff`, `pytest`, `mypy`, `pip` (auto-detects uv), `uv` |
| **Go** | `go` (test/build/vet; other passthrough), `golangci-lint` |
| **JVM** | `gradlew`, `mvn` |
| **Ruby** | `rspec`, `rubocop`, `rake` |
| **.NET** | `dotnet` (build/test/restore/format; other passthrough) |
| **Cloud / containers / data** | `docker` (ps/images/logs/compose; other passthrough), `kubectl` (get/pods/services/logs), `oc`, `aws` (JSON + compress), `psql`, `curl` (body/JSON), `wget` (strip progress) |
| **System / files** | `ls`, `tree`, `read` (`--level none\|minimal\|aggressive`), `smart` (2-line summary), `grep`/`rg`, `find`, `diff`, `wc`, `json`, `log`, `env`, `deps`, `format` (auto-detect prettier/black/ruff format), `summary`, `err`, `test` |

## TOML built-ins (regex-based, 63+)

`make`, `df`, `du`, `ps`, `ping`, `rsync`, `shellcheck`, `hadolint`, `yamllint`, `markdownlint`, `terraform plan`, `tofu` (plan/init/validate/fmt), `pulumi` (up/preview/refresh/destroy/stack), `helm`, `gcloud`, `ansible-playbook`, `gradle`/`gradlew`, `swift build`, `xcodebuild`, `brew install`, `bundle install`, `poetry install`, `uv sync`, `composer install`, `mix compile/format`, `turbo`, `nx`, `biome`, `oxlint`, `basedpyright`, `ty`, `just`, `task`, `mise`, `pre-commit`, `jq`, `ssh`, `jj`, `ollama run`, `shopify theme`, `pio run`, `quarto render`, `sops`, `skopeo`, `liquibase`, `fail2ban-client`, `iptables`, `systemctl status`, `spring-boot`, and more.

These work via hook rewrite + fallback with simpler regex filtering. A project `.rtk/filters.toml` can add or override any of them.

## Meta / ops / audit (no output filtering)

| Command | Role |
|---------|------|
| `rtk init` | Hook + config install (`--global`, `--agent cursor\|claude`, `--codex`, `--auto-patch`) |
| `rtk gain` | Token-savings analytics (`--daily/--weekly/--monthly/--graph/--history/--all --format json`) |
| `rtk discover` | Missed-savings scan from agent session history |
| `rtk session` | Per-session RTK adoption % |
| `rtk learn` | CLI correction rules from error history (`-w/--write-rules`) |
| `rtk cc-economics` | ccusage spend vs rtk savings |
| `rtk rewrite` | Hook rewrite engine (single source of truth) |
| `rtk verify` | Hook integrity + TOML filter inline tests (`--require-all` for CI) |
| `rtk trust` / `rtk untrust` / `rtk trust --list` | Project `.rtk/filters.toml` trust gate (0.43.x) |
| `rtk proxy` | Run raw, track only |
| `rtk run` | Raw shell via `sh -c`, no tracking |
| `rtk pipe` | Stdin filter mode |
| `rtk hook` | Agent hook processors (claude, cursor, gemini, copilot) |
| `rtk hook-audit` | Rewrite audit metrics |
| `rtk config` | Show/create config |
| `rtk telemetry` | Telemetry consent subcommands (disabled by ECI policy) |

## Bypass caveat (cite everywhere)

The hook covers **shell/Bash tool calls only**. Built-in Read/Grep/Glob and MCP tool outputs **never** pass through RTK. For those paths, prefer shell `rg` / `cat` / `find` or explicit `rtk read` / `rtk grep` / `rtk find` so the output is filtered and counted toward savings. On native Windows, the auto-rewrite hook is unavailable — committed rules tell the agent to prefix `rtk` explicitly (rules-only mode).

## Citing rules for skill/snippet authors

- If a command is in the **Rust-filtered** table, cite the `rtk <cmd>` form and claim savings.
- If only in **TOML built-ins**, it still works via hook rewrite + fallback — cite `rtk <cmd>` but describe filtering as simpler/regex-based.
- **Do not** claim RTK filters for Cursor/Claude built-in Read/Grep/Glob/MCP — use the shell or `rtk read/grep/find` alternatives above.
- For niche toolchains with no built-in (MarkSystems/BBj, proprietary SQL runners), savings are 0% until a `.rtk/filters.toml` filter exists — see [`CONTRIBUTING.md`](../CONTRIBUTING.md) and [`catalog/_template/filters.toml`](../catalog/_template/filters.toml).
