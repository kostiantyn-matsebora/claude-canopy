# Canopy

> The tree is the source of truth. Natural language is just one rendering of it.

AI skills written as prose are instructions. Instructions get interpreted. Interpretations
drift. When a skill fails, you're re-reading sentences trying to figure out which one was
misunderstood. When it works, you're not entirely sure why it did.

**Canopy makes skills programs.**

---

**Skills that run the same way twice.**  
Not because you wrote better instructions — because the execution pipeline is explicit.
The model follows the tree you defined, not its best guess at what you meant.

**Operations you write once and reuse everywhere.**  
`DEPLOY`, `VERIFY`, `ROLLBACK` — define them once in `ops.md`. Every skill that needs
them shares the same definition. Change one, every skill updates automatically.

**Execution you can read before it runs.**  
The tree shows exactly what will happen and in what order — before the model touches a
single file.

**No framework to learn to get started.**  
Tell the `canopy-skill` agent what you need. It creates, scaffolds, validates, and
converts skills for you.

---

```
release
├── EXPLORE >> current_version | version_files     ← subagent reads your project; typed JSON output
├── SHOW_PLAN >> new_version | files | changelog   ← always shows the plan before touching anything
├── ASK << Proceed? | Yes | No                     ← halts until you respond
├── BUMP_FILES << version_files | new_version      ← named op, defined once in ops.md
├── IF << CHANGELOG.md exists                      ← branches on real state; false branch is skipped
│   └── ADD_CHANGELOG_ENTRY << new_version
└── VERIFY_EXPECTED << verify/verify-expected.md  ← post-run checklist
```

Seven nodes. Anyone reading this knows exactly what `release` does and in what order.
`BUMP_FILES` is defined once — every skill that calls it stays in sync. `IF` evaluates
against real project state; the false branch is never executed.

This is Canopy — a declarative execution framework for Claude Code skills.

See [claude-canopy-examples](https://github.com/kostiantyn-matsebora/claude-canopy-examples) for a working example project.

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

The setup script creates files and links in your project (outside the submodule):

```
.claude/
├── canopy/                          ← git submodule (never edit here)
├── agents/
│   ├── canopy-skill.md              ← symlinked from canopy; bundled agent
│   └── canopy-skill/                ← symlinked from canopy; agent resources
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

### Using the `canopy-skill` Agent

The `canopy-skill` agent handles the full skill lifecycle. Invoke it naturally in Claude Code:

| Operation | What to say |
|-----------|------------|
| **Create** | "Create a canopy skill that bumps semantic versions across project files" |
| **Modify** | "Add a dry-run option to the deploy-service skill" |
| **Scaffold** | "Scaffold a blank skill called api-docs" |
| **Convert to Canopy** | "Convert my old deploy.md skill to canopy format" |
| **Validate** | "Validate the bump-version skill" |
| **Convert to regular** | "Convert the review-file skill back to a plain skill" |

For **Create** and **Scaffold**, the agent asks your preferred tree syntax — **markdown list** (`*` nested bullets) or **box-drawing** (fenced tree characters) — before writing anything.

Every operation shows a plan and asks for confirmation before making changes.

### Writing a Skill Manually

See [`AUTHORING.md`](AUTHORING.md) for the full manual reference — skill anatomy, tree
syntax, op definitions, category resource conventions, and what `skill.md` must not contain.

---

### Directory Structure

```
claude-canopy/
├── FRAMEWORK.md                    # Full framework specification
├── AUTHORING.md                    # Manual skill authoring reference
├── README.md                       # This file
├── CHANGELOG.md
├── LICENSE
├── agents/
│   ├── canopy-skill.md            # Bundled framework agent
│   └── canopy-skill/              # Agent resource files
│       ├── policies/
│       │   └── optimization-rules.md
│       ├── schemas/
│       │   └── explore-schema.json
│       └── templates/
│           ├── skill.md           # Skill skeleton template
│           └── ops.md             # Ops skeleton template
├── rules/
│   └── skill-resources.md         # Ambient rules (standalone use)
└── skills/
    └── shared/
        ├── framework/
        │   └── ops.md             # Framework primitives — never overridden
        ├── project/
        │   └── ops.md             # Stub — replace with your project ops
        └── ops.md                 # Redirect stub
```

---

### Bundled Agents

| Agent | Description |
|-------|-------------|
| `canopy-skill` | Create, modify, scaffold, validate, and convert Canopy skills |

---

## Under the Hood

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

## Contributing

Canopy is currently a personal project. Issues and PRs welcome once the API stabilizes.

- Keep `FRAMEWORK.md` as the single source of truth
- `canopy-skill` agent must be updated whenever framework rules change
- Framework primitives in `skills/shared/framework/ops.md` are immutable contracts

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and PR expectations.

---

## License

MIT — see [`LICENSE`](LICENSE).
