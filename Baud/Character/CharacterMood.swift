/// What kind of reminder the character is carrying. Mood changes the accent and
/// small details, never the animation skeleton. Adding a mood is one case here.
///
/// String-backed and Codable so a reminder's mood reads as plain text in the
/// JSON a user can edit.
enum CharacterMood: String, Codable, CaseIterable {
    case move
    case water
    case eyes
    case posture
    case custom
}
