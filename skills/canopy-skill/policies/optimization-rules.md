# Skill Optimization Rules

## 1. skill.md contains only orchestration

skill.md must contain only:
- Frontmatter (`name`, `description`, `argument-hint`)
- `## Agent`, `## Tree`, `## Rules`, `## Response:` sections
- Op calls and natural language in the tree
- `Read <category>/<file>` references where tree format is not yet used

skill.md must NOT contain:
- Tables
- JSON, YAML, or any structured data blocks
- Scripts, shell commands, or code fences with executable content
- Inline examples or templates
- Phase-by-phase prose when a `## Tree` is possible

## 2. Structured content goes into categorized subdirectories

Each skill directory contains category subdirectories alongside skill.md:

| Category dir | Content type | File pattern |
|---|---|---|
| `schemas/` | Subagent output schemas, input parameter tables | `explore-schema.json`, `inputs.md` |
| `templates/` | YAML/JSON/Markdown templates to be instantiated | `<name>.yaml`, `<name>.md` |
| `constants/` | Hardcoded values, config references | `constants.md` |
| `policies/` | Rules, access control definitions, best practices | `access-control.md`, `optimization-rules.md` |
| `commands/` | Shell and PowerShell scripts | `commands-<purpose>.ps1`, `commands-<purpose>.sh` |
| `verify/` | Verification expected states and checklists | `verify-expected.md` |
| `ops.md` | Skill-local op definitions (alongside skill.md, not in a subdir) | `ops.md` |

One concern per file. Do not bundle unrelated content into a single file.

## 3. Subagent contracts — schema in file, task in ## Agent

If a skill launches a subagent:
- Schema must exist as `schemas/explore-schema.json` (the rules file makes this the output contract automatically)
- `## Agent` section needs only the task description — "do not inline-read" and "return JSON only matching schema" are implicit from the ambient `skill-resources.md`
- No freeform prose output — every field the skill uses must be declared in the schema

## 4. Prose → step lists

Replace narrative paragraphs with numbered or bulleted steps.
Each step: one action, one outcome, optionally one `Read <category>/<file>` reference.
No multi-sentence explanations inside a step.

## 5. Phase structure preserved only when tree format is not applicable

Prefer `## Tree` over `## Phase N` sections.
Keep phase headings only when steps have complex inter-phase state that cannot be expressed as a flat pipeline.
Keep `## Rules` and `## Response:` sections as short bullet lists.
Remove subsection headings that are just labels for what follows extracted content.

## 6. Tree format over step lists

When `## Steps` is a sequential pipeline with only `IF` branches, replace with `## Tree`.

Two equivalent syntaxes are accepted — convert to whichever reads more clearly:

**Markdown list syntax** (preferred for new or simple trees):
```markdown
* skill-name
  * OP_ONE >> output
  * IF << condition
    * OP_TWO
  * OP_THREE << input
```

**Box-drawing syntax** (fenced code block):
```
skill-name
├── OP_ONE >> output
├── IF << condition
│   └── OP_TWO
└── OP_THREE << input
```

Each node is an op call (`OP_NAME << inputs >> outputs`) or natural language — both are valid.
`IF` nodes branch on condition; both branches may be ops or natural language.
Op definitions in `ops.md` may also use tree notation internally.

## 7. Multi-clause steps → hierarchical sub-bullets

Steps with multiple clauses joined by `;` or ` — ` must be split into a numbered step header with indented sub-bullets.

Before:
```
1. **Check tunnel** — read `commands/commands-cloudflare.ps1` for check command; if tunnel exists capture `id`; if not: proceed to step 2
```

After:
```
1. **Check tunnel**
   - Read `commands/commands-cloudflare.ps1` for check command
   - If tunnel exists: capture `id`
   - If not: proceed to step 2
```

Each sub-bullet: one action or one condition. No inline chaining with `;` or ` — `.

## 8. Reference pattern

Standard reference line:
  `Read \`<category>/<file>\` for <brief description>.`

Used at the point in the steps where the content is needed — not all at the top.
Load only what's needed for the current branch or action.

## 9. Behavior details belong in resource files, not skill.md

Mechanical behavior (e.g. "patch if path exists, put if new", "token substitution targets") belongs as a section comment in the resource file itself, not repeated in skill.md steps.

skill.md states only:
- Which file to read (`Read commands/X.ps1 for <operation>`)
- Which section/operation (`for <operation>` identifies the section)
- Arguments and captured output values
- Exceptions to default behavior (these stay inline — e.g., `[never overwrite]`)

## 10. Named operations for recognizable patterns

For multi-line blocks expressing a single recognizable operation, replace with a named op.

Lookup order: `<skill>/ops.md` first, then `shared/project/ops.md`, then `shared/framework/ops.md`.

Cross-skill project ops use `shared/project/ops.md`. Framework primitives use `shared/framework/ops.md`. Skill-local ops use `<skill>/ops.md`.

Named op notation: `OP_NAME << inputs >> outputs`
Examples: `MY_DEPLOY << dir`, `MY_VERIFY << namespace`, `MY_SECRET_READ <path> >> {fields}`

## 11. Skill-local ops.md for branches and procedures

Conditional branches, multi-step procedures, and decision trees specific to one skill belong in `<skill>/ops.md`.

Op definitions use tree notation where branching exists; prose for simple linear ops:

```
## OP_NAME << inputs >> outputs

description of simple op
```

```
## OP_NAME << inputs >> outputs

\`\`\`
OP_NAME
├── IF << condition
│   └── branch-op or natural language
└── otherwise — natural language description
\`\`\`
```

## 12. Control flow as ops — standard notation

Replace all ad-hoc patterns with standard control flow ops:

| Old pattern | Replace with |
|---|---|
| `Ask: "question? (yes/no)"` | `ASK << question? \| Yes \| No` |
| `Show Plan (field1, field2)` | `SHOW_PLAN >> field1 \| field2` |
| `Read verify/verify-expected.md for expected state` | `VERIFY_EXPECTED` |
| `→ {fields}` (output capture) | `>> {fields}` |
| `IF << condition → action` (inline branch) | `IF << condition` with `action` as nested child node |
| `ELSE → action` (inline branch) | `ELSE` with `action` as nested child node |
| `if X: do Y` (in steps) | `IF << X` tree node with `Y` as child |
| `else if Y: do Z` (in steps) | `ELSE_IF << Y` chained after `IF` |
| `else: do Z` (in steps) | `ELSE` chained after `IF` or `ELSE_IF` |
| early return from op (no error) | `BREAK` |
| fatal stop with message | `END <message>` |
