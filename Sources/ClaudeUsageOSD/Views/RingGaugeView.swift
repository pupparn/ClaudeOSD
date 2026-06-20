import SwiftUI

/// 158×158 radial gauge. Track radius 52 / stroke 11 inside a 132×132 viewBox, scaled to 158.
struct RingGaugeView: View {
    let pct: Double
    let color: Color
    let percentLabel: String
    let caption: String

    private let viewBoxSize: CGFloat = 132
    private let displaySize: CGFloat = 158
    private let radius: CGFloat = 52
    private let strokeWidth: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.13), lineWidth: strokeWidth)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .trim(from: 0, to: pct)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: pct)

            VStack(spacing: 3) {
                Text(percentLabel)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(.white.opacity(0.97))
                    .tracking(-0.03 * 38)
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .frame(width: viewBoxSize, height: viewBoxSize)
        .scaleEffect(displaySize / viewBoxSize)
        .frame(width: displaySize, height: displaySize)
    }
}
