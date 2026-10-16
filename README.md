# Overbright

**Extra brightness for XDR and HDR displays on your Mac, and dimming below the macOS minimum.** Overbright is a
small menu bar app that lets a capable display go past its standard maximum, display by display, and always returns
it to a neutral picture. Free and open source (MIT), no account, no analytics.

> **Status: 0.1.0, in development.** The repository holds the scaffold and the contracts; the features are being
> built. Nothing here is ready to use yet. The plan lives in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and the
> design in [docs/DESIGN.md](docs/DESIGN.md).

## Build from source

Requirements: macOS 14 or later to run; **Xcode 27** to build the app (the package alone builds with Xcode 26). No
Metal Toolchain and no third-party tools are needed.

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # if xcode-select points at the Command Line Tools
make help      # every target
make build     # universal Release → build/Overbright.app
make test      # the package's unit tests
```

Ad-hoc signed builds need Gatekeeper's "Open Anyway" in System Settings ▸ Privacy & Security once, or
`xattr -dr com.apple.quarantine /Applications/Overbright.app`.

## Permissions

None. Overbright asks for no privacy permission and makes no network request unless you turn on the update check.

## License

MIT, see [LICENSE](LICENSE). Credits and the notice for code derived from Cranny are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
