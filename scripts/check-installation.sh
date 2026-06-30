#!/usr/bin/env bash
# check-installation.sh — RTK installation diagnostic for ECI pilots.
#
# Read-only pre-adoption probe: confirms the CORRECT rtk (Rust Token Killer,
# not the crates.io "Rust Type Kit"), checks the 0.43.x native binary hook via
# `rtk init --show`, and reports ECI governance (telemetry off). Exits non-zero
# only when the wrong package is installed (the #1 adoption failure).
#
# Adapted from upstream repo/rtk/scripts/check-installation.sh for RTK 0.43.x
# + ECI governance. Fixes the upstream install URL (raw.githubusercontent,
# not the GitHub blob HTML page) and drops upstream in-repo `cargo install`
# / `feat/all-features` branch logic.
#
# Usage: ./scripts/check-installation.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PINNED="$(cat "$ROOT/RTK_VERSION" 2>/dev/null || echo 0.43.0)"
INSTALL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"

pass=0; warn=0; fail=0
ok()    { echo "  OK    $*"; pass=$((pass+1)); }
warnn() { echo "  WARN  $*"; warn=$((warn+1)); }
faill() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "RTK installation check (ECI) — pinned $PINNED"
echo "================================================"
echo

# 1. Binary on PATH
echo "1. Binary on PATH"
if command -v rtk >/dev/null 2>&1; then
  ok "rtk found at $(command -v rtk)"
else
  faill "rtk not on PATH"
  echo "      Install: brew install rtk (macOS) | curl -fsSL $INSTALL_URL | RTK_VERSION=v$PINNED sh (Linux/WSL)"
  echo "      Ensure ~/.local/bin (Linux/WSL) or the Homebrew prefix is on PATH."
  echo
  echo "Results: $pass OK, $warn WARN, $fail FAIL — rtk missing."
  exit 2
fi
echo

# 2. Version
echo "2. Version"
ver="$(rtk --version 2>/dev/null || echo unknown)"
echo "  rtk --version: $ver"
case "$ver" in
  *"$PINNED"*) ok "matches pinned $PINNED";;
  *) warnn "not the pinned version ($PINNED) — bump may be intentional, verify before rollout";;
esac
echo

# 3. Correct package (the #1 failure)
echo "3. Correct package (Rust Token Killer, not Rust Type Kit)"
if rtk gain >/dev/null 2>&1 || rtk gain --help >/dev/null 2>&1; then
  ok "rtk gain works — this is Rust Token Killer"
else
  faill "rtk gain failed — crates.io 'Rust Type Kit' is installed (wrong project)"
  echo "      Fix: cargo uninstall rtk"
  echo "           brew install rtk  (macOS)  OR  curl -fsSL $INSTALL_URL | RTK_VERSION=v$PINNED sh  (Linux/WSL)"
  echo "           then verify: rtk --version && rtk gain"
  echo
  echo "Results: $pass OK, $warn WARN, $fail FAIL — WRONG PACKAGE."
  exit 1
fi
echo

# 4. Hook status (0.43.x native binary hook, via rtk init --show)
echo "4. Hook status (rtk init --show)"
show="$(rtk init --show 2>/dev/null || true)"
if echo "$show" | grep -q '\[ok\] Hook:'; then ok "Claude Code hook registered"; else warnn "Claude Code hook not found (run: rtk init --global, then restart Claude Code)"; fi
if echo "$show" | grep -q '\[ok\] Cursor hook:'; then ok "Cursor hook registered"; else warnn "Cursor hook not found (run: rtk init -g --agent cursor, then restart Cursor)"; fi
if uname -s 2>/dev/null | grep -qi 'MINGW\|MSYS\|CYGWIN'; then
  warnn "native Windows: no auto-rewrite hook (expected — rules-only mode; use WSL for full hooks)"
fi
echo

# 5. Key subcommands present
echo "5. Key subcommands"
for c in gain discover session verify trust rewrite proxy; do
  if rtk --help 2>/dev/null | grep -qw "$c"; then ok "rtk $c"; else warnn "rtk $c missing (old/incomplete build)"; fi
done
echo

# 6. Project trust (if .rtk/filters.toml exists here)
echo "6. Project trust"
if [[ -f "$ROOT/.rtk/filters.toml" ]]; then
  if rtk trust --list 2>/dev/null | grep -q "$(cd "$ROOT" && pwd -P)"; then
    ok "this repo's .rtk/filters.toml is trusted"
  else
    warnn ".rtk/filters.toml present but not trusted — run 'rtk trust' in the repo (0.43.x security gate)"
  fi
else
  echo "  (no .rtk/filters.toml here — skipped)"
fi
echo

# 7. ECI governance: telemetry off
echo "7. ECI governance (telemetry off)"
if [[ "${RTK_TELEMETRY_DISABLED:-}" == "1" ]]; then ok "RTK_TELEMETRY_DISABLED=1 set in env"; else warnn "RTK_TELEMETRY_DISABLED=1 not set — add to ~/.zshrc / ~/.bashrc"; fi
case "$(uname -s)" in
  Darwin) cfg="$HOME/Library/Application Support/rtk/config.toml";;
  *)      cfg="$HOME/.config/rtk/config.toml";;
esac
if [[ -f "$cfg" ]] && grep -q '\[telemetry\]' "$cfg" && grep -A1 '\[telemetry\]' "$cfg" | grep -q 'enabled = false'; then
  ok "[telemetry] enabled = false in $cfg"
else
  warnn "[telemetry] enabled = false not found in $cfg (run adopt.sh, or rtk config --create + edit)"
fi
echo

echo "================================================"
echo "Results: $pass OK, $warn WARN, $fail FAIL"
if [[ $fail -gt 0 ]]; then exit 1; fi
if [[ $warn -gt 0 ]]; then echo "Review the WARN items before fleet rollout."; exit 0; fi
echo "RTK installation looks healthy."
