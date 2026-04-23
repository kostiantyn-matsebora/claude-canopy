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

This repo ships two installable Agent Skills under `skills/`:

| Skill | Purpose |
|-------|---------|
| `canopy/` | The agent skill — ops, policies, constants, schemas, templates, verify checklists, framework primitives, runtime specs. Invokes as `/canopy`. The HELP op (`/canopy help`) covers what `canopy-help` used to. |
| `canopy-debug/` | Trace any Canopy skill with phase banners and per-node tracing |

Plus:

- `.claude-plugin/plugin.json` — Claude Code plugin manifest (makes the whole repo installable as a plugin via `/plugin install canopy@claude-canopy`)
- `.claude-plugin/marketplace.json` — marketplace catalog (makes the repo a marketplace that users can add via `/plugin marketplace add kostiantyn-matsebora/claude-canopy`)
- `docs/` — `FRAMEWORK.md`, `AUTHORING.md`, `CHEATSHEET.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `README.md`
- `assets/` — logo / icon files referenced by docs
- `.canopy-version` — single-line version string (machine-readable)
- `LICENSE`

The repo is intentionally shaped so the SAME `skills/canopy/` and `skills/canopy-debug/` directories serve all three install paths:
1. **Claude Code plugin** — `.claude-plugin/plugin.json` at repo root + `skills/<name>/SKILL.md` matches the Claude Code plugin layout. Skills become `/canopy:canopy` and `/canopy:canopy-debug` (plugin-namespaced).
2. **`gh skill install`** — reads `skills/*/SKILL.md` from the repo directly. Lands skills at `.claude/skills/<name>/`; slash commands are `/canopy` and `/canopy-debug` (no namespace).
3. **Manual `git clone` + `cp -r`** — same as `gh skill install`.

Keep this single-source-of-truth property when adding skills: put them under `skills/<name>/` only. Don't create parallel copies.

## Op Lookup Order

When a tree node has an `ALL_CAPS` identifier, look up in this order:
1. `<skill>/ops.md` — skill-local
2. Consumer-defined cross-skill ops (optional; consumers package these as their own skill — no built-in location)
3. `skills/canopy/references/framework-ops.md` — framework primitives (`IF`, `ELSE_IF`, `ELSE`, `SWITCH`, `CASE`, `DEFAULT`, `FOR_EACH`, `BREAK`, `END`, `ASK`, `SHOW_PLAN`, `VERIFY_EXPECTED`)

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
- `skills/canopy/SKILL.md` — agent body: detects platform, dispatches deterministically to one of 10 ops
- `skills/canopy/ops/` — per-operation procedure files
- `skills/canopy/policies/authoring-rules.md` — skill structure, writing style, op naming, subagent contract, debug meta-skill
- `skills/canopy/policies/category-decision-flowchart.md` · `platform-targeting.md` · `preservation-rules.md` · `conversion-expansion-rules.md`
- `skills/canopy/constants/` — lookup tables: category dirs, control flow notation, operation detection, dispatch map, validation checks
- `skills/canopy/schemas/dispatch-schema.json` — output contract for the canopy's intent-classification subagent
- `skills/canopy/schemas/explore-schema.json` — output contract for skill-analysis explore subagents
- `skills/canopy/templates/SKILL.md` and `ops.md` — skeletons used by SCAFFOLD
- `skills/canopy/verify/` — expected-state checklists per operation
- `skills/canopy/references/framework-ops.md` — immutable framework primitives
- `skills/canopy/references/runtime-claude.md` — Claude Code runtime spec (base paths, native subagents, invocation forms)
- `skills/canopy/references/runtime-copilot.md` — GitHub Copilot runtime spec (inline subagent fallback, `.github/` paths, invocation forms)
- `skills/canopy/references/skill-resources.md` — category behavior, op lookup chain, tree format, explore subagent (reference doc)

## Install / Distribute

Three install paths supported:

1. **Claude Code plugin marketplace** — inside Claude Code: `/plugin marketplace add kostiantyn-matsebora/claude-canopy` then `/plugin install canopy@claude-canopy`. No external CLI required.
2. **`gh skill`** ([GitHub CLI v2.90.0+](https://cli.github.com/manual/gh_skill_install)) — `gh skill install kostiantyn-matsebora/claude-canopy <skill> --agent claude-code|github-copilot --scope project --pin v0.17.0`. `--agent` chooses `.claude/skills/<skill>/` or `.github/skills/<skill>/`.
3. **Manual** — `git clone --branch vX.Y.Z` + `cp -r skills/<name> .claude/skills/` (or `.github/skills/`).

No more `setup.sh`, no more git subtree, no more symlink wiring.

## Contributing Rules

When modifying any of these, keep all in sync:
- `docs/FRAMEWORK.md`
- `skills/canopy/references/skill-resources.md`
- `skills/canopy/references/framework-ops.md`
- `skills/canopy/policies/` — update the relevant policy file(s)

After any change to skill or op behavior, check that `references/runtime-claude.md`, `references/runtime-copilot.md`, and `docs/AUTHORING.md` still accurately describe current behavior. Update stale content before the work is considered done.

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`).

## Versioning

When bumping the framework version, update **both**:
1. `.canopy-version` — single line containing the new version string (e.g. `0.17.0`)
2. `docs/CHANGELOG.md` — prepend a new `## [X.Y.Z] — YYYY-MM-DD` entry

Both files must be kept in sync. Releases are made by tagging the new version (`git tag vX.Y.Z && git push origin vX.Y.Z`), which becomes the install artifact for `gh skill install --pin vX.Y.Z`.

## SKILL.md Constraints

`SKILL.md` must contain **only** orchestration — no tables, JSON/YAML blocks, scripts, inline examples, or templates. Structured content belongs in category subdirectories. See `skills/canopy/policies/authoring-rules.md` for the full rule set.

## Platform Compatibility

Canopy must remain fully compatible with **both** Claude Code and **GitHub Copilot**.

- Every change to skills, ops, or policies must be verified against both platforms before the work is considered done.
- If a construct works on one platform but not the other, it must be reworked until it passes on both, or the incompatibility must be explicitly documented with a rationale.
