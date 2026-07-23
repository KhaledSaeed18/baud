/// What kind of reminder the character is carrying. Mood changes the accent and
/// small details, never the animation skeleton. Adding a mood is one case here.
enum CharacterMood: CaseIterable {
    case move
    case water
    case eyes
    case posture
    case custom
}
