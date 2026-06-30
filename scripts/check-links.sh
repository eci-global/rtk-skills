#!/usr/bin/env bash
# check-links.sh — verify http(s) links in markdown/rules/TOML resolve.
# Tolerant: retries, short timeout, HEAD-then-GET fallback. Fails on any broken link.
# Runnable WITHOUT RTK installed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0
checked=0

# Collect URLs from content files (dedup, preserve order). bash-3.2 safe (no mapfile).
urls=()
while IFS= read -r line; do
  [[ -n "$line" ]] && urls+=("$line")
done < <(grep -rhoE 'https://[a-zA-Z0-9./_:?=&%#~+-]+' \
  "$ROOT/README.md" \
  "$ROOT/cursor-rtk/README.md" \
  "$ROOT/.claude/skills" \
  "$ROOT/cursor-rtk/.cursor/rules" \
  "$ROOT/examples" \
  "$ROOT/.rtk/filters.toml" \
  2>/dev/null | awk '!seen[$0]++')

# Strip trailing prose punctuation that is not part of the URL.
clean_url() {
  local u="$1"
  u="${u%) }"
  u="${u%)}"
  u="${u%.}"
  u="${u%,}"
  printf '%s' "$u"
}

check_url() {
  local url="$1"
  local code
  # HEAD first (lighter); fall back to GET for servers that reject HEAD.
  code=$(curl -sIL --retry 3 --retry-delay 2 --max-time 25 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo 000)
  if [[ ! "$code" =~ ^(2|3)..$ ]]; then
    code=$(curl -sL --retry 3 --retry-delay 2 --max-time 25 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo 000)
  fi
  if [[ "$code" =~ ^(2|3)..$ ]]; then
    echo "  PASS  $code  $url"
    return 0
  else
    echo "  FAIL  $code  $url"
    return 1
  fi
}

echo "Link check"
echo "=========="
if [[ ${#urls[@]} -eq 0 ]]; then
  echo "  (no URLs found)"
fi

for raw in "${urls[@]}"; do
  u="$(clean_url "$raw")"
  checked=$((checked + 1))
  if check_url "$u"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
done

echo "=========="
echo "Results: $pass passed, $fail failed ($checked checked)"
if [[ $fail -gt 0 ]]; then
  echo "Broken links found." >&2
  exit 1
fi
echo "All links resolve."
