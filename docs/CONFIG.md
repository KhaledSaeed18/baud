# Configuration

Baud stores its reminders as a JSON file you can read, edit, and share. This is a
supported, public interface: the format is stable and changes to it will be
noted here.

## Location

    ~/Library/Application Support/Baud/reminders.json

The file is created on first launch, seeded with the built-in reminders. Edits
are picked up the next time Baud loads the file (relaunch, or after saving from
the reminder editor). Editing while Baud is running and then saving from the
editor will overwrite your hand edits, so edit with the app quit.

## Format

A JSON array of reminders. Each reminder is an object:

| Field       | Type    | Meaning                                                        |
|-------------|---------|----------------------------------------------------------------|
| `id`        | string  | UUID. Stable identity. Built-ins use fixed ids.                |
| `label`     | string  | Short name shown in the menu and editor.                       |
| `message`   | string  | What the character says. Keep it short and calm.               |
| `interval`  | number  | Seconds between occurrences.                                   |
| `mood`      | string  | One of `move`, `water`, `eyes`, `posture`, `custom`.           |
| `isEnabled` | boolean | Whether the reminder is scheduled.                             |
| `isBuiltIn` | boolean | True for the shipped reminders. Built-ins cannot be deleted.   |

## Example

```json
[
  {
    "id" : "22222222-2222-2222-2222-222222222222",
    "label" : "Water",
    "message" : "Water.",
    "interval" : 2700,
    "mood" : "water",
    "isEnabled" : true,
    "isBuiltIn" : true
  },
  {
    "id" : "9F1C0E7A-2B3D-4E5F-8A1B-0C2D3E4F5A6B",
    "label" : "Tea",
    "message" : "Time for tea.",
    "interval" : 5400,
    "mood" : "custom",
    "isEnabled" : true,
    "isBuiltIn" : false
  }
]
```

## Notes

- An unreadable or malformed file falls back to the built-in reminders rather
  than leaving you with nothing. Keep a backup before hand editing.
- `mood` changes the character's accent and its small gesture, not the whole
  animation. An unknown mood value is rejected on load.
