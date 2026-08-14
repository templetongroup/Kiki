# Kiki public-release gauntlet

This log records independent builder/critic rounds for the release candidate. A source build, screenshot, signature, or builder report cannot pass a piece by itself. Each piece must be inspected in the real artifact by a fresh critic, and the complete installed artifact must pass a final integration critic before publication.

## Objective and release bar

- Objective: complete the latest Kiki app for public release.
- Quality bar: a sleek, modern macOS app with Apple-level clarity, accessibility, stability, recovery, and performance.
- Stop condition: the complete installed artifact is good enough to be proudly submitted to the Mac App Store, even though the public distribution channel remains the signed and notarized GitHub/Sparkle release.
- Feature scope: frozen. Fix correctness, comprehension, accessibility, consistency, performance, and release integrity; do not add unrelated product features.

## Independently judged pieces

1. Interface system, navigation, layout adaptation, copy, keyboard access, and accessibility.
2. Dictation, insertion, shortcut, HUD, model preparation/download, cancellation, retry, and recovery.
3. Meetings, file transcription, history, personalization/privacy, Pawprints, support bundle, and Voice Studio.
4. Packaging, signing, notarization, updater, public asset, installed artifact, and upgrade path.
5. Fresh integration review of the complete installed release candidate.

## Round 0 — Baseline

- What changed: no product changes; established the release baseline and frozen gauntlet scope.
- Evidence: clean `codex/live-transcription` worktree at `eca4e5e`; installed `/Applications/Kiki.app` reports 0.6.24 build 57; `--self-test-features` passed; Master Design interface-risk scan completed.
- Verifier result: baseline only, not a release verdict.
- Largest observed risk candidates: suppressed focus rings, very small metadata text, and readiness/destructive states that still require rendered and interactive verification.
- Failed approach: none.
- Next action: run independent builder/critic loops for pieces 1–4.
- Remaining budget: no explicit token budget was supplied; four pieces plus final integration remain.

## Required critic record

Every critic record must state:

1. Pass or fail.
2. Evidence inspected.
3. The single largest meaningful gap.
4. The observable change required to pass.
5. Working behavior that must not regress.

## Piece 2, Round 1 — Dictation and model state

- What changed: preserved exact model loading/downloading state after transient HUD messages and rearmed custom held shortcuts when the modifier is released before the letter key.
- Evidence: source build, packaged feature diagnostics, HUD diagnostics, rendered 42% model progress, and 3.37 ms deterministic post-processing benchmark.
- Verifier result: **Fail**.
- Single largest gap: a capture shorter than 0.3 seconds stopped audio while leaving Kiki permanently in the recording state.
- Failed approach: the generic post-processing resolver intentionally ignored the recording state and therefore could not recover an ended accidental tap.
- Next action: use a dedicated post-recording resolver and rerun the same critic.
- Remaining budget: no explicit token budget; Piece 2 fix round, three other piece verdicts, and final integration remain.

## Piece 2, Round 2 — Short-capture recovery

- What changed: short captures and Escape cancellation now resolve to idle with a hidden HUD when no work remains, or to transcribing when an earlier zero-wait job is processing or queued.
- Evidence: deterministic ordinary, active-processing, and queued zero-wait diagnostics; source build; full feature and HUD diagnostics; clean diff check.
- Verifier result: **Pass**. The same critic verified ordinary and zero-wait transitions in the packaged artifact; feature/HUD diagnostics passed, the strict signature validated, and post-processing averaged 3.50 ms.
- Failed approach: recorded in Round 1; no repeat yet.
- Next action: retain installed physical shortcut, insertion, undo/retry, and real download recovery for final integration.
- Remaining budget: no explicit token budget; three other piece verdicts and final integration remain.

## Piece 1, Round 1 — Interface and accessibility

- What changed: added standard macOS Settings, Services, Hide, and Window menu commands; raised sub-10-point sidebar/model metadata; added keyboard focus and accessibility help to icon-only information buttons; unified the recording action label to “Stop & Insert.”
- Evidence: minimum/default/large Home renders, Checkup and Settings renders, focused navigation render, source build, packaged feature diagnostics, and clean diff check.
- Verifier result: **Fail**. Layout, focus, and accessibility checks passed, but the fresh critic found Kiki remained an accessory app while the Workbench was open, so the standard macOS menu was invisible and unreachable.
- Failed approach: adding a complete in-memory menu did not make it usable while the runtime activation policy remained permanently accessory-only.
- Next action: promote to a regular foreground app while management windows are open, demote after they all close, then rerun the same critic.
- Remaining budget: no explicit token budget; four piece verdicts and final integration remain.

## Piece 1, Round 2 — Foreground window activation

- What changed: an activation-policy coordinator now promotes Kiki to a regular foreground app whenever a titled management window opens and restores accessory/menu-bar-only behavior after the last such window closes.
- Evidence: Kiki 0.6.25 build 58 built; real Workbench launch promoted the same runtime from UIElement/accessory to Foreground/regular; prior sizing, keyboard, accessibility, and focus evidence remained clear.
- Verifier result: **Fail** on evidence, not a confirmed code defect. The preview ended before last-window demotion, status-item continuity, shortcut response, and all menu actions were observed in one runtime.
- Failed approach: recorded in Piece 1 Round 1; no repeat yet.
- Next action: complete the exact same-process close/demotion/menu/status-item/shortcut interaction, then rerun the same critic again.
- Remaining budget: no explicit token budget; Piece 1 evidence round and final integration remain.

## Piece 1, Round 3 — Complete activation lifecycle evidence

- What changed: no product change before the test; this round exercised the previously missing physical menu evidence.
- Evidence: foreground promotion, menu visibility, Settings navigation, Zoom 1240×840 → 3008×1608, and Minimize/restore passed in one isolated runtime.
- Verifier result: **Fail**. Hide Kiki and Command-H left the app unhidden because application-owned menu commands were not explicitly targeted to `NSApp`.
- Failed approach: relying on the responder chain for application-level Hide commands produced a visible but inert standard menu item.
- Next action: explicitly bind application-owned commands to `NSApp`, repeat Hide/unhide and the remaining close/demotion/status-item/shortcut lifecycle, then rerun the same critic.
- Remaining budget: no explicit token budget; Piece 1 fix/evidence rerun and final integration remain.

## Piece 1, Round 4 — Standard application command targets

- What changed: application-level About, Hide, Hide Others, Show All, Quit, and Bring All to Front commands now explicitly target `NSApp`; Settings targets the app delegate.
- Evidence: the same PID promoted to Foreground; Settings, Minimize, Zoom, Hide/unhide, and Services physically worked; closing the last management window demoted to UIElement while the PID and status item remained; Ctrl-Option-D still produced Kiki’s HUD; minimum/default/large layouts remained unclipped.
- Verifier result: **Fail**. The same critic found that after Settings → Home, repeated Tab stayed trapped on the last sidebar item and never reached Home’s actions.
- Failed approach: the route changed the visible content but did not rebuild or reconnect the key-view loop, leaving keyboard traversal attached to the prior view hierarchy.
- Next action: reconnect logical forward and reverse key traversal whenever Workbench content changes, then rerun the same critic.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 5 — Route-transition keyboard traversal

- What changed: after replacing route content, Kiki asked AppKit to recalculate the automatic key-view loop.
- Evidence: the builder observed Tab/Shift-Tab recovery, but the same critic independently reproduced Settings → Home in the packaged artifact and found Tab, Shift-Tab, and another Tab all remained on `kiki.workbench.nav.settings`; Home’s first action was present but unreachable.
- Verifier result: **Fail**. The same keyboard focus trap repeated.
- Failed approach: `recalculateKeyViewLoop()` alone does not reconnect the last persistent sidebar control to the first control in a newly created content subtree.
- Next action: use a materially different explicit key-view-boundary strategy and rerun the same critic.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 6 — Explicit route key-view boundary

- What changed: Kiki disabled automatic key-loop rebuilding and explicitly reconstructed a full cycle from sidebar controls through the active route’s visible controls after every surface replacement.
- Evidence: the first Settings → Home cycle passed, but the same critic found later cycles trapped on Settings or moved Tab/Shift-Tab to unrelated Models and Personalization controls, with visible focus matching the wrong target.
- Verifier result: **Fail**. Explicit full-loop reconstruction was still corrupted across repeated surface replacement.
- Failed approach: rebuilding the entire `nextKeyView` cycle still interacts with AppKit’s cached route boundaries and does not reliably discard old route links.
- Next action: bypass the cached loop only at the route boundary by directly handling forward/reverse focus movement, then rerun the same critic.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 7 — Direct route-boundary focus handling

- What changed: a Workbench window subclass intercepted `selectNextKeyView` and `selectPreviousKeyView` only at the Settings-to-route boundary and held weak references to the current route’s first control.
- Evidence: the first cycle passed, but the same critic found cycles 2–5 progressively traversed unrelated sidebar and page controls even though route changes completed and visible focus matched those incorrect targets.
- Verifier result: **Fail**. AppKit’s focus-movement hooks still reached stale traversal state after the first surface replacement.
- Failed approach: overriding `selectNextKeyView`/`selectPreviousKeyView` occurs too late to guarantee the cached loop is bypassed consistently.
- Next action: intercept the Tab key event before AppKit consults its loop and handle only the affected boundary, then rerun the same critic.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 8 — Pre-loop Tab event boundary

- What changed: the Workbench window intercepted plain Tab/Shift-Tab before AppKit traversal and armed a one-shot boundary when navigation left Settings.
- Evidence: the first cycle passed, but the same critic found cycle 2 and later cycles returned to unrelated sidebar/page controls; the implementation cleared the one-shot on every mouse event, including mouse-move/hover events that can arrive after navigation.
- Verifier result: **Fail**. The pre-loop interception was disarmed by harmless pointer activity before Tab.
- Failed approach: treating all mouse events as a new deliberate interaction made the boundary state timing-dependent and explained the builder/critic disagreement.
- Next action: retain the boundary through hover/mouse-move and clear it only on a new deliberate interaction; include that event sequence in verification.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 9 — Stable boundary event lifecycle

- What changed: the forward boundary now survives hover/mouse-move and resets only on a new deliberate mouse-down or route change.
- Evidence: the same critic ran five real-click cycles with hover. The first passed, while cycles 2–5 consistently moved to `kiki.workbench.home.readiness.microphone.action` and reversed to `kiki.workbench.home.audio`.
- Verifier result: **Fail**. Event timing stabilized, but generic first-focusable discovery selected an internal readiness action rather than Home’s explicit primary action after later rebuilds.
- Failed approach: inferring a page’s primary control from subview traversal order is unstable when the page rearranges or reuses its content.
- Next action: use Home’s explicit primary action identifier and a one-shot reverse boundary independent of responder identity, then rerun the same critic.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 10 — Explicit primary focus target

- What changed: Home now targets `kiki.workbench.home.dictation` explicitly and a successful forward move arms a one-shot reverse return to Settings.
- Evidence: the same critic ran five real-click/hover cycles. Cycles 1 and 3 passed; cycles 2, 4, and 5 still fell into Home’s native internal order, proving the route-navigation one-shot was intermittently unarmed.
- Verifier result: **Fail**. The target is correct, but route-event timing remains unreliable.
- Failed approach: arming forward focus from route-navigation timing is vulnerable to the exact input sequence even when the target itself is explicit.
- Next action: remove forward timing state and decide the boundary from the actual focused sidebar control at Tab time.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 11 — Contextual sidebar boundary

- What changed: Tab-time logic now recognizes any persistent sidebar first responder, moves to the active page’s explicit first action, and returns Shift-Tab to the captured origin.
- Evidence: the AX Settings-origin path passed, and Home-origin cycles 1–3 passed, but cycles 4–5 fell into Home’s native order even while accessibility still reported `nav.home` before Tab.
- Verifier result: **Fail**. Accessibility focus and `NSWindow.firstResponder` identity can diverge after repeated real route replacements.
- Failed approach: requiring the internal first responder to equal the accessibility-focused sidebar view is not stable enough to identify the origin.
- Next action: capture the exact sidebar sender when its navigation action fires and use that as the next boundary origin.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 12 — Exact navigation sender origin

- What changed: the exact sidebar action sender became the pending origin for the next Tab/Shift-Tab pair.
- Evidence: pointer cycles initially entered Dictation but recorded the Workbench window—not a sidebar item—as pre-Tab focus; later cycles degraded. In the AX path, Settings was the real origin but the clicked Home sender overwrote it, so reverse returned to Home.
- Verifier result: **Fail**. Mouse and accessibility navigation need different origin policies.
- Failed approach: always treating the clicked sender as the origin ignores an existing keyboard/AX origin, while clearing mouse first responder prevents a stable pointer origin.
- Next action: focus and capture the clicked nav item for mouse input, but preserve a live sidebar origin for AX/keyboard activation.
- Remaining budget: no explicit token budget; Piece 1 keyboard fix and final integration remain.

## Piece 1, Round 13 — Input-aware sidebar origin

- What changed: mouse navigation focuses and captures the clicked sidebar item; AX/non-mouse navigation preserves the live sidebar responder; Home uses its explicit Dictation primary action; immediate Shift-Tab returns to the captured origin.
- Evidence: an opt-in diagnostic trace revealed the earlier verifier retained Shift on its next alleged forward Tab (`modifiers=131072`). Temporary logging was removed, the verifier corrected its full key-down/key-up lifecycle, and the same critic then passed five real click/hover cycles (`nav.home → home.dictation → nav.home`) plus the AX path (`nav.settings → home.dictation → nav.settings`). Foreground/accessory lifecycle, native menus/Hide, status item, hotkey HUD, visible focus, AX identifiers, signature, and normal layout also passed.
- Verifier result: **Pass**. No confirmed Piece 1 interface defect remains.
- Failed approach: input-agnostic sender capture is recorded in Piece 1 Round 12; the apparent later failures were then proven to come from a stuck Shift modifier in the verifier rather than Kiki.
- Next action: freeze Piece 1 and proceed to the complete candidate/integration release gate.
- Remaining budget: no explicit token budget; final candidate, publication/updater proof, and fresh integration critic remain.

## Piece 3, Round 1 — Secondary workflow concurrency

- What changed: file transcription now admits only one heavyweight request, exposes cancellation, blocks drops while busy, rejects stale completions, and restores retry only after cancellation completes.
- Evidence: regression diagnostic failed before the gate and passed after it; source and packaged feature diagnostics passed; idle/completed file-transcription renders inspected.
- Verifier result: **Fail**. File concurrency and export interaction passed, but the fresh critic found Meeting Mode did not preserve Private Session across the entire recording lifecycle.
- Failed approach: checking the current Private Session state only when meeting transcription finished allowed a capture started privately to become persistable before Stop.
- Next action: make meeting privacy sticky from capture start and whenever privacy is enabled mid-capture, then rerun the same critic.
- Remaining budget: no explicit token budget; four piece verdicts and final integration remain.

## Piece 3, Round 2 — Sticky meeting privacy

- What changed: Meeting Mode snapshots privacy at capture start, permanently marks the active capture private if privacy is enabled mid-recording, gates history on that lifecycle state, and resets only after the capture/transcription lifecycle ends.
- Evidence: deterministic coverage for start-private/end-before-stop, start-normal/enable-then-disable, and a subsequent normal meeting; debug build, feature diagnostics, HUD diagnostics, and clean diff check passed.
- Verifier result: **Pass**. The same critic verified all three privacy-lifecycle cases plus packaged builds, meeting exports, support allowlist, Pawprints, file request gate, diagnostics, signing, and benchmark.
- Failed approach: recorded in Piece 3 Round 1; no repeat yet.
- Next action: retain real microphone/system-audio, disposable installed history, file cancellation, and Voice Studio synthesis for final integration.
- Remaining budget: no explicit token budget; Piece 1 rerun and final integration remain.

## Piece 4, Round 1 — Release artifact integrity

- What changed: the release command now reopens and verifies the final post-staple ZIP, including identity fields, Sparkle feed/key, architecture, signature, notarization ticket, Gatekeeper, feature diagnostics, HUD states, benchmark, and SHA-256.
- Evidence: the new verifier passed against the public Kiki 0.6.24 build 57 archive; its SHA-256 was `727940cbfbb9e631a48e5eb3a92847c5b013fa188ad07ae32bcb63d7c7636ae6`, matching the public release and installed executable.
- Verifier result: **Fail**. The fresh critic confirmed final-archive integrity but found that a new public version could default to build 1 and therefore never be offered over public build 57.
- Failed approach: validating the final archive against the caller-supplied build proved internal consistency but not updater monotonicity.
- Next action: require an explicit positive build greater than the newest public feed entry, then rerun the same critic.
- Remaining budget: no explicit token budget; four piece verdicts and final integration remain.

## Piece 4, Round 2 — Monotonic updater build

- What changed: public release now requires an explicit semantic version and positive build number greater than the newest build in the intended appcast; the final archive verifier retains exact version/build checks.
- Evidence: missing build rejected; malformed build rejected; build 57 rejected against public build 57; Kiki 0.6.25 build 58 preflight passed; shell syntax and diff checks passed.
- Verifier result: **Pass**. The same critic confirmed fail-fast rejection for missing, malformed, and stale builds; build 58 preflight; exact-version/build rejection; and all prior public-archive integrity checks.
- Failed approach: recorded in Piece 4 Round 1; no repeat yet.
- Next action: align the distribution guide with the new required-build contract, then rerun the same critic.
- Remaining budget: no explicit token budget; Piece 1 evidence rerun and final integration remain.

## Piece 4, Round 3 — Distribution guidance alignment

- What changed: the public distribution guide now documents `KIKI_BUILD_NUMBER` as required and greater than the newest public appcast build, with 0.6.25 build 58 clearly marked as an example.
- Evidence: the critic inspected the guide, release command, preflight script, release checklist, public appcast, exact-archive verifier, syntax checks, and failure cases for missing, malformed, stale, and invalid version/build values.
- Verifier result: **Pass**. Release code, checklist, and documentation now state the same monotonic-build contract.
- Failed approach: no new failed implementation; the earlier guide simply described the superseded default-build behavior.
- Next action: run the verifier against the final notarized build 58 ZIP and prove an older installed Kiki completes the public Sparkle update.
- Remaining budget: no explicit token budget; Piece 1 evidence rerun and final integration remain.

## Complete candidate, Round 1 — Notarized public artifact and updater path

- What changed: built Kiki 0.6.25 build 58 from source commit `8ab9fb98b3946cc155d923023d733a250c5801b3`, signed it with Developer ID, notarized and stapled it, published the exact ZIP as GitHub release `v0.6.25`, and published its signed Sparkle entry on `main`.
- Evidence: the final ZIP reopened successfully through the release verifier; strict nested signing, notarization ticket, Gatekeeper, arm64, fixed feed/key, feature diagnostics, HUD diagnostics, and deterministic post-processing passed. The local and freshly downloaded public ZIPs shared SHA-256 `d5de9fb46d20970bc2d931e6893ef00acbd70cce3204936766e952523efac0e6`. The public appcast reported 0.6.25 build 58 with the exact archive length and Sparkle signature.
- Verifier result: **Pass** for artifact and publication integrity. The installed Kiki 0.6.24 build 57 discovered 0.6.25 through its own Check for Updates flow, downloaded it, displayed Ready to Install, installed and relaunched as 0.6.25 build 58. The installed bundle passed strict signing, stapler validation, and Gatekeeper; its executable matched the public ZIP.
- Failed approach: optional Sparkle delta generation was unavailable because older archives contain signed extended attributes on `mlx.metallib`; the signed full-archive update path was retained and completed successfully.
- Next action: obtain the fresh final integration critic's whole-product verdict against `/Applications/Kiki.app` and close only if it passes.
- Remaining budget: no explicit token budget; fresh final installed-artifact integration verdict and evidence record remain.

## Final integration, Round 1 — Installed Kiki 0.6.25

- What changed: no product change before the verdict; a fresh integration critic reviewed the exact public `/Applications/Kiki.app` installed through Sparkle from 0.6.24.
- Evidence: version/build, Developer ID, hardened runtime, notarization, staple, Gatekeeper, public tag/feed/SHA, all primary Workbench routes, visible keyboard focus, native menus, menu-bar lifecycle, and packaged diagnostics were inspected.
- Verifier result: **Fail**. Home described the configured `Fn` shortcut as press-twice even though this Mac used Hold to Dictate, while Dictation foregrounded the separate hardcoded `⌃⌥D` toggle without identifying it as a second hands-free path.
- Failed approach: independent shortcut strings described different activation paths without a shared behavior-aware source of truth.
- Next action: derive Home, Dictation, Settings, Checkup, and menu-bar guidance from the configured shortcut and activation mode; explicitly label `⌃⌥D` as hands-free; rerun the same critic.
- Remaining budget: no explicit token budget; fix verification, replacement publication/update, and fresh final installed-artifact critic remain.

## Final integration, Round 2 — Unified shortcut guidance candidate

- What changed: added one behavior-aware shortcut guidance source for Hold to Dictate, Press to Toggle, shortcut testing, recording stop hints, and the separate hands-free action. Home, Dictation, Settings, Checkup, and the status menu now use it.
- Evidence: debug and packaged release builds passed; feature and HUD diagnostics passed; deterministic post-processing averaged 3.30 ms. Native Accessibility inspection of the real 0.6.26 build 59 candidate showed `Hold Fn to dictate; release to stop and insert` on Home, Dictation, and Settings, plus a separately labeled `⌃⌥D` hands-free toggle. The default-size Dictation render was unclipped and visually coherent.
- Verifier result: **Pass**. The same critic verified packaged 0.6.26 build 59 in persisted hold mode and isolated non-persistent toggle mode across Home, Dictation, Settings, unresolved and armed Checkup states, and the status menu. Compact 900×760 and default 1240×840 layouts, visible keyboard focus, native navigation, status-menu controls, window resizing, and packaged diagnostics also passed.
- Failed approach: recorded in Round 1; no repeat yet.
- Next action: publish the frozen candidate, update installed 0.6.25 through Sparkle, then give the exact installed public artifact to a new fresh integration critic.
- Remaining budget: no explicit token budget; replacement publication/update and fresh final installed-artifact critic remain.

## Final integration, Round 3 — Installed public Kiki 0.6.26

- What changed: published the Round 2 source as Developer ID-signed, notarized Kiki 0.6.26 build 59; independently matched the public ZIP and live appcast; updated installed 0.6.25 through Sparkle.
- Evidence: SHA-256 `231504dd7e59ce601e3bfe30ea7000f9f08d9a1204d8fba994b19d51a3bbbf8a` matched local and public ZIPs; the installed app passed strict signing, staple, Gatekeeper, executable comparison, feature/HUD diagnostics, and performance checks. A new fresh integration critic inspected the exact installed public artifact.
- Verifier result: **Fail**. On this Mac, all-controls traversal uses Option-Tab. Kiki's custom Workbench boundary handled plain Tab/Shift-Tab only, so Option-Tab traversed the sidebar and became trapped on Settings; Personalization similarly remained trapped on Learning.
- Failed approach: the explicit boundary solved standard Tab traversal but filtered out the Option modifier, excluding macOS's alternate all-controls traversal gesture.
- Next action: recognize Option-Tab and Option-Shift-Tab as forward/reverse traversal at the same route boundary, then rerun the same critic.
- Remaining budget: no explicit token budget; keyboard fix verification, replacement publication/update, and a new fresh installed-artifact critic remain.

## Final integration, Round 4 — All-controls traversal candidate

- What changed: the Workbench route boundary now treats Tab and Option-Tab as forward traversal and Shift-Tab and Option-Shift-Tab as reverse traversal; Control/Command combinations remain untouched. Focus-modifier diagnostics cover all six cases.
- Evidence: debug and packaged 0.6.27 build 60 builds passed; feature and HUD diagnostics passed; clean diff check passed.
- Verifier result: **Fail**. The same critic proved both sidebar-to-page and page-to-sidebar crossings with plain and Option-modified Tab, but 12 subsequent forward Tab events remained trapped on Home's Try Dictation action and never reached the other visible actions.
- Failed approach: boundary-only event interception repaired the crossing but left AppKit's stale internal key loop in control inside each dynamically replaced route.
- Next action: replace the boundary-only repair with one explicit live sequence of every visible, enabled route control, including forward/reverse movement, wrapping to the exact sidebar origin, and scrolling the focused control into view.
- Remaining budget: no explicit token budget; full route-loop verification, replacement publication/update, and a new fresh installed-artifact critic remain.

## Final integration, Round 5 — Complete route-aware key loop

- What changed: the Workbench now rebuilds a visual-order list of all visible, enabled controls whenever a route changes and handles forward/reverse traversal, sidebar-origin restoration, wrapping, and scroll-to-visible for the complete route. A synthetic diagnostic proves first/next/last/wrap/reverse behavior.
- Evidence: debug and packaged Kiki 0.6.27 build 60 builds passed; feature and HUD diagnostics passed; clean diff check passed.
- Verifier result: **Fail.** After the Mac was unlocked and duplicate Kiki processes were removed, Home and Dictation passed the full matrix. Settings/Checkup and Personalization passed forward traversal, but both reverse variants became trapped in the practice text area and table at every size.
- Failed approach: recorded in Round 4; this round uses a materially different full-route traversal strategy.
- Next action: normalize composite child responders back to their registered route control and exclude focusable scroll/clip containers from the route sequence, then rerun the same complete matrix.
- Remaining budget: no explicit token budget; same-critic verdict, replacement publication/update, and a new fresh installed-artifact critic remain.

## Final integration, Round 6 — Composite responder normalization

- What changed: route discovery now registers actual controls and text views rather than focusable scroll/clip containers; live child and field-editor responders normalize to the nearest registered route control before traversal continues.
- Evidence: debug and Developer ID-signed packaged builds passed feature/HUD diagnostics and strict signing. The same critic physically verified both reverse sequences at all three sizes and with both Shift variants.
- Verifier result: **Fail** on a new gap. Composite reverse traversal is fixed, but at the true 900×650 Settings minimum the practice text area received focus while remaining completely below the outer Checkup viewport.
- Failed approach: Round 5's full sequence did not account for AppKit composite-control responder identity; this round changes both route discovery and live responder normalization.
- Next action: propagate scroll-to-visible through nested scroll ancestors, then rerun minimum-size Checkup visibility and the bounded regressions.
- Remaining budget: no explicit token budget; same-critic verdict, replacement publication/update, and a new fresh installed-artifact critic remain.

## Final integration, Round 7 — Nested focus visibility

- What changed: after focus moves, the focused control's bounds are converted and revealed through every ancestor so an inner text/table scroll view cannot prevent the outer Workbench page from scrolling it onscreen.
- Evidence: debug and signed packaged diagnostics passed. Physical 900×650 Checkup verification proved the practice field scrolls fully onscreen and preserves both corrected reverse variants.
- Verifier result: **Fail** on a new gap. Reverse traversal starting from Dictation or Personalization's active sidebar item escaped through earlier sidebar items instead of entering the route's last control; Home minimum also exposed an inconsistent scrollbar stop.
- Failed approach: a single `scrollToVisible` call stopped at the focused control's nearest clip view and did not reveal it in the outer page.
- Next action: make reverse traversal from a sidebar origin enter the route's last visible enabled control, mirror the full forward loop, and keep any visible scrollbar stop consistent in both directions.
- Remaining budget: no explicit token budget; same-critic verdict, replacement publication/update, and a new fresh installed-artifact critic remain.

## Final integration, Round 8 — Symmetric reverse route entry

- What changed: reverse traversal from an active or pending sidebar origin now enters the route's last visible enabled control and preserves that exact origin for wrapping; diagnostics prove reverse entry and continued reverse order.
- Evidence: debug and Developer ID-signed packaged builds passed feature/HUD diagnostics and strict signing. The same critic physically verified Home, Dictation, Settings/Checkup, and Personalization at minimum/default/large sizes with plain and Option-modified forward/reverse traversal.
- Verifier result: **Pass**. Reverse traversal enters the last page control, follows exact reverse visual order, keeps focus visible, and wraps to the exact originating sidebar item. Home's non-task scroll indicator is symmetrically omitted. Checkup's practice field remains fully visible at 900×650.
- Failed approach: prior manual traversal was complete only after focus had entered a page; its sidebar entry rule existed for forward traversal but not reverse traversal.
- Next action: freeze, publish, update the installed app through Sparkle, and give the exact public installed artifact to a new fresh integration critic.
- Remaining budget: no explicit token budget; same-critic verdict, replacement publication/update, and a new fresh installed-artifact critic remain.
