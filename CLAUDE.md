# Companion (placeholder name): Claude Code Context

PLACEHOLDER NAME: the project is currently called "Companion". The name is not decided.
Every occurrence of "Companion" / "companion" in this repo is a placeholder to be replaced later.
Do not spend effort on naming or branding copy until the name is chosen.

A macOS desktop companion that reminds you to move, drink water, rest your eyes, and anything
custom you define. Instead of a system notification, a small animated character slides in from a
screen corner, delivers the reminder, and leaves. Free and open source. Native Swift, no Electron.

This file is the always-loaded context. It holds only non-negotiable rules and pointers. The full
style and structure guide lives in `docs/CONVENTIONS.md`. Read it before writing code.

## Read before working

- `docs/PRODUCT.md`: what it is, competitors, positioning, scope guardrails
- `docs/ARCHITECTURE.md`: window model, scheduler, character state machine. Read first
- `docs/CHARACTER.md`: the character state vocabulary and motion spec. Read before any UI work
- `docs/CONVENTIONS.md`: code style, naming, structure, writing rules, design rules
- `docs/ROADMAP.md`: build order; do phases in sequence, don't skip ahead
- `docs/DECISIONS.md`: why things are the way they are; append new ADRs here

## Git rules (hard)

- Never commit or push without being asked. Stage and describe changes, then wait for approval.
- Commit messages describe the change only. Never add a co-author trailer, never mention an AI,
  agent, assistant, or tool as author or contributor. No "Generated with", no "Co-Authored-By".
- Conventional-commit style: `type(scope): summary`. Imperative mood, lower case, no trailing period.

## Platform rules (hard)

- Swift + SwiftUI, macOS 14+. Use `@Observable`, `MenuBarExtra`, `SMAppService`.
- Do NOT enable App Sandbox. Distributed outside the App Store.
- `LSUIElement = true`: menu-bar only, no Dock icon. The character window is not a Dock app.
- The character window never takes focus. `NSWindow` must not become key or main when it appears.

## The one rule that defines this app (hard)

NEVER interrupt the user at a bad moment. A reminder that appears during a screen share, a call,
a full-screen video, or a presentation is a bug, not a feature. When the context is bad, the
reminder is HELD and delivered later. It is never dropped silently and never forced through.
See `docs/ARCHITECTURE.md` "Suppression rules". This is the single most important behaviour in
the product. Treat a violation as a P0.

## Architecture rules (hard)

- Three layers with clean seams: Scheduler (when), Presenter (window + character), Reminders
  (what). The Scheduler never touches AppKit. The Presenter never decides timing.
- The character is a state machine, not a pile of booleans. States and transitions are defined in
  `docs/CHARACTER.md`. Adding a mood means adding a case, not an `if` in a view.
- Reminder definitions are data, not code. A built-in reminder and a user-defined one are the same
  type. No special-casing water or movement.
- No polling loops for scheduling. Use timers with computed fire dates and recompute after wake.
  The Mac sleeps; a naive repeating timer will drift or misfire.

## Writing rules (hard, apply everywhere: UI, comments, commits, docs)

- No em dashes. Use a comma, a colon, or rewrite. This applies to every character you emit,
  including in these docs.
- No emojis anywhere, including in UI copy and character dialogue.
- No exclamation marks in UI text or copy. The character is calm, not excitable.
- No filler adjectives: seamless, robust, comprehensive, powerful, cutting-edge, intuitive,
  innovative, next-level, world-class.
- No AI-flavored verbs: leverage, utilize, delve, explore, unlock, elevate.
- UI copy is short and direct. Character dialogue is short, warm, and never nags.
- Never guilt the user. No streaks that punish, no sad-face shaming, no "you missed 3 breaks".

## Comment rules (hard)

- Plain comments only. No decorative dividers, no rules, no ASCII art, no box borders.
- Comment only when the WHY is non-obvious: a hidden constraint, a subtle invariant, a workaround
  for a known bug. Never describe what the code does; well-named identifiers do that.
- If removing a comment would not confuse a future reader, do not write it.

## Conventions

- After any architectural decision, append an ADR to `docs/DECISIONS.md`.
- Tick roadmap boxes in `docs/ROADMAP.md` as phases complete.
- Everything else: `docs/CONVENTIONS.md`.
