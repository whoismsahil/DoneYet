import Foundation

enum SharedWidgetStoreError: Error {
    case appGroupUnavailable
}

struct SharedWidgetStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(reminders: [WidgetReminder]) throws {
        let snapshot = WidgetReminderSnapshot(reminders: reminders, updatedAt: .now)
        let data = try encoder.encode(snapshot)
        try data.write(to: dataFileURL(), options: .atomic)
        persistPickerTitles(from: reminders)
    }

    func load() throws -> [WidgetReminder] {
        let url = try dataFileURL()
        if fileManager.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let snapshot = try? decoder.decode(WidgetReminderSnapshot.self, from: data) {
            persistPickerTitles(from: snapshot.reminders)
            return snapshot.reminders
        }

        return []
    }

    func reminder(id: UUID) throws -> WidgetReminder? {
        try load().first { $0.id == id }
    }

    func pickerTitles() -> [String] {
        let loaded = (try? load()) ?? []
        if !loaded.isEmpty {
            return uniqued(loaded.filter(\.appearsInWidgetPicker).map(\.pickerLabel))
        }
        return storedPickerTitles()
    }

    func dataFileURL() throws -> URL {
        try containerURL().appendingPathComponent(AppGroupConstants.widgetDataFileName)
    }

    private func persistPickerTitles(from reminders: [WidgetReminder]) {
        let pickable = reminders.filter(\.appearsInWidgetPicker)
        let titles = uniqued(pickable.map(\.pickerLabel))
        if reminders.isEmpty, !storedPickerTitles().isEmpty {
            return
        }

        if let defaults = UserDefaults(suiteName: AppGroupConstants.identifier) {
            defaults.set(titles, forKey: AppGroupConstants.widgetPickerTitlesKey)
            defaults.set(
                pickable.map { ["id": $0.id.uuidString, "title": $0.pickerLabel] },
                forKey: AppGroupConstants.widgetPickerCatalogKey
            )
            defaults.synchronize()
        }

        if let data = try? JSONEncoder().encode(titles),
           let url = try? containerURL().appendingPathComponent(AppGroupConstants.widgetPickerFileName) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func storedPickerTitles() -> [String] {
        if let titles = UserDefaults(suiteName: AppGroupConstants.identifier)?
            .stringArray(forKey: AppGroupConstants.widgetPickerTitlesKey),
           !titles.isEmpty {
            return titles
        }

        if let url = try? containerURL().appendingPathComponent(AppGroupConstants.widgetPickerFileName),
           let data = try? Data(contentsOf: url),
           let titles = try? JSONDecoder().decode([String].self, from: data),
           !titles.isEmpty {
            return titles
        }

        let catalog = UserDefaults(suiteName: AppGroupConstants.identifier)?
            .array(forKey: AppGroupConstants.widgetPickerCatalogKey) as? [[String: String]]
        let fromCatalog = (catalog ?? []).compactMap { $0["title"] }.filter { !$0.isEmpty }
        return uniqued(fromCatalog)
    }

    private func uniqued(_ titles: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return titles.map { title in
            let count = seen[title, default: 0]
            seen[title] = count + 1
            return count == 0 ? title : "\(title) (\(count + 1))"
        }
    }

    private func containerURL() throws -> URL {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        ) else {
            throw SharedWidgetStoreError.appGroupUnavailable
        }
        return containerURL
    }
}
