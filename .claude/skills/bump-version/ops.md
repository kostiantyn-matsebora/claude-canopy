# bump-version — Local Ops

---

## BUMP_VERSION_SITES << new_version

Update the version string in every Canopy version-bearing file. All four sites must end at `new_version`.

* BUMP_VERSION_SITES << new_version
  * replace the entire contents of `.canopy-version` with `new_version\n`
  * in `.claude-plugin/plugin.json`, set the top-level `version` field to `new_version`
  * in `.claude-plugin/marketplace.json`:
    * set `metadata.version` to `new_version`
    * set `plugins[0].version` to `new_version` (the `canopy` plugin entry)
  * verify every write succeeded; if any write fails, STOP and report the partial state so the user can recover

---

## BUMP_CHANGELOG << new_version

Prepend a new version entry to `docs/CHANGELOG.md` using today's date.

* BUMP_CHANGELOG << new_version
  * read recent git commits since the last tag >> commits
  * classify each commit into Added / Changed / Fixed / Removed buckets based on conventional commit prefix (`feat:` → Added, `refactor:`/`perf:` → Changed, `fix:` → Fixed, commits with `!` or `BREAKING` note → Changed (BREAKING))
  * compose the entry header: `## [<new_version>] — <YYYY-MM-DD>`
  * prepend the entry above the first existing version section, keeping the top-of-file header intact
