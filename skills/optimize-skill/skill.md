---
name: optimize-skill
description: Optimize a Claude Code skill — extract inline structured content into categorized subdirectories, convert steps to Tree format, create skill-local ops.md, compress prose, and replace cross-skill patterns with named ops. Result: a lean skill.md containing only orchestration.
argument-hint: "<skill-name>"
---

Optimize skill: $ARGUMENTS

---

## Agent

**explore** — reads `<skill-name>/` under the skills directory — skill.md, ops.md (if present), and all existing category subdirectory files.

---

## Tree

```
optimize-skill
├── EXPLORE >> context
├── AUDIT << context
├── SHOW_PLAN >> files to create | blocks to replace | trims | splits | named ops | tree conversions
├── ASK << Proceed? | Yes | No
├── IF << inline_blocks or collapsible_bullets present
│   └── EXTRACT_RESOURCES
├── REWRITE_SKILL_MD
└── VERIFY >> line_count_delta | files_created | remaining_issues
```

---

## Rules

- Do not change the skill's logic or intent — only structure and format
- Do not merge unrelated content into one file
- Preserve existing categorized files that are already correct
- Apply `policies/optimization-rules.md` strictly

## Response: Summary / Plan / Files / Notes
