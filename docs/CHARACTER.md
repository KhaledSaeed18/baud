# Character

The app is named Baud. The character itself has no name.

This document is the spec for the character: its states, what triggers each, and how it moves.
Read this before any UI or animation work. It is the design contract for both the v1 code-drawn
character and any future imported character format.

## Design approach for v1

Code-drawn in SwiftUI. Geometric primitives, not illustration. Reasons:

- Vector, so it scales to any Retina density with no asset pipeline
- Every state is a parameter change on the same shapes, not a new file
- Animates natively with SwiftUI springs
- No export step, no licence questions, no frame budgets
- The hours go into windowing and scheduling, which is the actual learning goal

Personality comes from MOTION, not from detail. A simple shape that moves well reads as more alive
than a detailed sprite that moves badly. This is the core bet of the design.

Do NOT ask an image generator for a mascot and try to trace it. Do NOT build the custom character
import system in v1. If the code-drawn character proves too limiting after real use, the migration
path is Rive (it has a state machine model that maps directly onto the states below) or a sprite
sheet. Design the state vocabulary now so that migration is a swap, not a rewrite.

## Form

A small, simple, geometric character. Suggested starting point, not binding:

- One rounded body shape
- Two dots for eyes
- One arc for a mouth, or no mouth at all
- Optional single antenna or a small element that can react

Restraint is the aesthetic. It should not look like a cute mascot from a wellness app. Calm,
minimal, slightly deadpan. The visual relatives are simple robots and geometric icons, not kawaii
pixel art. This is deliberate: the competitors are cute, and being not-cute is a real position.

Keep the whole character within roughly 120 by 120 points. It is a corner guest, not a window.

## States

The character is a state machine. Adding a mood means adding a case, never an `if` in a view.

```swift
enum CharacterState {
    case hidden        // not on screen at all
    case arriving      // sliding in
    case idle          // present, waiting for the user to react
    case speaking      // delivering the message
    case acknowledged  // user dismissed, brief happy beat before leaving
    case snoozed       // user postponed, brief nod before leaving
    case leaving       // sliding out
}
```

Mood is separate from state. State is where it is in the appearance lifecycle. Mood is what kind
of reminder it is carrying.

```swift
enum CharacterMood {
    case move      // walk, stand, stretch
    case water     // hydration
    case eyes      // 20-20-20, look away
    case posture
    case custom    // user-defined reminders
}
```

Mood changes the accent and small details, not the whole animation. Keep the shared skeleton.

## Motion spec

- **Arriving**: slide up from below the screen edge into position, with a small overshoot and
  settle. Spring, roughly 400ms. This is the signature moment of the app. Get it right.
- **Idle**: almost still. A slow blink every few seconds. Very small vertical breathing motion.
  Nothing that pulls the eye. The user is working; the character is waiting politely.
- **Speaking**: the message appears in a small bubble or beside the character. Character does one
  small gesture tied to mood: a hop for move, a tip for water, a slow blink for eyes.
- **Acknowledged**: one brief positive beat, roughly 300ms, then leaving. No confetti, no
  celebration, no sound by default.
- **Snoozed**: a small nod, then leaving. Identical weight to acknowledged. Snoozing is not
  failure and must not look like disappointment.
- **Leaving**: slide back down, slightly faster than arriving, roughly 300ms, ease-in.

## Hard rules for the character

- It NEVER shows disappointment, sadness, or guilt. No drooping when ignored, no sad face, no
  streak shaming. The competitors do this; deliberately do not. Ignoring a reminder is the user's
  right and the character does not have an opinion about it.
- It never blocks content. Corner only, small, and click-through except its own hit area.
- It never makes sound by default. Sound is opt-in, one quiet cue, never a jingle.
- It never idle-animates in a way that draws the eye. Motion only on arrival, reaction, departure.
- Respect Reduce Motion. When that accessibility setting is on, replace slides with a simple fade
  and skip the springs entirely.
- It is calm. No exclamation marks in its dialogue, no emoji, no excitable copy.

## Dialogue

Short, warm, plain. Two to six words is the target. Examples of the register:

- "Time to stand up."
- "Water."
- "Look away for twenty seconds."
- "Been a while. Stretch?"

Never: "Great job!", "You did it!", "Don't forget again", anything with an exclamation mark, any
emoji, any guilt.
