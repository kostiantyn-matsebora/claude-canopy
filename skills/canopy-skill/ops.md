# canopy-skill — Local Ops

Skill-specific ops. Highest priority in the three-level lookup order.
Branches may be op calls or natural language.

---

## AUDIT \<\< context

Read `policies/optimization-rules.md` for the full rule set and category directory mapping.

```
AUDIT << context
├── list inline_blocks — type, line range, target category/file
├── list prose_sections — heading, line range, compression note
├── list agent_boilerplate — ## Agent sections with boilerplate to trim
├── list inline_step_chains — multi-clause steps joined by ; or —
├── list collapsible_bullets — mechanical sub-bullets collapsible by category rule
├── list named_op_candidates — patterns replaceable with ops from shared/ops.md
├── list tree_candidates — ## Steps sections convertible to ## Tree with IF nodes
├── list ops_candidates — conditional branches extractable to skill-local ops.md
└── report current line count
```

---

## EXTRACT_RESOURCES

For each `inline_block` from audit output:

```
EXTRACT_RESOURCES
├── determine category subdir from policies/optimization-rules.md
├── create <skill-name>/<category>/<file>
└── one concern per file — do not bundle unrelated content
```

---

## REWRITE_SKILL_MD

```
REWRITE_SKILL_MD
├── replace each inline_block with Read `<category>/<file>` reference at point of use
├── compress prose_sections to numbered/bulleted steps
├── trim ## Agent — remove boilerplate; keep task description only
├── split inline_step_chains → step header + indented sub-bullets
├── collapse collapsible_bullets → one-line Read reference; move behavior to resource file
├── replace named_op_candidates with shared ops (OP_NAME << >> notation)
├── replace Ask: "..." patterns with ASK << question | options
├── replace → {fields} captures with >> {fields}
├── IF << tree_candidates present
│   └── convert ## Steps to ## Tree; extract conditional branches to ops.md with tree notation
├── IF << ops_candidates present
│   └── create <skill>/ops.md — skill-local op definitions using tree notation where branching exists
└── remove now-empty subsection headings
```

---

## VERIFY \>\> line_count_delta | files_created | remaining_issues

```
VERIFY
├── report final line count vs original
├── report list of category files created
├── IF << inline_blocks remain
│   └── flag as error
├── IF << inline_step_chains remain
│   └── flag as error
├── IF << collapsible_bullets remain
│   └── flag as error
├── IF << named_op_candidates not replaced
│   └── flag as error
├── IF << tree_candidates not converted
│   └── flag as warning
├── IF << ops_candidates not extracted
│   └── flag as warning
└── IF << Ask:/Show Plan/(→) patterns remain
    └── flag as error
```
