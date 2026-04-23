#!/usr/bin/env bash
# Validate the canopy repo against the agentskills.io spec + Canopy's release invariants.
#
# Checks:
#   1. Each skills/<name>/SKILL.md has valid YAML frontmatter with:
#        - name: 1-64 chars, ^[a-z0-9]+(-[a-z0-9]+)*$, matches parent dir
#        - description: 1-1024 chars, non-empty
#   2. .claude-plugin/plugin.json is valid JSON with name, description, version
#   3. .claude-plugin/marketplace.json is valid JSON with name, owner.name,
#      and a non-empty plugins array
#   4. The version string matches across all four sites:
#        .canopy-version
#        .claude-plugin/plugin.json : .version
#        .claude-plugin/marketplace.json : .metadata.version
#        .claude-plugin/marketplace.json : .plugins[0].version
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more failures (details printed to stderr)
#
# Dependencies: bash 4+, jq, awk, tr, head

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
errors=()

fail() {
    errors+=("$1")
}

# Extract a flat scalar frontmatter field (key → value) from a SKILL.md file.
# Strips surrounding single or double quotes from the value. Prints empty if
# the key is absent or the frontmatter is malformed.
get_frontmatter_field() {
    local file="$1" key="$2"
    awk -v key="$key" '
        BEGIN { state = 0 }
        /^---[[:space:]]*$/ {
            if (state == 0) { state = 1; next }
            if (state == 1) { exit }
        }
        state == 1 {
            # Match "key: value" at top-level (no leading whitespace)
            re = "^" key "[[:space:]]*:[[:space:]]*"
            if (match($0, re)) {
                val = substr($0, RLENGTH + 1)
                # Strip matching surrounding quotes
                if (val ~ /^".*"$/) val = substr(val, 2, length(val) - 2)
                else if (val ~ /^\x27.*\x27$/) val = substr(val, 2, length(val) - 2)
                print val
                exit
            }
        }
    ' "$file"
}

check_skill() {
    local skill_dir="$1"
    local skill_md="$skill_dir/SKILL.md"
    local rel="${skill_md#${REPO}/}"
    local name_expected
    name_expected="$(basename "$skill_dir")"

    if [[ ! -f "$skill_md" ]]; then
        fail "$rel: SKILL.md missing from skill directory"
        return
    fi

    if [[ "$(head -n 1 "$skill_md" | tr -d '\r')" != "---" ]]; then
        fail "$rel: missing YAML frontmatter (must start with ---)"
        return
    fi

    local name description
    name="$(get_frontmatter_field "$skill_md" "name")"
    description="$(get_frontmatter_field "$skill_md" "description")"

    if [[ -z "$name" ]]; then
        fail "$rel: frontmatter.name is empty or missing"
    else
        if (( ${#name} > 64 )); then
            fail "$rel: frontmatter.name ${#name} chars exceeds max 64"
        fi
        if ! [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            fail "$rel: frontmatter.name '$name' must be lowercase letters, numbers, and hyphens only (no leading/trailing/consecutive hyphens)"
        fi
        if [[ "$name" != "$name_expected" ]]; then
            fail "$rel: frontmatter.name '$name' must match parent directory '$name_expected'"
        fi
    fi

    if [[ -z "$description" ]]; then
        fail "$rel: frontmatter.description is empty or missing"
    elif (( ${#description} > 1024 )); then
        fail "$rel: frontmatter.description ${#description} chars exceeds max 1024"
    fi
}

check_plugin_manifest() {
    local file="$REPO/.claude-plugin/plugin.json"
    local rel=".claude-plugin/plugin.json"
    if [[ ! -f "$file" ]]; then
        fail "$rel: file missing"
        return
    fi
    if ! jq empty "$file" 2>/dev/null; then
        fail "$rel: invalid JSON"
        return
    fi
    local field
    for field in name description version; do
        if [[ -z "$(jq -r --arg f "$field" '.[$f] // ""' "$file")" ]]; then
            fail "$rel: required field '$field' missing or empty"
        fi
    done
}

check_marketplace_manifest() {
    local file="$REPO/.claude-plugin/marketplace.json"
    local rel=".claude-plugin/marketplace.json"
    if [[ ! -f "$file" ]]; then
        fail "$rel: file missing"
        return
    fi
    if ! jq empty "$file" 2>/dev/null; then
        fail "$rel: invalid JSON"
        return
    fi
    local field
    for field in name owner plugins; do
        if ! jq -e --arg f "$field" 'has($f)' "$file" >/dev/null; then
            fail "$rel: required field '$field' missing"
        fi
    done
    if [[ -z "$(jq -r '.owner.name // ""' "$file")" ]]; then
        fail "$rel: owner.name is empty or missing"
    fi
    if [[ "$(jq '.plugins | length' "$file")" == "0" ]]; then
        fail "$rel: plugins must be a non-empty array"
    fi
}

check_version_sync() {
    local plugin="$REPO/.claude-plugin/plugin.json"
    local market="$REPO/.claude-plugin/marketplace.json"
    local cv="$REPO/.canopy-version"

    if [[ ! -f "$cv" ]]; then
        fail ".canopy-version: file missing"
        return
    fi
    [[ -f "$plugin" && -f "$market" ]] || return  # manifest checks above will have reported missing files

    local canopy_version plugin_version market_meta market_plugin0
    canopy_version="$(tr -d '[:space:]' < "$cv")"
    plugin_version="$(jq -r '.version // ""' "$plugin")"
    market_meta="$(jq -r '.metadata.version // ""' "$market")"
    market_plugin0="$(jq -r '.plugins[0].version // ""' "$market")"

    if [[ "$canopy_version" != "$plugin_version" ]] \
       || [[ "$canopy_version" != "$market_meta" ]] \
       || [[ "$canopy_version" != "$market_plugin0" ]]; then
        fail "version drift across sites:
  .canopy-version = '$canopy_version'
  plugin.json .version = '$plugin_version'
  marketplace.json .metadata.version = '$market_meta'
  marketplace.json .plugins[0].version = '$market_plugin0'"
    fi
}

# Main
if ! command -v jq >/dev/null 2>&1; then
    echo "validate.sh: jq is required but not found in PATH" >&2
    exit 2
fi

skills_root="$REPO/skills"
if [[ ! -d "$skills_root" ]]; then
    fail "skills/: directory missing at repo root"
else
    for dir in "$skills_root"/*/; do
        [[ -d "$dir" ]] || continue
        check_skill "${dir%/}"
    done
fi

check_plugin_manifest
check_marketplace_manifest
check_version_sync

if (( ${#errors[@]} > 0 )); then
    echo "validation failed:" >&2
    for e in "${errors[@]}"; do
        # Indent multi-line messages
        while IFS= read -r line; do
            echo "  - $line" >&2
        done <<< "$e"
    done
    exit 1
fi

echo "all checks passed"
