import SwiftUI
import AppKit

private let coral = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
private let amber = Color(red: 0xE0 / 255, green: 0xA4 / 255, blue: 0x58 / 255)

struct OSDPanelView: View {
    @StateObject private var model = UsageViewModel()
    @State private var quitHovered = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(EdgeInsets(top: 13, leading: 14, bottom: 0, trailing: 14))
                .padding(.bottom, 12)

            SegmentedControlView(tab: $model.tab)
                .padding(.horizontal, 14)

            content
                .padding(EdgeInsets(top: 18, leading: 14, bottom: 16, trailing: 14))

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 13)

            quitRow
        }
        .padding(.bottom, 8)
        .frame(width: 312)
        .background(
            ZStack {
                VisualEffectBlur(material: .menu, blendingMode: .behindWindow)
                Color(red: 38 / 255, green: 38 / 255, blue: 42 / 255).opacity(0.72)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 13)
        }
        .shadow(color: .black.opacity(0.42), radius: 22, x: 0, y: 14)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(coral)
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
            }
            Text("Claude")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
            Spacer()
        }
        .frame(height: 18)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            switch model.tab {
            case .today:
                RingGaugeView(
                    pct: model.dailyPct,
                    color: coral,
                    percentLabel: model.hasDailyData ? "\(Int(model.dailyPct * 100))%" : "—",
                    caption: "of daily limit"
                )
                .padding(.bottom, 18)

                HStack(spacing: 9) {
                    StatTileView(label: "Resets in", value: model.dailyResetLabel)
                    StatTileView(label: "Spent today", value: model.dailySpend)
                }
            case .week:
                RingGaugeView(
                    pct: model.weeklyPct,
                    color: amber,
                    percentLabel: model.hasWeeklyData ? "\(Int(model.weeklyPct * 100))%" : "—",
                    caption: "of weekly limit"
                )
                .padding(.bottom, 18)

                HStack(spacing: 9) {
                    StatTileView(label: "Resets in", value: model.weeklyResetLabel)
                    StatTileView(label: "Spent this week", value: model.weeklySpend)
                }
            }
        }
    }

    private var quitRow: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack {
                Text("Quit")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            .padding(EdgeInsets(top: 11, leading: 15, bottom: 11, trailing: 15))
            .background(quitHovered ? Color.white.opacity(0.08) : Color.clear)
            .animation(.linear(duration: 0.12), value: quitHovered)
        }
        .buttonStyle(.plain)
        .onHover { quitHovered = $0 }
    }
}
