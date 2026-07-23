# Decisions (ADR log)

Append a new entry for every meaningful decision. Format: what, why, alternatives rejected.

## ADR-001: Learning project first, product second
**Decision:** Optimise for learning Swift and macOS platform APIs. Shipping something usable is
the second goal.
**Why:** The space has competent paid competitors. Building to compete would mean rushing past the
parts that teach the most. Building to learn means the windowing and scheduling work gets proper
attention, and the result is still usable.

## ADR-002: Free and open source, MIT
**Decision:** No paid tiers, no subscriptions, no in-app purchases. MIT licence.
**Why:** Both direct competitors (Mushroom, Animinder) are paid and closed. Stretchly owns free
and open but is characterless Electron. Free, open, native, with a character is an empty lane.
**Consequence:** User-supplied characters become architecture rather than a feature, which a
closed app structurally cannot match. That is the long-term differentiator.

## ADR-003: Never interrupt at a bad moment, hold rather than drop
**Decision:** A suppression gate blocks presentation during full screen, screen sharing, calls,
Focus modes, lock, and idle. Suppressed reminders are held in a queue, not dropped, and delivered
one at a time when the context clears.
**Why:** A reminder that appears during a screen share is the failure that gets an app deleted.
Dropping silently is also wrong because the user then gets no reminder at all.
**Rejected:** Firing regardless (hostile), dropping silently (useless), flushing the whole queue
when context clears (four characters in a row after a meeting).

## ADR-004: Code-drawn geometric character for v1
**Decision:** The character is SwiftUI shapes, not imported art. Personality comes from motion.
**Why:** No asset pipeline, no export step, no licence questions, vector at any density, and every
state is a parameter change. The hours go into windowing and scheduling, which is the learning
goal. Image generators also cannot hold a character consistent across poses.
**Migration path:** Rive if the code-drawn character proves limiting. Its state machine model maps
onto CharacterState directly, so the swap is contained.
**Rejected:** Generated raster art (consistency problem), sprite sheets (asset pipeline before the
state vocabulary is known), buying assets (not uniquely yours, licence questions when open source).

## ADR-005: No custom character import in v1
**Decision:** Ship one hardcoded character. Extensibility comes later.
**Why:** Designing an asset import format before animating a single character means specifying a
contract for states you have not yet discovered. Real use defines the vocabulary first.

## ADR-006: No guilt mechanics
**Decision:** The character never shows disappointment. No drooping when ignored, no sad faces, no
punishing streaks, no shaming copy.
**Why:** Mushroom droops when reminders are ignored. Deliberately go the other way. Ignoring a
reminder is the user's right and the character does not have an opinion about it. This is also a
positioning choice: calm and deadpan rather than cute and needy.

## ADR-007: Reminders as data, not code
**Decision:** Built-in and user-defined reminders are the same type, persisted as readable JSON in
Application Support.
**Why:** No special-casing water or movement. A file the user can read, edit, and share is part of
being open and hackable.
**Rejected:** UserDefaults (opaque), hardcoded built-ins with a separate custom path (two code
paths for one concept).

## ADR-008: Style rules enforced mechanically
**Decision:** A pre-commit hook greps for em dashes, emojis, and exclamation marks in UI strings.
**Why:** Writing rules stated in a doc get violated by anyone writing prose quickly, including the
author and any agent. A hook catches it at the only moment that matters.

## ADR-009: The project is named baud
**Decision:** The app is named baud, replacing the "Companion" placeholder everywhere. Written
"Baud" as a proper noun in prose, UI copy, Swift types (`BaudApp`, `BaudWindow`), the Xcode target,
and the built app (Baud.app). Lowercase "baud" for the bundle identifier and the repository
directory.
**Why:** The placeholder blocked committing a real target, bundle identifier, and window class
name. Baud is short, sits in the product's domain (a unit of signalling rate), and avoids the
wellness-app register the product positions against.
**Consequence:** The Phase 5 rename task is done early. The character stays unnamed; only the app
has a name.

## ADR-010: Xcode project committed directly, synchronized file groups, Swift 5 language mode
**Decision:** Baud.xcodeproj is committed to the repo, no XcodeGen or Tuist. It uses the Xcode 16
file-system synchronized group format (objectVersion 77): the target references the Baud/ folder,
so adding a source file needs no project edit. Info.plist is an explicit file under
Baud/Supporting, excluded from the synchronized target membership so it is not copied as a
resource. The target builds in Swift 5 language mode for now.
**Why:** A committed project matches `open Baud.xcodeproj` in the README and needs no extra tooling
to build. Synchronized groups keep the project file stable across the phased build, so it is not
hand-edited every phase. An explicit, readable Info.plist fits the hackable ethos and keeps
LSUIElement visible. Swift 5 mode keeps Phase 0 free of warnings; adopting Swift 6 data-race
checking is a later, deliberate step.
**Rejected:** XcodeGen or Tuist (an extra dependency for a single-target app), and generating the
Info.plist from build settings (less visible than a real file).

## ADR-011: Arrival overshoot on the window frame, micro-motion in SwiftUI
**Decision:** The signature arrival slides the whole window up into the corner with a back-out
bezier timing function for a small overshoot, not a physics spring on the window. The character's
own beats (blink, breathing, hop, tip, nod, straighten) are SwiftUI springs inside the view. Reduce
Motion replaces the window slide with a fade and skips the character springs.
**Why:** AppKit has no spring solver for a window frame; a back-out bezier gives the overshoot the
motion spec asks for without driving the frame by hand every display tick. The character's
micro-motion stays in SwiftUI, where springs are cheap and where CHARACTER.md's gestures live.
**Rejected:** Animating the character's offset inside a fixed, taller window (it would have to
extend off-screen to hide the start, which fights the corner geometry). A hand-driven spring on the
window frame via a display link (more code than the beat warrants for v1).

## ADR-012: The scheduler is main-actor isolated, one coordinating wait
**Decision:** ReminderScheduler is @MainActor (CONVENTIONS asks this choice be recorded). It holds
a next fire Date per reminder and a single coordinating wait that sleeps until the earliest fire
date, then delivers and recomputes. It is not a repeating timer and not a polling loop. Wake is
handled by the App observing NSWorkspace.didWakeNotification and calling handleWake, which
re-evaluates due reminders. Occurrences missed while asleep collapse to a single delivery.
**Why:** Delivery drives the main-actor presenter, so main-actor isolation avoids hops and keeps
the seam simple; the pure fire-date math (nextOccurrence) stays static and testable. A computed
wait honours "compute, do not count down" without a per-reminder timer. Keeping the wake
notification in the App layer keeps AppKit out of the scheduler, so it stays headless-testable.
**Rejected:** A Foundation Timer per reminder (drift, and its Sendable block fights main-actor
capture); observing the wake notification inside the scheduler (pulls AppKit into a layer that must
test without it).

## ADR-013: Tests are an app-hosted target using Swift Testing
**Decision:** BaudTests is a unit-test target hosted by Baud.app, using Swift Testing (import
Testing) with @testable import Baud to reach internal types.
**Why:** The scheduler and store are internal to the app module, so @testable import needs the app
as test host. Swift Testing is the current default and reads cleanly. Debug already builds with
testability enabled.
**Rejected:** A separate core framework the app and tests both link (more structure than a
single-target app needs now); XCTest (Swift Testing is the newer default).

## ADR-014: Suppression is a gate protocol plus a scheduler-owned held queue
**Decision:** SuppressionGate is a @MainActor protocol that answers "why hold, or nil if clear."
SystemSuppressionGate detects screen lock, an active camera or microphone, a full-screen frontmost
window (by a size heuristic), and idle beyond a threshold. The scheduler owns the held queue: a
suppressed reminder is held with its original due time, its schedule still advances, and held
reminders drain one at a time on a recheck cadence, never as a flush. A cooldown spaces every
appearance, held or not, so two characters never arrive back to back.
**Why:** The protocol seam lets the hold logic be unit-tested by driving bad-moment states directly,
with no real system state. Environmental detection belongs in the gate; queue orchestration and
timing belong in the scheduler. Camera or microphone catches calls; full screen catches
presentations and full-screen video, the cases that get an app deleted.
**Deferred:** Do Not Disturb, Focus, and screen-recording detection have no reliable public API, so
they are not reported rather than reported wrongly. Cooldown is measured from last delivery for now;
measuring from the user's dismissal can come when the presenter reports outcomes back.
**Rejected:** Private CoreGraphics space SPI for full screen (fragile, undocumented); parsing the
Focus assertion files (version-specific and brittle); flushing the queue when context clears (four
characters in a row after a meeting).

## ADR-015: Pause skips, the app model is the UI seam, the character auto-dismisses
**Decision:** Pause is first class in the scheduler. A paused reminder is skipped: its schedule
advances and nothing is held, so resuming does not pop a backlog, unlike a bad-moment hold which is
delivered later. The UI talks to one observable AppModel that owns the store, scheduler, and
presenter and turns intents into calls; the scheduler is @Observable so the menu reads the next
fire and pause state directly. With no character interaction yet, a shown reminder auto-dismisses
after a short idle, which is a normal outcome, never tracked as a miss.
**Why:** Skipping on pause matches the user's intent to silence the app, where holding matches the
app's intent not to interrupt a bad moment; they are different and behave differently. A single
AppModel keeps the wiring in one place and the views dumb. Auto-dismiss is needed because the menu
no longer drives the character off screen, and clicking the character is a later phase.
**Rejected:** Holding during pause (a surprise pop on resume); letting each view reach into the
scheduler directly (leaks it across the UI); leaving the character on screen until the next
interaction (it would never leave).

## ADR-016: The config file is a public interface; distribution is a notarised zip and a cask
**Decision:** reminders.json is a supported public interface with a documented, stable schema (see
docs/CONFIG.md); format changes will be noted there. Baud ships as a Developer ID signed, hardened,
notarised, stapled zip built by scripts/release.sh, distributed through GitHub Releases and a
Homebrew cask. The app icon and menu bar template are generated from the same geometry as the code
drawn character by scripts/make-icons.swift.
**Why:** A file the user can read and edit is part of being open and hackable, which only holds if
the format is treated as an interface rather than an implementation detail. Signing and notarising
avoid the Gatekeeper friction that a native, non-Electron app is meant to beat. Generating the icon
from code keeps it consistent with the character and free of an asset pipeline.
**Rejected:** Keeping the config format private (undercuts the hackable positioning); shipping
unsigned (Gatekeeper friction is exactly what the product positions against); hand-drawn icon
assets (an asset pipeline the code-drawn approach was chosen to avoid).

## ADR-017: The character is interactive by toggling click-through over its hit strip
**Decision:** While a reminder is on screen, the overlay window is click-through except over the
bottom strip where the character and its controls sit; a global mouse monitor toggles
ignoresMouseEvents as the cursor enters and leaves that strip. The character carries a dismiss
control and a snooze control that appear while it is present. The hosting view accepts the first
mouse, so a click acts immediately without activating the never-key window. Dismiss, snooze, and
auto-dismiss are reported to the app model as outcomes; snooze reschedules the reminder ten minutes
out.
**Why:** The window must stay click-through so it never blocks the content behind it, and it must
never become key so it never steals focus while the user types; toggling ignoresMouseEvents over
only the hit strip satisfies both while still letting the controls be clicked. Reporting outcomes
keeps the character ignorant of scheduling: it says how the reminder ended, the app model decides
what that means.
**Rejected:** Per-pixel hit testing via a hosting-view hitTest override (hard to get right against
SwiftUI's internal view tree, and untestable); making the whole window interactive whenever visible
(captures clicks over the transparent bubble area too); a right-click menu for snooze (less
discoverable than a one-click control, which PRODUCT.md asks for).
