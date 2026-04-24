#!/usr/bin/env bash
# test-install.sh — end-to-end idempotency tests for install.sh.
#
# Exercises the 9 scenarios documented in the install.sh contract:
#   1. Clean install (file doesn't exist)
#   2. Existing user content above and below marker block
#   3. Re-run idempotency (block already present — should be no-op)
#   4. Drift restoration (block manually edited — should be rewritten)
#   5. Multiple marker pairs (corruption — should warn + rewrite first only)
#   6. Malformed markers (missing -end — should refuse to write)
#   7. --target both writes to BOTH CLAUDE.md and .github/copilot-instructions.md
#   8. Trailing newline preservation
#   9. --ref branch install (uses local branch; does NOT write .canopy-version)
#
# Requires: local v0.17.0 tag on the canopy repo + jq in PATH.
#
# Usage:
#   bash scripts/test-install.sh [--keep]
#     --keep   do not clean up the temp test dir on success (for debugging)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"
TEST_TAG="v0.17.0"
TEST_BRANCH="canopy-as-agent-skill"

KEEP=0
[[ "${1:-}" == "--keep" ]] && KEEP=1

# Check prerequisites
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq required" >&2; exit 2; }
git -C "$REPO_ROOT" rev-parse "$TEST_TAG" >/dev/null 2>&1 \
    || { echo "FAIL: local tag $TEST_TAG does not exist. Create it with: git -C $REPO_ROOT tag $TEST_TAG" >&2; exit 2; }

TMP_DIR="$(mktemp -d)"
trap '[[ $KEEP -eq 0 ]] && rm -rf "$TMP_DIR"' EXIT

# Create a patched install.sh that points at the local repo via file:// URL
TEST_INSTALL="$TMP_DIR/install.sh"
sed 's|REPO_URL="https://github.com/kostiantyn-matsebora/claude-canopy"|REPO_URL="file://'"$REPO_ROOT"'"|' \
    "$INSTALL_SH" > "$TEST_INSTALL"

PASSED=0
FAILED=0
RESULTS=()

record() {
    local status="$1"; local name="$2"; local detail="${3:-}"
    RESULTS+=("$status: $name${detail:+ — $detail}")
    if [[ "$status" == "PASS" ]]; then ((PASSED++)); else ((FAILED++)); fi
}

run_install() {
    # Suppress normal output unless debugging; capture stderr for inspection.
    bash "$TEST_INSTALL" "$@" > "$TMP_DIR/last.stdout" 2> "$TMP_DIR/last.stderr"
    return $?
}

block_present() {
    grep -qF '<!-- canopy-runtime-begin -->' "$1" 2>/dev/null \
        && grep -qF '<!-- canopy-runtime-end -->' "$1" 2>/dev/null
}

block_count() {
    grep -cFx '<!-- canopy-runtime-begin -->' "$1" 2>/dev/null || echo 0
}

# ----- Test 1: Clean install -----
cd "$TMP_DIR" && mkdir t1 && cd t1
if run_install --version 0.17.0 && block_present CLAUDE.md && [[ "$(block_count CLAUDE.md)" -eq 1 ]]; then
    record PASS "T1 clean install creates CLAUDE.md with single block"
else
    record FAIL "T1 clean install" "$(cat "$TMP_DIR/last.stderr")"
fi

# ----- Test 2: Existing user content preserved -----
cd "$TMP_DIR" && mkdir t2 && cd t2
printf '# My Project\n\nCustom notes above.\n' > CLAUDE.md
if run_install --version 0.17.0 \
   && grep -qF '# My Project' CLAUDE.md \
   && grep -qF 'Custom notes above.' CLAUDE.md \
   && block_present CLAUDE.md; then
    record PASS "T2 existing user content preserved alongside new block"
else
    record FAIL "T2 existing user content preservation"
fi

# ----- Test 3: Re-run idempotency -----
cd "$TMP_DIR" && mkdir t3 && cd t3
run_install --version 0.17.0 > /dev/null 2>&1
cp CLAUDE.md CLAUDE.md.first
run_install --version 0.17.0 > /dev/null 2>&1
if diff -q CLAUDE.md CLAUDE.md.first >/dev/null 2>&1 && [[ "$(block_count CLAUDE.md)" -eq 1 ]]; then
    record PASS "T3 re-run is a no-op; exactly one block"
else
    record FAIL "T3 re-run idempotency"
fi

# ----- Test 4: Drift restoration -----
cd "$TMP_DIR" && mkdir t4 && cd t4
run_install --version 0.17.0 > /dev/null 2>&1
# Corrupt the block body
sed -i 's|## Canopy Runtime|## CORRUPTED HEADING|' CLAUDE.md
run_install --version 0.17.0 > /dev/null 2>&1
if grep -qF '## Canopy Runtime' CLAUDE.md && ! grep -qF '## CORRUPTED HEADING' CLAUDE.md; then
    record PASS "T4 drift restored to current version"
else
    record FAIL "T4 drift restoration"
fi

# ----- Test 5: Multiple marker pairs (corruption) -----
cd "$TMP_DIR" && mkdir t5 && cd t5
run_install --version 0.17.0 > /dev/null 2>&1
# Append a second marker pair
cat >> CLAUDE.md <<'EOF'

<!-- canopy-runtime-begin -->
## Old block content
stuff
<!-- canopy-runtime-end -->
EOF
run_install --version 0.17.0 > "$TMP_DIR/last.stdout" 2> "$TMP_DIR/last.stderr"
# Expect: warning to stderr; first block replaced; second block intact
if grep -qF 'canopy-runtime marker pairs' "$TMP_DIR/last.stderr" \
   && [[ "$(block_count CLAUDE.md)" -eq 2 ]] \
   && grep -qF '## Old block content' CLAUDE.md; then
    record PASS "T5 multiple pairs: warn + rewrite first only"
else
    record FAIL "T5 multiple pairs"
fi

# ----- Test 6: Malformed (missing -end) -----
cd "$TMP_DIR" && mkdir t6 && cd t6
cat > CLAUDE.md <<'EOF'
# Some file

<!-- canopy-runtime-begin -->
partial block with no end
EOF
CLAUDE_before="$(cat CLAUDE.md)"
run_install --version 0.17.0 > "$TMP_DIR/last.stdout" 2> "$TMP_DIR/last.stderr"
rc=$?
CLAUDE_after="$(cat CLAUDE.md)"
if [[ $rc -ne 0 ]] \
   && grep -qF 'malformed canopy-runtime block' "$TMP_DIR/last.stderr" \
   && [[ "$CLAUDE_before" == "$CLAUDE_after" ]]; then
    record PASS "T6 malformed: refuses to write, file unchanged"
else
    record FAIL "T6 malformed block"
fi

# ----- Test 7: --target both writes BOTH files -----
cd "$TMP_DIR" && mkdir t7 && cd t7
if run_install --version 0.17.0 --target both \
   && block_present CLAUDE.md \
   && block_present .github/copilot-instructions.md; then
    record PASS "T7 --target both writes CLAUDE.md + copilot-instructions.md"
else
    record FAIL "T7 --target both"
fi

# ----- Test 8: Trailing newline preservation -----
cd "$TMP_DIR" && mkdir t8 && cd t8
printf 'No trailing newline here' > CLAUDE.md
run_install --version 0.17.0 > /dev/null 2>&1
# File must end with newline
if [[ -s CLAUDE.md ]] && [[ "$(tail -c1 CLAUDE.md | od -An -tx1 | tr -d ' ')" == "0a" ]]; then
    record PASS "T8 file ends with newline after install"
else
    record FAIL "T8 trailing newline"
fi

# ----- Test 9: --ref branch install -----
cd "$TMP_DIR" && mkdir t9 && cd t9
if git -C "$REPO_ROOT" rev-parse "$TEST_BRANCH" >/dev/null 2>&1; then
    if run_install --ref "$TEST_BRANCH" --target claude \
       && [[ -d .claude/skills/canopy ]] \
       && [[ -d .claude/skills/canopy-debug ]] \
       && [[ -d .claude/skills/canopy-runtime ]] \
       && [[ ! -f .canopy-version ]]; then
        record PASS "T9 --ref branch: 3 skills installed, .canopy-version NOT written"
    else
        record FAIL "T9 --ref branch install"
    fi
else
    record FAIL "T9 --ref skipped (branch $TEST_BRANCH not present)"
fi

echo ""
echo "===== test-install.sh results ====="
for r in "${RESULTS[@]}"; do
    echo "  $r"
done
echo ""
echo "Passed: $PASSED / $((PASSED + FAILED))"
[[ $KEEP -eq 1 ]] && echo "Temp dir preserved at: $TMP_DIR"

[[ $FAILED -eq 0 ]] && exit 0 || exit 1
