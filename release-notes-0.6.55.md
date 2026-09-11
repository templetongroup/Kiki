# Kiki 0.6.55

- Fixes automatic update checks so Kiki initializes Sparkle and checks its signed feed whenever the app launches and automatic checks are enabled.
- Preserves the disabled setting: Kiki does not perform a launch check when automatic checks are turned off.
- Adds an installed-app regression test that verifies a deliberately overdue update check runs on launch.
