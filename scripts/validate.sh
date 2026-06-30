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
check "RTK_VERSION is 0.42.4" grep -q '^0.42.4$' "$ROOT/RTK_VERSION"
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

echo
echo "Examples & docs"
check "root README exists" test -f "$ROOT/README.md"
check "cursor-rtk README exists" test -f "$ROOT/cursor-rtk/README.md"
check "example filters.toml exists" test -f "$ROOT/examples/filters.toml"
check "example filters.toml uses 0.42.x [filters. schema" grep -q '\[filters\.' "$ROOT/examples/filters.toml"
check "example filters.toml: no legacy [[filter]]" bash -c '! grep -q "\[\[filter\]\]" "$0"' "$ROOT/examples/filters.toml"
check "dogfood .rtk/filters.toml exists" test -f "$ROOT/.rtk/filters.toml"
check "dogfood .rtk/filters.toml uses [filters. schema" grep -q '\[filters\.' "$ROOT/.rtk/filters.toml"
check "AGENTS.md snippet exists" test -f "$ROOT/examples/snippets/AGENTS.md"
check "CLAUDE.md snippet exists" test -f "$ROOT/examples/snippets/CLAUDE.md"
check "snippets mention rtk trust" grep -q 'rtk trust' "$ROOT/examples/snippets/AGENTS.md"
check "snippets mention Read/Grep/Glob bypass" grep -q 'Read/Grep/Glob' "$ROOT/examples/snippets/CLAUDE.md"

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
