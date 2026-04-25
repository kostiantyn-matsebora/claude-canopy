# Expected State After ACTIVATE

For each target file (`CLAUDE.md` and/or `.github/copilot-instructions.md`):

- [ ] The target file exists at the workspace root (created by ACTIVATE if it didn't exist).
- [ ] The file contains exactly one `<!-- canopy-runtime-begin -->` line and exactly one `<!-- canopy-runtime-end -->` line (or, if multiple pairs were already present and ACTIVATE warned about them, the count is unchanged from before).
- [ ] The block content between (and including) the markers is byte-identical to `constants/marker-block.md`.
- [ ] All file content above the opening marker is preserved byte-identical to its pre-ACTIVATE state (only exception: if the file did not previously end with a newline, one was added before the appended block).
- [ ] All file content below the closing marker is preserved byte-identical to its pre-ACTIVATE state.
- [ ] The file ends with a newline character.
- [ ] No new files were created outside the workspace root.

Re-running ACTIVATE on the resulting file produces no diff (idempotency holds).
