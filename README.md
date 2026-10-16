# Overbright

**Extra brightness for XDR and HDR displays on your Mac, and dimming below the macOS minimum.** Overbright is a
small menu bar app that lets a capable display go past its standard maximum, display by display, explains every
limit it runs into, and always brings the display back to a neutral picture. Free and open source (MIT), no account,
no analytics.

> **Status: 0.1.0, in development.** The scaffold, the contracts, the settings and welcome windows' infrastructure, the
> shortcut center and the update check exist; the brightness engine and most of the interface are being built. It is
> not ready to use yet. The plan lives in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and the design in
> [docs/DESIGN.md](docs/DESIGN.md).

## What it does

- **Extra brightness** on displays that have extra range: the Liquid Retina XDR display of a MacBook Pro, Apple's
  XDR displays and HDR external displays with HDR turned on. macOS keeps that range for HDR video; Overbright lets
  everyday content use it, so the screen stays readable in a bright room or in sunlight.
- **Dim below minimum** on any display, HDR or not, with one slider per display: left of Standard dims, right of it
  adds extra brightness.
- **Honest about every limit.** Each display gets a verdict and a fix ("Turn on High Dynamic Range for this display
  in Displays settings"), the slider shows where it stops right now, and the reason when battery, heat, a full-screen
  video or another app holds it back.
- **Safe by default.** It starts off, steps back on battery, in Low Power Mode and when the Mac gets warm, ramps
  every change so nothing flickers, and has a Safe ceiling and a Peak one.
- **Fill Light** for video calls, keyboard shortcuts, Shortcuts actions and a Focus filter, a small on-screen
  indicator for level changes, and full keyboard and VoiceOver support, in 35 languages.

Your display uses more power when it is brighter: that is what extra brightness is. Overbright's own work is close to
nothing while it is off and small while it is on.

## Install

Requires **macOS 14 Sonoma or later** (Apple silicon or Intel).

1. Download `Overbright-<version>.dmg` (or `.zip`) from the GitHub Releases page. No release is published yet;
   until then, build from source below.
2. Drag **Overbright** to **Applications** and open it. It lives in the menu bar; there is no Dock icon unless you
   turn one on. Launched from somewhere else, it offers to move itself to Applications, because Shortcuts actions
   and opening at login work only from there.

**"Overbright can't be opened" / "unidentified developer".** Builds that are not notarized by Apple are blocked by
Gatekeeper the first time. Either open **Privacy & Security** in System Settings and click **Open Anyway** next to
the message about Overbright, or remove the quarantine flag in Terminal:

```zsh
xattr -dr com.apple.quarantine /Applications/Overbright.app
```

## Build from source

You need **Xcode 27** to build the app (the Swift package alone also builds and tests with Xcode 26). No Metal
Toolchain is needed: Overbright has no shader files. No third-party tools either.

If `xcode-select -p` points at the Command Line Tools rather than Xcode, select Xcode for the commands you type
yourself (the `make` targets find Xcode in `/Applications` on their own):

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Then, one command at a time:

```zsh
git clone <this repository> Overbright
make -C Overbright build      # universal Release build → build/Overbright.app (ad-hoc signed, no Apple account)
make -C Overbright test       # the package's unit tests (Swift Testing)
make -C Overbright run        # Debug build, launched with simulated displays: it never changes your screen
make -C Overbright help       # everything else (check, strings, smoke test, dist, …)
```

`make run` starts the app with `--off --qa-simulate builtin-xdr-lid-open` and a settings suite of its own, so a
development build never brightens or dims a real display and never touches your installed copy's settings.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) explains the rest.

## Permissions

**None.** Overbright asks for no privacy permission: no Accessibility, Screen Recording, camera or microphone access.
Its global shortcuts use the system's hot-key API, and noticing that a camera is in use (for Fill Light's automatic
mode) reads only whether a camera runs, never its picture.

## Safety and recovery

Overbright changes your display's brightness through the display's color table and macOS's extra range. Every way
back to a normal picture is built in:

- **Back to Standard** — `⌃⌥⌘0` by default (Settings ▸ Shortcuts shows your key caps), "Back to Standard" in the
  menu, the Dock menu and the Shortcuts app — turns Overbright off at once from anywhere. Your levels are kept for
  next time.
- **Quit, crash or Force Quit** — macOS restores every display the moment Overbright's process ends. If Overbright
  ever stops responding, Force Quit it; your displays return to normal at once.
- **Colors look wrong after another app quit?** Settings ▸ Advanced ▸ Reset Display Colors… puts every display back
  on its color profile.
- **From Terminal**, without opening any window:

  ```zsh
  /Applications/Overbright.app/Contents/MacOS/Overbright --restore-gamma
  ```

  It checks every display against its color profile, restores the profile where something else is left, prints
  the result and quits. If a display still looks wrong after that, change its preset (or its color profile) in
  Displays settings and back, or log out.

At every launch Overbright first checks that no display was left scaled; it never starts brighter than Standard
unless you chose "Open Overbright and turn it on". Very dark levels ask "Keep this level?" and go back on their own
after 10 seconds.

## Privacy

- No analytics, no crash reporting, no account, no ads.
- Everything stays on your Mac: settings in the app's preferences, self-test logs in
  `~/Library/Application Support/app.overbright.Overbright/`, caches in `~/Library/Caches/app.overbright.Overbright/`.
- The only network request is the optional daily update check against this project's GitHub Releases page (no
  identifiers, no cookies). It is off until you turn it on. Releases published here ask this repository; a build
  from source has no repository set, and so no update check, unless you build it with
  `OVERBRIGHT_GITHUB_REPOSITORY=owner/repo`.
- Copy Diagnostics puts a technical report on the clipboard; nothing is ever sent anywhere.

## Languages

English · العربية · Català · Čeština · Dansk · Deutsch · Ελληνικά · Español · Suomi · Français · עברית · हिन्दी ·
Hrvatski · Magyar · Bahasa Indonesia · Italiano · 日本語 · 한국어 · Bahasa Melayu · Norsk bokmål · Nederlands ·
Polski · Português (Brasil) · Português (Portugal) · Română · Русский · Slovenčina · Slovenščina · Svenska · ไทย ·
Türkçe · Українська · Tiếng Việt · 简体中文 · 繁體中文

English is the original. Translations are in progress; [docs/TRANSLATING.md](docs/TRANSLATING.md) shows how to fix or
review a language.

## Contributing

Bug reports and pull requests are welcome. Start with [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) (rules, workflow,
how to build one module, visual QA), then [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (code structure and
contracts) and [docs/DESIGN.md](docs/DESIGN.md) (every pixel, color and word). Translators:
[docs/TRANSLATING.md](docs/TRANSLATING.md).

## Credits

Overbright is original work by the Overbright contributors, MIT-licensed, with no third-party dependencies. Parts of
its scaffold, build scripts, translation tools, settings store, hot-key center and update checker come from
[Cranny](THIRD_PARTY_NOTICES.md), an MIT-licensed app by the same owner; its notice is in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), together with the projects whose ideas Overbright learned from
(xdr-boost, xdr-light, displaytint, MonitorControl). SF Symbols and the system frameworks are Apple's.

## License

MIT, see [LICENSE](LICENSE).
