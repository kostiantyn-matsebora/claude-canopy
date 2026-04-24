#!/usr/bin/env pwsh
<#
install.ps1 — Install or update Canopy skills in the current project.

Usage:
  # One-liner install/update (resolves version from .canopy-version, else latest):
  irm https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.ps1 | iex

  # Pin to a specific version:
  irm .../install.ps1 -OutFile install.ps1
  pwsh ./install.ps1 -Version 0.18.0

  # Install from a branch, tag, or commit SHA (pre-release testing):
  pwsh ./install.ps1 -Ref canopy-as-agent-skill

  # Install for GitHub Copilot instead of Claude Code:
  pwsh ./install.ps1 -Target copilot

  # Install for BOTH platforms in one pass (.claude/skills/ and .github/skills/):
  pwsh ./install.ps1 -Target both

  # Local invocation:
  pwsh ./install.ps1 [-Version X.Y.Z | -Ref GIT_REF] [-Target claude|copilot|both]

Canopy ships as THREE skills, all installed by this script:
  canopy         — authoring agent (create / modify / validate / improve / scaffold)
  canopy-debug   — trace wrapper (/canopy-debug <skill> emits phase banners + node traces)
  canopy-runtime — execution engine (platform detection, primitives spec, op lookup, category semantics).
                   Hidden from /; loaded ambiently via CLAUDE.md / .github/copilot-instructions.md.
                   Install this alone if you only want to EXECUTE canopy skills (not author them).

Version resolution order:
  1. -Ref parameter (git branch/tag/SHA; skips version resolution; does NOT write .canopy-version)
  2. -Version parameter (v<version> tag)
  3. .canopy-version file in the current directory (v<contents> tag)
  4. Latest release tag from GitHub API

Ambient runtime activation:
  On -Target claude|both, the script idempotently writes a marker-delimited
  canopy-runtime block to ./CLAUDE.md.
  On -Target copilot|both, same for ./.github/copilot-instructions.md.
  Re-running replaces the block in place; user content above/below is preserved.

Re-run to update: bump .canopy-version (or pass -Version / -Ref) then re-invoke.
The script is idempotent end-to-end.
#>

[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$Ref = "",
    [ValidateSet("claude", "copilot", "both")]
    [string]$Target = "claude"
)

$ErrorActionPreference = "Stop"

$RepoUrl   = "https://github.com/kostiantyn-matsebora/claude-canopy"
$RepoOwner = "kostiantyn-matsebora"
$RepoName  = "claude-canopy"
$Skills    = @("canopy", "canopy-debug", "canopy-runtime")

$MarkerStart = "<!-- canopy-runtime-begin -->"
$MarkerEnd   = "<!-- canopy-runtime-end -->"

if (-not [string]::IsNullOrWhiteSpace($Version) -and -not [string]::IsNullOrWhiteSpace($Ref)) {
    Write-Error "install.ps1: -Version and -Ref are mutually exclusive"
    exit 2
}

# Resolve target(s) — Canopy is platform-agnostic, so both are supported.
switch ($Target) {
    "claude"  { $Targets = @(".claude/skills");                       $AmbientFiles = @("CLAUDE.md") }
    "copilot" { $Targets = @(".github/skills");                       $AmbientFiles = @(".github/copilot-instructions.md") }
    "both"    { $Targets = @(".claude/skills", ".github/skills");     $AmbientFiles = @("CLAUDE.md", ".github/copilot-instructions.md") }
}

# Resolve version / ref
if (-not [string]::IsNullOrWhiteSpace($Ref)) {
    $GitRef = $Ref
    Write-Host "install.ps1: using explicit ref: $GitRef"
} else {
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
    $Version = $Version -replace '^v', ''
    if ($Version -notmatch '^\d+\.\d+\.\d+') {
        Write-Error "install.ps1: version '$Version' does not look like semver (MAJOR.MINOR.PATCH)"
        exit 2
    }
    $GitRef = "v$Version"
}

# Download to temp dir
$TmpDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "canopy-install-$([guid]::NewGuid())")

try {
    Write-Host "install.ps1: downloading canopy from $RepoUrl at ref '$GitRef'..."
    $cloneTarget = Join-Path $TmpDir "canopy"
    git clone --depth 1 --branch $GitRef $RepoUrl $cloneTarget 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "install.ps1: failed to clone canopy at ref '$GitRef' from $RepoUrl. Does the ref exist? Check $RepoUrl/branches and $RepoUrl/tags"
        exit 1
    }

    foreach ($skill in $Skills) {
        $skillMd = Join-Path $cloneTarget "skills" $skill "SKILL.md"
        if (-not (Test-Path $skillMd)) {
            Write-Error "install.ps1: ref '$GitRef' does not contain skills/$skill/SKILL.md"
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

    # Record installed version (only for version-pinned installs, NOT for -Ref)
    if ([string]::IsNullOrWhiteSpace($Ref)) {
        Set-Content -Path ".canopy-version" -Value $Version -NoNewline
        Add-Content -Path ".canopy-version" -Value ([System.Environment]::NewLine) -NoNewline
    }

    # --- Idempotent ambient-file write: CLAUDE.md and/or copilot-instructions.md ---

    function Build-MarkerBlock {
        return @"
<!-- canopy-runtime-begin -->
## Canopy Runtime

Any ``SKILL.md`` under ``.claude/skills/`` or ``.github/skills/`` that declares a ``## Tree``
section is a canopy-flavored skill. Before interpreting it, load
``<skills-root>/canopy-runtime/SKILL.md`` and apply the execution model defined
there — sections (``## Agent``, ``## Tree``, ``## Rules``, ``## Response:``), tree
notation (``<<``, ``>>``, ``|``), control-flow and interaction primitives, op lookup
chain (skill-local ops.md → consumer project ops → framework primitives),
category directory semantics (``schemas/``/``templates/``/``commands/``/``constants/``/
``checklists/``/``policies/``/``verify/``/``references/``), subagent contract
(``EXPLORE`` as first node when ``## Agent`` declares ``**explore**``), and the
active platform runtime (``references/runtime-claude.md`` or
``references/runtime-copilot.md``).

``<skills-root>`` resolves to ``.claude/skills/`` on Claude Code and ``.github/skills/``
on Copilot.
<!-- canopy-runtime-end -->
"@
    }

    function Write-MarkerBlock {
        param([string]$TargetFile)

        $block = Build-MarkerBlock

        # Case 1: file doesn't exist → create
        if (-not (Test-Path $TargetFile)) {
            $dir = Split-Path -Parent $TargetFile
            if ($dir -and -not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            # Default to platform-native line endings for new file
            [System.IO.File]::WriteAllText($TargetFile, $block + [System.Environment]::NewLine)
            Write-Host "install.ps1: created $TargetFile with canopy-runtime block"
            return
        }

        $content = [System.IO.File]::ReadAllText($TargetFile)
        # Detect line-ending style: if file has any CRLF, preserve CRLF; else LF.
        $useCrlf = $content.Contains("`r`n")
        $nl = if ($useCrlf) { "`r`n" } else { "`n" }

        $beginCount = ([regex]::Matches($content, [regex]::Escape($MarkerStart))).Count
        $endCount   = ([regex]::Matches($content, [regex]::Escape($MarkerEnd))).Count

        # Case 5: malformed → refuse
        if ($beginCount -ne $endCount) {
            Write-Error "install.ps1: malformed canopy-runtime block in $TargetFile (begin=$beginCount, end=$endCount). Fix manually before re-running."
            return
        }

        # Normalize block to file's line-ending style
        $blockNormalized = $block -replace "`r?`n", $nl

        if ($beginCount -eq 0) {
            # Case 2: no existing block → append with separating blank line
            if ($content.Length -gt 0 -and -not $content.EndsWith($nl)) {
                $content += $nl
            }
            $content += $nl + $blockNormalized + $nl
            [System.IO.File]::WriteAllText($TargetFile, $content)
            Write-Host "install.ps1: appended canopy-runtime block to $TargetFile"
            return
        }

        # Case 3 & 4: one or more existing pairs → replace first, warn if >1
        if ($beginCount -gt 1) {
            Write-Warning "install.ps1: $TargetFile has $beginCount canopy-runtime marker pairs; rewriting only the first."
        }
        $pattern = '(?s)' + [regex]::Escape($MarkerStart) + '.*?' + [regex]::Escape($MarkerEnd)
        $re = New-Object System.Text.RegularExpressions.Regex($pattern)
        $newContent = $re.Replace($content, [System.Text.RegularExpressions.Regex]::Escape($blockNormalized) -replace '\\(.)', '$1', 1)
        # Simpler replace-once:
        $newContent = $re.Replace($content, { param($m) $blockNormalized }, 1)

        [System.IO.File]::WriteAllText($TargetFile, $newContent)
        Write-Host "install.ps1: updated canopy-runtime block in $TargetFile"
    }

    foreach ($ambient in $AmbientFiles) {
        Write-MarkerBlock -TargetFile $ambient
    }

    Write-Host ""
    Write-Host "install.ps1: installed canopy (ref '$GitRef') to: $($Targets -join ', ')"
    if ([string]::IsNullOrWhiteSpace($Ref)) {
        Write-Host "install.ps1: wrote .canopy-version = $Version"
    } else {
        Write-Host "install.ps1: .canopy-version NOT written (-Ref install is transient)"
    }
    Write-Host ""
    Write-Host "Slash commands now available:"
    Write-Host "  /canopy            (authoring agent)"
    Write-Host "  /canopy-debug      (trace wrapper)"
    Write-Host "  (canopy-runtime is hidden — loaded ambiently via $($AmbientFiles -join ', '))"
} finally {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    }
}
