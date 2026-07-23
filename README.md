<div align="center">

<img src="https://shieldcn.dev/header/graph.svg?title=Baud&subtitle=Break%20reminders%20with%20a%20character%2C%20for%20macOS&theme=amber&logo=https%3A%2F%2Fraw.githubusercontent.com%2FKhaledSaeed18%2Fbaud%2Fmain%2FBaud%2FResources%2FAssets.xcassets%2FAppIcon.appiconset%2Ficon_256.png&size=lg&align=center" width="820" alt="Baud" />

<p>
  <img src="https://shieldcn.dev/badge/platform-macOS%2014%2B-amber.svg?variant=secondary&logo=apple&logoColor=ffffff" alt="Platform: macOS 14+" />
  <img src="https://shieldcn.dev/badge/Swift-5-orange.svg?variant=secondary&logo=swift&logoColor=ffffff" alt="Swift 5" />
  <img src="https://shieldcn.dev/badge/interface-menu%20bar-amber.svg?variant=secondary" alt="Interface: menu bar" />
  <a href="LICENSE"><img src="https://shieldcn.dev/badge/license-MIT-green.svg?variant=secondary" alt="License: MIT" /></a>
  <a href="https://github.com/KhaledSaeed18/baud/stargazers"><img src="https://shieldcn.dev/github/stars/KhaledSaeed18/baud.svg" alt="GitHub stars" /></a>
</p>

<strong>Slides in. Says one thing. Leaves.</strong>

</div>

Baud is a small character that lives on your desktop and reminds you to move, drink water, rest your
eyes, and anything else you define. Instead of a system notification you swipe away on reflex, a
character slides in from a screen corner, says one short thing, and leaves.

Most break reminders are a banner you dismiss without reading. Baud is a character you glance at, and
it knows when to stay quiet. It holds a reminder during a call or a full screen video instead of
talking over it, and delivers it once the moment clears.

## Why Baud

- **It never interrupts at a bad moment.** No reminder during a call, a full screen video, or a
  presentation, and none while the screen is locked or you are away. When the moment is bad the
  reminder is held, then delivered once things clear. This is the single behaviour the app is built
  around.
- **It never guilts you.** The character does not droop, shame you, or punish a broken streak.
  Ignore it and it leaves on its own. No streaks, no sad faces, no "you missed three breaks".
- **Free and open source.** Every comparable app with a character is paid. Baud is MIT.
- **Native, not Electron.** Swift and SwiftUI, small, menu bar only, no Dock icon, no runtime to
  install.
- **Your reminders are data.** A built-in reminder and one you write are the same type: any text,
  any interval. They live in a JSON file you can read and edit by hand.

## Features

The built-in reminders, each with its own character mood:

| Reminder | Nudges you to ... |
|----------|-------------------|
| Move     | stand up and walk for a moment |
| Water    | drink some water |
| Eyes     | look away for twenty seconds (20-20-20) |
| Posture  | sit back and straighten up |

On top of the built-ins:

- **Custom reminders**: any label, any message, any mood, any interval, added from Settings.
- **Suppression**: a call (camera or microphone in use), a full screen window, a locked screen, or
  time away all hold a reminder rather than drop it. Held reminders return one at a time, never as a
  flush after a meeting.
- **Pause**: silence Baud for thirty minutes, an hour, three hours, or until you resume, from the
  menu bar without quitting.
- **Snooze without nagging**: click the character to dismiss, or snooze for ten minutes. Ignore it
  and it dismisses itself.
- **Launch at login**, through `SMAppService`.

## How it works

Three layers with a clean seam, so no layer reaches into another:

- **Scheduler** decides when. It owns each reminder's next fire date, recomputes after the Mac wakes
  from sleep so a slept-through timer never dumps a backlog, and asks the suppression gate before
  anything shows. It never touches AppKit.
- **Presenter** decides how it looks. It owns the borderless overlay window and the character, and
  never decides timing. The window never becomes key or main, so it cannot steal focus while you
  type.
- **Reminders** are the data: label, message, interval, mood, enabled. A built-in and a user-defined
  reminder are the same type, with no special casing for water or movement.

The character is a state machine, not a pile of flags: arriving, idle, speaking, acknowledged,
snoozed, and leaving, each tied to a mood. Adding a mood is adding a case, not an `if` in a view. See
[docs/CHARACTER.md](docs/CHARACTER.md).

## Install

Requires macOS 14 or later and Xcode 16 or later. Baud is built from source.

```bash
git clone https://github.com/KhaledSaeed18/baud.git
cd baud
scripts/install-hooks.sh   # optional: the style pre-commit hook
open Baud.xcodeproj         # build and run with Cmd R
```

Baud lives in the menu bar and has no Dock icon. Look for its mark in the menu bar after launch.

## Usage

### Menu bar

Click the menu bar mark to see the next reminder, pause for a while, show a reminder now, open
Settings, or quit.

### When a reminder appears

The character slides in from the corner and says one short thing. Click it to dismiss, or use the
snooze control to be reminded again in ten minutes. Ignore it and it leaves on its own. None of the
three outcomes is a failure, and none is tracked as one.

### Custom reminders

Open Settings, then the Reminders tab, to enable or disable the built-ins and add your own with any
label, message, mood, and interval.

## Configuration

Settings has three tabs:

- **General**: launch at login.
- **Reminders**: enable, disable, add, edit, and delete reminders.
- **About**: version and a link to the source.

Reminders are stored as a JSON file in Application Support that you can read and edit by hand. The
format is a supported interface, documented in [docs/CONFIG.md](docs/CONFIG.md).

## Architecture

Three layers with clean seams: the Scheduler (when) never touches AppKit, the Presenter (window and
character) never decides timing, and Reminders are plain data. The character is a state machine, so a
new mood is a new case rather than a branch in a view. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [CLAUDE.md](CLAUDE.md) for the full map and the
design rules.

## Development

```bash
xcodebuild test -project Baud.xcodeproj -scheme Baud -destination 'platform=macOS'
```

Or run the tests with Cmd U in Xcode. If Xcode is installed but is not the active command-line
toolchain, prefix the command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Read [docs/CONVENTIONS.md](docs/CONVENTIONS.md) before opening a pull request, and run
`scripts/install-hooks.sh` once so the style hook is active.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel

## License

MIT. See [LICENSE](LICENSE).
