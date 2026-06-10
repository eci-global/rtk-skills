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
echo "Examples & docs"
check "root README exists" test -f "$ROOT/README.md"
check "cursor-rtk README exists" test -f "$ROOT/cursor-rtk/README.md"
check "example filters.toml exists" test -f "$ROOT/examples/filters.toml"

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
