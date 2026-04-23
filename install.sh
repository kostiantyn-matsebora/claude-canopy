#!/usr/bin/env bash
# install.sh — Install or update Canopy skills in the current project.
#
# Usage:
#   # One-liner install/update (resolves version from .canopy-version, else latest):
#   curl -sSL https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.sh | bash
#
#   # Pin to a specific version:
#   curl -sSL https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.sh \
#     | bash -s -- --version 0.18.0
#
#   # Install for GitHub Copilot instead of Claude Code:
#   curl -sSL https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.sh \
#     | bash -s -- --target copilot
#
#   # Install for BOTH platforms in one pass (.claude/skills/ and .github/skills/):
#   curl -sSL https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.sh \
#     | bash -s -- --target both
#
#   # Local invocation:
#   bash install.sh [--version X.Y.Z] [--target claude|copilot|both]
#
# Version resolution order:
#   1. --version flag (explicit)
#   2. .canopy-version file in the current directory
#   3. Latest release tag from GitHub
#
# Re-run to update: bump .canopy-version (or pass --version) then re-invoke.
# The script is idempotent; it overwrites the installed skill dirs in place.

set -euo pipefail

REPO_URL="https://github.com/kostiantyn-matsebora/claude-canopy"
REPO_OWNER="kostiantyn-matsebora"
REPO_NAME="claude-canopy"
SKILLS=("canopy" "canopy-debug")

version=""
target="claude"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v)
            version="${2:-}"
            shift 2
            ;;
        --target|-t)
            target="${2:-}"
            shift 2
            ;;
        --help|-h)
            sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "install.sh: unknown argument: $1" >&2
            echo "install.sh: run with --help for usage" >&2
            exit 2
            ;;
    esac
done

# Resolve target(s) — Canopy is platform-agnostic, so both are supported.
targets=()
case "$target" in
    claude)  targets=(".claude/skills") ;;
    copilot) targets=(".github/skills") ;;
    both)    targets=(".claude/skills" ".github/skills") ;;
    *)
        echo "install.sh: --target must be 'claude', 'copilot', or 'both' (got '$target')" >&2
        exit 2
        ;;
esac

# Resolve version
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

# Normalize: strip any leading 'v'
version="${version#v}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "install.sh: version '$version' does not look like semver (MAJOR.MINOR.PATCH)" >&2
    exit 2
fi

# Download to temp dir
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "install.sh: downloading canopy v$version…"
if ! git clone --depth 1 --branch "v$version" "$REPO_URL" "$tmpdir/canopy" >/dev/null 2>&1; then
    echo "install.sh: failed to clone canopy v$version from $REPO_URL" >&2
    echo "install.sh: does the tag v$version exist? check $REPO_URL/tags" >&2
    exit 1
fi

# Verify expected structure
for skill in "${SKILLS[@]}"; do
    if [[ ! -f "$tmpdir/canopy/skills/$skill/SKILL.md" ]]; then
        echo "install.sh: tag v$version does not contain skills/$skill/SKILL.md" >&2
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

# Record installed version
echo "$version" > .canopy-version

echo ""
echo "install.sh: installed canopy v$version to: ${targets[*]}"
echo "install.sh: wrote .canopy-version"
echo ""
echo "Slash commands now available:"
for skill in "${SKILLS[@]}"; do
    echo "  /$skill"
done
