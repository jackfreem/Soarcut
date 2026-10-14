# Cutting a Soarcut release

Releases are produced by `.github/workflows/release.yml`, which runs when a `v*`
tag is pushed. It builds `Soarcut.app`, packages it as `Soarcut-<version>.dmg`,
signs and notarizes it if the secrets below are set, and publishes a GitHub
Release with the DMG attached. Running the workflow manually (workflow_dispatch)
does the same as a dry run without publishing.

## Cutting a release

1. Add a `## <version>` section at the top of `CHANGELOG.md`. It becomes the
   release notes (the workflow falls back to the commit log if it's missing).
2. Tag and push:

   ```
   git tag v0.1.0
   git push origin v0.1.0
   ```

The workflow stamps `MARKETING_VERSION` from the tag, so the app version always
matches the tag.

## Signing (optional, recommended)

Without secrets the DMG contains an **ad-hoc signed** app: it works, but macOS
warns on first launch ("unidentified developer") and users must approve it in
System Settings > Privacy & Security. Accessibility permission may also need to be
re-granted after each update.

With an Apple Developer Program membership ($99/year), add these under
**Settings > Secrets and variables > Actions** and releases are signed,
notarized and stapled, so they open without warnings and keep their
Accessibility permission across updates. That is also what MDM tools like Jamf
expect.

| Secret | Purpose |
| --- | --- |
| `CERTIFICATES_P12` | base64 of your **Developer ID Application** certificate exported as `.p12` |
| `CERTIFICATES_PASSWORD` | the password set when exporting the `.p12` |
| `NOTARY_KEY` | base64 of an App Store Connect API key (`.p8`), role Developer |
| `NOTARY_KEY_ID` | the API key's Key ID |
| `NOTARY_ISSUER_ID` | the API key's Issuer ID |

Create the API key at **App Store Connect > Users and Access > Integrations >
App Store Connect API** (Team Key). The `.p8` downloads only once.

```
base64 -i Certificates.p12 | gh secret set CERTIFICATES_P12 -R jackfreem/Soarcut
gh secret set CERTIFICATES_PASSWORD -R jackfreem/Soarcut   # prompts for the passphrase
base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set NOTARY_KEY -R jackfreem/Soarcut
gh secret set NOTARY_KEY_ID -R jackfreem/Soarcut --body "XXXXXXXXXX"
gh secret set NOTARY_ISSUER_ID -R jackfreem/Soarcut --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

| Secrets configured | Result |
| --- | --- |
| none | ad-hoc signed; Gatekeeper warns on first launch |
| signing only | Developer ID signed, hardened runtime; still warned until notarized |
| signing + notary | signed, notarized and stapled; installs cleanly |

Soarcut is not sandboxed and has no embedded helpers or frameworks, so only the
app itself is signed (with `FlycutDeveloperID.entitlements`).
