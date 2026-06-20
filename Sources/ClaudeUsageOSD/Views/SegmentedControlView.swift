import SwiftUI

struct SegmentedControlView: View {
    @Binding var tab: UsageTab

    var body: some View {
        GeometryReader { geo in
            let segmentWidth = (geo.size.width - 4) / 2

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.10))

                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: segmentWidth, height: geo.size.height - 4)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: 2 + (tab == .week ? segmentWidth : 0), y: 2)
                    .animation(.timingCurve(0.3, 0.8, 0.3, 1, duration: 0.22), value: tab)

                HStack(spacing: 0) {
                    segmentButton(title: "Today", value: .today)
                    segmentButton(title: "This Week", value: .week)
                }
            }
        }
        .frame(height: 30)
    }

    private func segmentButton(title: String, value: UsageTab) -> some View {
        Button {
            tab = value
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.92))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
