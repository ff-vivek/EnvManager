# EnvManager

EnvManager is a native macOS app for viewing, editing, and previewing shell environment variables across `zsh`, `bash`, and `fish`.

It provides a desktop workflow for:

- switching between common shell config files
- browsing user-defined exports and current process variables
- editing regular variables and PATH-style values
- previewing config-file changes before writing them
- creating timestamped backups before each save

## Requirements

- macOS 13 or newer
- Xcode 15+

## Build

Open the project in Xcode:

```bash
open EnvManager.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project EnvManager.xcodeproj -scheme EnvManager -destination 'platform=macOS' build
```

## Run

From Xcode, run the `EnvManager` scheme on `My Mac`.

The app directly reads and writes shell config files in your home directory, including:

- `~/.zshrc`
- `~/.zshenv`
- `~/.zprofile`
- `~/.bashrc`
- `~/.bash_profile`
- `~/.profile`
- `~/.config/fish/config.fish`

Each write creates a backup under:

```text
~/Library/Application Support/EnvManager/Backups
```

## Install

Public releases are intended to ship through:

- GitHub Releases as a notarized `DMG`
- a Homebrew cask from a user-owned tap

Maintainer-facing release steps live in [RELEASE.md](RELEASE.md) and [docs/public-release-checklist.md](docs/public-release-checklist.md).

## Project Structure

```text
EnvManager/
├── EnvManagerApp.swift
├── ContentView.swift
├── EnvironmentViewModel.swift
├── Models/
├── Services/
└── Views/
```

- `EnvManagerApp.swift`: app entrypoint and menu commands
- `ContentView.swift`: main dashboard and shared UI theme
- `EnvironmentViewModel.swift`: state, pending changes, save flow
- `Models/`: shell and environment variable models
- `Services/`: config parsing, writing, and backup logic
- `Views/`: editor and selector views

## Development Notes

- The app is intentionally not sandboxed for shell-config file access.
- Automated integration coverage lives in `EnvManagerTests` and `EnvManagerUITests`.
- The repository includes GitHub Actions workflows for build verification and tag-based releases.

## Releasing

The recommended release path is a `Developer ID`-signed, notarized `DMG` distributed outside the Mac App Store.

Release docs are in [RELEASE.md](RELEASE.md).

The repo also includes `./scripts/publish_release.sh` for end-to-end release publication to GitHub Releases and a Homebrew tap.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
