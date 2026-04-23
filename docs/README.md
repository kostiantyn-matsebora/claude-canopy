# Canopy <img src="../assets/icons/logo-ai-skills.svg" align="right" width="60%" />

**AI skills as executable code, not prose.**



AI skills written as prose are instructions. Instructions get interpreted. Interpretations
drift. When a skill fails, you're re-reading sentences trying to figure out which one was
misunderstood. When it works, you're not entirely sure why it did.

**Canopy makes skills programs.**

---
## Why Canopy?

```
Canopy
├── DETERMINISTIC
│   ├── skills run identically every time
│   └── the tree is explicit — no interpretation, no drift
│
├── REUSABLE OPS
│   ├── define DEPLOY, VERIFY, ROLLBACK once in ops.md
│   └── one change keeps every skill that uses them in sync
│
├── TRANSPARENT
│   ├── the tree shows execution order before anything runs
│   └── when it fails, the failing node is obvious — no re-reading prose
│
├── ORGANIZED RESOURCES
│   ├── schemas · templates · commands · constants · policies · verify
│   └── find what you need instantly; no hunting through paragraphs
│
├── CROSS-PLATFORM
│   ├── write once; runs on Claude Code and GitHub Copilot unchanged
│   └── the interpreter adapts at runtime — same skill.md, zero changes
│
├── EDITOR-NATIVE
│   ├── VS Code extension: completions, hover docs, go-to-definition, live diagnostics
│   └── broken op references and signature errors surface before the skill runs
│
└── ZERO LEARNING CURVE
    ├── /canopy scaffolds, validates, improves, and converts for you
    └── no syntax to memorize before you ship your first skill
```

* **VS Code extension:** [claude-canopy-vscode](https://github.com/kostiantyn-matsebora/claude-canopy-vscode) — syntax highlighting, op completions, diagnostics.

* **Examples:** [claude-canopy-examples](https://github.com/kostiantyn-matsebora/claude-canopy-examples) — a working project to learn from.

## How it works

> The tree is the source of truth. The platform is just a detail.

Every Canopy skill is a `skill.md` file — platform-agnostic by design. When a skill runs, the `canopy` agent detects whether you're on Claude Code or GitHub Copilot, loads the matching runtime spec, then executes the tree using platform-appropriate primitives. The same skill file works on both platforms without modification.

The `canopy` agent itself is a Canopy skill: its `## Agent` section classifies your intent and detects the platform; its `## Tree` routes to the correct operation via an explicit `IF/ELSE_IF` chain — no LLM-inferred dispatch.

Here's a complete skill — frontmatter, execution tree, and all:

```markdown
---
name: release
description: Bump version across files and update changelog.
argument-hint: "[major|minor|patch]"
---

Parse `$ARGUMENTS` to determine version bump strategy.

---

## Agent

**explore** — reads the project structure: current version in package.json,
pyproject.toml, and other version-bearing files; lists all files needing updates.

---

## Tree

* release
  * EXPLORE >> current_version | version_files
  * SHOW_PLAN >> new_version | files | changelog
  * ASK << Proceed? | Yes | No
  * IF << Yes
    * BUMP_FILES << version_files | new_version
    * IF << CHANGELOG.md exists
      * ADD_CHANGELOG_ENTRY << new_version
    * VERIFY_EXPECTED << verify/verify-expected.md
  * ELSE
    * natural language: Cancelled by user.

## Rules

* Never overwrite version files without confirmation via `SHOW_PLAN` and `ASK`.
* Verify all files were updated before responding.
```

> 
> Seven nodes, reusable op definitions, real-state evaluation, and guardrails to prevent mistakes - this is **Canopy** in action.

## Resources

**Cheatsheet:** [CHEATSHEET.md](CHEATSHEET.md) — one-page reference: skill anatomy, all primitives with examples, op syntax, category directories, canopy agent operations, and debug mode.

**Workflow:** [FRAMEWORK.md](FRAMEWORK.md#workflow-diagram) explains the full execution pipeline.



## Quick Start

Canopy ships as a set of [Agent Skills](https://agentskills.io) installable via [`gh skill`](https://cli.github.com/manual/gh_skill_install) (GitHub CLI v2.90.0+). Install one command per skill, per target agent:

```bash
# Claude Code (project scope, pinned to a release)
gh skill install kostiantyn-matsebora/claude-canopy canopy-agent --agent claude-code --scope project --pin v0.17.0
gh skill install kostiantyn-matsebora/claude-canopy canopy        --agent claude-code --scope project --pin v0.17.0
gh skill install kostiantyn-matsebora/claude-canopy canopy-debug  --agent claude-code --scope project --pin v0.17.0
gh skill install kostiantyn-matsebora/claude-canopy canopy-help   --agent claude-code --scope project --pin v0.17.0

# GitHub Copilot (same skills, --agent github-copilot drops them under .github/skills/)
gh skill install kostiantyn-matsebora/claude-canopy canopy-agent --agent github-copilot --scope project --pin v0.17.0
gh skill install kostiantyn-matsebora/claude-canopy canopy        --agent github-copilot --scope project --pin v0.17.0
gh skill install kostiantyn-matsebora/claude-canopy canopy-debug  --agent github-copilot --scope project --pin v0.17.0
gh skill install kostiantyn-matsebora/claude-canopy canopy-help   --agent github-copilot --scope project --pin v0.17.0
```

The four skills:

- **`canopy-agent`** — the heavy agent skill (ops, policies, constants, schemas, templates, verify checklists, framework primitives, runtime specs)
- **`canopy`** — lightweight slash-command wrapper that delegates to `canopy-agent` (provides `/canopy`)
- **`canopy-debug`** — trace any Canopy skill with phase banners and per-node tracing (`/canopy-debug <skill>`)
- **`canopy-help`** — read-only operations reference (`/canopy-help [op]`)

Drop `--scope project` for `--scope user` to install once for all your projects.

Update later with `gh skill update`. Inspect a skill before installing with `gh skill preview`.

---

## Usage

### Using the `canopy` Agent

The `canopy` agent handles the full skill lifecycle.

**Claude Code:**

```
/canopy improve bump-version
/canopy create a skill that bumps semantic versions
/canopy validate the bump-version skill
```

**GitHub Copilot:**

Same `/canopy` slash command via the wrapper skill installed at `.github/skills/canopy/`:

```
/canopy improve bump-version
/canopy create a skill that bumps semantic versions
```

Explicit form (always works):

```
Follow .github/skills/canopy-agent/SKILL.md and improve bump-version
```

| Operation | Example |
|-----------|---------|
| **Create** | `/canopy create a skill that bumps semantic versions` |
| **Modify** | `/canopy add a dry-run option to the deploy-service skill` |
| **Scaffold** | `/canopy scaffold a blank skill called api-docs` |
| **Convert to Canopy** | `/canopy convert my deploy.md skill to canopy format` |
| **Validate** | `/canopy validate the bump-version skill` |
| **Improve** | `/canopy improve the deploy-service skill` |
| **Advise** | `/canopy how should I add a verify step to the review-api skill?` |
| **Refactor skills** | `/canopy refactor skills — extract shared ops` |
| **Convert to regular** | `/canopy convert the review-file skill back to a plain skill` |
| **Help** | `/canopy help` |

For **Create** and **Scaffold**, the agent asks your preferred tree syntax - **markdown list** (`*` nested bullets) or **box-drawing** (fenced tree characters) - before writing anything.

Every operation shows a plan and asks for confirmation before making changes.

### Using the `canopy-help` Skill

`canopy-help` is a lightweight read-only skill that emits the canopy agent reference without invoking the agent itself. Use it when you just want to browse the operations list or look up a specific procedure.

```
/canopy-help
/canopy-help improve
/canopy-help refactor-skills
```

With no argument it prints the full operations reference. With an operation name it prints that operation's procedure verbatim.

### Writing a Skill Manually

See [AUTHORING.md](AUTHORING.md) for the full manual reference - skill anatomy, tree syntax, op definitions, category resource conventions, and what `SKILL.md` must not contain.

---

For detailed directory layout and structure (standalone vs. submodule), see [FRAMEWORK.md](FRAMEWORK.md#directory-layout).

---

## Under the Hood

```text
┌────────────────────────────────────────────────────────────────────────────┐
│  my-skill/skill.md                                                         │
│                                                                            │
│  Stage 1: Initialize context                                               │
│  ┌─ Frontmatter + Preamble ───────────────────────────────────────────┐    │
│  │  name, description, argument-hint                                  │    │
│  │  parse $ARGUMENTS, set context variables                           │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                            │                                               │
│                            ▼                                               │
│  Stage 2: Detect platform + load runtime                                   │
│  ┌─ canopy-agent skill (## Tree, first steps) ───────────────────────┐    │
│  │  detect platform: .claude/ -> Claude Code | .github/ -> Copilot   │    │
│  │  load references/runtime-claude.md or references/runtime-copilot  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                            │                                               │
│                            ▼                                               │
│  Stage 3: Explore (optional)                                               │
│  ┌─ ## Agent: explore ────────────────────────────────────────────────┐    │
│  │  Claude Code: run native explore subagent                          │    │
│  │  Copilot:     inline sequential file reading (fallback)            │    │
│  │  capture schemas/explore-schema.json output into context           │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                            │                                               │
│                            ▼                                               │
│  Stage 4: Plan and confirmation gate                                       │
│  ┌─ ## Tree entry steps ──────────────────────────────────────────────┐    │
│  │  SHOW_PLAN >> fields                                               │    │
│  │  ASK << Proceed? | Yes | No                                        │    │
│  │  No -> stop without changes                                        │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                            │ Yes                                           │
│                            ▼                                               │
│  Stage 5: Execute workflow actions (iterative loop)                        │
│  ┌─ ## Tree action steps ─────────────────────────────────────────────┐    │
│  │  run op calls + natural-language nodes top-to-bottom               │    │
│  │  evaluate IF / ELSE_IF / ELSE branches                             │    │
│  │  repeat until no remaining actions                                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                            │                                               │
│                            ▼                                               │
│  Stage 6: Verify expected outcomes                                         │
│  ┌─ VERIFY_EXPECTED ──────────────────────────────────────────────────┐    │
│  │  compare resulting state against verify checklist                  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│  ┌─ ## Rules (guardrails) ────────────────────────────────────────────┐    │
│  │  • Never overwrite without confirmation                            │    │
│  │  • Always show plan before changes                                 │    │
│  │  Enforced for the full duration of skill execution                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                            │                                               │
│                            ▼                                               │
│  Stage 7: Respond                                                          │
│  ┌─ ## Response ──────────────────────────────────────────────────────┐    │
│  │  Declares output format: Summary / Changes / Notes                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────────┘

Op lookup (ALL_CAPS node -> definition):                         Category resources (loaded per step):
1. my-skill/ops.md                          (skill-local)        schemas/   -> subagent contracts
2. consumer-defined cross-skill ops         (optional)           policies/  -> active rules / guardrails
3. canopy-agent/references/framework-ops.md (primitives)         templates/ -> fill <token> -> write file
   IF, ELSE, SWITCH, FOR_EACH, ASK, SHOW_PLAN, VERIFY...         commands/  -> run named shell section
                                                                  constants/ -> load named values
                                                                  verify/    -> post-run checklist

Runtime specs (loaded at Stage 2):
  canopy-agent/references/runtime-claude.md   -> .claude/ paths, native subagents
  canopy-agent/references/runtime-copilot.md  -> .github/ paths, inline subagent fallback
```

---

## Contributing

Canopy is currently a personal project. Issues and PRs welcome once the API stabilizes.

- Keep `docs/FRAMEWORK.md` as the single source of truth
- `canopy-agent` skill must be updated whenever framework rules change
- Framework primitives in `skills/canopy-agent/references/framework-ops.md` are immutable contracts

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and PR expectations.

---

## License

MIT - see [LICENSE](../LICENSE).
