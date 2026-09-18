# ⏳ Event Countdown Widget

A native **macOS app** that shows live countdowns to your Mac Calendar events in
desktop / Notification Center **widgets** — built entirely with Apple frameworks,
no external dependencies.

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-black)
![swift](https://img.shields.io/badge/Swift-SwiftUI-orange)
![frameworks](https://img.shields.io/badge/deps-Apple%20frameworks%20only-blue)
![license](https://img.shields.io/badge/license-MIT-green)

Each widget is configured individually (right-click → **Edit widget**): pick a
calendar to filter by, then choose the specific events you want to track. A
single widget can mix events from different calendars and accounts. The
countdown is shown compactly as days remaining (e.g. `3d`, and `5h` / `42m` when
an event is under a day away).

---

## ✨ Features

- 🗓️ Live countdowns to your **Mac Calendar events**, straight from EventKit.
- 🧩 **Per-widget configuration** — filter by calendar, then pick the exact events to track.
- 🔀 A single widget can **mix events from different calendars and accounts**.
- ⏱️ Compact countdown that tightens as the event nears: `3d` → `5h` → `42m`.
- 🎨 Rows show each **calendar's color**, and the widget adapts to **light & dark mode**.
- 🪶 **Zero third-party libraries** — Swift · SwiftUI · WidgetKit · App Intents · EventKit.

---

## 📐 Widget sizes

| Size   | Shows                                                        |
|--------|-------------------------------------------------------------|
| Small  | One event: big countdown, title, and date.                  |
| Medium | Up to 3 events as rows, evenly distributed.                 |
| Large  | Up to 7 events as rows, evenly distributed.                 |

Each row shows the calendar's color, the event title and date, and the
countdown.

---

## 🧱 Stack

Swift · SwiftUI · WidgetKit · App Intents · EventKit. All system frameworks,
zero third-party libraries.

---

## ✅ Requirements

| Requirement | Notes |
|---|---|
| **macOS 14 or later** | EventKit full access + App Intents for widgets. |
| **Xcode 15 or later** | To build the app and widget extension. |
| **Apple Developer account** | A free one works for personal use — needed to sign the app and widget extension. |

---

## 🚀 Build & run

1. Clone the repo:
   ```sh
   git clone https://github.com/tmatteozzi/event-countdown-widget.git
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

---

## ⚙️ Configuration (change these to your own)

The project ships with these bundle identifiers. A contributor signing with
their own Team should change them to unique values:

| What              | Value                                   | Where                                 |
|-------------------|-----------------------------------------|---------------------------------------|
| App bundle ID     | `com.tmatteozzi.eventcountdown`         | EventCountdown target build settings  |
| Widget bundle ID  | `com.tmatteozzi.eventcountdown.widget`  | CountdownWidget target build settings |

For example, replace `tmatteozzi` with your own identifier:

```
com.tmatteozzi.eventcountdown         →  com.yourname.eventcountdown
com.tmatteozzi.eventcountdown.widget  →  com.yourname.eventcountdown.widget
```

---

## 📝 Behavior notes

- Closing the main window (red button) quits the app. Widgets you've added keep
  working and updating on their own — the app only needs to run to browse events
  and configure widgets.
- Widget timelines refresh at a granularity that adapts to how soon the nearest
  shown event is: **per-minute** under an hour away, **every 15 min** under a day,
  and **hourly** when farther off.

---

## 🗑️ Uninstall

There is no in-app uninstall. Remove the app manually:

1. Quit the app, then drag `Event Countdown.app` from `/Applications` to the
   Trash.
2. The app's own data lives in its sandbox container. Deleting that folder
   removes its preferences, caches, and temporary files:
   ```sh
   rm -rf ~/Library/Containers/com.tmatteozzi.eventcountdown
   ```

> [!NOTE]
> A couple of things are deliberately left untouched:
> - **Your Calendar events are not affected.** They live in EventKit / your
>   Calendar, not in this app.
> - **Widget configuration is managed by the system (WidgetKit), not the app** —
>   the app can't remove it. To clear it, remove the widget from the widget
>   editing view in Notification Center.

---

## 🗂️ Project layout

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

---

## 📄 License

[MIT](LICENSE).
