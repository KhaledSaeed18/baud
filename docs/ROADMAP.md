# Roadmap

PLACEHOLDER NAME: "Companion" throughout. Not final.

Build phases in order. Each teaches a distinct part of the platform. Do not skip ahead.

## Phase 0: the window appears
- [ ] Xcode project, SwiftUI macOS 14 target, LSUIElement = true, no sandbox
- [ ] Borderless transparent NSWindow subclass, canBecomeKey and canBecomeMain return false
- [ ] Floating window level, ignoresMouseEvents, correct collectionBehavior
- [ ] Position at bottom trailing corner of visibleFrame
- [ ] Show a placeholder shape, slide it in and out on a manual trigger
Teaches: AppKit windowing, NSHostingView, screen geometry. This is the riskiest unknown, do it first.

## Phase 1: the character
- [ ] CharacterState and CharacterMood enums with transitions
- [ ] Code-drawn geometric character in SwiftUI
- [ ] Motion.swift with all animation constants in one place
- [ ] Arriving, idle blink, speaking, acknowledged, snoozed, leaving
- [ ] Reduce Motion path (fades, no springs)
Teaches: SwiftUI animation, state machines, accessibility. Follow docs/CHARACTER.md exactly.

## Phase 2: reminders and scheduling
- [ ] Reminder model, JSON persistence in Application Support
- [ ] Built-in reminders: move, water, eyes, posture
- [ ] ReminderScheduler with computed fire dates, single coordinating timer
- [ ] Wake-from-sleep recovery, missed occurrences collapse to at most one
Teaches: timers that survive sleep, file persistence, Codable.

## Phase 3: the suppression gate (the important one)
- [ ] SuppressionGate behind a protocol so it is testable
- [ ] Full screen detection, idle detection, screen lock detection
- [ ] Camera and microphone in use detection
- [ ] Do Not Disturb and Focus detection where reliable
- [ ] Held queue: one held reminder delivered when context clears, never a flush
- [ ] Unit tests for hold, not drop, and for one-at-a-time delivery
Teaches: NSWorkspace, CGEventSource, capture device APIs. This is what makes the app good.

## Phase 4: control surface
- [ ] MenuBarExtra: next reminder, pause for a duration, settings, quit
- [ ] Pause as a first class feature
- [ ] Settings scene, launch at login via SMAppService
- [ ] Reminder editor: add, edit, enable, disable custom reminders
Teaches: MenuBarExtra, SMAppService, form UI.

## Phase 5: ship
- [ ] Choose the real name, replace the placeholder everywhere
- [ ] Icon and menu bar template image
- [ ] Sign, notarize, staple
- [ ] GitHub Releases, Homebrew cask, MIT licence, README
- [ ] Decide the config file format is stable enough to document as a public interface

## Later, not v1
- Custom character import. Only after real use tells you what the state vocabulary needs.
  Likely Rive, whose state machine model maps onto CharacterState directly.
- Trigger a reminder from a script or CLI.
- Multiple characters, themes, skins.
