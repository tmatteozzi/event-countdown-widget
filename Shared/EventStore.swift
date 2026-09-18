import CoreGraphics
import EventKit
import WidgetKit

/// A calendar "account" — a group of calendars under one EventKit source
/// (iCloud, Google, On My Mac, etc.). `source.title` is the account name.
struct CalendarAccount: Identifiable {
    let id: String
    var title: String { id }
    let calendars: [EKCalendar]
}

/// A lightweight, UI-facing snapshot of a calendar event. Keeps `EKEvent` out
/// of the views (only the fields we need, all value types).
struct EventItem: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let calendarColor: CGColor
    let calendarName: String
    let accountName: String
}

/// Minimal shared wrapper around `EKEventStore`.
///
/// Compiled into *both* the app and the widget targets. Exposes calendar access
/// requests, calendars grouped by account, and future-event queries, and
/// reloads the widgets whenever the calendar database changes.
final class EventStore {
    /// Shared singleton.
    static let shared = EventStore()

    /// The underlying EventKit store.
    let store = EKEventStore()

    /// Called on the main queue when the calendar database changes, so the app's
    /// own UI can refresh. (The widgets are reloaded independently below.)
    var onStoreChanged: (() -> Void)?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            // Calendar data changed (event added/moved/deleted): rebuild widgets.
            WidgetCenter.shared.reloadAllTimelines()
            self?.onStoreChanged?()
        }
    }

    // MARK: - Permission

    /// Current calendar authorization status.
    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Requests full access to calendar events (macOS 14+).
    /// - Returns: `true` if full access was granted.
    @discardableResult
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    // MARK: - Calendars

    /// All event calendars grouped by account (`source.title`), sorted.
    func calendarAccounts() -> [CalendarAccount] {
        let grouped = Dictionary(grouping: store.calendars(for: .event)) { $0.source.title }
        return grouped
            .map { key, calendars in
                CalendarAccount(id: key, calendars: calendars.sorted { $0.title < $1.title })
            }
            .sorted { $0.title < $1.title }
    }

    // MARK: - Events

    /// Future events in a calendar, from now up to `years` ahead, ascending.
    /// - Parameters:
    ///   - calendar: the calendar to query.
    ///   - years: how far into the future to look (default 2).
    func futureEvents(in calendar: EKCalendar, years: Int = 2) -> [EventItem] {
        let now = Date()
        let end = Calendar.current.date(byAdding: .year, value: years, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: [calendar])
        return store.events(matching: predicate)
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                EventItem(
                    id: EventID.make(identifier: event.eventIdentifier ?? UUID().uuidString, start: event.startDate),
                    title: event.title ?? "(untitled)",
                    startDate: event.startDate,
                    calendarColor: event.calendar.cgColor,
                    calendarName: event.calendar.title,
                    accountName: event.calendar.source.title
                )
            }
    }

    /// The event calendar with the given identifier, if any.
    func calendar(withID id: String) -> EKCalendar? {
        store.calendars(for: .event).first { $0.calendarIdentifier == id }
    }

    /// Future events for a calendar identified by id (empty if not found).
    func futureEvents(forCalendarID id: String, years: Int = 2) -> [EventItem] {
        guard let calendar = calendar(withID: id) else { return [] }
        return futureEvents(in: calendar, years: years)
    }

    /// Future events across every event calendar, ascending.
    func allFutureEvents(years: Int = 2) -> [EventItem] {
        store.calendars(for: .event)
            .flatMap { futureEvents(in: $0, years: years) }
            .sorted { $0.startDate < $1.startDate }
    }
}
