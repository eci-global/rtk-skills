#!/usr/bin/env bash
# adopt.sh — one-command RTK adoption for ECI (Claude Code + Cursor).
#
# Runs on macOS, Linux, WSL. Native Windows: use WSL (see README).
#
# What it does:
#   1. Installs RTK pinned to RTK_VERSION (if missing or not the pinned version).
#   2. Inits BOTH agents: `rtk init --global` (Claude Code) + `rtk init -g --agent cursor`.
#   3. Copies rtk-adoption / rtk-operations / rtk-audit skills to ~/.claude/skills/ (global).
#   4. Seeds the target repo: .cursor/rules, .claude/skills, .rtk/filters.toml (if absent),
#      and an RTK block in AGENTS.md + CLAUDE.md (idempotent, marker-guarded).
#   5. Applies ECI governance: [telemetry] off, [hooks] exclude_commands, tee=failures
#      (add-if-missing; respects existing user values), RTK_TELEMETRY_DISABLED=1 in shell rc.
#   6. Runs `rtk trust` in the target repo (if .rtk/filters.toml present).
#   7. Verifies: rtk init --show + rtk verify, prints a readiness summary + restart reminder.
#
# Flags: --dry-run  --scope global|repo|both  --repo <path>  --yes/-y  --help
# Default scope: both. Default repo: $PWD.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTK_VERSION="$(cat "$ROOT/RTK_VERSION" 2>/dev/null || echo 0.43.0)"
DRY_RUN=false
SCOPE=both
REPO_TARGET="$PWD"
ASSUME_YES=false
NO_TRUST=false

usage() {
  cat <<EOF
Usage: ./scripts/adopt.sh [options]

One-command RTK adoption for ECI (Claude Code + Cursor).
  --dry-run             Predict actions, write nothing
  --scope SCOPE         global | repo | both (default: both)
  --repo PATH           Repo to seed (default: \$PWD)
  --no-trust            Seed .rtk/filters.toml but do NOT run rtk trust (review first)
  -y, --yes             Skip the confirm prompt
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift;;
    --scope)   SCOPE="$2"; shift 2;;
    --repo)    REPO_TARGET="$2"; shift 2;;
    --no-trust) NO_TRUST=true; shift;;
    -y|--yes)  ASSUME_YES=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done

case "$SCOPE" in global|repo|both) ;; *) echo "invalid --scope: $SCOPE (use global|repo|both)" >&2; exit 2;; esac

# Resolve repo target to an absolute path (tolerate non-existent for dry-run).
REPO_TARGET="$(cd "$REPO_TARGET" 2>/dev/null && pwd || echo "$REPO_TARGET")"

run()  { if $DRY_RUN; then echo "  [dry-run] $*"; else "$@"; fi; }
step() { echo; echo "==> $*"; }

# ---------- platform ----------
OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM=macos;;
  Linux*)  PLATFORM=linux;;
  *) echo "Unsupported OS: $OS (on Windows, run inside WSL)" >&2; exit 3;;
esac
if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then PLATFORM=linux-wsl; fi

config_path() {
  case "$PLATFORM" in
    macos) printf '%s/Library/Application Support/rtk/config.toml' "$HOME";;
    *)     printf '%s/.config/rtk/config.toml' "$HOME";;
  esac
}

# ---------- gating ----------
ROOT_ABS="$(cd "$ROOT" 2>/dev/null && pwd -P 2>/dev/null || echo "$ROOT")"
REPO_ABS="$(cd "$REPO_TARGET" 2>/dev/null && pwd -P 2>/dev/null || echo "$REPO_TARGET")"
DO_GLOBAL=false
DO_REPO=false
if [[ "$SCOPE" == "global" || "$SCOPE" == "both" ]]; then DO_GLOBAL=true; fi
if [[ "$SCOPE" == "repo" || "$SCOPE" == "both" ]]; then DO_REPO=true; fi
# Don't seed the toolkit repo itself (would just copy onto itself + add snippet noise).
if [[ "$REPO_ABS" == "$ROOT_ABS" ]]; then
  if $DO_REPO; then
    echo "note: --repo is the toolkit repo itself — skipping repo seeding (cd into a product repo, or use --repo <path>)."
  fi
  DO_REPO=false
fi

echo "RTK adoption (ECI) — pinned RTK $RTK_VERSION"
echo "platform: $PLATFORM | scope: $SCOPE | repo: $REPO_TARGET | dry-run: $DRY_RUN"
if $DO_GLOBAL; then echo "  + global (machine hook + global Claude skills + governance)"; fi
if $DO_REPO;   then echo "  + repo (seed $REPO_TARGET + rtk trust)"; fi

# ---------- confirm ----------
if ! $DRY_RUN && ! $ASSUME_YES; then
  echo
  echo "This will install/init RTK, copy skills, seed the repo, apply governance, and verify."
  printf "Proceed? [y/N] "
  read -r ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then echo "aborted"; exit 0; fi
fi

# ---------- 1. ensure RTK ----------
step "1/7 Ensure RTK $RTK_VERSION is installed"
need_install=false
if ! command -v rtk >/dev/null 2>&1; then
  need_install=true
else
  ver="$(rtk --version 2>/dev/null || echo none)"
  if [[ "$ver" != *"$RTK_VERSION"* ]]; then
    echo "  installed rtk is '$ver' (pinned: $RTK_VERSION) — installing pinned version."
    need_install=true
  fi
fi
if $need_install; then
  if $DRY_RUN; then
    echo "  [dry-run] install rtk $RTK_VERSION ($PLATFORM)"
  else
    case "$PLATFORM" in
      macos) brew install rtk;;
      *)     curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \
               | RTK_VERSION="v$RTK_VERSION" sh;;
    esac
    [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
  fi
fi
if command -v rtk >/dev/null 2>&1; then
  echo "  rtk: $(rtk --version)"
  ver_now="$(rtk --version 2>/dev/null || echo none)"
  if [[ "$ver_now" != *"$RTK_VERSION"* ]]; then
    echo "  warn: rtk is '$ver_now' but this toolkit pins $RTK_VERSION."
    if [[ "$PLATFORM" == macos ]]; then
      echo "        'brew install rtk' tracks latest; to pin exactly, install the v$RTK_VERSION"
      echo "        release (RTK_VERSION=v$RTK_VERSION via install.sh) or a versioned brew formula."
    fi
  fi
  if ! rtk gain >/dev/null 2>&1; then
    echo "  warn: 'rtk gain' did not succeed. If 'rtk --version' works, the wrong crates.io 'rtk'"
    echo "        ('Rust Type Kit') may be installed — uninstall it and reinstall from Homebrew or"
    echo "        GitHub releases. (gain can also fail when the tracking DB is read-only, e.g. some"
    echo "        sandboxes — not fatal.)"
  fi
else
  if $DRY_RUN; then
    echo "  [dry-run] rtk not yet installed (would install $RTK_VERSION)"
  else
    echo "  FAIL: rtk still not on PATH after install. Open a new shell or add ~/.local/bin to PATH." >&2
    exit 4
  fi
fi

# ---------- 2. init both agents ----------
rtk_init() {
  if $DRY_RUN; then
    echo "  [dry-run] rtk $*"
    if command -v rtk >/dev/null 2>&1; then rtk "$@" --dry-run 2>&1 | sed 's/^/    /' || true; fi
  else
    rtk "$@"
  fi
}
if $DO_GLOBAL; then
  step "2/7 Init Claude Code + Cursor hooks (both)"
  rtk_init init --global --auto-patch
  rtk_init init -g --agent cursor --auto-patch
fi

# ---------- 3. global Claude skills ----------
if $DO_GLOBAL; then
  step "3/7 Copy skills to ~/.claude/skills/ (global Claude Code)"
  run mkdir -p "$HOME/.claude/skills"
  for s in rtk-adoption rtk-operations rtk-audit; do
    run cp -R "$ROOT/.claude/skills/$s" "$HOME/.claude/skills/"
  done
  echo "  skills: rtk-adoption, rtk-operations, rtk-audit -> ~/.claude/skills/"
fi

# ---------- 4. seed repo ----------
inject_snippet() {
  local target="$1" src="$2"
  if $DRY_RUN; then echo "  [dry-run] inject RTK block into $target"; return; fi
  [[ -f "$src" ]] || { echo "  skip: $src missing"; return; }
  if [[ -f "$target" ]] && grep -q 'RTK snippet' "$target"; then
    echo "  keep existing RTK block in $target"
    return
  fi
  if [[ -f "$target" ]]; then
    { printf '\n'; cat "$src"; printf '\n'; } >> "$target"
  else
    { cat "$src"; printf '\n'; } >> "$target"
  fi
  echo "  added RTK block to $target"
}
if $DO_REPO; then
  step "4/7 Seed repo: $REPO_TARGET"
  run mkdir -p "$REPO_TARGET/.cursor/rules"
  run cp -R "$ROOT/cursor-rtk/.cursor/rules/." "$REPO_TARGET/.cursor/rules/"
  run mkdir -p "$REPO_TARGET/.claude/skills"
  for s in rtk-adoption rtk-operations rtk-audit; do
    run cp -R "$ROOT/.claude/skills/$s" "$REPO_TARGET/.claude/skills/"
  done
  if [[ ! -f "$REPO_TARGET/.rtk/filters.toml" ]]; then
    run mkdir -p "$REPO_TARGET/.rtk"
    run cp "$ROOT/examples/filters.toml" "$REPO_TARGET/.rtk/filters.toml"
  else
    echo "  keep existing $REPO_TARGET/.rtk/filters.toml"
  fi
  inject_snippet "$REPO_TARGET/AGENTS.md" "$ROOT/examples/snippets/AGENTS.md"
  inject_snippet "$REPO_TARGET/CLAUDE.md" "$ROOT/examples/snippets/CLAUDE.md"
fi

# ---------- 5. governance ----------
if $DO_GLOBAL; then
  step "5/7 Apply ECI governance (add-if-missing)"
  cfg="$(config_path)"
  if $DRY_RUN; then
    echo "  [dry-run] rtk config --create + patch $cfg"
    echo "    [telemetry] enabled=false, [hooks] exclude_commands, tee=failures, RTK_TELEMETRY_DISABLED=1"
  else
    if [[ ! -f "$cfg" ]]; then rtk config --create; fi
    if ! grep -q '^\[telemetry\]' "$cfg"; then
      printf '\n[telemetry]\nenabled = false\n' >> "$cfg"
      echo "  added [telemetry] enabled = false to $cfg"
    else
      echo "  keep existing [telemetry] in $cfg"
    fi
    if ! grep -q '^\[hooks\]' "$cfg"; then
      printf '\n[hooks]\nexclude_commands = ["git rebase", "git cherry-pick", "docker exec", "^psql"]\n' >> "$cfg"
      echo "  added [hooks] exclude_commands to $cfg"
    else
      echo "  keep existing [hooks] in $cfg"
    fi
    if grep -q '^\[tee\]' "$cfg" && ! grep -q 'mode = "failures"' "$cfg"; then
      echo "  warn: [tee] mode is not \"failures\" in $cfg (left as-is — review if this is a sensitive repo)"
    fi
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      [[ -f "$rc" ]] || continue
      if ! grep -q 'RTK_TELEMETRY_DISABLED=1' "$rc"; then
        printf '\nexport RTK_TELEMETRY_DISABLED=1\n' >> "$rc"
        echo "  added RTK_TELEMETRY_DISABLED=1 to $rc"
      fi
    done
  fi
fi

# ---------- 6. trust project filters ----------
if $DO_REPO; then
  step "6/7 Trust project filters (if present)"
  if [[ ! -f "$REPO_TARGET/.rtk/filters.toml" ]]; then
    echo "  no .rtk/filters.toml in $REPO_TARGET — skipping trust"
  elif $NO_TRUST; then
    echo "  trust skipped (--no-trust); review .rtk/filters.toml, then run 'rtk trust' in $REPO_TARGET"
  elif $DRY_RUN; then
    echo "  [dry-run] rtk trust in $REPO_TARGET"
  else
    ( cd "$REPO_TARGET" && yes | rtk trust ) 2>&1 | tail -3 \
      || echo "  (rtk trust did not complete — run it manually in $REPO_TARGET)"
  fi
fi

# ---------- 7. verify ----------
step "7/7 Verify"
if $DRY_RUN; then
  echo "  [dry-run] rtk init --show + rtk verify + readiness summary"
else
  echo "  rtk init --show:"
  rtk init --show 2>&1 | sed 's/^/    /' || true
  echo "  rtk verify:"
  if $DO_REPO; then
    ( cd "$REPO_TARGET" && rtk verify ) 2>&1 | tail -6 | sed 's/^/    /' || true
  else
    rtk verify 2>&1 | tail -6 | sed 's/^/    /' || true
  fi
  echo
  echo "Ready-to-go check:"
  show="$(rtk init --show 2>/dev/null || true)"
  if echo "$show" | grep -q '\[ok\] Hook:'; then
    echo "  [ok] Claude Code hook"
  else
    echo "  [--] Claude Code hook not found (run: rtk init --global --auto-patch, then restart Claude Code)"
  fi
  if echo "$show" | grep -q '\[ok\] Cursor hook:'; then
    echo "  [ok] Cursor hook"
  else
    echo "  [--] Cursor hook not found (run: rtk init -g --agent cursor --auto-patch, then restart Cursor)"
  fi
fi

echo
echo "Done. RESTART Claude Code and Cursor so the hooks load."
echo "Next session, run a few commands then check 'rtk gain' (non-zero = savings flowing)."
echo "For a structured baseline, run the rtk-audit skill."
