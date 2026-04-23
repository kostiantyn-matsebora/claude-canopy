#!/usr/bin/env pwsh
<#
install.ps1 — Install or update Canopy skills in the current project.

Usage:
  # One-liner install/update (resolves version from .canopy-version, else latest):
  irm https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.ps1 | iex

  # Pin to a specific version (download first, then run):
  irm https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.ps1 -OutFile install.ps1
  pwsh ./install.ps1 -Version 0.18.0

  # Install for GitHub Copilot instead of Claude Code:
  pwsh ./install.ps1 -Target copilot

  # Install for BOTH platforms in one pass (.claude/skills/ and .github/skills/):
  pwsh ./install.ps1 -Target both

  # Local invocation:
  pwsh ./install.ps1 [-Version X.Y.Z] [-Target claude|copilot|both]

Version resolution order:
  1. -Version parameter (explicit)
  2. .canopy-version file in the current directory
  3. Latest release tag from GitHub

Re-run to update: bump .canopy-version (or pass -Version) then re-invoke.
The script is idempotent; it overwrites the installed skill dirs in place.
#>

[CmdletBinding()]
param(
    [string]$Version = "",
    [ValidateSet("claude", "copilot", "both")]
    [string]$Target = "claude"
)

$ErrorActionPreference = "Stop"

$RepoUrl   = "https://github.com/kostiantyn-matsebora/claude-canopy"
$RepoOwner = "kostiantyn-matsebora"
$RepoName  = "claude-canopy"
$Skills    = @("canopy", "canopy-debug")

# Resolve target(s) — Canopy is platform-agnostic, so both are supported.
$Targets = switch ($Target) {
    "claude"  { @(".claude/skills") }
    "copilot" { @(".github/skills") }
    "both"    { @(".claude/skills", ".github/skills") }
}

# Resolve version
if ([string]::IsNullOrWhiteSpace($Version)) {
    if (Test-Path ".canopy-version") {
        $Version = (Get-Content ".canopy-version" -Raw).Trim()
        Write-Host "install.ps1: resolved version from .canopy-version: $Version"
    } else {
        Write-Host "install.ps1: fetching latest release tag from GitHub..."
        try {
            $latest = Invoke-RestMethod "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
        } catch {
            Write-Error "install.ps1: could not resolve latest release tag from GitHub: $_"
            exit 1
        }
        $Version = $latest.tag_name -replace '^v', ''
        Write-Host "install.ps1: resolved latest version: $Version"
    }
}

# Normalize: strip any leading 'v'
$Version = $Version -replace '^v', ''

if ($Version -notmatch '^\d+\.\d+\.\d+') {
    Write-Error "install.ps1: version '$Version' does not look like semver (MAJOR.MINOR.PATCH)"
    exit 2
}

# Download to temp dir
$TmpDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "canopy-install-$([guid]::NewGuid())")

try {
    Write-Host "install.ps1: downloading canopy v$Version..."
    $cloneTarget = Join-Path $TmpDir "canopy"
    git clone --depth 1 --branch "v$Version" $RepoUrl $cloneTarget 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "install.ps1: failed to clone canopy v$Version from $RepoUrl. Does the tag exist? Check $RepoUrl/tags"
        exit 1
    }

    # Verify expected structure
    foreach ($skill in $Skills) {
        $skillMd = Join-Path $cloneTarget "skills" $skill "SKILL.md"
        if (-not (Test-Path $skillMd)) {
            Write-Error "install.ps1: tag v$Version does not contain skills/$skill/SKILL.md"
            exit 1
        }
    }

    # Install (idempotent: overwrites existing skill dirs)
    foreach ($skillsBase in $Targets) {
        New-Item -ItemType Directory -Path $skillsBase -Force | Out-Null
        foreach ($skill in $Skills) {
            $dest = Join-Path $skillsBase $skill
            Write-Host "install.ps1: installing $dest"
            if (Test-Path $dest) {
                Remove-Item -Recurse -Force $dest
            }
            Copy-Item -Recurse (Join-Path $cloneTarget "skills" $skill) $dest
        }
    }

    # Record installed version
    Set-Content -Path ".canopy-version" -Value $Version -NoNewline
    Add-Content -Path ".canopy-version" -Value ([System.Environment]::NewLine) -NoNewline

    Write-Host ""
    Write-Host "install.ps1: installed canopy v$Version to: $($Targets -join ', ')"
    Write-Host "install.ps1: wrote .canopy-version"
    Write-Host ""
    Write-Host "Slash commands now available:"
    foreach ($skill in $Skills) {
        Write-Host "  /$skill"
    }
} finally {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    }
}
