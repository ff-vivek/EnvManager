# Public Release Checklist

This checklist is the operator view for shipping EnvManager to the general public.

## Release Channels

- Primary download: GitHub Release with a notarized `DMG`
- Secondary install path: Homebrew cask from a user-owned tap
- Source distribution: tagged source on GitHub

## Launch Readiness

- Confirm the app bundle identifier is final and public-safe.
- Confirm the app icon set builds without Xcode asset warnings.
- Confirm `xcodebuild -project EnvManager.xcodeproj -scheme EnvManager -destination 'platform=macOS' test` passes.
- Confirm the Developer ID certificate, notarization credentials, and tap credentials are available.
- Confirm the README and release notes describe installation, shell-file access, and backup behavior clearly.
- Confirm `LICENSE`, `CONTRIBUTING.md`, and issue reporting paths are visible in the repo.

## Versioning

1. Update the project version.

```bash
./scripts/set_version.sh --version 1.0.0 --build 1
```

2. Verify the extracted version matches what you plan to tag.

```bash
./scripts/extract_version.sh
```

## Release Execution

1. Run preflight.

```bash
./scripts/release_preflight.sh --version 1.0.0
```

2. Build local release artifacts if you want to inspect them before publishing.

```bash
./scripts/release.sh --version 1.0.0
```

3. Publish the public release.

```bash
./scripts/publish_release.sh --version 1.0.0
```

4. Tag the release if you are publishing from git directly.

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Post-Release Checks

- Download the published `DMG` from GitHub Releases.
- Install the app on a clean macOS machine or VM.
- Verify Gatekeeper opens the app without bypass prompts.
- Verify the Homebrew cask installs the same release artifact.
- Verify backups are written under `~/Library/Application Support/EnvManager/Backups`.
- Verify uninstall cleanup paths match the current bundle identifier.

## External Tasks Not Automated Here

- Apple Developer account setup and certificate issuance
- App screenshots, announcement copy, and launch post
- Support inbox, issue triage, and public roadmap communication
