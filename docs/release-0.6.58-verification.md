# Kiki 0.6.58 (91) — verification

## Scope

Light/Dark/Follow System appearance, native control consistency, immediate hover feedback, numeric typography, and nested corner geometry. Craft is a reference for AppKit implementation, not an imported web component library.

## Verified on 2026-09-18

- Debug and release builds succeeded on Apple Silicon/macOS 27.
- Feature diagnostics passed, including appearance preference round trips, text contrast of at least 4.5:1 for five primary text/surface pairs in both themes, equal button typography/geometry, equal model-action widths with label padding, numeric stability, keyboard traversal, window control hit testing, history, meetings, and privacy regressions.
- Exact final ZIP extracted and passed code-signature validation, notarization/stapling, Gatekeeper, feature diagnostics, listening-display diagnostics, and deterministic post-processing benchmark (3.32 ms average for 2,002 context terms).
- Apple notarization accepted: `e821a2ad-cb1a-465c-8263-e6eaea491035`.
- ZIP SHA-256: `9698baaf5858bac211b19a2f42c51e179ec60d0fef88a690175747cc2c3a3726`.
- Installed from that ZIP into `/Applications/Kiki.app`; version 0.6.58/build 91 confirmed in the running UI. Installed executable SHA-256 matches the signed build: `a4031d691a510003816fca381f5b88504267d7dfc6bc6530a26ee87dc03b2f58`.
- Light appearance inspected interactively on Home, General, Models, History, Meeting Capture, and Words & Replacements. Light preference survived app restart. Follow System selected in the installed UI and matched the Mac's light appearance.
- Native window zoom/restore inspected on Words & Replacements.
- Generated 54 deterministic native layout captures: nine routes, two appearances, and widths 900/1240/1440. Representative compact, regular, and large renders were reviewed. These are source-layout captures, not 54 independently exercised live workflows; standalone debug renders lack bundled artwork.

## Coverage limits

- No new live microphone/meeting recording was made for this appearance-only update; listening-display state transitions were exercised by the existing diagnostics.
- macOS's global appearance setting was not changed. Follow System inheritance was checked, but automatic sunrise/sunset switching was not observed.
- VoiceOver speech output and a physical continuous edge-drag resize sweep were not separately exercised.

## Release tracking

Linear: TG-479. Public release, signed updater feed, and landing page verification are recorded in that issue after publication.
