# adopt.ps1 — one-command RTK adoption for ECI on native Windows (Claude Code + Cursor).
#
# PowerShell port of scripts/adopt.sh. Run in PowerShell or Windows Terminal on
# native Windows (for WSL2, use adopt.sh instead).
#
# What it does:
#   1. Installs RTK pinned to RTK_VERSION (Windows zip + SHA-256 checksum, to $env:USERPROFILE\.local\bin).
#   2. Inits BOTH agents: rtk init --global (Claude Code) + rtk init -g --agent cursor.
#      Native Windows has NO auto-rewrite hook — init installs rules/RTK.md; agents prefix `rtk`.
#   3. Copies rtk-adoption / rtk-operations / rtk-audit to $env:USERPROFILE\.claude\skills\ (global).
#   4. Seeds the target repo: .cursor/rules, .claude/skills, .rtk/filters.toml (if absent),
#      and an RTK block in AGENTS.md + CLAUDE.md (idempotent, marker-guarded).
#   5. Applies ECI governance: [telemetry] off, [hooks] exclude_commands, tee=failures
#      (add-if-missing), RTK_TELEMETRY_DISABLED=1 as a User env var.
#   6. Runs rtk trust in the target repo (if .rtk/filters.toml present). -NoTrust to skip.
#   7. Verifies: rtk init --show + rtk verify, prints a readiness summary + restart reminder.
#
# Flags: -DryRun  -Scope global|repo|both  -Repo <path>  -NoTrust  -Yes  -Help
# Default scope: both. Default repo: current directory.
[CmdletBinding()]
param(
  [switch]$DryRun,
  [ValidateSet("global","repo","both")][string]$Scope = "both",
  [string]$Repo = (Get-Location).Path,
  [switch]$NoTrust,
  [switch]$Yes,
  [switch]$Help
)
$ErrorActionPreference = "Stop"

function Show-Usage {
  Write-Host @"
Usage: pwsh ./scripts/adopt.ps1 [options]

One-command RTK adoption for ECI on native Windows (Claude Code + Cursor).
  -DryRun              Predict actions, write nothing
  -Scope SCOPE         global | repo | both (default: both)
  -Repo PATH           Repo to seed (default: current directory)
  -NoTrust             Seed .rtk/filters.toml but do NOT run rtk trust (review first)
  -Yes                 Skip the confirm prompt
  -Help                Show this help
"@
}

if ($Help) { Show-Usage; exit 0 }

$Root        = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RtkVersion  = if (Test-Path "$Root\RTK_VERSION") { (Get-Content "$Root\RTK_VERSION" -Raw).Trim() } else { "0.43.0" }
$InstallDir  = "$env:USERPROFILE\.local\bin"

$RepoResolved = Resolve-Path $Repo -ErrorAction SilentlyContinue
$RepoAbs = if ($RepoResolved) { $RepoResolved.Path } else { $Repo }
$RootAbs = (Resolve-Path $Root).Path

$DoGlobal = ($Scope -eq "global" -or $Scope -eq "both")
$DoRepo   = ($Scope -eq "repo"   -or $Scope -eq "both")
if ($RepoAbs -eq $RootAbs) {
  if ($DoRepo) {
    Write-Host "note: -Repo is the toolkit repo itself - skipping repo seeding (cd into a product repo, or use -Repo <path>)."
  }
  $DoRepo = $false
}

function Step([string]$m) { Write-Host ""; Write-Host "==> $m" }
function Run-Op([scriptblock]$sb, [string]$desc) {
  if ($DryRun) { Write-Host "  [dry-run] $desc" } else { & $sb }
}

function Config-Path { Join-Path $env:APPDATA "rtk\config.toml" }

function Invoke-RtkInit {
  param([string[]]$InitArgs)
  if ($DryRun) {
    Write-Host "  [dry-run] rtk $($InitArgs -join ' ')"
    if (Get-Command rtk -ErrorAction SilentlyContinue) {
      & rtk @InitArgs '--dry-run' 2>&1 | ForEach-Object { "    $_" } | Write-Host
    }
  } else {
    & rtk @InitArgs
    if ($LASTEXITCODE -ne 0) { throw "rtk $($InitArgs -join ' ') failed (exit $LASTEXITCODE)" }
  }
}

function Invoke-InjectSnippet {
  param([string]$Target, [string]$Src)
  if ($DryRun) { Write-Host "  [dry-run] inject RTK block into $Target"; return }
  if (-not (Test-Path $Src)) { Write-Host "  skip: $Src missing"; return }
  if ((Test-Path $Target) -and (Select-String -Path $Target -Quiet -Pattern 'RTK snippet')) {
    Write-Host "  keep existing RTK block in $Target"; return
  }
  $content = [IO.File]::ReadAllText($Src)
  if (Test-Path $Target) {
    [IO.File]::AppendAllText($Target, "`n$content")
  } else {
    [IO.File]::WriteAllText($Target, $content)
  }
  Write-Host "  added RTK block to $Target"
}

function Install-Rtk {
  $need = $false
  if (-not (Get-Command rtk -ErrorAction SilentlyContinue)) {
    $need = $true
  } else {
    $ver = & rtk --version 2>$null
    if ($LASTEXITCODE -ne 0 -or $ver -notlike "*$RtkVersion*") {
      Write-Host "  installed rtk is '$ver' (pinned: $RtkVersion) - installing pinned version."
      $need = $true
    }
  }
  if ($need) {
    if ($DryRun) { Write-Host "  [dry-run] install rtk $RtkVersion (Windows zip to $InstallDir)"; return }
    $base = "https://github.com/rtk-ai/rtk/releases/download/v$RtkVersion"
    $zipUrl       = "$base/rtk-x86_64-pc-windows-msvc.zip"
    $checksumsUrl = "$base/checksums.txt"
    $tmp = Join-Path $env:TEMP "rtk-install-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp "rtk.zip"
    Write-Host "  downloading $zipUrl"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
    Write-Host "  downloading checksums..."
    $checksums = (Invoke-WebRequest -Uri $checksumsUrl -UseBasicParsing).Content
    $expected = ($checksums -split "`n" |
      Where-Object { $_ -match 'rtk-x86_64-pc-windows-msvc\.zip\s*$' } |
      ForEach-Object { ($_ -split '\s+')[0].Trim() } | Select-Object -First 1)
    if ($expected) {
      $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
      if ($actual -ne $expected.ToLower()) { throw "checksum mismatch: expected=$expected actual=$actual" }
      Write-Host "  checksum verified."
    } else {
      Write-Host "  warn: checksum not found in checksums.txt - installed unverified."
    }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
    Move-Item (Join-Path $tmp "rtk.exe") (Join-Path $InstallDir "rtk.exe") -Force
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$InstallDir*") {
      [Environment]::SetEnvironmentVariable("Path", ($userPath + ";$InstallDir"), "User")
      Write-Host "  added $InstallDir to user PATH (open a new terminal to pick it up)."
    }
    if ($env:Path -notlike "*$InstallDir*") { $env:Path += ";$InstallDir" }
    Remove-Item $tmp -Recurse -Force
  }
  if (Get-Command rtk -ErrorAction SilentlyContinue) {
    Write-Host "  rtk: $(& rtk --version 2>$null)"
    & rtk gain 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "  warn: 'rtk gain' did not succeed. If 'rtk --version' works, the wrong crates.io 'rtk'"
      Write-Host "        ('Rust Type Kit') may be installed - uninstall it and reinstall from GitHub releases."
    }
  } elseif ($DryRun) {
    Write-Host "  [dry-run] rtk not yet installed (would install $RtkVersion)"
  } else {
    throw "rtk still not on PATH after install. Open a new terminal or add $InstallDir to PATH."
  }
}

Write-Host "RTK adoption (ECI, native Windows) - pinned RTK $RtkVersion"
Write-Host "scope: $Scope | repo: $RepoAbs | dry-run: $DryRun"
if ($DoGlobal) { Write-Host "  + global (machine hook + global Claude skills + governance)" }
if ($DoRepo)   { Write-Host "  + repo (seed $RepoAbs + rtk trust)" }
Write-Host "  note: native Windows has no auto-rewrite hook - agents prefix 'rtk' per the committed rules."

if (-not $DryRun -and -not $Yes) {
  Write-Host ""
  Write-Host "This will install/init RTK, copy skills, seed the repo, apply governance, and verify."
  $ans = Read-Host "Proceed? [y/N]"
  if ($ans -notmatch '^[Yy]') { Write-Host "aborted"; exit 0 }
}

# 1. ensure RTK
Step "1/7 Ensure RTK $RtkVersion is installed"
Install-Rtk

# 2. init both agents
if ($DoGlobal) {
  Step "2/7 Init Claude Code + Cursor hooks (both)"
  Invoke-RtkInit -InitArgs @("init","--global","--auto-patch")
  Invoke-RtkInit -InitArgs @("init","-g","--agent","cursor","--auto-patch")
}

# 3. global Claude skills
if ($DoGlobal) {
  Step "3/7 Copy skills to $env:USERPROFILE\.claude\skills\ (global Claude Code)"
  $gs = "$env:USERPROFILE\.claude\skills"
  Run-Op { New-Item -ItemType Directory -Force -Path $gs | Out-Null } "mkdir $gs"
  foreach ($s in "rtk-adoption","rtk-operations","rtk-audit") {
    Run-Op { Copy-Item (Join-Path $Root ".claude\skills\$s") $gs -Recurse -Force } "copy $s -> $gs"
  }
  Write-Host "  skills: rtk-adoption, rtk-operations, rtk-audit -> $gs"
}

# 4. seed repo
if ($DoRepo) {
  Step "4/7 Seed repo: $RepoAbs"
  Run-Op { New-Item -ItemType Directory -Force -Path "$RepoAbs\.cursor\rules" | Out-Null } "mkdir $RepoAbs\.cursor\rules"
  Run-Op { Copy-Item "$Root\cursor-rtk\.cursor\rules\*" "$RepoAbs\.cursor\rules\" -Recurse -Force } "copy cursor rules"
  Run-Op { New-Item -ItemType Directory -Force -Path "$RepoAbs\.claude\skills" | Out-Null } "mkdir $RepoAbs\.claude\skills"
  foreach ($s in "rtk-adoption","rtk-operations","rtk-audit") {
    Run-Op { Copy-Item (Join-Path $Root ".claude\skills\$s") "$RepoAbs\.claude\skills\" -Recurse -Force } "copy skill $s"
  }
  if (-not (Test-Path "$RepoAbs\.rtk\filters.toml")) {
    Run-Op { New-Item -ItemType Directory -Force -Path "$RepoAbs\.rtk" | Out-Null; Copy-Item "$Root\examples\filters.toml" "$RepoAbs\.rtk\filters.toml" -Force } "copy .rtk\filters.toml"
  } else {
    Write-Host "  keep existing $RepoAbs\.rtk\filters.toml"
  }
  Invoke-InjectSnippet "$RepoAbs\AGENTS.md" "$Root\examples\snippets\AGENTS.md"
  Invoke-InjectSnippet "$RepoAbs\CLAUDE.md" "$Root\examples\snippets\CLAUDE.md"
}

# 5. governance
if ($DoGlobal) {
  Step "5/7 Apply ECI governance (add-if-missing)"
  $cfg = Config-Path
  if ($DryRun) {
    Write-Host "  [dry-run] rtk config --create + patch $cfg"
    Write-Host "    [telemetry] enabled=false, [hooks] exclude_commands, tee=failures, RTK_TELEMETRY_DISABLED=1"
  } else {
    if (-not (Test-Path $cfg)) {
      & rtk config --create 2>&1 | Out-Null
      if (-not (Test-Path $cfg)) {
        $cfgDir = Split-Path -Parent $cfg
        if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null }
        Set-Content -Path $cfg -Value ""
        Write-Host "  warn: 'rtk config --create' did not produce $cfg - created an empty one to patch."
      }
    }
    $txt = [IO.File]::ReadAllText($cfg)
    if ($txt -notmatch '(?m)^\[telemetry\]') {
      [IO.File]::AppendAllText($cfg, "`n[telemetry]`nenabled = false`n")
      Write-Host "  added [telemetry] enabled = false to $cfg"
    } else { Write-Host "  keep existing [telemetry] in $cfg" }
    if ($txt -notmatch '(?m)^\[hooks\]') {
      [IO.File]::AppendAllText($cfg, "`n[hooks]`n" + 'exclude_commands = ["git rebase", "git cherry-pick", "docker exec", "^psql"]' + "`n")
      Write-Host "  added [hooks] exclude_commands to $cfg"
    } else { Write-Host "  keep existing [hooks] in $cfg" }
    if ($txt -match '(?m)^\[tee\]' -and $txt -notmatch 'mode = "failures"') {
      Write-Host "  warn: [tee] mode is not `"failures`" in $cfg (left as-is - review if sensitive repo)"
    }
    if ([Environment]::GetEnvironmentVariable("RTK_TELEMETRY_DISABLED", "User") -ne "1") {
      [Environment]::SetEnvironmentVariable("RTK_TELEMETRY_DISABLED", "1", "User")
      Write-Host "  set RTK_TELEMETRY_DISABLED=1 (User env var)"
    } else { Write-Host "  keep existing RTK_TELEMETRY_DISABLED=1" }
  }
}

# 6. trust
if ($DoRepo) {
  Step "6/7 Trust project filters (if present)"
  if (-not (Test-Path "$RepoAbs\.rtk\filters.toml")) {
    Write-Host "  no .rtk\filters.toml in $RepoAbs - skipping trust"
  } elseif ($NoTrust) {
    Write-Host "  trust skipped (-NoTrust); review .rtk\filters.toml, then run 'rtk trust' in $RepoAbs"
  } elseif ($DryRun) {
    Write-Host "  [dry-run] rtk trust in $RepoAbs"
  } else {
    "y" | & rtk trust 2>&1 | Select-Object -Last 3 | Write-Host
    if ($LASTEXITCODE -ne 0) { Write-Host "  (rtk trust did not complete - run it manually in $RepoAbs)" }
  }
}

# 7. verify
Step "7/7 Verify"
if ($DryRun) {
  Write-Host "  [dry-run] rtk init --show + rtk verify + readiness summary"
} else {
  Write-Host "  rtk init --show:"
  & rtk init --show 2>&1 | ForEach-Object { "    $_" } | Write-Host
  Write-Host "  rtk verify:"
  & rtk verify 2>&1 | Select-Object -Last 6 | ForEach-Object { "    $_" } | Write-Host
  Write-Host ""
  Write-Host "Ready-to-go check:"
  $show = & rtk init --show 2>$null | Out-String
  if ($show -match '\[ok\] Hook:') { Write-Host "  [ok] Claude Code hook" }
  else { Write-Host "  [--] Claude Code hook not found (run: rtk init --global --auto-patch, then restart Claude Code)" }
  if ($show -match '\[ok\] Cursor hook:') { Write-Host "  [ok] Cursor hook" }
  else { Write-Host "  [--] Cursor hook: rules-only / no auto-rewrite (native Windows - agents prefix 'rtk' per committed rules)" }
}

Write-Host ""
Write-Host "Done. RESTART Claude Code and Cursor so the rules/RTK.md load."
Write-Host "Native Windows: no auto-rewrite - agents prefix 'rtk' (rtk git status, rtk test <cmd>) per the committed rules."
Write-Host "Next session, run a few commands then check 'rtk gain' (non-zero = savings flowing)."
Write-Host "For a structured baseline, run the rtk-audit skill."
