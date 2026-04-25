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

Canopy ships as three [Agent Skills](https://agentskills.io), split along **authoring vs. execution** lines. Same skills work on Claude Code and GitHub Copilot — only the install path differs.

**The three skills:**

| Skill | Role | Slash command | Notes |
|---|---|---|---|
| `canopy-runtime` | Execution engine — interprets canopy-flavored skills (platform detection, primitives, op lookup chain, category semantics, subagent contract). | hidden from `/` | Loaded ambiently via `CLAUDE.md` / `.github/copilot-instructions.md`. Install alone to just *execute* existing canopy skills. |
| `canopy` | Authoring agent — create / modify / validate / improve / scaffold / refactor / advise on / convert canopy skills. | `/canopy` | Depends on `canopy-runtime`. |
| `canopy-debug` | Trace wrapper — phase banners + per-node tracing for any canopy skill's execution. | `/canopy-debug <skill>` | Optional. |

### Authoring vs. execution

| If you want to… | Install |
|---|---|
| Run existing canopy skills that someone else wrote | `canopy-runtime` only |
| Author or edit canopy skills | `canopy` + `canopy-runtime` |
| Trace / debug a canopy skill's execution | `canopy-debug` + `canopy-runtime` |
| Everything (default) | All three |

The install script below installs all three by default. `gh skill install` and `/plugin install` let you pick individual skills.

### Install for Claude Code

Three install paths; pick whichever fits your workflow. All three land the same skill files; only the discovery and namespace differ.

**Option 1 — Claude Code plugin marketplace (recommended, no external CLI):**

Inside a Claude Code session:

```
/plugin marketplace add kostiantyn-matsebora/claude-canopy
/plugin install canopy@claude-canopy
/canopy:canopy activate
```

| Command | What it does | Scope |
|---|---|---|
| `/plugin marketplace add …` | Register the canopy marketplace | user — once per machine |
| `/plugin install canopy@claude-canopy` | Adds `/canopy:canopy` + `/canopy:canopy-debug` (plugin-namespaced) | user — once per machine |
| `/canopy:canopy activate` | Writes the canopy-runtime marker block to `CLAUDE.md` so user skills under `.claude/skills/` load runtime ambiently | project — once per project |

Update: `/plugin update canopy@claude-canopy`, then re-run `activate` if the new release changed the marker block.

**Option 2 — `gh skill` (GitHub CLI v2.90.0+):**

Skills land under `.claude/skills/<name>/` and become available as `/canopy` and `/canopy-debug` (no namespace).

```bash
gh skill install kostiantyn-matsebora/claude-canopy canopy-runtime --agent claude-code --scope project --pin v0.17.1
gh skill install kostiantyn-matsebora/claude-canopy canopy         --agent claude-code --scope project --pin v0.17.1
gh skill install kostiantyn-matsebora/claude-canopy canopy-debug   --agent claude-code --scope project --pin v0.17.1
```

Then `/canopy activate` to write the marker block — `gh skill install` skips it. (The vscode extension's `Canopy: Install as Agent Skill (gh skill)` command writes it automatically; re-running `activate` is a safe no-op.)

**Option 3 — Install script (recommended — also wires ambient runtime activation in one step):**

Installs all three skills + writes the canopy-runtime marker block to `CLAUDE.md` / `.github/copilot-instructions.md`. Idempotent — re-run to update. `--target claude|copilot|both` handles either platform in a single pass.

```bash
# macOS / Linux — defaults to --target claude
curl -sSL https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.sh | bash
```

```powershell
# Windows (PowerShell) — defaults to -Target claude
irm https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.ps1 | iex
```

Flags:

| Purpose | bash | PowerShell |
|---|---|---|
| Pin version | `--version 0.18.0` | `-Version 0.18.0` |
| Install a branch / tag / commit SHA (pre-release testing) | `--ref canopy-as-agent-skill` | `-Ref canopy-as-agent-skill` |
| Claude Code only | `--target claude` (default) | `-Target claude` (default) |
| GitHub Copilot only | `--target copilot` | `-Target copilot` |
| **Both platforms in one run** | `--target both` | `-Target both` |

Version resolution order:
1. `--ref` / `-Ref` flag (git branch/tag/SHA — bypasses version resolution; does NOT write `.canopy-version`)
2. `--version` / `-Version` flag (`v<version>` tag)
3. `.canopy-version` file — commit this to your repo to pin a version across collaborators
4. Latest release tag from GitHub

For version-pinned installs, the script writes `.canopy-version` after a successful install, so the next run reinstalls the same version unless you bump it. `--ref` installs skip this write (they're transient by design).

For user-scope install (available across all your projects), run the script from `~` instead of your project root.

### Install for GitHub Copilot

Skills land under `.github/skills/<name>/` and become available via `/canopy` and `/canopy-debug` in Copilot Chat. Copilot does not read `.claude/`, so the install target is different — but the skills themselves are identical.

**With `gh skill` (GitHub CLI v2.90.0+, recommended):**

```bash
gh skill install kostiantyn-matsebora/claude-canopy canopy-runtime --agent github-copilot --scope project --pin v0.17.1
gh skill install kostiantyn-matsebora/claude-canopy canopy         --agent github-copilot --scope project --pin v0.17.1
gh skill install kostiantyn-matsebora/claude-canopy canopy-debug   --agent github-copilot --scope project --pin v0.17.1
```

Then in Copilot Chat, invoke `/canopy activate` to write `.github/copilot-instructions.md` with the marker block — `gh skill install` doesn't do that for you. Or use the install script (Option 3 below) which writes it in the same pass.

**Install script (no external CLI required):**

Same `install.sh` / `install.ps1` as the Claude Code section — just pass `--target copilot` (or `-Target copilot` on PowerShell). Use `--target both` to install for Claude Code and Copilot in one pass.

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.sh | bash -s -- --target copilot
```

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/kostiantyn-matsebora/claude-canopy/master/install.ps1 -OutFile install.ps1
pwsh ./install.ps1 -Target copilot
```

Flags + version resolution are identical to the Claude Code option above.

### Updating

- Plugin: `/plugin marketplace update claude-canopy` then `/plugin install canopy@claude-canopy` (overwrites with the latest).
- `gh skill`: `gh skill update kostiantyn-matsebora/claude-canopy <skill> --pin vX.Y.Z` (per-skill).
- Install script: bump `.canopy-version` (or pass `--version`/`-Version`) and re-run the same one-liner.

Inspect a skill before installing: `gh skill preview kostiantyn-matsebora/claude-canopy <skill>`.

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
Follow .github/skills/canopy/SKILL.md and improve bump-version
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

### Getting Help

Run `/canopy help` (or just ask "help") to see the full operations reference — what each op does, example invocations, skill anatomy, and the op lookup order.

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
│  ┌─ canopy skill (## Tree, first steps) ───────────────────────┐    │
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
3. canopy-runtime/references/framework-ops.md (primitives)         templates/ -> fill <token> -> write file
   IF, ELSE, SWITCH, FOR_EACH, ASK, SHOW_PLAN, VERIFY...         commands/  -> run named shell section
                                                                  constants/ -> load named values
                                                                  verify/    -> post-run checklist

Runtime specs (loaded at Stage 2):
  canopy-runtime/references/runtime-claude.md   -> .claude/ paths, native subagents
  canopy-runtime/references/runtime-copilot.md  -> .github/ paths, inline subagent fallback
```

---

## Contributing

Canopy is currently a personal project. Issues and PRs welcome once the API stabilizes.

- Keep `docs/FRAMEWORK.md` as the single source of truth
- `canopy` skill must be updated whenever framework rules change
- Framework primitives in `skills/canopy-runtime/references/framework-ops.md` are immutable contracts

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and PR expectations.

---

## License

MIT - see [LICENSE](../LICENSE).
