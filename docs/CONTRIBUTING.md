# Contributing to Canopy

Thanks for contributing.

## Scope

This repo is the framework itself. Good contributions include:

- framework docs and clarifications
- improvements to bundled skills
- framework primitives or resource-loading behavior
- agentskills.io spec compliance fixes

If a change affects framework behavior, keep these files in sync:

- `docs/FRAMEWORK.md`
- `skills/canopy-runtime/references/skill-resources.md`
- `skills/canopy-runtime/references/framework-ops.md`
- `skills/canopy/policies/authoring-rules.md`

## Getting Started

1. Fork the repository.
2. Create a branch from `master`.
3. Make focused changes.
4. Update docs when behavior changes.
5. Update `docs/CHANGELOG.md` for user-visible changes.
6. Open a pull request.

## Style

- Keep changes minimal and scoped.
- Preserve the framework's terminology and tree notation.
- Prefer examples that are generic rather than project-specific.
- Do not introduce breaking behavior without documenting it clearly.

## Pull Requests

Before opening a pull request, check:

- the README still matches the actual install flow (`gh skill install ...`)
- framework docs do not duplicate each other unnecessarily
- bundled skills still reflect current framework rules
- `skills-ref validate ./skills/<skill>` passes for any modified skill

## Commit Messages

Conventional Commits are preferred, for example:

- `feat: add submodule setup wiring`
- `fix: align README setup instructions with actual behavior`
- `docs: clarify tree execution model`
