# Baud, Claude Code Context

Baud is a macOS app that lives on your desktop and reminds you to move, drink water, rest your eyes,
and anything custom you define. Instead of a system notification, a small animated character slides
in from a screen corner, delivers the reminder, and leaves. Free and open source. Native Swift, no
Electron.

Naming: the app is "Baud" as a proper noun (prose, UI copy, Swift types, the Xcode target, and
Baud.app). Lowercase "baud" for the bundle identifier and the repository directory. The character
itself has no name.

This file is the always-loaded context and the full guide. It is self-contained: there is no `docs/`
directory. It holds the idea, the codebase map, the architecture rules, the suppression rule that
defines the app, the character spec, the code and writing conventions, the design rules, and the git
workflow. Read it before writing code.

## The one rule that defines this app (hard)

NEVER interrupt the user at a bad moment. A reminder that appears during a screen share, a call, a
full-screen video, or a presentation is a bug, not a feature. When the context is bad, the reminder
is HELD and delivered later. It is never dropped silently and never forced through. This is the
single most important behaviour in the product. Treat a violation as a P0. The rules are in
"Suppression" below.

## The idea

Three layers with a clean seam: Scheduler (when), Presenter (window and character), Reminders (what).
The Scheduler decides, the Presenter performs. A reminder travels from Scheduler to Presenter as a
value (a message plus a mood plus dismissal options); the Presenter never asks "is it time yet", and
the Scheduler never touches AppKit.

Positioning: every good app in this space is paid and closed source, and most are cute. Baud is free,
open, native, and deliberately not-cute: a calm, minimal, faintly deadpan character. It never guilts
the user. Ignoring a reminder is the user's right.

## Codebase map

```
Baud/                                app target: SwiftUI, menu bar only (LSUIElement)
  App/
    BaudApp.swift                    @main; MenuBarExtra + Settings scenes
    AppDelegate.swift                owns AppModel; starts scheduling, recomputes on wake
    AppModel.swift                   @Observable controller the UI reads and sends intent to
  Reminders/                         what exists; data only, no AppKit, no timing
    Reminder.swift                   the model: label, message, interval, mood, enabled, built-in
    DefaultReminders.swift           the built-ins (move, water, eyes, posture), fixed ids
    ReminderStore.swift              JSON load and save in Application Support
  Scheduler/                         when it fires; no AppKit, no SwiftUI, tested headless
    ReminderScheduler.swift          fire dates, held queue, pause, one coordinating wait, wake recovery
    SuppressionGate.swift            the "is now a good moment" protocol plus a clear-gate stub
    SystemSuppressionGate.swift      the real gate: lock, capture, full screen, idle
    CaptureMonitor.swift             camera and microphone in-use checks
    IdleMonitor.swift                seconds since the last user input
  Presenter/                         how it appears; owns the window, never decides timing
    Presenter.swift                  show(reminder:), drives the character, reports the outcome
    BaudWindow.swift                 borderless overlay NSWindow; never key or main
    WindowPositioner.swift           corner math against visibleFrame; on and off screen frames
    InteractiveCharacterView.swift   the character plus its dismiss and snooze controls
    InteractiveHostingView.swift     hosting view that accepts the first mouse
  Character/                         the state machine and its motion; knows only the value it is handed
    CharacterModel.swift             @Observable state machine with validated transitions
    CharacterState.swift             the appearance lifecycle enum plus its allowed transitions
    CharacterMood.swift              move / water / eyes / posture / custom
    CharacterView.swift              the code-drawn character in SwiftUI
    Motion.swift                     every animation constant in one place
  UI/
    MenuBarView.swift                next reminder, pause, show now, settings, quit
    SettingsView.swift               tabbed settings (General, Reminders, About)
    ReminderEditorView.swift         list, add, edit, enable, delete; the reminder detail sheet
  Resources/Assets.xcassets          AppIcon and the MenuBarIcon template mark
  Supporting/Info.plist              LSUIElement = true

BaudTests/                           Swift Testing suites; the scheduler, the store, the gate
  ReminderSchedulerTests.swift
  ReminderStoreTests.swift
  SuppressionTests.swift

Baud.xcodeproj                       the app target
```

The `.xcodeproj` uses file-system-synchronized groups: a new `.swift` file under `Baud/` or
`BaudTests/` compiles with no project edit.

## Building and testing

Full Xcode is installed but is not the active command-line toolchain, so prefix build and test
commands with `DEVELOPER_DIR`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Baud.xcodeproj -scheme Baud -destination 'platform=macOS' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Baud.xcodeproj -scheme Baud -destination 'platform=macOS' test
```

In Xcode, run the tests with Cmd U. The scheduler, store, and suppression gate hold the coverage;
they run with no window on screen, which is the point of the seam. Verify with a clean `xcodebuild
... test` before pushing.

## Architecture rules (hard)

- Three layers, clean seams. The Scheduler never touches AppKit. The Presenter never decides timing.
  Reminders are data with no timing and no AppKit.
- Reminder definitions are data, not code. A built-in reminder and a user-defined one are the same
  type. No special-casing water or movement.
- The character is a state machine, not a pile of booleans. States and transitions live in
  `CharacterState`. Adding a mood means adding a case, not an `if` in a view.
- No polling loops for scheduling. Use one coordinating wait with computed fire dates, and recompute
  after wake. The Mac sleeps; a naive repeating timer would drift or misfire.

### The character window

An `NSWindow` configured as a floating overlay:

- `styleMask = .borderless`; `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`.
- `level = .floating` (above normal windows, below system alerts).
- `collectionBehavior` includes `.canJoinAllSpaces` and `.fullScreenAuxiliary`, but see Suppression
  before showing over full screen.
- Click-through by default. `ignoresMouseEvents` is toggled off only over the bottom hit strip where
  the character and its controls sit, so clicks pass through the bubble area above it.
- Must never become key or main. `canBecomeKey` and `canBecomeMain` return false. Stealing focus
  while the user types is the worst failure mode this app has.

Content is a SwiftUI view inside an `NSHostingView` that accepts the first mouse, so a click acts
without activating the never-key window. Position at the bottom trailing corner of the screen under
the mouse, inset from `visibleFrame` so it clears the Dock and the menu bar.

### Scheduling

- Each enabled reminder has a next fire `Date`. Compute, do not count down.
- A single coordinating wait wakes for the next fire date, on a recheck cadence while anything is
  held, and at the end of a timed pause. Never one repeating timer per reminder.
- On wake from sleep, recompute. A wait that slept through its fire time must not dump a backlog;
  missed occurrences collapse to at most one. `AppDelegate` observes `NSWorkspace.didWakeNotification`.
- Pause silences the app: due reminders are skipped, not held, so resuming does not pop a backlog.
  Holding is the app's intent (a bad moment); pausing is the user's intent (silence). They differ.
- Quiet hours are a scheduled pause: a daily window (off by default, may wrap midnight) in which due
  reminders are skipped, not held, so a morning never starts with a backlog. The window math lives in
  `DailyWindow`, pure and tested; the scheduler takes it as a `(Date) -> Bool` provider.
- A reminder may carry its own active hours, a `DailyWindow` like lunch for a snack reminder. Due
  outside the window, it is deferred to the next window start, not skipped and not held.

### Reminder model

```swift
struct Reminder: Identifiable, Codable {
    let id: UUID
    var label: String          // "Drink water"
    var message: String        // what the character says
    var interval: TimeInterval // seconds
    var mood: CharacterMood
    var isEnabled: Bool
    var isBuiltIn: Bool
}
```

Persisted as readable JSON in Application Support, not UserDefaults. It is a file the user can read,
edit, and share, which is part of being open and hackable. See "Configuration".

### Dismissal

Three outcomes only: dismissed (the user clicked the character), snoozed (a short delay, default ten
minutes), or auto-dismissed after a timeout. All three are normal. None is a failure. Never track
them as failures anywhere in the UI.

## Suppression (the most important logic in the app)

Before presenting, the Scheduler asks the gate: is now a good moment. If a reason comes back, the
reminder is HELD, not dropped. Held reminders go into a queue with their original due time. When the
context clears, the Scheduler delivers at most ONE held reminder, then resumes normal timing. Never
flush the whole queue; nobody wants four characters in a row after a meeting.

The real gate reports a reason for: screen locked; camera or microphone in use (a call is likely);
frontmost window is full screen; the user is idle beyond a threshold. Conditions with no reliable
public API (Focus, Do Not Disturb, screen recording) are best effort and not reported; the signals
that catch the cases that matter most still fire. When in doubt, do not interrupt: prefer holding
over showing.

The capture, full-screen, and idle holds can each be turned off in Settings > Timing; all default to
on, and the screen-lock hold is not optional. The calendar hold is the inverse: off by default,
because it needs read access to the local event store, which is the user's to grant; while a
non-all-day event is on, reminders are held. The calendar is read on-device only, never stored or
sent. The gate reads all of these through provider closures handed in by the app model, so a change
applies on the next check and the gate never learns a settings key.

## Character

Code-drawn in SwiftUI from geometric primitives, not illustration: it scales with no asset pipeline,
every state is a parameter change on the same shapes, and it animates natively with springs.
Personality comes from motion, not from detail. Keep the whole character within roughly 120 by 120
points; it is a corner guest, not a window. Do not build a custom character import system now; design
the state vocabulary so a later move to Rive or a sprite sheet is a swap, not a rewrite.

State is where the character is in its appearance lifecycle. Mood is what kind of reminder it carries.
They are separate.

```swift
enum CharacterState {
    case hidden, arriving, idle, speaking, acknowledged, snoozed, leaving
}

enum CharacterMood {
    case move, water, eyes, posture, custom
}
```

Mood changes the accent and a small gesture, not the whole animation. Keep the shared skeleton.

Motion spec:

- **Arriving**: slide up from below the screen edge with a small overshoot and settle, spring, about
  400ms. This is the signature moment; get it right.
- **Idle**: almost still. A slow blink every few seconds, very small vertical breathing. Nothing that
  pulls the eye.
- **Speaking**: the message appears beside the character, with one small gesture tied to mood.
- **Acknowledged**: one brief positive beat, about 300ms, then leaving. No confetti, no sound.
- **Snoozed**: a small nod, then leaving. Identical weight to acknowledged. Snoozing is not failure
  and must not look like disappointment.
- **Leaving**: slide back down, slightly faster than arriving, about 300ms, ease-in.

Hard rules for the character:

- It NEVER shows disappointment, sadness, or guilt. No drooping when ignored, no sad face, no streak
  shaming. Ignoring a reminder is the user's right and the character has no opinion about it.
- It never blocks content: corner only, small, click-through except its own hit area.
- It never makes sound by default. Sound is opt-in, one quiet cue, never a jingle.
- It never idle-animates in a way that draws the eye. Motion only on arrival, reaction, departure.
- Respect Reduce Motion: replace slides with a fade and skip the springs.
- It is calm. No exclamation marks in dialogue, no emoji, no excitable copy.

Dialogue is short, warm, and plain, two to six words. "Time to stand up." "Water." "Look away for
twenty seconds." Never "Great job", "You did it", "Don't forget again", any exclamation, any emoji,
any guilt.

## Key decisions

The durable choices and the why. History is in git.

- **Three-layer seam.** Scheduler, Presenter, Reminders are separable, so the Scheduler is tested
  with no window on screen.
- **Hold, do not drop.** A bad moment holds a reminder in a queue keyed by its original due time; the
  queue drains one at a time when the moment clears. Pause is different: it skips, so resume is quiet.
- **Reminders as data.** Built-in and custom are the same `Reminder` type; only add and delete are
  restricted to custom ones. A built-in can be edited but not removed, and keeps a fixed id.
- **The config file is a public interface.** `reminders.json` has a documented, stable schema (see
  "Configuration"). A file the user can read and edit is part of being open and hackable.
- **Code-drawn character, code-drawn icon.** The app icon and the menu-bar template come from the
  same geometry as the character, so there is no asset pipeline to keep in sync.
- **Interactive by click-through toggle.** The overlay is click-through except over the character's
  hit strip; a global mouse monitor toggles `ignoresMouseEvents`. Outcomes (dismiss, snooze,
  auto-dismiss) are reported to the app model, which decides what they mean.
- **Ship from source.** Baud is built from source for now: clone, open in Xcode, run. No signing,
  notarisation, or Homebrew cask while the app is a learning project with no release.

When you make an architectural decision, record the why in the commit body and update the relevant
rule here if it changes one.

## Platform rules (hard)

- Swift and SwiftUI, macOS 14+. Use `@Observable`, `MenuBarExtra`, `SMAppService`.
- Do NOT enable App Sandbox. Distributed outside the App Store.
- `LSUIElement = true`: menu bar only, no Dock icon. The character window is not a Dock app.
- The character window never takes focus. `NSWindow` must not become key or main when it appears.

## Configuration

Baud stores its reminders as a JSON array at
`~/Library/Application Support/Baud/reminders.json`. The file is created on first launch, seeded with
the built-ins. It is a supported public interface: the schema is stable.

| Field       | Type    | Meaning                                                   |
|-------------|---------|-----------------------------------------------------------|
| `id`        | string  | UUID. Stable identity. Built-ins use fixed ids.           |
| `label`     | string  | Short name shown in the menu and editor.                  |
| `message`   | string  | What the character says. Short and calm.                  |
| `interval`  | number  | Seconds between occurrences.                              |
| `mood`      | string  | One of `move`, `water`, `eyes`, `posture`, `custom`.      |
| `isEnabled` | boolean | Whether the reminder is scheduled.                        |
| `isBuiltIn` | boolean | True for the shipped reminders; those cannot be deleted.  |
| `snoozeInterval` | number | Optional. Seconds a snooze postpones this reminder; omitted means the app-wide snooze length applies. |
| `activeHours` | object | Optional. `{"startMinutes": 720, "endMinutes": 840}`, minutes after midnight; the window may wrap midnight. Due outside it, the reminder waits for the next window start. Omitted means the whole day. |

Edit with the app quit: saving from the editor while Baud runs overwrites hand edits. An unreadable
or malformed file falls back to the built-ins in memory only, never overwriting the file, rather than
leaving the user with nothing. An unknown `mood` is rejected on load.

### App preferences

App-wide preferences live in UserDefaults, not in `reminders.json`: they are app behaviour, not
reminder data. The keys are defined as statics on `AppModel`; the Settings window writes them with
`@AppStorage` and the app model reads them at use time (or hands the gate and scheduler provider
closures), so every change applies without a restart.

| Key                     | Default | Meaning                                                 |
|-------------------------|---------|---------------------------------------------------------|
| `snoozeMinutes`         | 10      | App-wide snooze length; a reminder's `snoozeInterval` overrides it. |
| `autoDismissSeconds`    | 8       | How long the character waits for a click before leaving. |
| `idleMinutes`           | 2       | Input-free minutes before reminders are held.            |
| `idleHoldEnabled`       | true    | Whether being away holds reminders at all.               |
| `fullScreenHoldEnabled` | true    | Whether a full-screen frontmost app holds reminders.     |
| `captureHoldEnabled`    | true    | Whether an active camera or microphone holds reminders.  |
| `cooldownSeconds`       | 120     | Minimum gap between two appearances.                     |
| `calendarHoldEnabled`   | false   | Whether a calendar event in progress holds reminders. Needs calendar access. |
| `quietHoursEnabled`     | false   | Whether the daily quiet window applies.                  |
| `quietStartMinutes`     | 1260    | Quiet window start, minutes after midnight (21:00).      |
| `quietEndMinutes`       | 480     | Quiet window end, minutes after midnight (08:00).        |

A missing hold toggle reads as enabled; holding is always the default. Turning the idle hold off maps
to an infinite idle threshold, so the gate carries no extra state.

## Code conventions

- **Access control and finality.** Every type is `final` unless designed for subclassing. Default to
  `private`; widen only when a real caller needs it. Never expose mutable state as a public `var`;
  use `private(set)` and mutate through methods so invariants cannot be bypassed.
- **Safety.** No force-unwrap or force-try in shipping code; use `guard let`, `if let`, or typed
  errors. Allowed only in tests and `@main` bootstrap. Prefer `struct` over `class`; a `class` only
  for identity or reference semantics.
- **Model with enums, not flags.** `CharacterState` and `CharacterMood` are enums, never
  `isArriving` plus `isLeaving` plus `isIdle`. Typed error enums per subsystem, not string errors.
- **Functions.** One job each; if the name needs "and", split it. Roughly 25 to 40 lines. Early
  return with `guard` at the top, happy path unindented below. Isolate side effects (window creation,
  timers, capture-device checks) in named methods, never in a computed property or a view body.
- **Concurrency.** `async`/`await` and structured concurrency for new code. Anything touching AppKit
  or the window runs on the main actor; the Presenter and the Scheduler are `@MainActor`. C callbacks
  hop to the main actor before mutating shared state.
- **SwiftUI.** Views are dumb: read from an `@Observable` model and send intent. No AppKit window
  manipulation in a view body. Extract a subview when `body` grows past a screen or nests more than
  two levels. Animation constants live in `Motion.swift`, not scattered as magic numbers.
- **DRY, threshold two.** Extract on the second occurrence, not the first. Do not pre-abstract.
- **Naming.** UpperCamelCase types, lowerCamelCase members. Booleans read as assertions (`isEnabled`,
  `shouldSuppress`, `hasHeldReminders`). Files named after their primary type; one type per file by
  default. Protocols name a capability (`SuppressionGate`), never `IFoo` or `FooProtocol`.
- **Testing.** Unit-test the Scheduler and the gate with no window on screen. Test the invariants
  that matter: a suppressed reminder is held and not dropped; a wake after sleep collapses missed
  occurrences to at most one; the held queue delivers one at a time. The gate is behind a protocol so
  tests drive bad-moment states directly.

## Writing rules (hard, apply everywhere: UI, character dialogue, comments, commits, README)

- No em dashes. Use a comma, a colon, parentheses, or rewrite. This applies to every character.
- No emojis anywhere, including UI copy and character dialogue.
- No exclamation marks in UI text or copy. The character is calm, not excitable.
- No filler adjectives: seamless, robust, comprehensive, powerful, cutting-edge, intuitive,
  innovative, next-level, world-class.
- No AI-flavored verbs: leverage, utilize, delve, explore, unlock, elevate.
- UI copy is short and direct. Character dialogue is short, warm, and never nags.
- Never guilt the user. No streaks that punish, no sad-face shaming, no "you missed 3 breaks".

## Comment rules (hard)

- Plain comments only. No decorative dividers, rules, ASCII art, or box borders. `// MARK:` is fine
  for Xcode navigation; do not pad it into a banner.
- Comment only when the WHY is non-obvious: a hidden constraint, a subtle invariant, a workaround for
  a known bug, a non-obvious ordering. Never restate what the code does; well-named identifiers do
  that. If removing a comment would not confuse a future reader, do not write it.

## Design rules (SwiftUI)

Two visible surfaces: the character overlay and a small settings window. Keep both plain and native.

- No gradient chrome; flat fills. Gradients only inside the character if the design calls for it.
- No glass or blur added for looks, no fake depth, no neumorphism, no glow, neon, bloom, or text
  shadows. The character window has `hasShadow = false`.
- No shimmer, confetti, particle systems, or celebration effects.
- Respect light and dark automatically. Never hard-code the menu-bar icon colour; use a template
  image that macOS tints.
- Respect Reduce Motion (slides become fades, springs skipped) and Reduce Transparency where the
  overlay uses translucency.
- Prefer SF Symbols and system controls unless the character requires a custom shape.

## Git rules (hard)

- Micro-commits: every small, self-contained unit of work gets its own commit immediately (one type,
  one file group, one behavior, one doc update). Never batch unrelated changes into one commit.
  Commits must be small enough to review at a glance.
- Push cadence: commit locally as you go, push to origin main when a feature or a unit of work is
  complete. One push may carry multiple micro-commits.
- Everything goes directly to main. No branches, no PRs for now.
- Commit messages: conventional-commit style, `type(scope): summary`, imperative mood, lower case, no
  trailing period. Add a body only when the why is not obvious from the diff.
- Strictly forbidden in commits: co-author trailers, "Generated with", any mention of an AI, agent,
  assistant, or tool as author or contributor. The human is the sole author of record.
- Never force-push. Never rewrite pushed history.

## Definition of done

- Builds with no new warnings; the tests pass.
- No force-unwrap and no leftover TODO escape hatches in shipping paths.
- A new character mood is one enum case plus its motion, with no view branching added.
- A held reminder is never dropped and the queue never flushes; the window never becomes key.
- Comments and copy follow the rules above.
- Committed as micro-commits with the why in the body when it is not obvious.
