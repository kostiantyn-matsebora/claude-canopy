---
name: bump-version
description: Bump the Canopy framework version across all four version sites (.canopy-version, .claude-plugin/plugin.json, .claude-plugin/marketplace.json), prepend a CHANGELOG entry, and create a local git tag. Use when preparing a Canopy release.
argument-hint: "<new-version>  (e.g. 0.18.0)"
---

New version: $ARGUMENTS

---

## Agent

**explore** — reads the current version from `.canopy-version`, the version fields in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, and the most recent CHANGELOG entry to confirm all version sites are in sync before bumping.

---

## Tree

* bump-version
  * EXPLORE >> context
  * IF << $ARGUMENTS is not a valid semver string (MAJOR.MINOR.PATCH)
    * END Version argument is not valid semver — expected MAJOR.MINOR.PATCH
  * IF << new version is not greater than context.current_version
    * END New version must be greater than context.current_version
  * IF << context has any version-site drift (sites disagree before bump)
    * Report the drift in SHOW_PLAN so the user sees it
  * bind new_version = $ARGUMENTS
  * bind tag_name = `v` + new_version
  * Read recent git commits since last tag into context.commit_log
  * Draft a CHANGELOG entry categorising commits into Added / Changed / Fixed / Removed
  * SHOW_PLAN >> current_version | new_version | tag_name | files_to_update | changelog_preview | pre-bump_drift_warnings
  * ASK << Proceed? | Yes | Adjust changelog | No
  * IF << No
    * END Release bump cancelled.
  * IF << Adjust changelog
    * Accept user-provided edits to the drafted changelog entry; loop back to SHOW_PLAN
  * BUMP_VERSION_SITES << new_version
  * BUMP_CHANGELOG << new_version
  * Commit all changes: `git add -A && git commit -m "chore: release <tag_name>"`
  * Create local tag: `git tag <tag_name>`
  * VERIFY_EXPECTED << verify/verify-expected.md
  * Report: **tag_name created locally; push with `git push origin master <tag_name>` to trigger the release workflow.**

## Rules

- Never push — tag creation and commit are LOCAL ONLY; the user controls when to push.
- All four version sites must be updated atomically — partial updates are an error.
- Preserve existing CHANGELOG entries; only prepend the new one below the header.
- If the tag already exists locally, fail before making any changes.
- Do not modify `.canopy-version` or the manifests if the version string cannot be located unambiguously.

## Response: new_version | tag_name | files_updated | changelog_entry_added | push_command
