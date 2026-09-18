import AppIntents
import CoreGraphics
import EventKit
import Foundation

// MARK: - Calendar entity (used only as a FILTER for the event picker)
//
// Options come from EventStore. Title = calendar name, subtitle = account
// (source.title), so the user recognizes Work / iCloud / Google, etc.

struct CalendarEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Calendar")
    static var defaultQuery = CalendarQuery()

    let id: String       // EKCalendar.calendarIdentifier
    let name: String
    let account: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(account)")
    }
}

struct CalendarQuery: EntityQuery {
    func entities(for identifiers: [CalendarEntity.ID]) async throws -> [CalendarEntity] {
        let wanted = Set(identifiers)
        return allCalendars().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CalendarEntity] {
        allCalendars()
    }

    private func allCalendars() -> [CalendarEntity] {
        EventStore.shared.calendarAccounts().flatMap { account in
            account.calendars.map {
                CalendarEntity(id: $0.calendarIdentifier, name: $0.title, account: account.title)
            }
        }
    }
}

// MARK: - Event entity
//
// The real selection. Each event carries its own calendar (color, name,
// account) so a widget can mix events from different calendars/accounts.

struct EventEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Event")
    static var defaultQuery = EventQuery()

    let id: String              // composite EventID (identifier + occurrence start)
    let title: String
    let date: Date
    let calendarName: String
    let accountName: String
    let calendarColor: CGColor

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(date.formatted(date: .abbreviated, time: .shortened)) · \(calendarName) · \(accountName)"
        )
    }

    init(item: EventItem) {
        self.id = item.id
        self.title = item.title
        self.date = item.startDate
        self.calendarName = item.calendarName
        self.accountName = item.accountName
        self.calendarColor = item.calendarColor
    }

    /// Back to the shared render model used by the widget views.
    var eventItem: EventItem {
        EventItem(
            id: id,
            title: title,
            startDate: date,
            calendarColor: calendarColor,
            calendarName: calendarName,
            accountName: accountName
        )
    }
}

/// Chained + searchable query for the event picker.
///
/// - Suggestions are FILTERED by the chosen `calendarFilter` (chaining).
/// - `entities(for:)` resolves ids GLOBALLY across all calendars, so a mixed
///   selection (events from different calendars) always re-materializes even
///   when the filter currently points at another calendar.
struct EventQuery: EntityStringQuery {
    @IntentParameterDependency<SelectEventsIntent>(\.$calendarFilter)
    var selection

    func entities(for identifiers: [EventEntity.ID]) async throws -> [EventEntity] {
        let wanted = Set(identifiers)
        return EventStore.shared.allFutureEvents()
            .filter { wanted.contains($0.id) }
            .map(EventEntity.init(item:))
    }

    func entities(matching string: String) async throws -> [EventEntity] {
        filteredPool()
            .filter { $0.title.localizedCaseInsensitiveContains(string) }
            .map(EventEntity.init(item:))
    }

    func suggestedEntities() async throws -> [EventEntity] {
        filteredPool().map(EventEntity.init(item:))
    }

    /// Future events restricted to the chosen calendar, or all of them if no
    /// filter is set (so the user can still browse/search everything).
    private func filteredPool() -> [EventItem] {
        if let calendarID = selection?.calendarFilter.id {
            return EventStore.shared.futureEvents(forCalendarID: calendarID)
        }
        return EventStore.shared.allFutureEvents()
    }
}

// MARK: - Widget configuration intent

struct SelectEventsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Events"
    static var description = IntentDescription("Pick a calendar, then its events. Repeat with another calendar to mix events from different accounts.")

    // Filter only: narrows the event picker. Not rendered by the widget.
    @Parameter(title: "Calendar")
    var calendarFilter: CalendarEntity?

    // The real selection (up to 7, shown per family). May mix calendars.
    @Parameter(title: "Events")
    var events: [EventEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$calendarFilter
            \.$events
        }
    }
}
