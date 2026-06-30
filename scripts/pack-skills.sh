#!/usr/bin/env bash
# Build portable .skill zip archives from directory-based Claude skills.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"

mkdir -p "$DIST"

pack() {
  local name="$1"
  local src="$ROOT/.claude/skills/$name"
  local out="$DIST/$name.skill"

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "ERROR: missing $src/SKILL.md" >&2
    exit 1
  fi

  rm -f "$out"
  (cd "$src/.." && zip -qr "$out" "$name")
  echo "  $out ($(du -h "$out" | cut -f1))"
}

echo "Packing Claude skills to dist/"
pack rtk-adoption
pack rtk-operations
pack rtk-audit
echo "Done."
