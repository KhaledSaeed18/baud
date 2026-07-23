# Conventions

The full style, naming, structure, and design guide. CLAUDE.md carries the non-negotiables and
points here.

## 1. Writing style (all text: UI, character dialogue, comments, commits, docs)

- No em dashes anywhere. Use a comma, a colon, parentheses, or rewrite the sentence.
- No emojis.
- No exclamation marks in UI copy or character dialogue.
- No filler adjectives: seamless, robust, comprehensive, powerful, cutting-edge, intuitive,
  innovative, next-level, world-class.
- No AI-flavored verbs: leverage, utilize, delve, explore, unlock, elevate.
- No guilt, shaming, or streak-punishment language anywhere in the product.
- UI copy is short and direct. Character dialogue is two to six words where possible.

The pre-commit hook in `scripts/check-style.sh` enforces the mechanical parts of this. Install it
with `scripts/install-hooks.sh`. Do not bypass it with `--no-verify`.

## 2. Comments

Plain only. No decorative dividers, horizontal rules, ASCII art, or box borders.

    // Wrong
    // --- Window setup -----------------------------------
    // === Scheduler ===

    // Correct
    // Window setup
    // Scheduler

Write a comment only when the WHY is non-obvious: a hidden constraint, a subtle invariant, a
workaround for a known bug, a non-obvious ordering requirement. Never restate what the code does.

`// MARK:` is fine for Xcode navigation. Do not pad it into a banner.

## 3. Swift style

### Access control and finality
- Every type is `final` unless designed for subclassing.
- Default to `private`. Widen only when a real caller needs it.
- Never expose mutable state publicly. Use `private(set)` and mutate through methods so invariants
  cannot be bypassed from outside.

### Types and safety
- No force-unwrap (`!`) or force-try in shipping code. Use `guard let`, `if let`, typed errors.
  Allowed only in tests and `@main` bootstrap where failure is a programmer error.
- Prefer `struct` over `class`. Use a class only when identity or reference semantics are needed.
- Model state with enums and associated values, never boolean flags. `CharacterState` and
  `CharacterMood` are enums. Never `isArriving` plus `isLeaving` plus `isIdle`.
- Typed `Error` enums per subsystem, not string errors.

### Functions
- One function, one job. If the name needs "and", split it.
- Roughly 25 to 40 lines. Longer means extract into private helpers or an extension.
- Early returns via `guard`. Guard clauses at the top, happy path unindented at the bottom.
- Pure functions where possible. Side effects (window creation, timers, capture-device checks)
  isolated in named methods, never inside a computed property or a view body.

### Concurrency
- `async`/`await` and structured concurrency. No completion-handler pyramids in new code.
- Anything touching AppKit or the window runs on the main actor. Mark the Presenter `@MainActor`.
- The Scheduler can be an actor or main-actor isolated. Pick one and document it in DECISIONS.md.

### SwiftUI
- Views are dumb. They read from an `@Observable` model and send intent.
- No AppKit window manipulation inside a SwiftUI view body.
- Extract subviews when a body grows past a screen or nests more than two levels.
- Animation values (durations, spring parameters) live in one constants file, not scattered as
  magic numbers. The motion spec in CHARACTER.md is the source of truth for those values.

## 4. Separation of concerns

- **Reminders**: data models, persistence, defaults. No timing, no AppKit.
- **Scheduler**: fire dates, wake recovery, suppression gate, held queue. No AppKit, no SwiftUI.
- **Presenter**: `NSWindow`, positioning, hosting, show and hide. No timing decisions.
- **Character**: SwiftUI views, the state machine, the motion. No knowledge of reminders beyond
  the value it is handed.
- **UI**: menu bar, settings, reminder editor.
- **App**: `@main`, wiring, launch at login.

The Scheduler must be testable with no window on screen. That is the point of the seam.

## 5. DRY

Threshold is two. Two occurrences means extract. Do not pre-abstract a single use.

## 6. Naming

- Types and protocols: UpperCamelCase. Methods, properties, cases: lowerCamelCase.
- Booleans read as assertions: `isEnabled`, `shouldSuppress`, `hasHeldReminders`.
- Files named after their primary type.
- Protocols describe capability. No `IFoo` or `FooProtocol`.

## 7. Project structure

    Baud/
      App/
        BaudApp.swift               // @main, wiring
      Reminders/
        Reminder.swift              // the model
        ReminderStore.swift         // JSON persistence in Application Support
        DefaultReminders.swift      // built-ins
      Scheduler/
        ReminderScheduler.swift     // fire dates, wake recovery, held queue
        SuppressionGate.swift       // "is now a good moment"
        IdleMonitor.swift
      Presenter/
        BaudWindow.swift            // borderless NSWindow subclass, canBecomeKey = false
        WindowPositioner.swift      // corner math against visibleFrame
        Presenter.swift             // show(reminder:), hide()
      Character/
        CharacterView.swift
        CharacterState.swift        // state machine enum + transitions
        CharacterMood.swift
        Motion.swift                // durations, springs, all animation constants
      UI/
        MenuBarView.swift
        SettingsView.swift
        ReminderEditorView.swift
      Resources/
        Assets.xcassets
      Supporting/
        Info.plist                  // LSUIElement = true

One type per file by default.

## 8. Design rules

This app has two visible surfaces: the character overlay and a small settings window. Keep both
plain and native.

- No gradient chrome. Flat fills. Gradients only inside the character if the design calls for it.
- No glass or blur effects added for looks. System materials only where a popover already uses them.
- No fake depth, no neumorphism, no glow, no neon, no bloom.
- No text shadows. No heavy or decorative shadows. The character window has `hasShadow = false`.
- No shimmer or animated-gradient loading states.
- No confetti, particle systems, or celebration effects. Explicitly banned, see CHARACTER.md.
- Respect light and dark mode automatically. Never hard-code the menu bar icon colour; use a
  template image.
- Respect Reduce Motion. Slides become fades, springs are skipped.
- Respect Reduce Transparency where the overlay uses any translucency.

## 9. Testing

- Scheduler and SuppressionGate are unit-tested with no window on screen.
- Test the invariants that matter: a suppressed reminder is held and not dropped; a wake after
  sleep collapses missed occurrences to at most one; the held queue delivers one at a time.
- The suppression gate is behind a protocol so tests can drive "bad moment" states directly.
- No UI snapshot tests at this stage.

## 10. Definition of done (per feature)

- Builds with no warnings.
- No force-unwrap left in shipping paths.
- Style hook passes.
- New character mood is one enum case plus its motion, with no view branching added.
- Roadmap box ticked, ADR appended if a decision was made.
- Committed as its own micro-commit; pushed to main when the unit of work is complete. See the Git
  rules in CLAUDE.md.
