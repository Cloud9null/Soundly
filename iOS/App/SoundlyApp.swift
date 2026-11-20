import SwiftUI
import SwiftData

@main
struct SoundlyApp: App {
    @State private var container: ModelContainer?
    @State private var failure: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    #if DEBUG
                    RootView().modelContainer(container).modifier(DebugPresentation())
                    #else
                    RootView().modelContainer(container)
                    #endif
                }
                else if let failure { ContentUnavailableView("Library could not open",systemImage:"externaldrive.badge.exclamationmark",description:Text(failure)) }
                else { ProgressView("Opening your library…") }
            }.task {
                guard container == nil, failure == nil else { return }
                do {
                    let created = try await Task.detached {
                        let url = try LibraryPaths.base().appendingPathComponent("Library.store")
                        var configuration = ModelConfiguration(url:url,cloudKitDatabase:.none)
                        #if DEBUG
                        if ProcessInfo.processInfo.arguments.contains("--soundly-fixtures") { configuration = ModelConfiguration(isStoredInMemoryOnly:true,cloudKitDatabase:.none) }
                        #endif
                        let db = try ModelContainer(for:Song.self,configurations:configuration)
                        try await DuplicateManager(modelContainer:db).recoverPendingRemovals()
                        return db
                    }.value
                    #if DEBUG
                    if DebugFixtures.enabled { try await DebugFixtures.prepare(created) }
                    #endif
                    container = created
                } catch { failure = "Your existing files have been preserved. Restart Soundly to retry. \(error.localizedDescription)" }
            }
        }
    }
}
