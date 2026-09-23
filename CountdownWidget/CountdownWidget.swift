import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Sample data
//
// Used only for SwiftUI previews, the widget placeholder, and the widget
// gallery snapshot. At runtime the widget renders the user's real selection
// (see CountdownProvider). Events are relative to `now` so the countdowns stay
// meaningful in previews.

private enum SampleData {
    static var events: [EventItem] {
        let now = Date()
        func offset(days: Double, hours: Double = 0) -> Date {
            now.addingTimeInterval(days * 86_400 + hours * 3_600)
        }
        func item(_ id: String, _ title: String, _ start: Date, _ color: CGColor,
                  _ calendar: String, _ account: String) -> EventItem {
            EventItem(id: id, title: title, startDate: start, calendarColor: color,
                      calendarName: calendar, accountName: account)
        }
        return [
            item("1", "Team Standup", offset(days: 0, hours: 3), CGColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1), "Work", "Google"),
            item("2", "Dentist", offset(days: 1, hours: 5), CGColor(red: 0.30, green: 0.78, blue: 0.45, alpha: 1), "Personal", "iCloud"),
            item("3", "Flight to NYC", offset(days: 3, hours: 4), CGColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 1), "Travel", "iCloud"),
            item("4", "Mom's Birthday", offset(days: 8), CGColor(red: 0.90, green: 0.30, blue: 0.55, alpha: 1), "Family", "iCloud"),
            item("5", "Project Deadline", offset(days: 14), CGColor(red: 0.60, green: 0.40, blue: 0.90, alpha: 1), "Work", "Google"),
            item("6", "Conference", offset(days: 30), CGColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 1), "Work", "Google"),
            item("7", "Vacation", offset(days: 60), CGColor(red: 0.20, green: 0.70, blue: 0.75, alpha: 1), "Personal", "iCloud"),
        ]
    }
}

/// How many events a given widget family shows.
private func maxEvents(for family: WidgetFamily) -> Int {
    switch family {
    case .systemSmall: return 1
    case .systemMedium: return 3
    case .systemLarge: return 7
    default: return 3
    }
}

// MARK: - Timeline

struct CountdownEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: Date(), events: SampleData.events)
    }

    func snapshot(for configuration: SelectEventsIntent, in context: Context) async -> CountdownEntry {
        // The widget gallery preview looks best with sample data; the real
        // snapshot reflects the user's selection.
        let events = context.isPreview ? SampleData.events : resolvedEvents(from: configuration)
        return CountdownEntry(date: Date(), events: events)
    }

    func timeline(for configuration: SelectEventsIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let events = resolvedEvents(from: configuration)
        let now = Date()

        // Granularity adapts to the nearest shown event (events are sorted
        // ascending, so the first one is the nearest regardless of family cap).
        let interval = RefreshPlanner.interval(toNearest: events.first?.startDate, from: now)

        // A bounded batch forward; `.atEnd` makes WidgetKit re-request (and
        // recompute the interval) once it runs out.
        let entryCount = 12
        var entries = (0..<entryCount).map { step in
            CountdownEntry(date: now.addingTimeInterval(Double(step) * interval), events: events)
        }

        // Days are calendar days, so the count must flip exactly at midnight
        // rather than at the next regular step.
        let calendar = Calendar.current
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           let last = entries.last?.date, midnight < last {
            entries.append(CountdownEntry(date: midnight, events: events))
            entries.sort { $0.date < $1.date }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Resolves the intent's selected events into render models: drops events
    /// that already passed or no longer resolve, sorted by soonest first.
    /// (The per-family cap is applied by the views via `maxEvents(for:)`.)
    private func resolvedEvents(from configuration: SelectEventsIntent) -> [EventItem] {
        let now = Date()
        return (configuration.events ?? [])
            .map(\.eventItem)
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Views

/// Single big centered countdown — `systemSmall`.
private struct SmallCountdownView: View {
    let event: EventItem
    let now: Date

    var body: some View {
        let countdown = CountdownCalculator.remaining(to: event.startDate, from: now)
        VStack(alignment: .leading, spacing: 4) {
            Circle()
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 8, height: 8)
            Spacer(minLength: 0)
            Text(countdown.shortText)
                .font(.system(size: 34, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .widgetAccentable()
            Text(event.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Text(event.startDate, format: .dateTime.weekday(.abbreviated).day().month())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// One event row, reused by `systemMedium` and `systemLarge`.
private struct EventRow: View {
    let event: EventItem
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(event.startDate, format: .dateTime.weekday(.abbreviated).day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(CountdownCalculator.remaining(to: event.startDate, from: now).shortText)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(cgColor: event.calendarColor))
                .widgetAccentable()
        }
    }
}

/// Vertical list of rows — `systemMedium` (3) and `systemLarge` (7).
private struct EventListView: View {
    let events: [EventItem]
    let now: Date
    let maxRows: Int

    var body: some View {
        // Stocks-style even distribution: a flexible spacer BETWEEN each row
        // spreads them across the full height (first row pinned top, last row
        // pinned bottom, equal gaps in between) instead of clumping at the top.
        let rows = Array(events.prefix(maxRows))
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, event in
                EventRow(event: event, now: now)
                if index < rows.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 2)
    }
}

/// Native-style empty state (shown when there are no events to display).
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No events")
                .font(.caption).bold()
                .foregroundStyle(.secondary)
            // WidgetKit doesn't let a widget open its own configuration sheet;
            // it's only reachable via right-click → Edit widget. So the empty
            // state guides the user there instead of trying to open it.
            Text("Right-click → Edit Widget")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CountdownWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: CountdownEntry

    var body: some View {
        Group {
            if entry.events.isEmpty {
                EmptyStateView()
            } else if family == .systemSmall {
                SmallCountdownView(event: entry.events[0], now: entry.date)
            } else {
                EventListView(events: entry.events, now: entry.date, maxRows: maxEvents(for: family))
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectEventsIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Shows countdowns to your upcoming events.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct CountdownWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, events: SampleData.events)
}

#Preview("Medium", as: .systemMedium) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, events: SampleData.events)
}

#Preview("Large", as: .systemLarge) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, events: SampleData.events)
}
