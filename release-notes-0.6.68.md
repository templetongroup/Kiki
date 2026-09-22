# Kiki 0.6.68

## Meeting notes and transcript reliability

- Preserve model-extracted next steps instead of replacing them with the first six keyword-matching utterances.
- Process long meetings in bounded parts and retain each part's extracted key points and actions without overflowing the final summary context.
- Reject leaked prompt instructions and incomplete summaries. Failed generation leaves saved text unchanged; opening remarks are no longer presented as a completed summary.
- Extract follow-ups separately with references to original transcript entries. If the local model declines a section, retain useful notes as an explicitly incomplete draft with review gaps instead of silently pretending every section succeeded.
- Create or refresh summaries directly from the saved Meetings library, with per-part progress. Summary generation requires macOS 26+ and available Apple Intelligence.
- Preserve decimal version numbers during sentence splitting; tolerate filler differences in cross-source echo detection while retaining short acknowledgments and negation differences.
- Mark possible post-meeting material for review after a late farewell exchange without deleting it.

These changes do not reconstruct missing words in old transcripts, prove speaker identity, or establish audio-grounded transcription accuracy. Generated notes should be reviewed before sharing.
