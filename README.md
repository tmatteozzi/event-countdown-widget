# Event Countdown Widget

A native macOS app that shows live countdowns to your Mac Calendar events in
desktop / Notification Center widgets. Built entirely with Apple frameworks — no
external dependencies.

Each widget is configured individually (right-click → **Edit widget**): pick a
calendar to filter by, then choose the specific events you want to track. A
single widget can mix events from different calendars and accounts. The
countdown is shown compactly as days remaining (e.g. `3d`, and `5h` / `42m` when
an event is under a day away).

## Widget sizes

| Size   | Shows                                                        |
|--------|-------------------------------------------------------------|
| Small  | One event: big countdown, title, and date.                  |
| Medium | Up to 3 events as rows, evenly distributed.                |
| Large  | Up to 7 events as rows, evenly distributed.                 |

Each row shows the calendar's color, the event title and date, and the
countdown. Colors follow the source calendar, and the widget adapts to light and
dark mode.

## Stack

Swift · SwiftUI · WidgetKit · App Intents · EventKit. All system frameworks,
zero third-party libraries.

## Requirements

- macOS 14 or later (EventKit full access + App Intents for widgets).
- Xcode 15 or later.
- An Apple Developer account (a free one works for personal use) to sign the app
  and widget extension.

## Build & run (developers)

1. Clone the repo:
   ```sh
   git clone <this-repo-url>
   cd event-countdown-widget
   ```
2. Open `EventCountdown.xcodeproj` in Xcode.
3. Set your signing team: select the project → **EventCountdown** target →
   **Signing & Capabilities** → check *Automatically manage signing* and pick your
   own **Team**. Repeat for the **CountdownWidget** target. You will likely also
   need to change the bundle identifiers to something unique to you (see below).
4. Press **Cmd+R**. The app launches and asks for Calendar access. Grant it, then
   add the widget from the desktop / Notification Center and configure it via
   right-click → **Edit widget**.

## Configuration (change these to your own)

The bundle identifiers ship as placeholders so the project builds out of the
box. A contributor signing with their own Team should change them to unique
values:

| What              | Value                                | Where                                 |
|-------------------|--------------------------------------|---------------------------------------|
| App bundle ID     | `com.example.eventcountdown`         | EventCountdown target build settings  |
| Widget bundle ID  | `com.example.eventcountdown.widget`  | CountdownWidget target build settings |

For example, replace `example` with your own identifier:

```
com.example.eventcountdown         →  com.tmatteozzi.eventcountdown
com.example.eventcountdown.widget  →  com.tmatteozzi.eventcountdown.widget
```

## Behavior notes

- Closing the main window (red button) hides it and keeps the app running in the
  background, Reminders-style; clicking the Dock icon brings the same window back.
- Widget timelines refresh at a granularity that adapts to how soon the nearest
  shown event is (per-minute when it's under an hour away, hourly when far off).

## Uninstall

There is no in-app uninstall. Remove the app manually:

1. Quit the app, then drag `Event Countdown.app` from `/Applications` to the
   Trash.
2. The app's own data lives in its sandbox container. Deleting that folder
   removes its preferences, caches, and temporary files:
   ```sh
   rm -rf ~/Library/Containers/com.tmatteozzi.eventcountdown
   ```

A couple of things are deliberately left untouched:

- **Your Calendar events are not affected.** They live in EventKit / your
  Calendar, not in this app.
- **Widget configuration is managed by the system (WidgetKit), not the app** —
  the app can't remove it. To clear it, remove the widget from the widget
  editing view in Notification Center.

## Project layout

```
EventCountdown/                app (host) target
  EventCountdownApp.swift         @main app entry + AppDelegate (hide-on-close)
  PermissionView.swift            Calendar permission + main browser window
  Info.plist                      NSCalendarsUsageDescription
  EventCountdown.entitlements     sandbox + Calendars
CountdownWidget/               widget extension target
  CountdownWidget.swift           widget views, provider, and timeline
  SelectEventsIntent.swift        App Intent for per-widget event selection
  Info.plist                      widgetkit extension point
  CountdownWidget.entitlements    sandbox + Calendars
Shared/
  EventStore.swift                EKEventStore wrapper (shared by both targets)
  CountdownModel.swift            countdown math, event id, refresh planner
EventCountdown.xcodeproj       the Xcode project
```

## License

[MIT](LICENSE).
</content>
</invoke>
