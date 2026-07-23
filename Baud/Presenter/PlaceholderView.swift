import SwiftUI

/// A plain stand-in for the character so Phase 0 can prove out windowing and
/// motion. Phase 1 replaces this with the code-drawn character; keep it a flat
/// shape until then.
struct PlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.accentColor)
            .frame(width: 120, height: 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
