import Foundation
import SwiftData
import SwiftUI

@main
struct DaycoApp: App {
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.system.rawValue

    var sharedModelContainer: ModelContainer = {
        if let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        }

        let schema = Schema([
            DDayItem.self,
        ])
        let isICloudBackupEnabled = UserDefaults.standard.bool(forKey: "isICloudBackupEnabled")
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: isICloudBackupEnabled ? .private("iCloud.com.seunghwabaek.dayco") : .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            DDayListView()
                .preferredColorScheme(appAppearance.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .system
    }
}
