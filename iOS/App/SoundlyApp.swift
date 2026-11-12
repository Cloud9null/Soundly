import SwiftUI
import SwiftData

@main
struct SoundlyApp: App {
    @State private var container: ModelContainer?
    @State private var failure: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let container { RootView().modelContainer(container) }
                else if let failure { ContentUnavailableView("Library could not open",systemImage:"externaldrive.badge.exclamationmark",description:Text(failure)) }
                else { ProgressView("Opening your library…") }
            }.task {
                guard container == nil, failure == nil else { return }
                do {
                    container = try await Task.detached {
                        let url = try LibraryPaths.base().appendingPathComponent("Library.store")
                        let configuration = ModelConfiguration(url:url,cloudKitDatabase:.none)
                        return try ModelContainer(for:Song.self,configurations:configuration)
                    }.value
                } catch { failure = "Your existing files have been preserved. Restart Soundly to retry. \(error.localizedDescription)" }
            }
        }
    }
}
