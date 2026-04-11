# Changelog

All notable changes to Canopy are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
