#!/usr/bin/env bash
# install.sh — Install or update Canopy skills in the current project.
#
# Usage:
#   # One-liner install/update (resolves version from .canopy-version, else latest):
#   curl -sSL https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.sh | bash
#
#   # Pin to a specific version:
#   curl -sSL .../install.sh | bash -s -- --version 0.18.0
#
#   # Install from a branch, tag, or commit SHA (pre-release testing):
#   curl -sSL .../install.sh | bash -s -- --ref canopy-as-agent-skill
#
#   # Install for GitHub Copilot instead of Claude Code:
#   curl -sSL .../install.sh | bash -s -- --target copilot
#
#   # Install for BOTH platforms in one pass (.claude/skills/ and .github/skills/):
#   curl -sSL .../install.sh | bash -s -- --target both
#
#   # Local invocation:
#   bash install.sh [--version X.Y.Z | --ref GIT_REF] [--target claude|copilot|both]
#
# Canopy ships as THREE skills, all installed by this script:
#   canopy         — authoring agent (create / modify / validate / improve / scaffold)
#   canopy-debug   — trace wrapper (/canopy-debug <skill> emits phase banners + node traces)
#   canopy-runtime — execution engine (platform detection, primitives spec, op lookup, category semantics)
#                    Hidden from /; loaded ambiently via CLAUDE.md / .github/copilot-instructions.md.
#                    Install this alone if you only want to EXECUTE canopy skills (not author them).
#
# Version resolution order:
#   1. --ref flag (git branch/tag/SHA; skips version resolution; does NOT write .canopy-version)
#   2. --version flag (v<version> tag)
#   3. .canopy-version file in the current directory (v<contents> tag)
#   4. Latest release tag from GitHub API
#
# Ambient runtime activation:
#   On --target claude|both, the script idempotently writes a marker-delimited
#   canopy-runtime block to ./CLAUDE.md (auto-loaded by Claude Code).
#   On --target copilot|both, same for ./.github/copilot-instructions.md.
#   Re-running replaces the block in place; user content above/below is preserved.
#
# Re-run to update: bump .canopy-version (or pass --version / --ref) then re-invoke.
# The script is idempotent end-to-end.

set -euo pipefail

REPO_URL="https://github.com/kostiantyn-matsebora/claude-canopy"
REPO_OWNER="kostiantyn-matsebora"
REPO_NAME="claude-canopy"
SKILLS=("canopy" "canopy-debug" "canopy-runtime")

MARKER_START="<!-- canopy-runtime-begin -->"
MARKER_END="<!-- canopy-runtime-end -->"

version=""
ref=""
target="claude"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v)
            version="${2:-}"
            shift 2
            ;;
        --ref|-r)
            ref="${2:-}"
            shift 2
            ;;
        --target|-t)
            target="${2:-}"
            shift 2
            ;;
        --help|-h)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "install.sh: unknown argument: $1" >&2
            echo "install.sh: run with --help for usage" >&2
            exit 2
            ;;
    esac
done

if [[ -n "$version" && -n "$ref" ]]; then
    echo "install.sh: --version and --ref are mutually exclusive" >&2
    exit 2
fi

# Resolve target(s) — Canopy is platform-agnostic, so both are supported.
targets=()
ambient_files=()
case "$target" in
    claude)
        targets=(".claude/skills")
        ambient_files=("CLAUDE.md")
        ;;
    copilot)
        targets=(".github/skills")
        ambient_files=(".github/copilot-instructions.md")
        ;;
    both)
        targets=(".claude/skills" ".github/skills")
        ambient_files=("CLAUDE.md" ".github/copilot-instructions.md")
        ;;
    *)
        echo "install.sh: --target must be 'claude', 'copilot', or 'both' (got '$target')" >&2
        exit 2
        ;;
esac

# Resolve version / ref
git_ref=""
if [[ -n "$ref" ]]; then
    git_ref="$ref"
    echo "install.sh: using explicit ref: $git_ref"
else
    if [[ -z "$version" ]]; then
        if [[ -f .canopy-version ]]; then
            version="$(tr -d '[:space:]' < .canopy-version)"
            echo "install.sh: resolved version from .canopy-version: $version"
        else
            echo "install.sh: fetching latest release tag from GitHub…"
            latest_tag="$(curl -fsSL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" \
                | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
                | head -1)"
            if [[ -z "$latest_tag" ]]; then
                echo "install.sh: could not resolve latest release tag from GitHub" >&2
                exit 1
            fi
            version="${latest_tag#v}"
            echo "install.sh: resolved latest version: $version"
        fi
    fi
    version="${version#v}"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo "install.sh: version '$version' does not look like semver (MAJOR.MINOR.PATCH)" >&2
        exit 2
    fi
    git_ref="v$version"
fi

# Download to temp dir
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "install.sh: downloading canopy from $REPO_URL at ref '$git_ref'…"
if ! git clone --depth 1 --branch "$git_ref" "$REPO_URL" "$tmpdir/canopy" >/dev/null 2>&1; then
    echo "install.sh: failed to clone canopy at ref '$git_ref' from $REPO_URL" >&2
    echo "install.sh: does the ref exist? check $REPO_URL/branches and $REPO_URL/tags" >&2
    exit 1
fi

# Verify expected structure
for skill in "${SKILLS[@]}"; do
    if [[ ! -f "$tmpdir/canopy/skills/$skill/SKILL.md" ]]; then
        echo "install.sh: ref '$git_ref' does not contain skills/$skill/SKILL.md" >&2
        exit 1
    fi
done

# Install (idempotent: overwrites existing skill dirs)
for skills_base in "${targets[@]}"; do
    mkdir -p "$skills_base"
    for skill in "${SKILLS[@]}"; do
        dest="$skills_base/$skill"
        echo "install.sh: installing $dest"
        rm -rf "$dest"
        cp -r "$tmpdir/canopy/skills/$skill" "$dest"
    done
done

# Record installed version (only for version-pinned installs, NOT for --ref)
if [[ -z "$ref" ]]; then
    echo "$version" > .canopy-version
fi

# --- Idempotent ambient-file write: CLAUDE.md and/or copilot-instructions.md ---

build_marker_block() {
    cat <<'EOF'
<!-- canopy-runtime-begin -->
## Canopy Runtime

Any `SKILL.md` under `.claude/skills/` or `.github/skills/` that declares a `## Tree`
section is a canopy-flavored skill. Before interpreting it, load
`<skills-root>/canopy-runtime/SKILL.md` and apply the execution model defined
there — sections (`## Agent`, `## Tree`, `## Rules`, `## Response:`), tree
notation (`<<`, `>>`, `|`), control-flow and interaction primitives, op lookup
chain (skill-local ops.md → consumer project ops → framework primitives),
category directory semantics (`schemas/`/`templates/`/`commands/`/`constants/`/
`checklists/`/`policies/`/`verify/`/`references/`), subagent contract
(`EXPLORE` as first node when `## Agent` declares `**explore**`), and the
active platform runtime (`references/runtime-claude.md` or
`references/runtime-copilot.md`).

`<skills-root>` resolves to `.claude/skills/` on Claude Code and `.github/skills/`
on Copilot.
<!-- canopy-runtime-end -->
EOF
}

write_marker_block() {
    local target_file="$1"
    local block
    block="$(build_marker_block)"

    # Case 1: file doesn't exist → create with just the block
    if [[ ! -f "$target_file" ]]; then
        local dir
        dir="$(dirname "$target_file")"
        [[ -n "$dir" ]] && mkdir -p "$dir"
        printf '%s\n' "$block" > "$target_file"
        echo "install.sh: created $target_file with canopy-runtime block"
        return 0
    fi

    local begin_count end_count
    begin_count="$(grep -cFx "$MARKER_START" "$target_file" 2>/dev/null || echo 0)"
    end_count="$(grep -cFx "$MARKER_END" "$target_file" 2>/dev/null || echo 0)"

    # Case 5: malformed (unmatched markers) → refuse
    if [[ "$begin_count" -ne "$end_count" ]]; then
        echo "install.sh: malformed canopy-runtime block in $target_file (begin=$begin_count, end=$end_count). Fix manually before re-running." >&2
        return 1
    fi

    local tmp
    tmp="$(mktemp "${target_file}.XXXXXX")"

    if [[ "$begin_count" -eq 0 ]]; then
        # Case 2: no existing block → append with separating blank line
        cp "$target_file" "$tmp"
        if [[ -s "$tmp" ]] && [[ "$(tail -c1 "$tmp" 2>/dev/null | od -An -tx1 | tr -d ' ')" != "0a" ]]; then
            printf '\n' >> "$tmp"
        fi
        printf '\n%s\n' "$block" >> "$tmp"
        mv "$tmp" "$target_file"
        echo "install.sh: appended canopy-runtime block to $target_file"
    else
        # Case 3 & 4: one or more existing pairs → replace first, warn if >1
        if [[ "$begin_count" -gt 1 ]]; then
            echo "install.sh: warning — $target_file has $begin_count canopy-runtime marker pairs; rewriting only the first." >&2
        fi
        awk -v start="$MARKER_START" -v end="$MARKER_END" -v block="$block" '
            BEGIN { replaced = 0; in_block = 0 }
            !replaced && $0 == start { print block; in_block = 1; replaced = 1; next }
            in_block && $0 == end    { in_block = 0; next }
            in_block                 { next }
                                     { print }
        ' "$target_file" > "$tmp"
        mv "$tmp" "$target_file"
        echo "install.sh: updated canopy-runtime block in $target_file"
    fi
}

for ambient in "${ambient_files[@]}"; do
    write_marker_block "$ambient"
done

# --- Summary ---

echo ""
echo "install.sh: installed canopy (ref '$git_ref') to: ${targets[*]}"
if [[ -z "$ref" ]]; then
    echo "install.sh: wrote .canopy-version = $version"
else
    echo "install.sh: .canopy-version NOT written (--ref install is transient)"
fi
echo ""
echo "Slash commands now available:"
echo "  /canopy            (authoring agent)"
echo "  /canopy-debug      (trace wrapper)"
echo "  (canopy-runtime is hidden — loaded ambiently via ${ambient_files[*]})"
