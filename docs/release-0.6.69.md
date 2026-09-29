# Kiki 0.6.69 — meeting speech preservation

- Meeting capture no longer runs through dictation editing rules. Phrases such as “scratch that” cannot erase preceding meeting speech, and meeting participants cannot trigger dictation snippets or learned text replacements.
- Ordinary dictation retains its existing editing, snippet and replacement behavior.
- Repair the packaged Whisper Metal shader so a missing header does not force CPU fallback. The actual packaged shader is compiled as a release check.
- Preserve existing saved transcripts and notes. This update cannot reconstruct speech already omitted from earlier transcripts.

## Important limitation

Meeting-summary accuracy remains unresolved. Experimental summarization engines did not pass the full-meeting evaluation and are **not included** in this hotfix. Check generated notes against the transcript; do not rely on Kiki alone for important meeting records.

Developer ID signed, Apple notarized and stapled. Build 102. Source regression tests cover every speech profile, preservation of negation and corrections, snippet isolation, and unchanged dictation behavior. The final archive passes signature, Gatekeeper, shader compilation, feature and listening-display checks.
