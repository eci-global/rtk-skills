#!/usr/bin/env bash
# Validate RTK Skills package structure and (optionally) local RTK install.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

pass=0
fail=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  PASS  $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL  $desc"
    fail=$((fail + 1))
  fi
}

is_markdown() {
  local f="$1"
  [[ -f "$f" ]] && file "$f" | grep -qE 'text|ASCII|Unicode'
}

is_not_zip() {
  local f="$1"
  [[ -f "$f" ]] && ! file "$f" | grep -q 'Zip archive'
}

echo "RTK Skills validation"
echo "====================="
echo

echo "Claude skills"
check "rtk-adoption/SKILL.md exists" test -f "$ROOT/.claude/skills/rtk-adoption/SKILL.md"
check "rtk-adoption/SKILL.md is markdown (not zip)" is_markdown "$ROOT/.claude/skills/rtk-adoption/SKILL.md"
check "rtk-adoption/SKILL.md is not a zip archive" is_not_zip "$ROOT/.claude/skills/rtk-adoption/SKILL.md"
check "rtk-adoption has frontmatter name" grep -q '^name: rtk-adoption' "$ROOT/.claude/skills/rtk-adoption/SKILL.md"
check "governance.md exists" test -f "$ROOT/.claude/skills/rtk-adoption/references/governance.md"
check "governance.md mentions macOS config path" grep -q 'Application Support/rtk' "$ROOT/.claude/skills/rtk-adoption/references/governance.md"
check "windows.md exists" test -f "$ROOT/.claude/skills/rtk-adoption/references/windows.md"
check "windows.md mentions WSL" grep -q 'WSL' "$ROOT/.claude/skills/rtk-adoption/references/windows.md"
check "windows.md mentions APPDATA config path" grep -q 'APPDATA' "$ROOT/.claude/skills/rtk-adoption/references/windows.md"
check "governance.md mentions Windows platform" grep -q 'Windows' "$ROOT/.claude/skills/rtk-adoption/references/governance.md"
check "rtk-operations/SKILL.md exists" test -f "$ROOT/.claude/skills/rtk-operations/SKILL.md"
check "rtk-operations/SKILL.md is markdown (not zip)" is_markdown "$ROOT/.claude/skills/rtk-operations/SKILL.md"
check "rtk-operations/SKILL.md is not a zip archive" is_not_zip "$ROOT/.claude/skills/rtk-operations/SKILL.md"
check "rtk-operations has frontmatter name" grep -q '^name: rtk-operations' "$ROOT/.claude/skills/rtk-operations/SKILL.md"
check "rtk-audit/SKILL.md exists" test -f "$ROOT/.claude/skills/rtk-audit/SKILL.md"
check "rtk-audit/SKILL.md is markdown (not zip)" is_markdown "$ROOT/.claude/skills/rtk-audit/SKILL.md"
check "rtk-audit has frontmatter name" grep -q '^name: rtk-audit' "$ROOT/.claude/skills/rtk-audit/SKILL.md"
check "rtk-audit uses rtk verify (no rtk doctor)" grep -q 'rtk verify' "$ROOT/.claude/skills/rtk-audit/SKILL.md"
check "rtk-audit has fixed Hook status section" grep -q '### Hook status' "$ROOT/.claude/skills/rtk-audit/SKILL.md"
check "no stale skill.md zip files" bash -c '! find "$0/.claude/skills" -name "skill.md" 2>/dev/null | grep -q .' "$ROOT"

echo
echo "Cursor rules"
check "rtk.mdc exists" test -f "$ROOT/cursor-rtk/.cursor/rules/rtk.mdc"
check "rtk.mdc alwaysApply" grep -q 'alwaysApply: true' "$ROOT/cursor-rtk/.cursor/rules/rtk.mdc"
check "rtk-operations.mdc exists" test -f "$ROOT/cursor-rtk/.cursor/rules/rtk-operations.mdc"
check "rtk-operations.mdc agent-requested" grep -q 'alwaysApply: false' "$ROOT/cursor-rtk/.cursor/rules/rtk-operations.mdc"
check "rtk-operations mentions macOS config path" grep -q 'Application Support/rtk' "$ROOT/cursor-rtk/.cursor/rules/rtk-operations.mdc"
check "rtk-operations mentions Windows config path" grep -q 'APPDATA' "$ROOT/cursor-rtk/.cursor/rules/rtk-operations.mdc"
check "root README mentions Windows" grep -q 'Windows' "$ROOT/README.md"

echo
echo "CI & parity scripts"
check "RTK_VERSION pin exists" test -f "$ROOT/RTK_VERSION"
check "RTK_VERSION is 0.43.0" grep -q '^0.43.0$' "$ROOT/RTK_VERSION"
check "check-parity.sh exists" test -f "$ROOT/scripts/check-parity.sh"
check "check-parity.sh is executable" test -x "$ROOT/scripts/check-parity.sh"
check "check-links.sh exists" test -f "$ROOT/scripts/check-links.sh"
check "check-links.sh is executable" test -x "$ROOT/scripts/check-links.sh"
check "CI workflow exists" test -f "$ROOT/.github/workflows/rtk-skills-ci.yml"
check "CI has package job (no RTK)" grep -q 'Package checks (no RTK)' "$ROOT/.github/workflows/rtk-skills-ci.yml"
check "CI has full job (pinned RTK)" grep -q 'Full validation (pinned RTK)' "$ROOT/.github/workflows/rtk-skills-ci.yml"
check "CI pins RTK via install.sh" grep -q 'install.sh' "$ROOT/.github/workflows/rtk-skills-ci.yml"

echo
echo "Adoption bootstrap"
check "adopt.sh exists" test -f "$ROOT/scripts/adopt.sh"
check "adopt.sh is executable" test -x "$ROOT/scripts/adopt.sh"
check "adopt.sh inits both agents" bash -c 'grep -q "init --global" "$0" && grep -q "init -g --agent cursor" "$0"' "$ROOT/scripts/adopt.sh"
check "adopt.sh supports --dry-run" grep -q -- '--dry-run' "$ROOT/scripts/adopt.sh"
check "adopt.sh supports --scope" grep -q -- '--scope' "$ROOT/scripts/adopt.sh"
check "adopt.sh supports --no-trust" grep -q -- '--no-trust' "$ROOT/scripts/adopt.sh"
check "adopt.sh pins RTK_VERSION" grep -q 'RTK_VERSION' "$ROOT/scripts/adopt.sh"
check "adopt.ps1 exists (native Windows)" test -f "$ROOT/scripts/adopt.ps1"
check "adopt.ps1 inits both agents" bash -c 'grep -q -- "--global" "$0" && grep -q -- "--agent" "$0" && grep -q -- "cursor" "$0"' "$ROOT/scripts/adopt.ps1"
check "adopt.ps1 supports -DryRun" grep -q -- '-DryRun' "$ROOT/scripts/adopt.ps1"
check "adopt.ps1 uses APPDATA config path" grep -q 'APPDATA' "$ROOT/scripts/adopt.ps1"
check "adopt.ps1 checksum-verifies install" grep -q 'Get-FileHash' "$ROOT/scripts/adopt.ps1"

echo
echo "Examples & docs"
check "root README exists" test -f "$ROOT/README.md"
check "cursor-rtk README exists" test -f "$ROOT/cursor-rtk/README.md"
check "example filters.toml exists" test -f "$ROOT/examples/filters.toml"
check "example filters.toml uses 0.43.x [filters. schema" grep -q '\[filters\.' "$ROOT/examples/filters.toml"
check "example filters.toml has schema_version = 1" grep -q '^schema_version = 1' "$ROOT/examples/filters.toml"
check "example filters.toml: no legacy [[filter]]" bash -c '! grep -q "\[\[filter\]\]" "$0"' "$ROOT/examples/filters.toml"
check "dogfood .rtk/filters.toml exists" test -f "$ROOT/.rtk/filters.toml"
check "dogfood .rtk/filters.toml uses [filters. schema" grep -q '\[filters\.' "$ROOT/.rtk/filters.toml"
check "dogfood .rtk/filters.toml has schema_version = 1" grep -q '^schema_version = 1' "$ROOT/.rtk/filters.toml"
check "AGENTS.md snippet exists" test -f "$ROOT/examples/snippets/AGENTS.md"
check "CLAUDE.md snippet exists" test -f "$ROOT/examples/snippets/CLAUDE.md"
check "snippets mention rtk trust" grep -q 'rtk trust' "$ROOT/examples/snippets/AGENTS.md"
check "snippets mention Read/Grep/Glob bypass" grep -q 'Read/Grep/Glob' "$ROOT/examples/snippets/CLAUDE.md"

echo
echo "Filter catalog"
check "catalog/README.md exists" test -f "$ROOT/catalog/README.md"
check "catalog/README.md has filter index" grep -q 'Filter index' "$ROOT/catalog/README.md"
check "catalog/_template/filters.toml exists" test -f "$ROOT/catalog/_template/filters.toml"
check "catalog template uses 0.43.x [filters. schema" grep -q '\[filters\.' "$ROOT/catalog/_template/filters.toml"
check "catalog template has schema_version = 1" grep -q '^schema_version = 1' "$ROOT/catalog/_template/filters.toml"
check "catalog template: no legacy [[filter]]" bash -c '! grep -q "\[\[filter\]\]" "$0"' "$ROOT/catalog/_template/filters.toml"
check "catalog template has inline test" grep -q '\[\[tests\.' "$ROOT/catalog/_template/filters.toml"
check "CONTRIBUTING.md exists" test -f "$ROOT/CONTRIBUTING.md"
check "CONTRIBUTING.md documents promote workflow" grep -q 'catalog/<team>/filters.toml' "$ROOT/CONTRIBUTING.md"

# Every promoted catalog/<team>/filters.toml must meet the same schema bar as
# the template: schema_version = 1, [filters.<name>] (not legacy [[filter]]),
# and at least one inline [[tests.*]] so rtk verify --require-all can validate it.
catalog_team_filters() {
  find "$ROOT/catalog" -mindepth 2 -maxdepth 2 -type f -name 'filters.toml' \
    ! -path "$ROOT/catalog/_template/*" 2>/dev/null
}
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  rel="${f#$ROOT/}"
  check "$rel has schema_version = 1" grep -q '^schema_version = 1' "$f"
  check "$rel uses [filters. schema" grep -q '\[filters\.' "$f"
  check "$rel: no legacy [[filter]]" bash -c '! grep -q "\[\[filter\]\]" "$0"' "$f"
  check "$rel has inline tests" grep -q '\[\[tests\.' "$f"
done < <(catalog_team_filters)

echo
echo "Slash commands, docs & install check"
check ".claude/commands/diagnose.md exists" test -f "$ROOT/.claude/commands/diagnose.md"
check "diagnose.md mentions rtk init --show" grep -q 'rtk init --show' "$ROOT/.claude/commands/diagnose.md"
check "diagnose.md mentions rtk gain" grep -q 'rtk gain' "$ROOT/.claude/commands/diagnose.md"
check ".claude/commands/test-routing.md exists" test -f "$ROOT/.claude/commands/test-routing.md"
check "test-routing.md mentions rtk --help/rewrite/discover" bash -c 'grep -qE "rtk --help|rtk rewrite|rtk discover" "$0"' "$ROOT/.claude/commands/test-routing.md"
check "docs/COMMANDS.md exists" test -f "$ROOT/docs/COMMANDS.md"
check "docs/COMMANDS.md mentions rtk gain" grep -q 'rtk gain' "$ROOT/docs/COMMANDS.md"
check "docs/COMMANDS.md mentions Read/Grep/Glob bypass" grep -q 'Read/Grep/Glob' "$ROOT/docs/COMMANDS.md"
check "check-installation.sh exists" test -f "$ROOT/scripts/check-installation.sh"
check "check-installation.sh is executable" test -x "$ROOT/scripts/check-installation.sh"
check "check-installation.sh mentions rtk gain" grep -q 'rtk gain' "$ROOT/scripts/check-installation.sh"
check "check-installation.sh uses raw install URL (not blob)" bash -c '! grep -q "github.com/rtk-ai/rtk/blob/master/install.sh" "$0"' "$ROOT/scripts/check-installation.sh"
check "adopt.sh seeds .claude/commands" grep -q '.claude/commands' "$ROOT/scripts/adopt.sh"
# Claude Code resolves markdown links in command/skill content relative to the
# workspace root, so parent-relative ](../  links climb out of the workspace and
# break. Use workspace-root-relative paths (e.g. docs/COMMANDS.md) in .claude/*.
check "no parent-relative markdown links in .claude/ (Claude Code resolves root-relative)" \
  bash -c '! grep -rnE "\]\(\.\./" "$0/.claude/commands" "$0/.claude/skills" 2>/dev/null | grep -q .' "$ROOT"

echo
echo "Cross-doc consistency (skills <-> rules <-> snippets <-> docs)"
check "AGENTS.md cites pinned 0.43.0" grep -q '0.43.0' "$ROOT/AGENTS.md"
check "CLAUDE.md cites pinned 0.43.0" grep -q '0.43.0' "$ROOT/CLAUDE.md"
check "AGENTS snippet cites pinned 0.43.0" grep -q '0.43.0' "$ROOT/examples/snippets/AGENTS.md"
check "adoption skill has rtk init --global" grep -q 'rtk init --global' "$ROOT/.claude/skills/rtk-adoption/SKILL.md"
check "operations rule has rtk init --global" grep -q 'rtk init --global' "$ROOT/cursor-rtk/.cursor/rules/rtk-operations.mdc"
check "AGENTS snippet has rtk init --global" grep -q 'rtk init --global' "$ROOT/examples/snippets/AGENTS.md"
check "docs/COMMANDS.md mentions rtk read bypass" grep -q 'rtk read' "$ROOT/docs/COMMANDS.md"
check "operations skill mentions rtk read bypass" grep -q 'rtk read' "$ROOT/.claude/skills/rtk-operations/SKILL.md"
check "CONTRIBUTING.md mentions rtk trust" grep -q 'rtk trust' "$ROOT/CONTRIBUTING.md"
check "catalog README mentions rtk trust" grep -q 'rtk trust' "$ROOT/catalog/README.md"
check "AGENTS.md has rtk gain verify block" grep -q 'Verify the right package' "$ROOT/AGENTS.md"
check "CLAUDE.md has rtk gain verify block" grep -q 'Verify the right package' "$ROOT/CLAUDE.md"

echo
echo "Repo-self AI config (dogfood)"
check "root AGENTS.md exists" test -f "$ROOT/AGENTS.md"
check "root CLAUDE.md exists" test -f "$ROOT/CLAUDE.md"
check "root CLAUDE.md mentions rtk trust" grep -q 'rtk trust' "$ROOT/CLAUDE.md"
check "root AGENTS.md mentions rtk trust" grep -q 'rtk trust' "$ROOT/AGENTS.md"
check ".cursorignore exists" test -f "$ROOT/.cursorignore"
check ".cursorignore excludes dist/" grep -q '^dist/' "$ROOT/.cursorignore"
check "dogfood .rtk/filters.toml has rtk-gates filter" grep -q '\[filters\.rtk-gates\]' "$ROOT/.rtk/filters.toml"

if $FULL; then
  echo
  echo "RTK install (--full)"
  check "rtk on PATH" command -v rtk >/dev/null
  if command -v rtk >/dev/null; then
    check "rtk --version succeeds" rtk --version >/dev/null 2>&1
    check "rtk gain succeeds (correct package)" rtk gain >/dev/null 2>&1
    check "hook installed (Claude Code or Cursor)" bash -c \
      'rtk init --show 2>/dev/null | grep -qE "\[ok\] Hook:|\[ok\] Cursor hook:"'
    echo
    echo "  rtk version: $(rtk --version 2>/dev/null || echo unknown)"
    echo "  hook status:"
    rtk init --show 2>/dev/null | sed 's/^/    /' || true
  fi
fi

echo
echo "====================="
echo "Results: $pass passed, $fail failed"
if [[ $fail -gt 0 ]]; then
  exit 1
fi
echo "Package ready for team distribution."
