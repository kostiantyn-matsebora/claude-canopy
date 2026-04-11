# Canopy

A declarative, tree-structured execution framework for Claude Code skills. Skills are defined as syntax trees of op calls and natural language. The tree is the source of truth; natural language is just one rendering of it.

---

## Framework Skills

`optimize-skill` is a framework skill — it enforces and applies framework rules to all other skills.
It must be updated whenever the framework changes (new syntax rules, new op levels, new category behavior).

When modifying `FRAMEWORK.md`, `rules/skill-resources.md`, `skills/shared/framework/ops.md`, or `skills/shared/project/ops.md`,
also check and update `skills/optimize-skill/policies/optimization-rules.md` to stay in sync.

---

## Directory Layout

### Standalone (Canopy is `.claude/`)

```
.claude/                              ← clone or copy of claude-canopy
├── rules/
│   └── skill-resources.md          # Ambient rules — auto-applied to all skill files
└── skills/
    ├── shared/
    │   ├── framework/
    │   │   └── ops.md              # Framework primitives (IF, ASK, SHOW_PLAN, …)
    │   ├── project/
    │   │   └── ops.md              # Project-wide ops — add your own here
    │   └── ops.md                  # Redirect stub — see framework/ and project/
    ├── FRAMEWORK.md                # This file
    ├── optimize-skill/             # Framework-bundled skill
    └── <your-skill>/
        ├── skill.md                # Skill definition — frontmatter + Tree + Rules
        ├── ops.md                  # Skill-local op definitions
        ├── schemas/                # Subagent output contracts, input schemas
        ├── templates/              # YAML/Markdown templates with <token> placeholders
        ├── constants/              # Named values loaded into step context
        ├── policies/               # Rules applied for the duration of the skill
        ├── commands/               # PowerShell / shell scripts with named sections
        └── verify/                 # Expected-state checklists
```

### As Git Submodule (recommended for projects)

```
.claude/
├── canopy/                         ← git submodule → claude-canopy
│   ├── FRAMEWORK.md
│   ├── rules/
│   │   └── skill-resources.md     # Canopy default rules (reference only)
│   └── skills/
│       ├── shared/
│       │   ├── framework/
│       │   │   └── ops.md         # Framework primitives
│       │   ├── project/
│       │   │   └── ops.md         # Stub — do not edit here
│       │   └── ops.md
│       └── optimize-skill/
├── rules/
│   └── skill-resources.md         # Project rules — override canopy; update paths
└── skills/
    ├── shared/
    │   └── project/
    │       └── ops.md             # Your project-specific ops live here
    └── <your-skill>/
```

See `README.md` for submodule setup instructions.

---

## Notation

| Symbol | Meaning |
|--------|---------|
| `<<` | Input — source file, condition to evaluate, or user-facing options |
| `>>` | Output — fields captured into step context, or fields displayed to user |
| `\|` | Separator — between multiple inputs, options, or output fields |

Examples:
```
VAULT_KV_READ secret/app/creds >> {client_id, client_secret}
ASK << Proceed? | Yes | No
FETCH_GITHUB_RELEASES << org/repo >> breaking-changes
SHOW_PLAN >> files | Vault changes | API calls
```

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

**explore** — reads helmfile for `<app-name>` under `apps/` or `platform/`,
including environment values and `.github/instructions/` file.
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

## Tree Execution Model

The tree is a **sequential pipeline** with branching. Execution is:
1. Start at the root node
2. Execute each sibling top-to-bottom
3. For `IF`/`ELSE_IF`/`ELSE` chains: evaluate conditions in order; execute first matching branch; skip the rest
4. After a branch completes, resume on the next sibling after the chain
5. `EXPLORE` is always the first node if an `## Agent` section is present

**Node types:**

| Node | Form | Behaviour |
|------|------|-----------|
| Op call | `OP_NAME << inputs >> outputs` | Look up and execute op definition |
| Natural language | any prose | Execute as described |
| `IF` | `IF << condition` | Branch — execute children if true |
| `ELSE_IF` | `ELSE_IF << condition` | Continue chain — execute if prior false |
| `ELSE` | `ELSE` | Close chain — execute if all prior false |

---

## Control Flow Primitives

Defined in `skills/shared/framework/ops.md`. Always looked up there — never overridden in skill-local or project ops.

### `IF << condition`
```
IF << condition
├── then-branch (op or natural language)
[ELSE_IF << condition2
 ├── branch2]
[ELSE
 └── else-branch]
```

### `ELSE_IF << condition`
Continues an `IF` or `ELSE_IF` chain. Only evaluated if all prior conditions were false.

### `ELSE`
Closes an `IF` or `ELSE_IF` chain. Executed only if all prior conditions were false.

### `ASK << question | option1 | option2 [| ...]`
Present a question with options. Execution halts until the user responds.

### `SHOW_PLAN >> field1 | field2 | ...`
Present a structured pre-execution plan covering the listed fields.

### `VERIFY_EXPECTED << verify/verify-expected.md`
Check current state against expected outcomes in the verify file.

---

## Op Lookup Order

When a tree node contains an `ALL_CAPS` identifier:

1. **`<skill>/ops.md`** — skill-local ops (checked first)
2. **`shared/project/ops.md`** — project-wide ops
3. **`shared/framework/ops.md`** — framework primitives (fallback)

Primitives (`IF`, `ELSE_IF`, `ELSE`, `ASK`, `SHOW_PLAN`, `VERIFY_EXPECTED`, `BREAK`, `END`) always
resolve to `shared/framework/ops.md` and are never overridden.

---

## Skill-Local `ops.md`

Skill-specific branches, multi-step procedures, and decision trees. Lives alongside
`skill.md`, not in a subdirectory.

**Simple op** — prose for linear behavior:
```markdown
## FETCH_CHART_DEFAULTS

Fetch the chart's upstream default values from the internet to confirm the current image and tag.
```

**Branching op** — use tree notation:
```markdown
## EDIT_IMAGE_TAG << image_defined_in | target_tag

\`\`\`
EDIT_IMAGE_TAG << image_defined_in | target_tag
├── IF << image_defined_in = chart-defaults-only
│   └── CREATE_ENV_OVERRIDE
└── ELSE — edit tag in-place at the path from image_defined_in
\`\`\`
```

Op definitions calling other ops (including shared ops) is valid — the system is self-similar.

---

## Op Registries

### Framework primitives (`skills/shared/framework/ops.md`)

Control-flow and interaction ops available in every skill, in every project.

| Op | Signature | Purpose |
|----|-----------|---------|
| `IF` | `<< condition` | Branch on condition |
| `ELSE_IF` | `<< condition` | Continue IF chain |
| `ELSE` | — | Close IF chain |
| `BREAK` | — | Exit current op, resume caller |
| `END` | `[message]` | Halt skill execution |
| `ASK` | `<question> << option1 \| ...` | Prompt user; halt until response |
| `SHOW_PLAN` | `>> field1 \| ...` | Present pre-execution plan |
| `VERIFY_EXPECTED` | `<< verify/verify-expected.md` | Check state against expected outcomes |

### Project-wide ops (`skills/shared/project/ops.md`)

Project-specific ops shared across skills in this project. Add here when a pattern appears in 2+ skills or has complex multi-step behavior worth naming. Op definitions follow the same tree notation as skills; lookup order places them after skill-local ops but before framework primitives.

---

## Category Resource Subdirectories

When a tree node or op step says `Read <category>/<file>`, the directory determines behavior:

| Directory | File types | Behavior |
|-----------|------------|----------|
| `schemas/` | `.json`, `.md` | Use as subagent output contract or input schema |
| `templates/` | `.yaml`, `.md`, `.yaml.gotmpl` | Substitute `<token>` placeholders from step context; write to target path |
| `commands/` | `.ps1`, `.sh` | Execute the named section; capture declared output values. Sections use `# === Section Name ===` headers. |
| `constants/` | `.md` | Load all named values into step context |
| `policies/` | `.md` | Apply as active rules for the skill's duration |
| `verify/` | `.md` | Use as expected-state checklist during verification |

**Reference line pattern:** `Read \`<category>/<file>\` for <brief description>.`
Load at the point of use — not front-loaded at the top of the tree.

---

## Ambient Rules

`rules/skill-resources.md` carries `globs` in its frontmatter.
It is automatically active whenever any skill file is read — no per-skill loading needed.
It encodes the category behavior table, op lookup order, tree execution model, and explore
subagent contract.

When using Canopy as a submodule, create a project-level `rules/skill-resources.md` that
overrides the canopy default — update the globs and op lookup paths to match your layout.
