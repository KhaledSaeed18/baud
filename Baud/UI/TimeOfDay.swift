import SwiftUI

/// Bridges minutes-after-midnight settings to what SwiftUI time controls want.
/// Shared by the quiet hours pickers and the reminder active hours pickers.
enum TimeOfDay {
    /// A Date binding for a DatePicker over a minutes value. Only the time
    /// components survive the round trip; the day is irrelevant.
    static func binding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let start = Calendar.current.startOfDay(for: Date())
                return start.addingTimeInterval(TimeInterval(minutes.wrappedValue * 60))
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    /// A short clock label for a minutes value, in the user's locale.
    static func label(_ minutes: Int) -> String {
        let start = Calendar.current.startOfDay(for: Date())
        let date = start.addingTimeInterval(TimeInterval(minutes * 60))
        return date.formatted(date: .omitted, time: .shortened)
    }
}
