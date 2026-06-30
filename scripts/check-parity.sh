#!/usr/bin/env bash
# check-parity.sh — fail if Claude skills and Cursor rules diverge on RTK facts.
#
# Parity dimensions (AHA handoff): init flags, config paths, tee recovery,
# exclude_commands, Read/Grep bypass. Plus a filter-schema guard so the
# examples/dogfood TOML cannot regress to the legacy [[filter]] schema.
#
# Content-only checks — runnable WITHOUT RTK installed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADOPTION_SKILL="$ROOT/.claude/skills/rtk-adoption/SKILL.md"
OPERATIONS_SKILL="$ROOT/.claude/skills/rtk-operations/SKILL.md"
RTK_MDC="$ROOT/cursor-rtk/.cursor/rules/rtk.mdc"
RTK_OPS_MDC="$ROOT/cursor-rtk/.cursor/rules/rtk-operations.mdc"
EXAMPLE_FILTERS="$ROOT/examples/filters.toml"
DOGFOOD_FILTERS="$ROOT/.rtk/filters.toml"

pass=0
fail=0

# assert_present <label> <file> <substring>   (fixed-string substring match)
assert_present() {
  local label="$1" file="$2" needle="$3"
  if [[ -f "$file" ]] && grep -qF -- "$needle" "$file"; then
    echo "  PASS  $label"
    pass=$((pass + 1))
  else
    echo "  FAIL  $label (missing '$needle' in $(basename "$file"))"
    fail=$((fail + 1))
  fi
}

# assert_absent <label> <file> <substring>
assert_absent() {
  local label="$1" file="$2" needle="$3"
  if [[ ! -f "$file" ]]; then
    echo "  FAIL  $label (file missing: $(basename "$file"))"
    fail=$((fail + 1))
    return
  fi
  if grep -qF -- "$needle" "$file"; then
    echo "  FAIL  $label (forbidden '$needle' present in $(basename "$file"))"
    fail=$((fail + 1))
  else
    echo "  PASS  $label"
    pass=$((pass + 1))
  fi
}

# pair <dimension> <token> <fileA> <fileB>   — token must appear in BOTH files
pair() {
  local dim="$1" token="$2" a="$3" b="$4"
  assert_present "[$dim] $(basename "$a")" "$a" "$token"
  assert_present "[$dim] $(basename "$b")" "$b" "$token"
}

echo "RTK skill ↔ rule parity"
echo "======================="

echo
echo "Pair 1: rtk-adoption (SKILL) ↔ rtk.mdc (always-on behavioral rule)"
echo "  Behavioral facts that must agree between the adoption skill and the always-on rule."
pair "tee recovery"      "~/.local/share/rtk/tee/" "$ADOPTION_SKILL" "$RTK_MDC"
pair "bypass: rtk read"  "rtk read"                "$ADOPTION_SKILL" "$RTK_MDC"
pair "bypass: rtk grep"  "rtk grep"                "$ADOPTION_SKILL" "$RTK_MDC"
pair "bypass: rtk find"  "rtk find"                "$ADOPTION_SKILL" "$RTK_MDC"

echo
echo "Pair 2: rtk-operations (SKILL) ↔ rtk-operations.mdc (agent-requested rule)"
echo "  Operational facts that must agree between the operations skill and rule."
pair "init flag cursor"    "rtk init -g --agent cursor" "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "init flag claude"    "rtk init --global"          "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "config path macOS"   "Application Support/rtk"    "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "config path Linux"   ".config/rtk/config.toml"    "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "config path Windows" "APPDATA"                    "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "tee recovery"        "~/.local/share/rtk/tee/"    "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "exclude_commands"    "exclude_commands"           "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "bypass: rtk read"    "rtk read"                   "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "bypass: rtk grep"    "rtk grep"                   "$OPERATIONS_SKILL" "$RTK_OPS_MDC"
pair "bypass: rtk find"    "rtk find"                   "$OPERATIONS_SKILL" "$RTK_OPS_MDC"

echo
echo "Filter schema (0.43.x [filters.<name>]; legacy [[filter]] must be absent)"
assert_present "[schema] examples/filters.toml has [filters." "$EXAMPLE_FILTERS" "[filters."
assert_present "[schema] .rtk/filters.toml has [filters."     "$DOGFOOD_FILTERS" "[filters."
assert_absent  "[schema] examples/filters.toml: no legacy [[filter]]" "$EXAMPLE_FILTERS" "[[filter]]"
assert_absent  "[schema] .rtk/filters.toml: no legacy [[filter]]"     "$DOGFOOD_FILTERS" "[[filter]]"

echo
echo "======================="
echo "Results: $pass passed, $fail failed"
if [[ $fail -gt 0 ]]; then
  echo "Parity BROKEN — fix the skill/rule drift listed above." >&2
  exit 1
fi
echo "Parity OK — Claude skills and Cursor rules agree on RTK 0.43.x facts."
