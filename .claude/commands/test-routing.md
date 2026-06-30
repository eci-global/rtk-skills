---
description: Dry-run check whether RTK has a filter for a command (no execution, no side effects)
---

# /test-routing

Check whether RTK has a filter for a command **without executing it**. Answers "why wasn't this filtered?" and "will RTK cover this before I run it?" — useful during adoption, hook debugging, and filter authoring.

Aligned to RTK 0.43.x. For the canonical list of built-in commands, see [`docs/COMMANDS.md`](docs/COMMANDS.md).

## Usage

```
/test-routing <command> [args...]
```

## Examples

```bash
/test-routing git status
# OK: RTK filter available — git status -> rtk git status

/test-routing psql -c "select * from users"
# WARN: no built-in RTK filter; would run raw (or via a project .rtk/filters.toml filter)

/test-routing cargo test
# OK: RTK filter available — cargo test -> rtk cargo test
```

## Implementation

```bash
COMMAND="$1"; shift; ARGS="$@"

if ! command -v rtk >/dev/null 2>&1; then
  echo "ERROR: rtk not installed — run the rtk-adoption skill or ./scripts/adopt.sh"
  exit 1
fi

echo "RTK version: $(rtk --version 2>/dev/null)"
echo "Command:     $COMMAND $ARGS"
echo

# Live check: does rtk expose this as a subcommand?
if rtk --help 2>/dev/null | grep -qw "$COMMAND"; then
  echo "OK: RTK filter available"
  echo "  input:  $COMMAND $ARGS"
  echo "  route:  rtk $COMMAND $ARGS"
  echo "  filter: applied (output condensed, exit code preserved)"
else
  echo "WARN: no built-in RTK filter for '$COMMAND'"
  echo "  input:  $COMMAND $ARGS"
  echo "  route:  $COMMAND $ARGS (raw, no RTK)"
  echo
  echo "Alternatives:"
  echo "  - rtk proxy $COMMAND $ARGS   # run raw, track in rtk gain --history"
  echo "  - rtk err $COMMAND $ARGS     # errors/warnings only"
  echo "  - rtk summary $COMMAND $ARGS # heuristic summary"
  echo "  - author a .rtk/filters.toml filter (see CONTRIBUTING.md + catalog/_template/filters.toml)"
fi
```

## Notes

- **Dry-run only** — no command is executed; this checks filter *availability*, not output quality.
- **First-class vs TOML built-ins:** commands in the Rust handler list (git, cargo, gh, pnpm, tsc, pytest, …) are first-class; 63+ others (make, terraform plan, shellcheck, …) work via TOML built-ins. Both are "filter available." See [`docs/COMMANDS.md`](docs/COMMANDS.md).
- **Project filters:** a repo's `.rtk/filters.toml` can add or override filters (e.g. MarkSystems/BBj). After `rtk trust`, `rtk verify` confirms they apply.
- **Bypass:** built-in Read/Grep/Glob and MCP outputs never pass through the hook — that is expected, not a routing failure.

## When to use

- Before running a high-output command, to decide `rtk <cmd>` vs raw.
- Debugging "why wasn't my command filtered?" — check the agent hook with the `/diagnose` command.
- Identifying filter candidates from `rtk discover` output.
