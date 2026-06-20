import Foundation

/// Reads the rate-limit / cost snapshot that `~/.claude/statusline-command.sh`
/// writes on every Claude Code statusline tick (see CLAUDE.md). This is the
/// only place Claude.ai subscription rate-limit data (`rate_limits.five_hour`,
/// `rate_limits.seven_day`) is exposed locally — there is no API for it.
struct UsageSnapshot {
    var dailyPct: Double?
    var dailyResetAt: Date?
    var weeklyPct: Double?
    var weeklyResetAt: Date?
    var dailySpend: Double
    var weeklySpend: Double
    var updatedAt: Date?
}

enum UsageDataSource {
    private static let cacheURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/usage-osd-cache.json")

    private static let eventsURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/usage-osd-events.jsonl")

    /// True once the cache file's mtime changes, so callers can skip re-parsing.
    static func cacheModificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: cacheURL.path))?[.modificationDate] as? Date
    }

    static func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        func pct(_ key: String) -> Double? {
            guard let window = json[key] as? [String: Any], let p = window["used_percentage"] as? Double else { return nil }
            return p / 100
        }
        func resetDate(_ key: String) -> Date? {
            guard let window = json[key] as? [String: Any], let epoch = window["resets_at"] as? Double else { return nil }
            return Date(timeIntervalSince1970: epoch)
        }
        let updatedAt = (json["updated_at"] as? Double).map { Date(timeIntervalSince1970: $0) }

        let (daily, weekly) = spendTotals()

        return UsageSnapshot(
            dailyPct: pct("five_hour"),
            dailyResetAt: resetDate("five_hour"),
            weeklyPct: pct("seven_day"),
            weeklyResetAt: resetDate("seven_day"),
            dailySpend: daily,
            weeklySpend: weekly,
            updatedAt: updatedAt
        )
    }

    /// Sums the latest cost seen per session within the last 24h / 7d.
    /// Cost in each event is the session's *cumulative* cost at that tick, so we
    /// take the max per session in-window rather than summing every line.
    private static func spendTotals() -> (daily: Double, weekly: Double) {
        guard let raw = try? String(contentsOf: eventsURL, encoding: .utf8) else { return (0, 0) }

        let now = Date().timeIntervalSince1970
        let dayCutoff = now - 86400
        let weekCutoff = now - 7 * 86400

        var maxCostPerSessionDay: [String: Double] = [:]
        var maxCostPerSessionWeek: [String: Double] = [:]

        for line in raw.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let ts = obj["ts"] as? Double,
                  let session = obj["session_id"] as? String,
                  let cost = obj["cost_usd"] as? Double else { continue }

            if ts >= weekCutoff {
                maxCostPerSessionWeek[session] = max(maxCostPerSessionWeek[session] ?? 0, cost)
            }
            if ts >= dayCutoff {
                maxCostPerSessionDay[session] = max(maxCostPerSessionDay[session] ?? 0, cost)
            }
        }

        return (maxCostPerSessionDay.values.reduce(0, +), maxCostPerSessionWeek.values.reduce(0, +))
    }
}
