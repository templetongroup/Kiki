# Kiki 0.6.59 (92) — final appearance verification

Extends the [0.6.58 verification](release-0.6.58-verification.md) with a fix for native checkbox labels retaining dark ink when the app overrides a light macOS appearance.

- Native checkboxes now explicitly refresh semantic label ink while retaining native behavior and accessibility. Regression diagnostics include checkbox label color/contrast in Light and Dark.
- Visually verified General Settings on a fresh Dark launch, then live switching to Light. Both themes have readable startup/update checkbox labels.
- Installed the exact notarized 0.6.59 ZIP into `/Applications/Kiki.app`, confirmed Release 0.6.59 / Build 92 in the running app, and visually rechecked Dark General and About after restart.
- Exact extracted release passed feature diagnostics, listening-display diagnostics, code-signature validation, stapling, and Gatekeeper. Post-processing benchmark: 3.30 ms average.
- Apple notarization accepted: `2e8ff230-d004-44d7-b0dc-4c34a02bad17`.
- ZIP SHA-256: `dc35f60f618dd55bd52395e520bf01f4516a84678c6bc52c086761c7f78ae35b`.
- Installed executable SHA-256 matches the signed build: `332dbc009cbec2c117b9d0a7235dd4fc470d44f26ef288ae2702345daaed11b4`.
- Dark remains the saved/default preference after testing. The appearance-only scope and manual coverage limits in the previous report still apply.

Final public artifact, updater, landing-page, and Git verification are tracked in Linear TG-479.
