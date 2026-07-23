# Architecture

For code style, naming, file layout, and design rules, see `docs/CONVENTIONS.md`.
For the character states and motion, see `docs/CHARACTER.md`.

## Three layers, clean seams

1. **Reminders**: what exists. Definitions as data (label, message, interval, character mood,
   enabled). Built-in and user-defined are the same type. No AppKit, no timing logic.
2. **Scheduler**: when it fires. Owns fire dates, sleep and wake recovery, suppression checks, the
   held queue. No AppKit, no SwiftUI. Testable headless.
3. **Presenter**: how it appears. Owns the borderless window, positioning, the character view, and
   the animation. Knows nothing about intervals or why a reminder fired.

The Scheduler decides, the Presenter performs. A reminder travels Scheduler to Presenter as a
value: message plus mood plus dismissal options. The Presenter never asks "is it time yet".

## The character window

An `NSWindow` configured as a floating overlay:

- `styleMask = .borderless`
- `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`
- `level = .floating` (above normal windows, below system alerts)
- `collectionBehavior` includes `.canJoinAllSpaces` and `.fullScreenAuxiliary` so it can appear
  over spaces correctly, but see suppression rules before showing over full screen
- `ignoresMouseEvents = true` by default, toggled off only for the character's own hit area so
  clicks pass through to whatever is behind it
- Must never become key or main. Override `canBecomeKey` and `canBecomeMain` to return false.
  Stealing focus while the user types is the worst failure mode this app has.

Content is a SwiftUI view inside an `NSHostingView`.

Positioning: bottom trailing corner of the screen containing the mouse or the active window, inset
from `visibleFrame` so it never overlaps the Dock or the menu bar. Corner is configurable.

## Suppression rules (the most important logic in the app)

Before presenting, the Scheduler asks: is now a good moment. If any of these is true, the reminder
is HELD, not dropped:

- Any application is in full screen on the active display
- Screen is being shared or recorded
- A camera or microphone is in use (a call is likely in progress)
- Do Not Disturb or a Focus mode is active
- The screen is locked, asleep, or the user is idle beyond a threshold (nobody is there to see it)
- A presentation app is frontmost and presenting
- The user dismissed a reminder within the last cooldown window

Held reminders go into a queue with their original due time recorded. When the context clears, the
Scheduler delivers at most one held reminder, then resumes normal timing. Never flush the whole
queue at once. Nobody wants four characters in a row after a meeting.

Detection notes:
- Full screen and frontmost app: `NSWorkspace.shared.frontmostApplication` plus window state
- Camera and microphone in use: check for active capture devices
- Idle time: `CGEventSource.secondsSinceLastEventType`
- Focus and Do Not Disturb: read the current Focus state where available. If detection is not
  reliable on a given OS version, prefer holding over showing. When in doubt, do not interrupt.

## Scheduling

- Each enabled reminder has a next fire `Date`. Compute, do not count down.
- Use a single coordinating timer that wakes, checks which reminders are due, and asks the
  suppression gate. Do not run one repeating timer per reminder.
- On wake from sleep, recompute all fire dates. A timer that slept through its fire time must not
  dump a backlog. Missed occurrences collapse to at most one.
- Register for `NSWorkspace.didWakeNotification` to trigger recomputation.

## Reminder model

```swift
struct Reminder: Identifiable, Codable {
    let id: UUID
    var label: String          // "Drink water"
    var message: String        // what the character says
    var interval: TimeInterval
    var mood: CharacterMood    // see CHARACTER.md
    var isEnabled: Bool
    var isBuiltIn: Bool
}
```

Persisted as JSON in Application Support, not UserDefaults. It should be a file a user can read,
edit, and share. That is part of being open and hackable.

## Dismissal

Three outcomes only: dismissed (done), snoozed (short delay, configurable, default around ten
minutes), or auto-dismissed after a timeout if the user does not react. All three are normal. None
is a failure. Do not track them as failures anywhere in the UI.

## Menu bar

A `MenuBarExtra` for: next reminder, pause for a duration, edit reminders, settings, quit. Pausing
is a first class feature. The user must be able to silence the app instantly without quitting it.

## Distribution
- macOS 14+, `LSUIElement = true`, no sandbox.
- Built from source: clone, open in Xcode, run. Free, open source, MIT.
- No signing, notarisation, or Homebrew cask for now. See ADR-018.
