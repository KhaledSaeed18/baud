# Roadmap

Build phases in order. Each teaches a distinct part of the platform. Do not skip ahead.

## Phase 0: the window appears
- [x] Xcode project, SwiftUI macOS 14 target, LSUIElement = true, no sandbox
- [x] Borderless transparent NSWindow subclass, canBecomeKey and canBecomeMain return false
- [x] Floating window level, ignoresMouseEvents, correct collectionBehavior
- [x] Position at bottom trailing corner of visibleFrame
- [x] Show a placeholder shape, slide it in and out on a manual trigger
Teaches: AppKit windowing, NSHostingView, screen geometry. This is the riskiest unknown, do it first.

## Phase 1: the character
- [x] CharacterState and CharacterMood enums with transitions
- [x] Code-drawn geometric character in SwiftUI
- [x] Motion.swift with all animation constants in one place
- [x] Arriving, idle blink, speaking, acknowledged, snoozed, leaving
- [x] Reduce Motion path (fades, no springs)
Teaches: SwiftUI animation, state machines, accessibility. Follow docs/CHARACTER.md exactly.

## Phase 2: reminders and scheduling
- [x] Reminder model, JSON persistence in Application Support
- [x] Built-in reminders: move, water, eyes, posture
- [x] ReminderScheduler with computed fire dates, single coordinating timer
- [x] Wake-from-sleep recovery, missed occurrences collapse to at most one
Teaches: timers that survive sleep, file persistence, Codable.

## Phase 3: the suppression gate (the important one)
- [x] SuppressionGate behind a protocol so it is testable
- [x] Full screen detection, idle detection, screen lock detection
- [x] Camera and microphone in use detection
- [ ] Do Not Disturb and Focus detection where reliable (deferred: no reliable public API, see ADR-014)
- [x] Held queue: one held reminder delivered when context clears, never a flush
- [x] Unit tests for hold, not drop, and for one-at-a-time delivery
Teaches: NSWorkspace, CGEventSource, capture device APIs. This is what makes the app good.

## Phase 4: control surface
- [x] MenuBarExtra: next reminder, pause for a duration, settings, quit
- [x] Pause as a first class feature
- [x] Settings scene, launch at login via SMAppService
- [x] Reminder editor: add, edit, enable, disable custom reminders
Teaches: MenuBarExtra, SMAppService, form UI.

## Phase 5: ship
- [x] Choose the real name, replace the placeholder everywhere (baud)
- [ ] Icon and menu bar template image
- [ ] Sign, notarize, staple
- [ ] GitHub Releases, Homebrew cask, MIT licence, README
- [ ] Decide the config file format is stable enough to document as a public interface

## Later, not v1
- Custom character import. Only after real use tells you what the state vocabulary needs.
  Likely Rive, whose state machine model maps onto CharacterState directly.
- Trigger a reminder from a script or CLI.
- Multiple characters, themes, skins.
