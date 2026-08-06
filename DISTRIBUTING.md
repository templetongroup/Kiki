# Signing and distributing Kiki

Kiki has separate signing paths for local development and public releases. Signing keys and notarization credentials must never be committed to the repository.

## Stable local development signing

An ad-hoc signature changes whenever the app is rebuilt, which can make macOS ask for Accessibility permission again. Create a self-signed identity in your login keychain once:

```bash
./scripts/setup-local-signing.sh
./scripts/make-app.sh
```

The setup script creates `Kiki Local Code Signing` in the current user's login keychain and grants `/usr/bin/codesign` access to its private key. `make-app.sh` selects that identity automatically. Other contributors do not need this certificate; without it, their builds fall back to ad-hoc signing.

This certificate is only trusted on the Mac where it is installed. It is not a substitute for Developer ID and must not be used for public downloads.

## Public GitHub releases

Apps downloaded outside the Mac App Store should be signed with an Apple-issued **Developer ID Application** certificate and notarized. This requires membership in the Apple Developer Program.

1. Install a Developer ID Application certificate and its private key in your keychain. Confirm it is available:

   ```bash
   security find-identity -v -p codesigning
   ```

2. Save notarization credentials in the login keychain. This example uses an app-specific password:

   ```bash
   xcrun notarytool store-credentials "kiki-notary" \
     --apple-id "YOUR_APPLE_ID" \
     --team-id "YOUR_TEAM_ID"
   ```

   Enter the app-specific password at the secure prompt. Do not put it directly on the command line, where it could be saved in shell history.

   App Store Connect API-key credentials are also supported by `notarytool` and are preferable for CI.

3. Build, sign, notarize, staple, and package the release:

   ```bash
   KIKI_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
   KIKI_NOTARY_PROFILE="kiki-notary" \
   KIKI_BUILD_NUMBER="1" \
   ./scripts/release.sh 0.1.0
   ```

   The output is `build/Kiki-0.1.0-macOS.zip`. The release script refuses to create a public archive with a local or ad-hoc identity. If `KIKI_NOTARY_PROFILE` is omitted it creates a Developer ID-signed archive but clearly reports that notarization was skipped.

4. Upload the ZIP to a GitHub Release. Before publishing, test the exact downloaded archive on another Mac or a clean user account.

## Build variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `KIKI_SIGNING_IDENTITY` | Exact code-signing identity | Local identity, or Developer ID for releases |
| `KIKI_LOCAL_SIGNING_IDENTITY` | Name of the self-signed development identity | `Kiki Local Code Signing` |
| `KIKI_NOTARY_PROFILE` | `notarytool` keychain profile | Notarization skipped |
| `KIKI_BUNDLE_ID` | App bundle identifier | `com.tonyricciardi.kiki` |
| `KIKI_VERSION` | User-visible version | `0.1.0` |
| `KIKI_BUILD_NUMBER` | Monotonically increasing build number | `1` |
