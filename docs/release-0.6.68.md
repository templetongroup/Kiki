# Kiki 0.6.68

- Fix the blank Capture Meeting transcript panel. Meeting text now resizes and scrolls with the window.
- Preserve existing transcripts and saved notes without rewriting history.
- Report summary-generation failure explicitly instead of substituting the first two transcript fragments and calling that a successful summary.

## Important limitation

Meeting-summary quality remains under investigation. This release fixes display and failure reporting; it does not provide a new summarization model or guarantee accurate summaries. Review the full transcript and verify any generated notes before relying on them.

Developer ID signed and Apple notarized. Build 101. Verified with the affected saved meeting on the Work MBP at three window sizes.
