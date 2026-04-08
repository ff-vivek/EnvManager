# Release Guide

EnvManager is set up for Developer ID distribution outside the Mac App Store.

## Requirements

- Apple Developer membership
- `Developer ID Application` certificate
- Xcode 15+
- Apple ID app-specific password for notarization
- GitHub CLI authenticated for the repo you are publishing from

## Public Release Strategy

For a general-public launch, this repo is optimized for:

1. a notarized `DMG` attached to GitHub Releases
2. an optional Homebrew cask in a user-owned tap
3. a repeatable, versioned release process driven by tags or `workflow_dispatch`

The operator checklist for launch day is in [docs/public-release-checklist.md](docs/public-release-checklist.md).

## Set the Version

Update the marketing version and, if needed, build number before tagging:

```bash
./scripts/set_version.sh --version 1.0.0 --build 1
```

You can confirm the current release version with:

```bash
./scripts/extract_version.sh
```

## Local Artifact Build

Run release preflight first. This validates the version, GitHub remote, required tools, and notarization env vars:

```bash
./scripts/release_preflight.sh --version 1.0.0 --skip-github-release --skip-homebrew
```

Then set the notarization environment variables:

```bash
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_ID="you@example.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

Build the notarized release artifacts:

```bash
./scripts/release.sh --version 1.0.0
```

Artifacts are written to:

```text
dist/release/
```

That pipeline performs:

1. Xcode archive
2. Developer ID export
3. signed app verification with `codesign` and `spctl`
4. DMG packaging
5. notarization
6. stapling and stapler validation
7. SHA256 generation

## Local Publish

To publish the notarized DMG to GitHub Releases and update a Homebrew tap, set:

```bash
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_ID="you@example.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export HOMEBREW_TAP_REPO="viveky259259/homebrew-tap"
```

If your tap push needs an explicit token:

```bash
export HOMEBREW_TAP_GH_TOKEN="github_pat_or_classic_token"
```

Then run:

```bash
./scripts/publish_release.sh --version 1.0.0
```

That orchestration script performs:

1. build and notarize the DMG
2. create or update the GitHub Release
3. push a Homebrew cask update to your tap repo

If you intentionally need to release from a non-clean worktree, the release scripts accept `--allow-dirty`, but public releases should normally come from a tagged commit.

## Local Dry Run

If you want to test the packaging flow without notarization:

```bash
./scripts/release.sh --version 1.0.0 --skip-notarize
```

## GitHub Actions Release

The repository includes a tag-driven workflow at `.github/workflows/release.yml`.

Create these repository secrets before using it:

- `APPLE_TEAM_ID`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `DEVELOPER_ID_APPLICATION_P12_BASE64`
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `HOMEBREW_TAP_REPO`
- `HOMEBREW_TAP_GH_TOKEN`

The workflow:

1. imports the Developer ID certificate into a temporary keychain
2. builds and notarizes the DMG
3. uploads the DMG and checksum to a GitHub Release
4. updates your Homebrew tap if the tap secrets are configured

## Tagging a Release

Push a semantic version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

That triggers the release workflow and publishes the assets.

For a manual release, `workflow_dispatch` can be used with the current project version or an explicit version input.

## Homebrew Scope

This automation targets a user-owned tap such as `owner/homebrew-tap`.

Publishing directly to `homebrew/cask` is a separate upstream contribution flow and typically requires opening a PR for review rather than pushing from your release script.
