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

## Status

Early development. This is a learning project first. See `docs/ROADMAP.md`.

## Build

Requires macOS 14 or later and Xcode 15 or later.

    git clone <repo>
    cd baud
    scripts/install-hooks.sh
    open Baud.xcodeproj

## Contributing

Read `docs/CONVENTIONS.md` before opening a pull request. Run `scripts/install-hooks.sh` once so
the style hook is active.

## Licence

MIT
