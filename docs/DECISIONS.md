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
