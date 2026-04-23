# bump-version — Expected State

After `bump-version` completes successfully:

- [ ] `.canopy-version` contains exactly `<new_version>\n` (no other text)
- [ ] `.claude-plugin/plugin.json` has `"version": "<new_version>"`
- [ ] `.claude-plugin/marketplace.json` has `metadata.version = "<new_version>"` AND `plugins[0].version = "<new_version>"`
- [ ] `docs/CHANGELOG.md` has a new `## [<new_version>] — <YYYY-MM-DD>` section at the top (below the file header) with at least one categorized entry
- [ ] A single new commit `chore: release v<new_version>` is on HEAD
- [ ] A local tag `v<new_version>` points at that commit
- [ ] The tag has NOT been pushed (git push must remain a manual, explicit step)
