# Kiki public-release gate

Feature scope is frozen until every required check below passes against the same version, build, and archive.

## Source gate

- [ ] `git diff --check` is clean and the intended release commit is recorded.
- [ ] Debug and release builds succeed without new warnings.
- [ ] `Kiki --self-test-features` passes from the source build.
- [ ] Privacy contracts pass: Private Session, support-bundle allowlist, Pawprints exclusions/reset, and memory-only retry audio.
- [ ] Every enabled action control in every window passes center-point hit testing.

## Packaged-app gate

- [ ] The packaged app reports the intended version and build.
- [ ] The packaged executable passes `--self-test-features`.
- [ ] `codesign --verify --deep --strict` succeeds with the intended Developer ID identity.
- [ ] Gatekeeper assessment and notarization-ticket validation succeed.
- [ ] The SHA-256 of the tested ZIP is recorded.

## Installed-app gate

- [ ] Install the exact tested archive into `/Applications/Kiki.app`.
- [ ] Confirm the installed version/build and executable hash match the packaged artifact.
- [ ] Launch the installed app and physically click every new menu item, window, checkbox, popup, and button.
- [ ] Kiki Checkup detects the selected microphone, live signal, permissions, model, shortcut, and an actual inserted first dictation.
- [ ] A real dictation inserts into another app; exact Undo removes it; Retry replaces it from memory.
- [ ] Private Session leaves history, learning, confidence review, and Pawprints unchanged.
- [ ] Read Selection prefills Voice Studio and does not generate until Generate is clicked.
- [ ] Pawprints opt-in, aggregate update, opt-out, Private Session exclusion, and complete reset work.
- [ ] A support ZIP opens and contains only `diagnostics.json` and `README.txt` with no user content.
- [ ] Existing Settings, Models, Personalization, Meeting Mode, audio-file transcription, Voice Studio playback/stop, exports, and the supported dark Studio Hardware layout still work.

## Publication gate

- [ ] Publish the exact tested ZIP and signed Sparkle appcast entry.
- [ ] Download the public asset again and confirm its SHA-256 matches.
- [ ] Confirm an older installed Kiki sees and installs the update.
- [ ] Repeat the installed-app smoke checks after updater installation.
