# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Canopy Is

Canopy is a declarative framework for writing skills as **syntax trees of named operations**, distributed as [agentskills.io](https://agentskills.io)-format Agent Skills. A skill is a `SKILL.md` file with four sections:

1. **Frontmatter** — `name`, `description` (required); optional `argument-hint`, `license`, `metadata`, `allowed-tools`
2. **`## Agent`** (optional) — declares an `**explore**` subagent; output contract is always `schemas/explore-schema.json`
3. **`## Tree`** — sequential execution pipeline with `IF`/`ELSE_IF`/`ELSE`/`SWITCH`/`CASE`/`FOR_EACH` branching (markdown list `*` or box-drawing fenced block)
4. **`## Rules`** — skill-wide invariants
5. **`## Response:`** — output format declaration

## Repo Layout (v0.17.0+)

This repo ships three installable Agent Skills under `skills/`, split along authoring-vs-execution lines:

| Skill | Role | Notes |
|-------|------|-------|
| `canopy/` | **Authoring agent** — create / modify / validate / improve / scaffold / refactor / advise / convert Canopy skills. | Invokes as `/canopy`. Depends on `canopy-runtime` for the framework spec. Ops loaded via `SWITCH`/`CASE` dispatch. |
| `canopy-debug/` | **Trace wrapper** — run any canopy-flavored skill with phase banners + per-node tracing. | Invokes as `/canopy-debug <skill>`. |
| `canopy-runtime/` | **Execution engine** — interprets canopy-flavored skills: platform detection, sections/notation/primitives spec, op lookup chain, category semantics, subagent contract. | Hidden from `/` menu (`user-invocable: false`). Loaded ambiently via `CLAUDE.md` / `.github/copilot-instructions.md` (install script writes a marker block). Install this alone to just *execute* canopy skills without authoring. |

Plus:

- `.claude-plugin/plugin.json` — Claude Code plugin manifest (makes the whole repo installable as a plugin via `/plugin install canopy@claude-canopy`)
- `.claude-plugin/marketplace.json` — marketplace catalog (makes the repo a marketplace that users can add via `/plugin marketplace add kostiantyn-matsebora/claude-canopy`)
- `docs/` — `FRAMEWORK.md`, `AUTHORING.md`, `CHEATSHEET.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `README.md`
- `assets/` — logo / icon files referenced by docs
- `.canopy-version` — single-line version string (machine-readable)
- `LICENSE`

The repo is intentionally shaped so the SAME `skills/canopy/`, `skills/canopy-debug/`, and `skills/canopy-runtime/` directories serve all three install paths:
1. **Claude Code plugin** — `.claude-plugin/plugin.json` at repo root + `skills/<name>/SKILL.md` matches the Claude Code plugin layout. Skills become `/canopy:canopy`, `/canopy:canopy-debug` (plugin-namespaced; canopy-runtime is hidden).
2. **`gh skill install`** — reads `skills/*/SKILL.md` from the repo directly. Lands skills at `.claude/skills/<name>/`; slash commands are `/canopy` and `/canopy-debug` (no namespace).
3. **`install.sh` / `install.ps1`** — same placement as gh-skill-install PLUS writes a canopy-runtime marker block to `CLAUDE.md` or `.github/copilot-instructions.md` for ambient runtime activation.

Keep this single-source-of-truth property when adding skills: put them under `skills/<name>/` only. Don't create parallel copies.

**Authoring vs. execution split:** the `canopy` skill (authoring agent) depends on `canopy-runtime` (execution engine) via sibling-relative reads (`../canopy-runtime/references/...`). `canopy-runtime` is the minimum install: a consumer who only wants to *execute* existing canopy skills can install just `canopy-runtime` and skip `canopy`. The install script installs all three by default.

## Op Lookup Order

When a tree node has an `ALL_CAPS` identifier, look up in this order:
1. `<skill>/ops.md` — skill-local
2. Consumer-defined cross-skill ops (optional; consumers package these as their own skill — no built-in location)
3. `skills/canopy-runtime/references/framework-ops.md` — framework primitives (`IF`, `ELSE_IF`, `ELSE`, `SWITCH`, `CASE`, `DEFAULT`, `FOR_EACH`, `BREAK`, `END`, `ASK`, `SHOW_PLAN`, `VERIFY_EXPECTED`)

Primitives are never overridden.

## Tree Notation

`<<` = input, `>>` = output/displayed fields, `|` = separator between options or fields.

```
skill-name
├── OP_NAME << input >> output
├── ASK << Proceed? | Yes | No
├── IF << condition
│   └── branch-op or natural language
└── ELSE
    └── other action
```

## Category Resource Directories

Each skill directory may contain subdirectories; behavior is determined by directory name:

| Directory | Behavior |
|-----------|----------|
| `schemas/` | Structure definitions: subagent output contracts, input/config file shapes, report template skeletons |
| `templates/` | Fillable output documents with `<token>` placeholders — substituted from context, written to target path |
| `commands/` | `.ps1`/`.sh` scripts with `# === Section Name ===` headers — execute named section, capture output |
| `constants/` | Read-only lookup data: mapping tables, enum-like value lists, fixed configuration values |
| `checklists/` | Evaluation criteria lists (`- [ ] ...`) — iterated by ops to assess compliance or correctness |
| `policies/` | Behavioural constraints: what the skill must/must not do, consent requirements, output protocols |
| `verify/` | Expected-state checklists consumed exclusively by `VERIFY_EXPECTED` |
| `references/` | Supporting documentation loaded on demand (per the agentskills.io progressive-disclosure pattern) |

Reference pattern in SKILL.md: `Read \`<category>/<file>\` for <brief description>.` — load at point of use, not front-loaded.

## Key Files

- `docs/FRAMEWORK.md` — canonical framework specification (single source of truth)
- `docs/AUTHORING.md` — manual skill authoring reference

**canopy (authoring agent):**
- `skills/canopy/SKILL.md` — agent body: loads canopy-runtime spec up-front (sibling-relative `../canopy-runtime/...`), then dispatches deterministically to one of 10 ops via `SWITCH/CASE`
- `skills/canopy/ops/` — per-operation procedure files (create, modify, scaffold, validate, improve, advise, refactor-skills, convert-to-canopy, convert-to-regular, help)
- `skills/canopy/policies/authoring-rules.md` — skill structure, writing style, op naming, subagent contract, debug meta-skill
- `skills/canopy/policies/category-decision-flowchart.md` · `platform-targeting.md` · `preservation-rules.md` · `conversion-expansion-rules.md`
- `skills/canopy/constants/` — lookup tables for authoring ops (category dirs, control flow notation, operation detection, dispatch map, validation checks)
- `skills/canopy/schemas/dispatch-schema.json` — output contract for canopy's intent-classification subagent
- `skills/canopy/schemas/explore-schema.json` — output contract for skill-analysis explore subagents
- `skills/canopy/templates/SKILL.md` and `ops.md` — skeletons used by SCAFFOLD
- `skills/canopy/verify/` — expected-state checklists per authoring op

**canopy-runtime (execution engine):**
- `skills/canopy-runtime/SKILL.md` — overview + platform detection + pointers to references/
- `skills/canopy-runtime/references/framework-ops.md` — immutable framework primitives (spec)
- `skills/canopy-runtime/references/runtime-claude.md` — Claude Code runtime rules (base paths, native subagents, invocation forms)
- `skills/canopy-runtime/references/runtime-copilot.md` — GitHub Copilot runtime rules (inline subagent fallback, `.github/` paths, invocation forms)
- `skills/canopy-runtime/references/skill-resources.md` — category behavior, op lookup chain, tree format, explore subagent contract (shared framework spec)

**canopy-debug (trace wrapper):**
- `skills/canopy-debug/SKILL.md` — loads canopy-runtime spec up-front, then wraps a target skill with `EXECUTE_WITH_TRACE`
- `skills/canopy-debug/ops.md` — trace ops (EMIT_PHASE_BANNER, EXECUTE_WITH_TRACE, TRACE_NODE, etc.)
- `skills/canopy-debug/policies/debug-output.md` — rendering protocol

## Install / Distribute

Three install paths supported:

1. **Claude Code plugin marketplace** — inside Claude Code: `/plugin marketplace add kostiantyn-matsebora/claude-canopy` then `/plugin install canopy@claude-canopy`. Bundles all three skills. No external CLI required.
2. **`gh skill`** ([GitHub CLI v2.90.0+](https://cli.github.com/manual/gh_skill_install)) — `gh skill install kostiantyn-matsebora/claude-canopy <skill> --agent claude-code|github-copilot --scope project --pin v0.17.0`. `--agent` chooses `.claude/skills/<skill>/` or `.github/skills/<skill>/`. **Does NOT write ambient instruction files.**
3. **Install script** — `install.sh` / `install.ps1` at repo root. Consumers fetch via `curl | bash` or `irm | iex`. Resolves version from `--ref` / `--version` flag → `.canopy-version` → latest release. Installs all three skills AND idempotently writes canopy-runtime marker block to `CLAUDE.md` / `.github/copilot-instructions.md` (per `--target`). Supports `--ref <branch|tag|SHA>` for pre-release testing; `--ref` installs do NOT write `.canopy-version`.

The install script is the most complete path because it handles ambient runtime activation. `gh skill install` and `/plugin install` leave the runtime to be loaded via skill-description discovery, which is less deterministic.

No more git subtree, no more symlink wiring.

## Contributing Rules

When modifying any of these, keep all in sync:
- `docs/FRAMEWORK.md`
- `skills/canopy-runtime/references/skill-resources.md` — category semantics, op lookup chain, tree format, subagent contract
- `skills/canopy-runtime/references/framework-ops.md` — primitive definitions
- `skills/canopy/policies/` — update the relevant policy file(s)

After any change to skill or op behavior, check that `skills/canopy-runtime/references/runtime-claude.md`, `runtime-copilot.md`, and `docs/AUTHORING.md` still accurately describe current behavior. Update stale content before the work is considered done.

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`).

## Versioning & release

The version string lives in **four places** that must stay in sync:
1. `.canopy-version`
2. `.claude-plugin/plugin.json` → `version`
3. `.claude-plugin/marketplace.json` → `metadata.version` AND `plugins[0].version`
4. The git tag `vX.Y.Z`

Use the `/bump-version X.Y.Z` skill (at `.claude/skills/bump-version/`) to update all four + draft a `docs/CHANGELOG.md` entry + create the local tag in one step. The skill never pushes; pushing is deliberate and manual:

```bash
git push origin master vX.Y.Z
```

Pushing a `v*` tag fires `.github/workflows/release.yml`, which extracts the matching `## [X.Y.Z] — …` block from `docs/CHANGELOG.md` and creates a GitHub Release with those notes. The git tag is also the install artifact for `gh skill install --pin vX.Y.Z` and for `/plugin install canopy@claude-canopy` (which picks up `plugin.json`'s `version`).

## SKILL.md Constraints

`SKILL.md` must contain **only** orchestration — no tables, JSON/YAML blocks, scripts, inline examples, or templates. Structured content belongs in category subdirectories. See `skills/canopy/policies/authoring-rules.md` for the full rule set.

## Platform Compatibility

Canopy must remain fully compatible with **both** Claude Code and **GitHub Copilot**.

- Every change to skills, ops, or policies must be verified against both platforms before the work is considered done.
- If a construct works on one platform but not the other, it must be reworked until it passes on both, or the incompatibility must be explicitly documented with a rationale.
