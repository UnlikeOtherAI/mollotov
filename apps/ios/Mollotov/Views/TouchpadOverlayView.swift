import SwiftUI

/// Fullscreen landscape overlay with a main touchpad (right) and scroll strip (left).
/// Visual placeholders only — interaction logic will be added later.
struct TouchpadOverlayView: View {
    let onClose: () -> Void

    private let scrollStripWidth: CGFloat = 60
    private let gap: CGFloat = 12
    private let outerPadding: CGFloat = 16
    private let cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: gap) {
                // Left: Scroll strip
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .frame(width: scrollStripWidth)

                // Right: Main touchpad
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(outerPadding)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
        }
        .ignoresSafeArea()
    }
}
