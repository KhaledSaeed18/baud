# Product

## One-liner
A small animated character that lives on your Mac and reminds you to move, drink water, rest your
eyes, and whatever else you tell it. Free, open source, native.

## Why it exists
Two honest reasons, in order:

1. It is a learning project. The goal is to learn Swift, AppKit windowing, SwiftUI animation, and
   macOS scheduling. Shipping something usable is the second goal, not the first.
2. Every good app in this space is paid and closed source. The free and open lane is empty for
   character-based reminders. Stretchly owns free-and-open but has no character and is Electron.

## Competitors (checked, be honest about this)
- **Mushroom** (getmushroom.app): pixel mushroom desktop pet, reminds to drink water, stretch,
  take breaks. On-device, no account, signed and notarized, menu bar with no Dock icon. Times
  nudges around what you are doing, suppresses pings while away or winding down. Character droops
  when ignored. Paid, pay-what-you-want from around 3 EUR. Closest competitor, well executed.
- **Animinder**: animated animals carry banners across the desktop on reminder triggers. Natural
  language reminder input. Click-through windows that never steal focus. Supports importing PNG
  frame sequences and Spine animations as character assets. Paid.
- **Stretchly**: free, open source, cross-platform, mini and long breaks. Electron, unsigned,
  Gatekeeper friction on macOS, no character, no native feel.
- Others: Time Out, LookAway, DeskRest, Viraam, Take a Break. All characterless timer apps.
  Several are paid.

## Position
Free and open source, native Swift, with a character. That combination does not currently exist.

Real advantages over the paid competitors:
- **Open source means user-supplied characters are architecture, not a feature.** Animinder ships
  asset import as a selling point; here it is the natural shape of the app. A community that makes
  and shares characters is something a closed app structurally cannot have. This is the strongest
  long-term differentiator.
- **Native beats Electron.** Stretchly loses on being unsigned Electron with Gatekeeper friction.
  A native, small, free, open app wins that comparison outright.
- **Scriptable and hackable.** Reminders as data, a config file people can edit, and eventually a
  way to trigger a reminder from a script.

Do not claim novelty. The idea is not new. The execution and the licence are the position.

## Core behaviours
- A character slides in from a screen corner, delivers one reminder, and leaves.
- Built-in reminders: move and walk, drink water, rest eyes (20-20-20), posture.
- Custom reminders: any text, any interval, defined by the user.
- Snooze without guilt. One click to dismiss, one click for a short delay. No nagging re-pop.
- Never appears at a bad moment. See the suppression rules in ARCHITECTURE.md.
- Character has moods tied to reminder type. See CHARACTER.md.

## Scope guardrails
- v1 ships ONE character, hardcoded, with a fixed state vocabulary. Do NOT build the custom
  character import system in v1. Extensibility comes after real use tells you what the states
  need to be. Designing an asset format before animating one character is how this stalls.
- No accounts, no cloud, no analytics, no telemetry. Everything local.
- No streaks that punish. No guilt mechanics. No shaming copy.
- Not a Pomodoro app. Not a task manager. Not a habit tracker with charts.

## Non-goals
- Cross platform. macOS only.
- Paid tiers, subscriptions, in-app purchases. It is free and open source.
- Being a general notification replacement.
