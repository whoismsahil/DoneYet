# Done Yet? — Implementation Plan

Generated from `Done_Yet_Native_iOS_Tech_Stack.md` after environment inspection.

---

## Environment (verified)

| Item | Value |
|------|-------|
| Xcode | 26.6 (Build 17F113) |
| Swift | 6.3.3 |
| iOS SDK | 26.5 (`iphoneos26.5`, `iphonesimulator26.5`) |
| Deployment target | 26.5 (already set in project) |
| Project state | Fresh SwiftUI app — `ContentView` placeholder only |

### Framework availability (iOS 26.5)

All required APIs are available at the current deployment target:

- SwiftUI, SwiftData — native
- WidgetKit + interactive widgets — iOS 17+
- App Intents — iOS 16+
- StoreKit 2 — iOS 15+
- UserNotifications — native
- App Groups — native

**Decision:** Keep `IPHONEOS_DEPLOYMENT_TARGET = 26.5`. No need to lower it; the installed SDK is iOS 26.5 and the project already targets it.

---

## Current project gaps

- Single app target only (no Widget extension)
- No SwiftData models or container
- No feature-based folder structure
- No App Group entitlement
- No StoreKit configuration
- Bundle ID: `DoneYet.Done-Yet-` (placeholder — update before App Store)

---

## Target architecture

```
Done Yet?/
├── App/
│   ├── DoneYetApp.swift          (rename from Done_Yet_App.swift)
│   └── AppEnvironment.swift
├── Models/
│   ├── Reminder.swift
│   ├── CompletionRecord.swift
│   └── RepeatRule.swift
├── Features/
│   ├── Home/
│   ├── ReminderEditor/
│   ├── History/
│   ├── Pro/
│   └── Settings/
├── Services/
│   ├── ReminderService.swift
│   ├── RecurrenceService.swift
│   ├── NotificationService.swift
│   ├── PurchaseService.swift
│   └── SharedWidgetStore.swift
├── DesignSystem/
│   ├── AppColors.swift
│   ├── AppTypography.swift
│   ├── AppSpacing.swift
│   └── AppComponents.swift
└── Shared/                       (app + widget target membership)
    ├── WidgetModels.swift
    └── AppGroupConstants.swift

DoneYetWidget/                    (new WidgetKit extension target)
├── DoneYetWidget.swift
├── WidgetProvider.swift
├── WidgetEntry.swift
├── WidgetViews.swift
└── CompleteReminderIntent.swift
```

---

## Shared completion pipeline

Both the main app and `CompleteReminderIntent` must call the same logic:

```
find reminder
  → create CompletionRecord
  → set lastCompletedAt
  → calculate nextOccurrence (if recurring)
  → save SwiftData (app/intent via shared ModelContainer in App Group)
  → write WidgetReminder[] to App Group JSON
  → WidgetCenter.reloadTimelines
  → reschedule/cancel notification
```

Widget reads **only** from App Group JSON — never depends on the main app process.

---

## Data model summary

### Reminder (SwiftData `@Model`)

- `id`, `title`, `completionButtonText` (default `"DONE YET?"`)
- `isRepeating`, `repeatType` (Never / EveryDay / EveryWeek / Custom)
- `repeatInterval`, `weekdays` (Custom only)
- `reminderHour`, `reminderMinute` (optional scheduled time)
- `createdAt`, `updatedAt`, `isActive`
- `lastCompletedAt`, `nextOccurrence`

### CompletionRecord (SwiftData `@Model`)

- `id`, `reminderID`, `completedAt`, `completionText`
- Never deleted when recurring reminder advances

### WidgetReminder (Codable, App Group)

- `id`, `title`, `buttonText`, `status` (pending/completed), `nextOccurrence`

---

## Pro / monetization

| Setting | Value |
|---------|-------|
| Product ID | `com.doneyet.app.pro.lifetime` (adjust to final bundle ID) |
| Type | Non-consumable |
| Price | $9.99 USD lifetime |
| Entitlement | `APP_PRO` |
| Free limit | 5 active reminders |

Rules:
- Never hard-code Pro status
- Never delete reminders due to paywall
- Sixth reminder creation → Pro screen
- Lapsed Pro: keep all reminders, block new ones above limit

---

## Phase 1 — Native iOS Foundation

**Goal:** App shell + SwiftData + core screens (no widget, no StoreKit yet).

### Tasks

1. Restructure folders under `Done Yet?/` per architecture above
2. Add `AppEnvironment` — SwiftData `ModelContainer`, service wiring
3. Implement models: `Reminder`, `CompletionRecord`, `RepeatType`
4. Implement `RecurrenceService` (stub next-occurrence for Phase 2)
5. Implement `ReminderService` — CRUD, pause, complete (in-app)
6. Build design system: colors, typography, spacing, shared components
7. **Home** — list active reminders, swipe/context actions (edit, pause, delete), `+ Add Reminder`
8. **ReminderEditor** — create/edit with title, repeat, time picker, completion button preview
9. **History** — grouped by Today/Yesterday/date, read-only completion list
10. **Settings** — notifications status, appearance (system/light/dark), about, restore placeholder
11. Wire root navigation (TabView or lightweight stack — keep flat)
12. Remove placeholder `ContentView`

### Exit criteria

- Create/edit/delete/pause reminders persist across app restart
- History shows completions
- App builds cleanly on simulator

---

## Phase 2 — Reminder Engine

**Goal:** Full recurrence and completion lifecycle.

### Tasks

1. `RecurrenceService` — Never, EveryDay, EveryWeek, Custom (every X days + weekdays)
2. `nextOccurrence` calculation with timezone/DST awareness
3. Completion flow: one-time → finished; recurring → pending again at next occurrence
4. Pending vs completed UI state on Home and editor preview
5. Unit-test recurrence edge cases (timezone change, DST, weekday selection)

### Exit criteria

- Daily / weekly / custom recurrence calculates correctly
- Completing recurring reminder schedules next occurrence
- Completion history preserved across occurrences

---

## Phase 3 — Notifications

**Goal:** UserNotifications integration.

### Tasks

1. `NotificationService` — permission request, schedule, cancel, reschedule
2. Schedule only when `reminderHour`/`reminderMinute` set
3. On complete (recurring): cancel current, schedule next
4. On edit/pause/delete: update notifications accordingly
5. Settings: show permission status, link to system settings if denied

### Exit criteria

- Notification fires at scheduled time
- Editing time updates schedule
- Paused/deleted reminders cancel notifications

---

## Phase 4 — WidgetKit

**Goal:** Widget extension + shared data.

### Tasks

1. Add WidgetKit extension target `DoneYetWidget`
2. Configure App Group: `group.com.doneyet.app` (match final bundle ID)
3. Implement `SharedWidgetStore` — read/write JSON in App Group container
4. Main app syncs active reminders to shared store on every data change
5. `WidgetProvider` — timeline entries, refresh policy
6. Widget views: Small (1 reminder), Medium (2–4), Large (more + context)
7. Visual design: bold editorial typography, monochrome, high contrast
8. Empty state when no reminders

### Exit criteria

- Widget displays reminders without opening app
- Widget updates after app edits reminders
- Small/Medium/Large render correctly

---

## Phase 5 — Interactive Widget

**Goal:** Tap-to-complete from Home Screen.

### Tasks

1. `CompleteReminderIntent` — accepts `reminderID`
2. Intent runs shared completion pipeline (SwiftData in App Group + JSON update)
3. `WidgetCenter.reloadTimelines(ofKind:)`
4. Completed state: `LOCKED ✓` with optional "NEXT Tomorrow · 10:00 PM"
5. Medium widget: independent interactive button per reminder
6. **Test on physical iPhone** (required)

### Exit criteria

- Tap `DONE YET?` on widget completes without launching app
- Widget and app show same state
- Works when main app is terminated

---

## Phase 6 — StoreKit 2

**Goal:** Pro purchase and free limit enforcement.

### Tasks

1. Add StoreKit configuration file for local testing
2. `PurchaseService` — load products, purchase, verify, observe updates, restore
3. Persist entitlement (UserDefaults in App Group or Keychain)
4. **Pro screen** — benefits, $9.99 lifetime, Unlock + Restore
5. Enforce 5-reminder limit for free users at creation time
6. Pro: unlimited reminders + editable completion button text
7. Free: completion button locked to `DONE YET?`

### Exit criteria

- Sixth reminder triggers Pro screen
- Purchase unlocks features immediately
- Restore recovers entitlement
- App usable when App Store unavailable

---

## Phase 7 — Polish

**Goal:** Production-quality MVP.

### Tasks

1. Accessibility: Dynamic Type, VoiceOver labels, Reduce Motion, contrast
2. Light/dark mode pass on all screens + widget
3. App icon concept (question mark / typographic mark — no checklist)
4. Edge cases: permission denied, timezone change, concurrent widget refresh
5. Compiler warnings = 0
6. Full manual test against Definition of Done (spec §38)

---

## Xcode project changes (by phase)

| Phase | Xcode changes |
|-------|---------------|
| 1 | Folder restructure (filesystem sync group picks up files automatically) |
| 3 | Notification usage description in Info.plist |
| 4 | Widget extension target, App Groups entitlement on both targets |
| 6 | StoreKit configuration, In-App Purchase capability |

---

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| SwiftData in widget/App Intent process | Use App Group–backed `ModelContainer` URL shared by app and intent |
| Interactive widget only on device | Phase 5 blocked until physical device test |
| Bundle ID placeholder | Set final ID before StoreKit/App Group configuration |
| Swift 6 concurrency | Use `@MainActor` view models, `async` StoreKit APIs |

---

## Definition of Done checklist (from spec)

- [ ] Create "Locking the door" · Every day · 10:00 PM
- [ ] See reminder in Home Screen widget
- [ ] Widget shows `DONE YET?` button
- [ ] Tap completes from widget → `LOCKED ✓`
- [ ] Next occurrence calculated
- [ ] Completion appears in History
- [ ] Free: 5 reminders max; 6th → Pro
- [ ] Pro purchase ($9.99 lifetime) unlocks unlimited + custom button
- [ ] Custom button (e.g. `I DRANK`) appears in widget
- [ ] Primary completion works without opening main app

---

## Recommended next step

**Start Phase 1** — foundation, models, Home, Editor, History, Settings. Build and verify persistence before moving to recurrence engine.

Estimated order: Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 (build after each phase).
