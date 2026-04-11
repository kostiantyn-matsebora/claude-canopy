# Canopy

> A declarative, tree-structured execution framework for Claude Code skills.

Canopy lets you define reusable AI agent workflows as **syntax trees of named operations**. Skills are self-contained, composable, and version-controlled. The tree is the source of truth; natural language is just one rendering of it.

---

## Features

- **Tree-structured execution** — skills are sequential pipelines with `IF`/`ELSE` branching, not prose instructions
- **Named ops** — reusable operations at three levels: skill-local, project-wide, framework primitives
- **Category resource directories** — schemas, templates, commands, constants, policies, verify — each with defined loading behavior
- **Subagent support** — explore subagents with typed JSON output contracts
- **`optimize-skill`** — a bundled meta-skill that enforces and applies framework rules to your own skills
- **Submodule-friendly** — designed to live at `.claude/canopy/` inside any project

---

## Quick Start

### Option A — Standalone (Canopy is your whole `.claude/`)

```bash
git clone https://github.com/kostiantyn-matsebora/claude-canopy .claude
```

Add your skills under `.claude/skills/<skill-name>/`. Add project-wide ops to `.claude/skills/shared/project/ops.md`.

### Option B — Git Submodule (recommended)

```bash
# From your project root
git submodule add https://github.com/kostiantyn-matsebora/claude-canopy .claude/canopy
```

Then create your project-level `.claude/rules/skill-resources.md` (see [Submodule Wiring](#submodule-wiring)).

---

## Directory Structure

```
claude-canopy/
├── FRAMEWORK.md                    # Full framework specification
├── README.md                       # This file
├── CHANGELOG.md
├── LICENSE
├── rules/
│   └── skill-resources.md         # Ambient rules (standalone use)
└── skills/
    ├── shared/
    │   ├── framework/
    │   │   └── ops.md             # Framework primitives — never overridden
    │   ├── project/
    │   │   └── ops.md             # Stub — replace with your project ops
    │   └── ops.md                 # Redirect stub
    └── optimize-skill/            # Bundled framework skill
        ├── skill.md
        ├── ops.md
        ├── policies/
        │   └── optimization-rules.md
        └── schemas/
            └── explore-schema.json
```

---

## Submodule Wiring

After `git submodule add`, create `.claude/rules/skill-resources.md` in your project with updated paths:

```markdown
---
globs: [".claude/skills/**", ".claude/canopy/skills/**"]
---

# Skill Resource Conventions

## Category behavior
... (same as canopy default) ...

## Named operations

When a step or tree node contains an ALL_CAPS identifier:
1. Look up in `<skill>/ops.md` first (skill-local ops)
2. Fall back to `.claude/skills/shared/project/ops.md` (project-wide ops)
3. Fall back to `.claude/canopy/skills/shared/framework/ops.md` (framework primitives)
```

Also add your project-specific ops to `.claude/skills/shared/project/ops.md`.

---

## Writing a Skill

Every skill is a `skill.md` file. Minimal example:

```markdown
---
name: my-skill
description: Does something useful.
argument-hint: "<target>"
---

Target: $ARGUMENTS

---

## Tree

\`\`\`
my-skill
├── SHOW_PLAN >> what will change
├── ASK << Proceed? | Yes | No
└── do the thing
\`\`\`

## Rules

- Never overwrite existing files without confirmation

## Response: Summary / Changes / Notes
```

See [`FRAMEWORK.md`](FRAMEWORK.md) for the full specification.

---

## Op Lookup Order

1. `<skill>/ops.md` — skill-local (highest priority)
2. `skills/shared/project/ops.md` — project-wide
3. `skills/shared/framework/ops.md` — Canopy primitives (lowest priority, never overridden)

---

## Bundled Skills

| Skill | Description |
|-------|-------------|
| `optimize-skill` | Audit and optimize any Canopy skill — extracts inline content, converts to tree format, creates ops |

---

## Contributing

Canopy is currently a personal project. Issues and PRs welcome once the API stabilizes.

- Keep `FRAMEWORK.md` as the single source of truth
- `optimize-skill` must be updated whenever framework rules change
- Framework primitives in `skills/shared/framework/ops.md` are immutable contracts

---

## License

MIT — see [`LICENSE`](LICENSE).
