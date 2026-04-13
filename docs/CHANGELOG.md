<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to Canopy are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.7.0] — 2026-04-13

### Added

- `skills/canopy-debug/skill.md` — new `canopy-debug` skill; traces any Canopy skill with live phase banners and per-node tree tracking; respects Claude Code mode (plan mode simulates mutations, edit mode executes normally)
- `skills/canopy-debug/ops.md` — skill-local ops: `EMIT_PHASE_BANNER` (renders double-box phase banners), `EXECUTE_WITH_TRACE` (drives full skill execution with tracing), `TRACE_NODE` (emits stream one-liner and overwrites trace file per state change), `TRACE_EXECUTE_NODES` (iterates nodes with mode-aware branch evaluation), `WRITE_TRACE_FILE` (overwrites `.canopy-debug-trace.log` with current full-tree snapshot)
- `skills/canopy-debug/policies/debug-output.md` — debug output protocol: dual-channel output (chat stream + trace file), phase registry with ordinals and descriptions, phase banner format, node state symbol table (`→ ⟳ ✓ ◎ ⊘ ✗ ⏸ ⊙`), stream and trace file formats, mode-aware execution rules, ASK interaction protocol, EXPLORE subagent handling, END/HALTED display

### Changed

- `docs/README.md` — added "Failures you can trace to a single node" bullet to the "Why Canopy?" section; references `/canopy-debug` for live phase and per-node tracing

---

## [0.6.0] — 2026-04-12

### Changed

- `agents/canopy-skill.md` → `agents/canopy.md` — agent renamed from `canopy-skill` to `canopy`
- `agents/canopy-skill/` → `agents/canopy/` — agent resource directory renamed to match
- `agents/canopy.md` — frontmatter `name:` updated to `canopy`; `optimization-rules.md` glob updated to `**/canopy/policies/optimization-rules.md`
- `docs/FRAMEWORK.md`, `docs/README.md`, `docs/AUTHORING.md`, `docs/CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE.md` — all `canopy-skill` agent references updated to `canopy`

---

## [0.5.0] — 2026-04-12

### Added

- `agents/canopy-skill.md` — `canopy-skill` promoted from skill to Claude Code agent; handles six operations: CREATE (new skill from description), MODIFY (targeted edits to existing skill), SCAFFOLD (blank skeleton with all dirs), CONVERT_TO_CANOPY (flat skill → Canopy format), VALIDATE (errors, warnings, optimization report), CONVERT_TO_REGULAR (Canopy → flat skill)
- `agents/canopy-skill/templates/skill.md` and `agents/canopy-skill/templates/ops.md` — skeleton templates used by the SCAFFOLD operation
- `AUTHORING.md` — manual skill authoring reference: full anatomy walkthrough, both tree syntaxes with examples, op definition patterns, primitives table, category resource directory reference, and `skill.md` content constraints
- `setup.sh` and `setup.ps1` — agent wiring: symlink/junction each bundled agent `.md` file and its resource directory into `.claude/agents/` (mirrors existing skill symlink pattern)

### Changed

- `agents/canopy-skill/policies/optimization-rules.md` — moved from `skills/canopy-skill/policies/`; content unchanged
- `agents/canopy-skill/schemas/explore-schema.json` — moved from `skills/canopy-skill/schemas/`; content unchanged
- `README.md` — Usage section rewritten around the `canopy-skill` agent (operation table with example invocations); manual authoring content replaced with a link to `AUTHORING.md`; `## Skill Anatomy` section trimmed to structural overview only; Features bullet updated to reflect agent promotion; `AUTHORING.md` added to Directory Structure
- `FRAMEWORK.md` — added `## Framework Agents` section documenting agent format, resource subdirectory conventions, and setup wiring; directory layout updated to show `agents/` alongside `skills/`
- `CONTRIBUTING.md` — sync-required file list updated to reference `agents/canopy-skill/policies/optimization-rules.md`

### Removed

- `skills/canopy-skill/skill.md` and `skills/canopy-skill/ops.md` — superseded by `agents/canopy-skill.md`

---

## [0.4.0] — 2026-04-12

### Added

- Markdown list syntax (`*` nested lists) as an alternative to box-drawing characters for tree definitions — write trees directly under `## Tree` without a fenced code block
- `examples/` documentation split out to `claude-canopy-examples` repo; canopy repo stays submodule-clean

### Changed

- `rules/skill-resources.md` — Tree format section now documents both syntaxes with examples
- `FRAMEWORK.md` — Tree Execution Model section shows both formats side-by-side; Skill-Local ops.md section shows markdown list format as alternative for branching op definitions
- `README.md` — `## Tree` anatomy and minimal example updated to lead with markdown list syntax
- `skills/canopy-skill/policies/optimization-rules.md` — Rule 6 updated to list both formats; markdown list marked as preferred for new/simple trees

---

## [0.3.2] — 2026-04-12

### Added

- community health files for GitHub: `CONTRIBUTING.md`, issue templates, and pull request template

---

## [0.3.1] — 2026-04-12

### Changed

- `README.md` — replaced the broken external examples link with plain repo mention, made the `## Agent` example generic instead of project-specific, and reduced duplication between `Skill Anatomy` and `Writing a Skill`

---

## [0.3.0] — 2026-04-12

### Fixed

- `setup.ps1` — create directory junctions in `.claude/skills/` for each bundled canopy skill so VS Code discovers them outside the submodule boundary
- `setup.sh` — create symlinks in `.claude/skills/` for each bundled canopy skill for the same reason on Linux/macOS

---

## [0.2.0] — 2026-04-12

### Added

- `setup.sh` and `setup.ps1` — submodule setup scripts; create wiring files in the user's project so Claude Code can see both canopy internals and project skills
- `skills/canopy-skill/` — renamed from `optimize-skill`; bundled meta-skill for auditing and optimizing Canopy skills

### Changed

- `README.md` — added "How It Works" diagram showing full skill anatomy; added inline examples in Features; added Skill Anatomy section; rewrote Quick Start Option A (vendored via curl/tar, explicit warning against git clone) and Option B (git submodule + setup script); removed manual Submodule Wiring section
- `FRAMEWORK.md` — removed content duplicated in README (intro paragraph, submodule directory tree, Skill Anatomy); added pointer to README for setup instructions
- `rules/skill-resources.md` — updated standalone note to reference setup scripts

---

## [0.1.0] — 2026-04-12

### Added

- Initial framework release — extracted from home-data-center project
- `FRAMEWORK.md` — full Canopy specification (tree execution model, op lookup order, category resources)
- `rules/skill-resources.md` — ambient rules for standalone use
- `skills/shared/framework/ops.md` — framework primitives: `IF`, `ELSE_IF`, `ELSE`, `BREAK`, `END`, `ASK`, `SHOW_PLAN`, `VERIFY_EXPECTED`
- `skills/shared/project/ops.md` — stub with commented examples for project-wide ops
- `skills/shared/ops.md` — redirect stub
- `skills/canopy-skill/` — bundled meta-skill for auditing and optimizing Canopy skills
- `README.md` — setup instructions for standalone and submodule usage
- `LICENSE` — MIT
- Submodule wiring documentation
