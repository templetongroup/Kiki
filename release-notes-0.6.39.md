# Kiki 0.6.39

- Fixes the paste-fallback popup remaining on screen after dictation finishes in another app.
- Keeps transient messages dismissing after three seconds when Kiki returns from transcribing to idle.
- Adds a deterministic HUD lifecycle check that reproduces and prevents this regression.
