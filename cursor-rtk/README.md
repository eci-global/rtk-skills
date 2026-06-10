# RTK Cursor Rules — ECI Distribution

Cursor companion to the Claude Code skills (`rtk-adoption` / `rtk-operations`). Same content, Cursor-native format.

See the [root README](../README.md) for full package layout, validation, and team rollout steps.

## What's inside

```
cursor-rtk/.cursor/rules/
├── rtk.mdc              # alwaysApply: true — lean behavioral rule (~250 words,
│                        #   kept small on purpose: always-on rules cost tokens
│                        #   in EVERY request, and this rule exists to SAVE tokens)
└── rtk-operations.mdc   # agent-requested (description-based) — setup, ROI
                         #   reporting, troubleshooting, custom filters; loads
                         #   only when the conversation is about RTK
```

## Adoption — two levels (mirrors RTK itself)

### Repo level (recommended for ECI enterprise repos)
1. Copy the `cursor-rtk/.cursor/` folder into the repository root as `.cursor/`.
2. Commit it. Every colleague and CI runner on the repo gets the rules automatically.
3. Each developer runs once per machine: `rtk init -g --agent cursor` → restart Cursor
   (installs the hooks.json preToolUse rewrite so commands are filtered transparently).

**Windows note:** WSL developers init from inside WSL (full hook support). Native Windows
developers still commit the rules — agents prefix `rtk` explicitly because auto-rewrite
hooks require a Unix shell. See `.claude/skills/rtk-adoption/references/windows.md`.

### Global level (per developer machine)
Cursor's user-level rules live in **Cursor Settings → Rules** (plain text, no .mdc
frontmatter). Paste this short version there:

> This machine uses RTK (Rust Token Killer) to cut LLM token use 60-90% on terminal
> output. If command output looks raw/verbose, prefix with `rtk` (rtk git status,
> rtk test <cmd>, rtk grep, rtk read). After a failed command, read the tee log path
> RTK prints instead of re-running. Need raw output once: RTK_DISABLED=1 <cmd>.
> Never suggest uninstalling RTK to work around one command.

Pair it with the machine-level hook: `rtk init -g --agent cursor`.

### Org-wide sync (optional)
Cursor supports Remote Rules: Settings → Rules → "Remote Rule (GitHub)" pointing at a
shared rules repo. Host these .mdc files in an internal `eci-cursor-rules` repo and
teams auto-sync updates.

## Why two rules instead of one

`alwaysApply: true` rules are injected into every request — a token tax. The always-on
rule is therefore minimal (just the per-command behavior the agent needs constantly).
Everything situational (setup, reporting, filter authoring) sits in the agent-requested
rule, which Cursor loads only when its description matches the conversation. Net effect:
the rule set itself stays token-cheap, consistent with its purpose.

## Verify after install

1. Restart Cursor, open a repo with the rules committed.
2. Ask the agent to run `git status` → output should be compact (3 lines, not 40).
3. `rtk gain` → savings counter increments.
4. Ask the agent "how much have we saved with RTK this week?" → the operations rule
   should load and produce a `rtk gain --weekly` report.

Maintained alongside: `.claude/skills/rtk-adoption` / `rtk-operations` (Claude Code) and
the RTK Enterprise Adoption Guide. Keep the three in sync when RTK behavior changes —
RTK versions move fast (docs said 0.28.x; live installer currently ships 0.42.x).

Run `./scripts/validate.sh` from the repo root before sharing with teams.
