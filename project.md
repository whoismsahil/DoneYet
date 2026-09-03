# Done Yet? — Comprehensive Project Documentation

## 1. Executive Summary & Core Philosophy

**Done Yet?** is a high-utility, minimalist native iOS reminder and habit-tracking application built with modern Swift and SwiftUI. 

### Core Product Philosophy
- **Frictionless Completion:** Completing a task should require zero navigation and zero unnecessary taps. Users can complete reminders directly from their Home Screen via **iOS 17+ Interactive Widgets** without opening the main app.
- **Bold Typography & Editorial Aesthetics:** Employs high-contrast design, clean SF Mono action labels (e.g. `DONE YET?`, `LOCKED ✓`), custom pet companions, and customizable widget themes.
- **Intelligent Recurrence:** Supports flexible repeating schedules (Daily, Weekly, Monthly, Yearly, and Custom intervals/weekdays) as well as one-off tasks with exact date/time scheduling.
- **Rich History & Archival:** Past completions are preserved cleanly in a permanent `CompletionRecord` archive without polluting active tasks.

---

## 2. Technical Architecture & Tech Stack

| Domain | Technology / Framework | Details |
| :--- | :--- | :--- |
| **Language & Concurrency** | Swift 6.3.3 | Concurrency-safe `@MainActor` services, `async/await`, structured concurrency |
| **UI Framework** | SwiftUI (iOS 17.0+) | Declarative views, `@Observable` macro view models, custom transitions |
| **Data Persistence** | SwiftData (`@Model`) | Native SQLite storage backed by shared App Group container |
| **Widgets** | WidgetKit & App Intents | Interactive home screen widgets, dynamic timeline generation, interactive completion intents |
| **Notifications** | UserNotifications framework | Local notification scheduling, background alerts, delegate handling |
| **Monetization** | StoreKit 2 | In-App Purchases (`PurchaseService`), non-consumable lifetime & subscription plans |
| **Inter-Process Sync** | App Groups (`group.com.doneyet.app`) | Atomic JSON state sharing & shared SQLite SwiftData store between App & Widget Extension |

### Project Directory Structure

```
Done Yet? - 2/
├── Done Yet?/                     # Main App Target
│   ├── App/                       # Entry point, AppSchema, RootView, AppNavigation
│   ├── Models/                    # SwiftData Models (Reminder, CompletionRecord, RepeatType)
│   ├── Services/                  # Business logic (ReminderService, RecurrenceService, NotificationService, PurchaseService, SharedWidgetStore, AppearanceManager)
│   ├── Features/                  # UI Feature Modules
│   │   ├── Home/                  # Main active reminder list & filter bar
│   │   ├── ReminderEditor/        # Creation/editing flow with custom emoji picker
│   │   ├── History/               # Completed reminder archive & batch management
│   │   ├── Search/                # Global search across reminders & history
│   │   ├── Settings/              # Appearance, notifications status, widget themes, paywall trigger
│   │   └── Pro/                   # Paywall UI & feature showcase
│   ├── DesignSystem/              # AppColors, AppTypography, AppFont, FluentCheckmark, WidgetFace, Pets
│   └── Assets.xcassets            # Icons & color sets
│
├── DoneYetWidget/                 # Widget Extension Target
│   ├── DoneYetWidget.swift        # Widget configuration entry point
│   ├── DoneYetWidgetProvider.swift# WidgetKit timeline provider & entry construction
│   ├── DoneYetWidgetViews.swift   # Canvas rendering for Small/Medium/Large widget sizes
│   ├── CompleteReminderIntent.swift# App Intent handling tap-to-complete actions
│   ├── SelectReminderIntent.swift # Configurable intent for selecting target reminder
│   └── PokePetIntent.swift        # Interactive pet animation intent
│
└── IMPLEMENTATION_PLAN.md         # Historical phase roadmap
```

---

## 3. Data Models

### 3.1 `Reminder` (`@Model`)
Represents an active or paused reminder.
- **`id`**: `UUID`
- **`title`**: Task description (e.g. *"Locking the door"*).
- **`completionButtonText`**: Label shown on interactive widget (default: `"DONE YET?"`).
- **`isRepeating` / `repeatType`**: Recurrence rules (`never`, `everyDay`, `everyWeek`, `everyMonth`, `everyYear`, `custom`).
- **`repeatInterval` & `weekdays`**: Custom repetition configuration (e.g., every 3 days, or on M/W/F).
- **`reminderHour` & `reminderMinute`**: Scheduled alert time.
- **`scheduledDate`**: Target date for one-off or yearly tasks.
- **`lastCompletedAt` & `nextOccurrence`**: Tracking current cycle completion and future fire date.
- **`iconEmoji` & `showsIconOnWidget`**: Custom visual identifier and widget display preference.
- **`isActive`**: Toggle for active vs. paused reminders.

### 3.2 `CompletionRecord` (`@Model`)
Permanent completion history entry created whenever a task is completed.
- Captures snapshots of title, button text, repeat rules, scheduled dates, and exact completion timestamp (`completedAt`).

### 3.3 `WidgetReminder` (`Codable`)
A lightweight snapshot model serialized to JSON in the shared App Group directory.
- Enables WidgetKit extensions to render reminder state instantly without requiring a heavy SwiftData context initialization or database lock.

---

## 4. Recurrence & Completion Pipeline

### Recurrence Calculation (`RecurrenceService`)
Calculates next valid dates based on calendar mechanics, handling:
- **Daily / Weekly / Monthly / Yearly**: Automatic offset calculations.
- **Custom Intervals**: N-day spacing from last completion or creation date.
- **Custom Weekdays**: Scans forward to the next scheduled weekday index (1–7).
- **Timezone & DST Awareness**: Relies on standard `Calendar` arithmetic to maintain scheduled time across daylight savings transitions.

### Shared Completion Flow
Whether initiated inside the main app UI or via `CompleteWidgetReminderIntent`:
1. Find target `Reminder` record.
2. If non-repeating (one-off):
   - Record `CompletionRecord` snapshot.
   - Set `isActive = false` and `nextOccurrence = nil`.
   - Cancel scheduled notifications.
3. If repeating:
   - Record `lastCompletedAt = now`.
   - Calculate and set `nextOccurrence` via `RecurrenceService`.
   - Reschedule local notification for the new fire date.
4. Save SwiftData model context.
5. Write updated `WidgetReminder` list to App Group JSON (`SharedWidgetStore`).
6. Call `WidgetCenter.shared.reloadTimelines(ofKind: "DoneYetWidget")`.

---

## 5. Interactive WidgetKit Extension (`DoneYetWidget`)

The widget target (`DoneYetWidget`) provides dynamic Home Screen elements:

- **App Intents:**
  - `CompleteWidgetReminderIntent`: Handles tap actions directly on the widget button. Runs shared completion pipeline and reloads timeline.
  - `SelectReminderIntent`: Allows users to long-press the widget and select a specific reminder to feature.
  - `PokeWidgetPetIntent`: Interactive pet sprite trigger (animates pet upon tap).
- **Widget Sizes Supported:**
  - **Small (SystemSmall)**: Compact view featuring title, checkmark, pet, and action button.
  - **Medium (SystemMedium)**: Extended horizontal view with schedule previews.
  - **Large (SystemLarge)**: Full editorial layout with larger typography and pet motion.
- **Dynamic Styling & Palette Sync:**
  - Automatically matches color schemes based on the selected `iconEmoji` or custom `WidgetTheme` (e.g. Willow).

---

## 6. App Features Breakdown

### 6.1 Home Screen (`HomeView`)
- Displays active reminders categorized with customizable horizontal filter tabs (`All`, `Noting`, `Daily`, `Weekly`, `Monthly`, `Yearly`, `Custom`, `Paused`).
- Supports swipe actions for **Edit**, **Pause/Resume**, and **Delete**.
- Context menus for quick management.
- Toast feedback banners on completion (e.g., *"Done. Repeats tomorrow."*).

### 6.2 Reminder Editor (`ReminderEditorView`)
- Form to configure title, repeat rules, scheduled time/date, custom completion text, and emoji icon.
- Built-in emoji suggestion based on title keywords.
- Enforces free vs. Pro limits during creation.

### 6.3 Completion History (`HistoryView`)
- Displays historical completion records grouped chronologically.
- Offers **Restore** (Add Again) functionality to reactivate archived tasks.
- Multi-select batch deletion.

### 6.4 Settings (`SettingsView`)
- **Notifications**: Request and verify permissions.
- **Appearance**: Toggle Light, Dark, or System mode.
- **Home Screen Customization**: Customize widget themes and pet companion.
- **Done Yet? Pro**: Check membership status and access paywall.

### 6.5 Monetization & Paywall (`ProPaywallView` / `PurchaseService`)
- StoreKit 2 integration supporting Monthly (`done_yet_pro_monthly`), Yearly (`done_yet_pro_yearly`), and Lifetime (`done_yet_pro_lifetime`) options.
- Configurable free tiers (e.g., 10 reminder limit, limited icon/widget customizations).

---

## 7. Build & Execution Configuration

- **Target OS:** iOS 17.0+ (Project configured for iOS 26.5 deployment target)
- **App Group Identifier:** `group.com.doneyet.app`
- **Widget Extension Kind:** `DoneYetWidget`
- **Swift Version:** 6.3.3

---

## 8. Summary of Project Status

- ✅ **SwiftData & Persistence Foundation:** Fully implemented with App Group container migration and fallback logic.
- ✅ **Recurrence Engine:** Fully functional daily, weekly, monthly, custom interval, and weekday calculations.
- ✅ **Interactive Widget Extension:** Complete with AppIntents for instant completion and pet interactions.
- ✅ **Full SwiftUI UI:** Home list, Reminder Editor, History archive, Settings, and Search views implemented.
- ✅ **StoreKit 2 Support:** Fully wired product catalog and transaction processing structure.
