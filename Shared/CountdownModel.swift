import Foundation

/// Remaining time broken into days/hours/minutes toward a target date.
/// This is the model the widget renders.
struct Countdown: Equatable {
    let days: Int
    let hours: Int
    let minutes: Int
    let isPast: Bool

    /// Compact days-first label, e.g. "3d", "5h", "42m", or "now" if elapsed.
    var shortText: String {
        if isPast { return "now" }
        if days > 0 { return "\(days)d" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}

enum CountdownCalculator {
    /// Pure function: time remaining from `now` to `target`.
    /// Fully testable — no `Date()` side effects unless the caller omits `now`.
    static func remaining(to target: Date, from now: Date = Date()) -> Countdown {
        let interval = target.timeIntervalSince(now)
        guard interval > 0 else {
            return Countdown(days: 0, hours: 0, minutes: 0, isPast: true)
        }
        let totalMinutes = Int(interval / 60)
        return Countdown(
            days: totalMinutes / (60 * 24),
            hours: (totalMinutes % (60 * 24)) / 60,
            minutes: totalMinutes % 60,
            isPast: false
        )
    }
}

/// Stable, occurrence-aware identifier for an event.
///
/// EventKit's `eventIdentifier` is shared across all occurrences of a recurring
/// event, so it alone can't distinguish "this Monday" from "next Monday". We
/// pair it with the occurrence start time to get a unique, stable id we can
/// round-trip through App Intents.
enum EventID {
    private static let separator: Character = "|"

    static func make(identifier: String, start: Date) -> String {
        "\(identifier)\(separator)\(Int(start.timeIntervalSince1970))"
    }

    /// Splits on the *last* separator so identifiers containing the separator
    /// still parse (the trailing epoch-seconds field is unambiguous).
    static func parse(_ id: String) -> (identifier: String, start: Date)? {
        guard let index = id.lastIndex(of: separator) else { return nil }
        let identifier = String(id[..<index])
        let secondsText = String(id[id.index(after: index)...])
        guard !identifier.isEmpty, let seconds = TimeInterval(secondsText) else { return nil }
        return (identifier, Date(timeIntervalSince1970: seconds))
    }
}

#if DEBUG
extension EventID {
    /// Runnable self-check for the composite id round-trip and recurrence split.
    static func demo() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let id = make(identifier: "ABC-123", start: start)
        let parsed = parse(id)
        assert(parsed?.identifier == "ABC-123", "identifier round-trip: \(String(describing: parsed))")
        assert(parsed?.start == start, "date round-trip: \(String(describing: parsed))")

        // Malformed input must fail gracefully.
        assert(parse("no-separator") == nil, "missing separator should be nil")
        assert(parse("|123") == nil, "empty identifier should be nil")

        // Two occurrences of the same recurring event must not collide.
        let occ1 = make(identifier: "REC", start: Date(timeIntervalSince1970: 1_000))
        let occ2 = make(identifier: "REC", start: Date(timeIntervalSince1970: 2_000))
        assert(occ1 != occ2, "recurring occurrences must differ")

        print("[EventID.demo] all checks passed")
    }
}

extension CountdownCalculator {
    /// Runnable self-check for the date math. Called on app launch in DEBUG.
    /// Uses `assert`, so a wrong result traps the debug build immediately.
    static func demo() {
        let base = Date(timeIntervalSince1970: 1_000_000)

        // 3d 4h 5m ahead
        let a = remaining(to: base.addingTimeInterval(3 * 86400 + 4 * 3600 + 5 * 60), from: base)
        assert(a.days == 3 && a.hours == 4 && a.minutes == 5, "d/h/m math: \(a)")
        assert(a.shortText == "3d", "days-only with days: \(a.shortText)")
        assert(!a.isPast)

        // under a day falls back to hours: 5h 30m -> "5h"
        let b = remaining(to: base.addingTimeInterval(5 * 3600 + 30 * 60), from: base)
        assert(b.shortText == "5h", "under a day shows hours: \(b.shortText)")

        // minutes only: 42m
        let c = remaining(to: base.addingTimeInterval(42 * 60), from: base)
        assert(c.days == 0 && c.hours == 0 && c.minutes == 42, "minutes math: \(c)")
        assert(c.shortText == "42m", "shortText minutes: \(c.shortText)")

        // elapsed target
        let d = remaining(to: base.addingTimeInterval(-60), from: base)
        assert(d.isPast && d.shortText == "now", "past: \(d)")

        print("[CountdownCalculator.demo] all checks passed")
    }
}
#endif

/// Decides how often the widget timeline should refresh, based on how close the
/// nearest shown event is. Closer events get finer granularity so the minute
/// countdown stays alive; distant ones refresh lazily to save battery.
enum RefreshPlanner {
    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 86_400

    /// Seconds between timeline entries for the given nearest event.
    /// - `nil` (no events) → hourly.
    static func interval(toNearest target: Date?, from now: Date = Date()) -> TimeInterval {
        guard let target else { return hour }
        let remaining = target.timeIntervalSince(now)
        if remaining < hour { return 60 }        // < 1h  → every minute
        if remaining < day { return 15 * 60 }    // < 1d  → every 15 min
        return hour                              // farther → hourly
    }
}

#if DEBUG
extension RefreshPlanner {
    /// Runnable self-check for the threshold branches (boundaries included).
    static func demo() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func at(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(seconds) }

        assert(interval(toNearest: nil, from: now) == hour, "no events → hourly")

        // < 1h boundary
        assert(interval(toNearest: at(30 * 60), from: now) == 60, "30m → 1min")
        assert(interval(toNearest: at(hour - 1), from: now) == 60, "just under 1h → 1min")
        assert(interval(toNearest: at(hour), from: now) == 15 * 60, "exactly 1h → 15min")

        // < 1 day boundary
        assert(interval(toNearest: at(5 * hour), from: now) == 15 * 60, "5h → 15min")
        assert(interval(toNearest: at(day - 1), from: now) == 15 * 60, "just under 1d → 15min")
        assert(interval(toNearest: at(day), from: now) == hour, "exactly 1d → hourly")
        assert(interval(toNearest: at(10 * day), from: now) == hour, "far → hourly")

        // already elapsed → refresh fast
        assert(interval(toNearest: at(-60), from: now) == 60, "past → 1min")

        print("[RefreshPlanner.demo] all checks passed")
    }
}
#endif
