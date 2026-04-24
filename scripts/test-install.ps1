#!/usr/bin/env pwsh
<#
test-install.ps1 — end-to-end idempotency tests for install.ps1.

Exercises the 9 scenarios documented in the install.ps1 contract:
  1. Clean install (file doesn't exist)
  2. Existing user content above and below marker block
  3. Re-run idempotency (block already present — should be no-op)
  4. Drift restoration (block manually edited — should be rewritten)
  5. Multiple marker pairs (corruption — should warn + rewrite first only)
  6. Malformed markers (missing -end — should refuse to write)
  7. -Target both writes to BOTH CLAUDE.md and .github/copilot-instructions.md
  8. Trailing newline preservation
  9. -Ref branch install (uses local branch; does NOT write .canopy-version)

Requires: local v0.17.0 tag on the canopy repo + git in PATH.

Usage:
  pwsh scripts/test-install.ps1 [-Keep]
#>

[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = "Continue"

$RepoRoot    = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$InstallPs1  = Join-Path $RepoRoot "install.ps1"
$TestTag     = "v0.17.0"
$TestBranch  = "canopy-as-agent-skill"

# Check prereqs
git -C $RepoRoot rev-parse $TestTag 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "local tag $TestTag does not exist. Create with: git -C $RepoRoot tag $TestTag"
    exit 2
}

$TmpDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "canopy-test-$([guid]::NewGuid())")

# Create a patched install.ps1 pointing at the local repo via file:// URL
$TestInstall = Join-Path $TmpDir "install.ps1"
$repoUrlEscaped = "file:///" + ($RepoRoot -replace '\\', '/')
(Get-Content $InstallPs1 -Raw) `
    -replace '"https://github.com/kostiantyn-matsebora/claude-canopy"', "`"$repoUrlEscaped`"" `
    | Set-Content -Path $TestInstall -NoNewline

$script:Passed = 0
$script:Failed = 0
$script:Results = @()

function Record-Result($status, $name, $detail = "") {
    $script:Results += "$status`: $name$(if ($detail) { ' — ' + $detail } else { '' })"
    if ($status -eq "PASS") { $script:Passed++ } else { $script:Failed++ }
}

function Run-Install {
    param([string[]]$InstallArgs)
    $stdout = Join-Path $TmpDir "last.stdout"
    $stderr = Join-Path $TmpDir "last.stderr"
    & pwsh -NoProfile -File $TestInstall @InstallArgs > $stdout 2> $stderr
    return $LASTEXITCODE
}

function Block-Present($file) {
    if (-not (Test-Path $file)) { return $false }
    $c = Get-Content $file -Raw
    return ($c -match '<!-- canopy-runtime-begin -->' -and $c -match '<!-- canopy-runtime-end -->')
}

function Block-Count($file) {
    if (-not (Test-Path $file)) { return 0 }
    $c = Get-Content $file -Raw
    return ([regex]::Matches($c, '<!-- canopy-runtime-begin -->')).Count
}

# ----- T1: clean install -----
$t1 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t1")
Push-Location $t1
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    $rc = Run-Install @("-Version", "0.17.0")
    if ($rc -eq 0 -and (Block-Present "CLAUDE.md") -and (Block-Count "CLAUDE.md") -eq 1) {
        Record-Result "PASS" "T1 clean install creates CLAUDE.md with single block"
    } else {
        Record-Result "FAIL" "T1 clean install" (Get-Content (Join-Path $TmpDir "last.stderr") -Raw -ErrorAction SilentlyContinue)
    }
} finally { Pop-Location }

# ----- T2: user content preserved -----
$t2 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t2")
Push-Location $t2
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    Set-Content "CLAUDE.md" "# My Project`n`nCustom notes above.`n" -NoNewline
    Run-Install @("-Version", "0.17.0") | Out-Null
    $c = Get-Content "CLAUDE.md" -Raw
    if ($c -match '# My Project' -and $c -match 'Custom notes above\.' -and (Block-Present "CLAUDE.md")) {
        Record-Result "PASS" "T2 existing user content preserved alongside new block"
    } else {
        Record-Result "FAIL" "T2 user content preservation"
    }
} finally { Pop-Location }

# ----- T3: re-run idempotency -----
$t3 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t3")
Push-Location $t3
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    Run-Install @("-Version", "0.17.0") | Out-Null
    $first = Get-Content "CLAUDE.md" -Raw
    Run-Install @("-Version", "0.17.0") | Out-Null
    $second = Get-Content "CLAUDE.md" -Raw
    if ($first -eq $second -and (Block-Count "CLAUDE.md") -eq 1) {
        Record-Result "PASS" "T3 re-run is a no-op; exactly one block"
    } else {
        Record-Result "FAIL" "T3 re-run idempotency"
    }
} finally { Pop-Location }

# ----- T4: drift restoration -----
$t4 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t4")
Push-Location $t4
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    Run-Install @("-Version", "0.17.0") | Out-Null
    $corrupted = (Get-Content "CLAUDE.md" -Raw) -replace '## Canopy Runtime', '## CORRUPTED HEADING'
    Set-Content "CLAUDE.md" $corrupted -NoNewline
    Run-Install @("-Version", "0.17.0") | Out-Null
    $c = Get-Content "CLAUDE.md" -Raw
    if ($c -match '## Canopy Runtime' -and $c -notmatch '## CORRUPTED HEADING') {
        Record-Result "PASS" "T4 drift restored to current version"
    } else {
        Record-Result "FAIL" "T4 drift restoration"
    }
} finally { Pop-Location }

# ----- T5: multiple marker pairs -----
$t5 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t5")
Push-Location $t5
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    Run-Install @("-Version", "0.17.0") | Out-Null
    Add-Content "CLAUDE.md" "`n<!-- canopy-runtime-begin -->`n## Old block content`n<!-- canopy-runtime-end -->`n"
    Run-Install @("-Version", "0.17.0") | Out-Null
    $stderr = Get-Content (Join-Path $TmpDir "last.stderr") -Raw -ErrorAction SilentlyContinue
    if ($stderr -match 'canopy-runtime marker pairs' -and (Block-Count "CLAUDE.md") -eq 2 -and (Get-Content "CLAUDE.md" -Raw) -match '## Old block content') {
        Record-Result "PASS" "T5 multiple pairs: warn + rewrite first only"
    } else {
        Record-Result "FAIL" "T5 multiple pairs"
    }
} finally { Pop-Location }

# ----- T6: malformed (missing -end) -----
$t6 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t6")
Push-Location $t6
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    Set-Content "CLAUDE.md" "# Some file`n`n<!-- canopy-runtime-begin -->`npartial block with no end`n" -NoNewline
    $before = Get-Content "CLAUDE.md" -Raw
    $rc = Run-Install @("-Version", "0.17.0")
    $after = Get-Content "CLAUDE.md" -Raw
    $stderr = Get-Content (Join-Path $TmpDir "last.stderr") -Raw -ErrorAction SilentlyContinue
    # PowerShell Write-Error causes non-zero exit via $ErrorActionPreference=Stop inside install.ps1;
    # the function returns after Write-Error, but exit code propagates via $? handling.
    # For this test we check: stderr contains the error AND the file is unchanged.
    if ($stderr -match 'malformed canopy-runtime block' -and $before -eq $after) {
        Record-Result "PASS" "T6 malformed: refuses to write, file unchanged"
    } else {
        Record-Result "FAIL" "T6 malformed block" "before=$($before.Length) after=$($after.Length) stderr-matched=$($stderr -match 'malformed')"
    }
} finally { Pop-Location }

# ----- T7: -Target both -----
$t7 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t7")
Push-Location $t7
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    Run-Install @("-Version", "0.17.0", "-Target", "both") | Out-Null
    if ((Block-Present "CLAUDE.md") -and (Block-Present ".github/copilot-instructions.md")) {
        Record-Result "PASS" "T7 -Target both writes CLAUDE.md + copilot-instructions.md"
    } else {
        Record-Result "FAIL" "T7 -Target both"
    }
} finally { Pop-Location }

# ----- T8: trailing newline preservation -----
$t8 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t8")
Push-Location $t8
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    [System.IO.File]::WriteAllText("CLAUDE.md", "No trailing newline here")
    Run-Install @("-Version", "0.17.0") | Out-Null
    $bytes = [System.IO.File]::ReadAllBytes("CLAUDE.md")
    if ($bytes.Length -gt 0 -and ($bytes[-1] -eq 0x0A -or $bytes[-1] -eq 0x0D)) {
        Record-Result "PASS" "T8 file ends with newline after install"
    } else {
        Record-Result "FAIL" "T8 trailing newline"
    }
} finally { Pop-Location }

# ----- T9: -Ref branch install -----
$t9 = New-Item -ItemType Directory -Path (Join-Path $TmpDir "t9")
Push-Location $t9
[System.IO.Directory]::SetCurrentDirectory($PWD.Path)
try {
    git -C $RepoRoot rev-parse $TestBranch 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $rc = Run-Install @("-Ref", $TestBranch, "-Target", "claude")
        if ($rc -eq 0 `
            -and (Test-Path ".claude/skills/canopy") `
            -and (Test-Path ".claude/skills/canopy-debug") `
            -and (Test-Path ".claude/skills/canopy-runtime") `
            -and -not (Test-Path ".canopy-version")) {
            Record-Result "PASS" "T9 -Ref branch: 3 skills installed, .canopy-version NOT written"
        } else {
            Record-Result "FAIL" "T9 -Ref branch install"
        }
    } else {
        Record-Result "FAIL" "T9 -Ref skipped (branch $TestBranch not present)"
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "===== test-install.ps1 results ====="
foreach ($r in $script:Results) { Write-Host "  $r" }
Write-Host ""
Write-Host "Passed: $script:Passed / $($script:Passed + $script:Failed)"
if ($Keep) { Write-Host "Temp dir preserved at: $TmpDir" }

if (-not $Keep) { Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue }
if ($script:Failed -eq 0) { exit 0 } else { exit 1 }
