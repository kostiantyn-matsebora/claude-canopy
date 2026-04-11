# Canopy

> A declarative, tree-structured execution framework for Claude Code skills.

Canopy lets you define reusable AI agent workflows as **syntax trees of named operations**.

Skills are self-contained, composable, and version-controlled. The tree is the source of truth; natural language is just one rendering of it.

See [claude-canopy-examples](https://github.com/kostiantyn-matsebora/claude-canopy-examples) for a working example project using Canopy as a submodule.

---

## How It Works

```
┌────────────────────────────────────────────────────────────────────────────┐
│  my-skill/skill.md                                                         │
│                                                                            │
│  ┌─ Frontmatter ──────────────────────────────────────────────────────┐    │
│  │  name, description, argument-hint                                  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│  ┌─ Preamble ─────────────────────────────────────────────────────────┐    │
│  │  Parse $ARGUMENTS, set context variables                           │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│  ┌─ ## Agent (optional) ──────────────────────────────────────────────┐    │
│  │  **explore** — reads target/, returns schemas/explore-schema.json  │    │
│  │                         │                                          │    │
│  │           spawns subagent; result captured as context              │    │
│  └─────────────────────────┼──────────────────────────────────────────┘    │
│                            ▼                                               │
│  ┌─ ## Tree ──────────────────────────────────────────────────────────┐    │
│  │                                                                    │    │
│  │  my-skill                                                          │    │
│  │  ├── EXPLORE >> context      ◄── always first when Agent present   │    │
│  │  ├── SHOW_PLAN >> a | b      ◄── framework primitive (ops.md L3)   │    │
│  │  ├── ASK << Go? | Yes | No   ◄── halts until user responds         │    │
│  │  ├── MY_OP << arg            ◄── skill-local op  (ops.md L1)       │    │
│  │  ├── PROJECT_OP              ◄── project-wide op (ops.md L2)       │    │
│  │  ├── IF << condition         ◄── branching; skips false branches   │    │
│  │  │   └── …                                                         │    │
│  │  └── ELSE                                                          │    │
│  │      └── …                                                         │    │
│  │                                                                    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│  ┌─ ## Rules (guardrails) ────────────────────────────────────────────┐    │
│  │  • Never overwrite without confirmation                            │    │
│  │  • Always show plan before changes                                 │    │
│  │  Enforced for the full duration of skill execution                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│  ┌─ ## Response ──────────────────────────────────────────────────────┐    │
│  │  Declares output format: Summary / Changes / Notes                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────────┘

Op lookup (ALL_CAPS node → definition):          Category resources (loaded per step):
  1. my-skill/ops.md          (skill-local)        schemas/   → subagent contracts
  2. shared/project/ops.md    (project-wide)        policies/  → active rules / guardrails
  3. shared/framework/ops.md  (primitives)          templates/ → fill <token> → write file
     IF · ELSE · ASK · SHOW_PLAN · VERIFY …        commands/  → run named shell section
                                                    constants/ → load named values
                                                    verify/    → post-run checklist
```

---

## Features

- **Tree-structured execution** — skills are sequential pipelines with `IF`/`ELSE` branching, not prose instructions

- **Named ops** — reusable operations at three levels: skill-local, project-wide, framework primitives

- **Category resource directories** — schemas, templates, commands, constants, policies, verify — each with defined loading behavior

- **Subagent support** — explore subagents with typed JSON output contracts

- **`canopy-skill`** — a bundled meta-skill that enforces and applies framework rules to your own skills

- **Submodule-friendly** — designed to live at `.claude/canopy/` inside any project

---

## Skill Anatomy

Every skill is a `skill.md` file with four sections:

```markdown
---
name: skill-name
description: One-line description shown in skill picker.
argument-hint: "<required-arg> [optional-arg]"
---

Preamble: $ARGUMENTS — parse and set context variables here.

---

## Agent          ← optional; declares an explore subagent
## Tree           ← execution tree (replaces ## Steps)
## Rules          ← invariants and safety constraints
## Response:      ← output format declaration
```

### `## Agent`

Declares an `**explore**` subagent. Keep to a single task description — the rules file
handles schema contract and no-inline-read implicitly.

```markdown
## Agent

**explore** — reads the files for `<service-name>` under `services/`,
including configs, templates, and existing deployment manifests.
```

The subagent uses `schemas/explore-schema.json` as its output contract automatically.

### `## Tree`

A fenced code block containing the skill's execution pipeline as a syntax tree.
Nodes execute top-to-bottom. Each node is either an **op call** or **natural language** — both are valid.

```
skill-name
├── EXPLORE >> context
├── IF << condition
│   └── SOME_OP << input
├── ELSE
│   └── natural language description of what to do
├── SHARED_OP << arg1 | arg2 >> output
└── IF << something went wrong
    └── ROLLBACK
```

### `## Rules`

Short bullet list of invariants that apply throughout the skill execution. Do not duplicate
op-level behavior here — these are skill-wide constraints.

---

## Quick Start

### Option A — Vendored (simplest)

Download Canopy as plain files into `.claude/`. Your project's git tracks everything — Canopy files and your own skills together.

```bash
mkdir -p .claude
curl -L https://github.com/kostiantyn-matsebora/claude-canopy/archive/refs/heads/master.tar.gz \
  | tar -xz --strip-components=1 -C .claude
```

Add your skills under `.claude/skills/<skill-name>/`. Update Canopy manually when needed.

> **Do not use `git clone` here.** That creates a nested `.git` repo — your project's git will not track any files inside `.claude/`, including your own skills.

### Option B — Git Submodule (recommended)

Keeps Canopy as a versioned dependency. Your skills live in your repo; Canopy lives in the submodule. Update Canopy anytime with `git submodule update --remote`.

```bash
# 1. Add the submodule
git submodule add https://github.com/kostiantyn-matsebora/claude-canopy .claude/canopy

# 2. Run the setup script to wire Claude Code to both canopy internals and your skills
bash .claude/canopy/setup.sh        # Linux / macOS
pwsh .claude/canopy/setup.ps1       # Windows
```

The setup script creates three files in your project (outside the submodule):

```
.claude/
├── canopy/                          ← git submodule (never edit here)
├── rules/
│   └── skill-resources.md          ← created by setup; globs cover both dirs
└── skills/
    ├── shared/
    │   ├── project/ops.md           ← created by setup; add your project-wide ops here
    │   └── ops.md                   ← created by setup; redirect stub
    └── <your-skill>/                ← your skills, tracked in your project repo
```

The script is idempotent — safe to re-run, never overwrites existing files.

---

## Usage

### Directory Structure

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
    └── canopy-skill/              # Bundled framework skill
        ├── skill.md
        ├── ops.md
        ├── policies/
        │   └── optimization-rules.md
        └── schemas/
            └── explore-schema.json
```

---

### Writing a Skill

Use the structure described in [Skill Anatomy](#skill-anatomy): frontmatter, optional Agent, Tree, Rules, and Response. In practice, most skills stay short and use the Tree for orchestration.

Minimal example:

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

### Bundled Skills

| Skill | Description |
|-------|-------------|
| `canopy-skill` | Audit and optimize any Canopy skill — extracts inline content, converts to tree format, creates ops |

---

## Contributing

Canopy is currently a personal project. Issues and PRs welcome once the API stabilizes.

- Keep `FRAMEWORK.md` as the single source of truth
- `canopy-skill` must be updated whenever framework rules change
- Framework primitives in `skills/shared/framework/ops.md` are immutable contracts

---

## License

MIT — see [`LICENSE`](LICENSE).
