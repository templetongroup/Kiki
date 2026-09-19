# Kiki 0.6.60 verification

- Scope: Light default for missing/invalid appearance preferences; existing saved choices preserved. No meeting-performance fix is included.
- Release source: `50998db1b0c445f641463789ac852ad9976b1def`; version 0.6.60, build 93.
- Developer ID signature verified; Apple notarization accepted (`6931b6d8-e2da-482d-b13d-0d0ee19bcece`); stapling and Gatekeeper passed.
- Exact post-staple ZIP passed feature, appearance-default/persistence, and HUD diagnostics. Post-processing benchmark: 3.22 ms (not a meeting-performance test).
- Public ZIP downloaded again; SHA-256 matches local tested archive: `91ee3c75ec94cd37dcac55de0f7b48091473ad83d54891dbc7abe8ea0644bfe4`.
- Public Sparkle feed offers build 93; public archive EdDSA verification passed.
- Installed 0.6.59 detected 0.6.60 through Check for Updates. Install Update and Install and Relaunch completed through Sparkle.
- Relaunched installed UI reports 0.6.60 / 93. Installed executable SHA-256 matches packaged executable: `8bf0bf5a6671f409281835fd0a63e98096031d5941eec54b96b5fd8d0d13c6cf`.
- Installed signature and Gatekeeper passed; installed feature and HUD diagnostics passed. Saved Dark preference remained Dark, confirmed in Settings and preferences.
- Website source `80f3fa7f5b1c40abd13623689e12e35d8cae35fc` updates download links/version to 0.6.60. Sites version 30 deployment succeeded at https://kiki-for-mac.tonyricciardi.chatgpt.site.
- Linear: TG-485. Sustained Zoom capture, a separate clean-user GUI run, and full cross-app dictation testing were not performed for this narrow release. No claims of resolving those issues are made.
