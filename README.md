# Baud

A small character that lives on your Mac and reminds you to move, drink water, and rest your eyes.
Free and open source. Native Swift, no Electron.

Instead of a system notification you will ignore, a character slides in from the corner of your
screen, says one short thing, and leaves.

## What makes it different

- Free and open source. Every comparable app with a character is paid.
- Native. Small, signed, no Electron runtime.
- It never interrupts at a bad moment. No reminders during a screen share, a call, a full screen
  video, or a Focus mode. Reminders are held and delivered when the moment is right.
- No guilt. It does not droop, shame you, or punish a broken streak. Ignoring it is fine.
- Custom reminders. Any text, any interval.

## Install

Requires macOS 14 or later.

Homebrew:

    brew install --cask baud

Or download `Baud.zip` from the [releases page](https://github.com/KhaledSaeed18/baud/releases),
unzip it, and move `Baud.app` to your Applications folder. Baud lives in the menu bar and has no
Dock icon.

## Using it

The menu bar shows the next reminder and a pause submenu. Open Settings to enable or disable the
built-in reminders, add your own, and turn on launch at login.

Reminders are stored as a JSON file you can edit by hand. See [docs/CONFIG.md](docs/CONFIG.md).

## Status

Phases 0 through 4 are done: the window, the character, scheduling, the suppression gate, and the
control surface. Signing and a first release are next. This is a learning project first. See
[docs/ROADMAP.md](docs/ROADMAP.md).

## Build

Requires macOS 14 or later and Xcode 16 or later.

    git clone https://github.com/KhaledSaeed18/baud.git
    cd baud
    scripts/install-hooks.sh
    open Baud.xcodeproj

Run the tests with Cmd U in Xcode, or:

    xcodebuild test -project Baud.xcodeproj -scheme Baud -destination 'platform=macOS'

## Releasing

`scripts/release.sh` builds, signs with a Developer ID, notarises, and staples a distributable zip.
Fill `scripts/notarize.env` first (see `scripts/notarize.env.example`).

## Contributing

Read [docs/CONVENTIONS.md](docs/CONVENTIONS.md) before opening a pull request. Run
`scripts/install-hooks.sh` once so the style hook is active.

## Licence

MIT. See [LICENSE](LICENSE).
