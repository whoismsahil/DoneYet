import Foundation
import SwiftData

enum AppSchema {
    static let modelContainer: ModelContainer = {
        let schema = Schema([Reminder.self, CompletionRecord.self])

        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        ) {
            let storeURL = groupURL.appendingPathComponent(AppGroupConstants.swiftDataStoreName)
            migrateLegacyStoreIfNeeded(to: storeURL, in: groupURL)

            let configuration = ModelConfiguration(url: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                deleteStore(at: storeURL)
                do {
                    return try ModelContainer(for: schema, configurations: [configuration])
                } catch {
                    let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                    do {
                        return try ModelContainer(for: schema, configurations: [fallback])
                    } catch {
                        fatalError("Could not create App Group ModelContainer: \(error)")
                    }
                }
            }
        }

        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func deleteStore(at storeURL: URL) {
        let fileManager = FileManager.default
        let related = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal"),
            storeURL.deletingLastPathComponent().appendingPathComponent("\(AppGroupConstants.swiftDataStoreName).shm"),
            storeURL.deletingLastPathComponent().appendingPathComponent("\(AppGroupConstants.swiftDataStoreName).wal")
        ]

        for url in related {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func migrateLegacyStoreIfNeeded(to destinationURL: URL, in groupURL: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destinationURL.path) else { return }

        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }

        let legacyURL = appSupport.appendingPathComponent("default.store")
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }

        do {
            try fileManager.copyItem(at: legacyURL, to: destinationURL)

            let legacySHM = appSupport.appendingPathComponent("default.store.shm")
            let legacyWAL = appSupport.appendingPathComponent("default.store.wal")
            let destinationSHM = groupURL.appendingPathComponent("\(AppGroupConstants.swiftDataStoreName).shm")
            let destinationWAL = groupURL.appendingPathComponent("\(AppGroupConstants.swiftDataStoreName).wal")

            if fileManager.fileExists(atPath: legacySHM.path) {
                try fileManager.copyItem(at: legacySHM, to: destinationSHM)
            }
            if fileManager.fileExists(atPath: legacyWAL.path) {
                try fileManager.copyItem(at: legacyWAL, to: destinationWAL)
            }
        } catch {
            // If migration fails, a fresh store will be created in the App Group.
        }
    }
}
