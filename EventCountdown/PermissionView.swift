import EventKit
import SwiftUI

/// Onboarding view: asks for EventKit full access and reports status. Once
/// access is granted it shows `CalendarBrowserView`, the app's main window.
struct PermissionView: View {
    @State private var status = EventStore.shared.authorizationStatus

    var body: some View {
        Group {
            if status == .fullAccess {
                CalendarBrowserView()
            } else {
                prompt
            }
        }
    }

    private var prompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Event Countdown")
                .font(.title.bold())

            Text(statusMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Calendar Access") {
                Task {
                    await EventStore.shared.requestAccess()
                    status = EventStore.shared.authorizationStatus
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 360)
    }

    private var statusMessage: String {
        switch status {
        case .fullAccess:
            return "Calendar access granted."
        case .denied, .restricted:
            return "Access denied. Enable it in System Settings › Privacy & Security › Calendars."
        case .notDetermined:
            return "This app needs access to your calendar to show event countdowns."
        case .writeOnly:
            return "Only write access was granted. Full access is required."
        @unknown default:
            return "Unknown authorization status."
        }
    }
}

/// Main window, styled after the macOS Stocks app: a translucent
/// `NavigationSplitView` sidebar (searchable list of calendars) and a detail
/// pane with a large "Upcoming Events" title over glass event cards.
struct CalendarBrowserView: View {
    private let accounts = EventStore.shared.calendarAccounts()
    @State private var selectedID: String?          // EKCalendar.calendarIdentifier
    @State private var events: [EventItem] = []
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if selectedID == nil {
                selectedID = accounts.first?.calendars.first?.calendarIdentifier
            }
            loadEvents()
        }
        .onChange(of: selectedID) { _, _ in loadEvents() }
    }

    // MARK: Sidebar — native translucent list (Liquid Glass material).

    private var sidebar: some View {
        List(selection: $selectedID) {
            ForEach(accounts) { account in
                let calendars = filteredCalendars(account)
                if !calendars.isEmpty {
                    Section(account.title) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            Label {
                                Text(calendar.title)
                            } icon: {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 10, height: 10)
                            }
                            .tag(calendar.calendarIdentifier)
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendars")
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search calendars")
    }

    private func filteredCalendars(_ account: CalendarAccount) -> [EKCalendar] {
        guard !searchText.isEmpty else { return account.calendars }
        return account.calendars.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: Detail — big title over glass event cards (Stocks-style).

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Upcoming Events")
                .font(.largeTitle.bold())
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 14)
            eventList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var eventList: some View {
        if events.isEmpty {
            ContentUnavailableView("No upcoming events", systemImage: "calendar")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(events) { event in
                        eventCard(event)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func eventCard(_ event: EventItem) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 5, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
                Text(event.startDate, format: .dateTime.weekday(.wide).day().month().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(CountdownCalculator.remaining(to: event.startDate).shortText)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Color(cgColor: event.calendarColor))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loadEvents() {
        guard let id = selectedID else { events = []; return }
        events = EventStore.shared.futureEvents(forCalendarID: id)
    }
}

#Preview {
    PermissionView()
}
