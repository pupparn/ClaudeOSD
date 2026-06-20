import Foundation
import Combine

enum UsageTab {
    case today
    case week
}

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var tab: UsageTab = .today
    @Published private var now: Date = Date()

    // Live values from UsageDataSource (~/.claude/usage-osd-cache.json),
    // written by the statusline hook on every Claude Code API response.
    // nil until the first real snapshot arrives — falls back to "—".
    @Published private var dailyPctValue: Double?
    @Published private var weeklyPctValue: Double?
    @Published private var dailyResetAt: Date?
    @Published private var weeklyResetAt: Date?
    @Published private var dailySpendValue: Double = 0
    @Published private var weeklySpendValue: Double = 0

    var dailyPct: Double { dailyPctValue ?? 0 }
    var weeklyPct: Double { weeklyPctValue ?? 0 }
    var hasDailyData: Bool { dailyPctValue != nil }
    var hasWeeklyData: Bool { weeklyPctValue != nil }

    var dailySpend: String { formatSpend(dailySpendValue) }
    var weeklySpend: String { formatSpend(weeklySpendValue) }

    private var clockTimer: Timer?
    private var pollTimer: Timer?
    private var lastCacheModDate: Date?

    func start() {
        refresh()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        clockTimer?.invalidate()
        clockTimer = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refresh() {
        let modDate = UsageDataSource.cacheModificationDate()
        guard modDate != lastCacheModDate else { return }
        lastCacheModDate = modDate

        guard let snapshot = UsageDataSource.load() else { return }
        dailyPctValue = snapshot.dailyPct
        weeklyPctValue = snapshot.weeklyPct
        dailyResetAt = snapshot.dailyResetAt
        weeklyResetAt = snapshot.weeklyResetAt
        dailySpendValue = snapshot.dailySpend
        weeklySpendValue = snapshot.weeklySpend
    }

    private func formatSpend(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    /// "Hh MMm SSs" countdown to the real 5-hour rate-limit reset (`resets_at`).
    var dailyResetLabel: String {
        guard let resetAt = dailyResetAt else { return "—" }
        return formatCountdown(to: resetAt, includeSeconds: true)
    }

    /// "Dd Hh MMm" countdown to the real 7-day rate-limit reset (`resets_at`).
    var weeklyResetLabel: String {
        guard let resetAt = weeklyResetAt else { return "—" }
        return formatCountdown(to: resetAt, includeSeconds: false)
    }

    private func formatCountdown(to date: Date, includeSeconds: Bool) -> String {
        let remaining = max(0, date.timeIntervalSince(now))
        let total = Int(remaining)
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if includeSeconds {
            return String(format: "%dh %02dm %02ds", h, m, s)
        }
        return String(format: "%dd %dh %02dm", d, h, m)
    }
}
