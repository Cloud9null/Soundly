import SwiftUI
import SwiftData
import Observation

@MainActor @Observable final class DuplicateController {
    var running = false
    var removing = false
    var report:DuplicateReport?
    var progress = ""
    var message:String?
    private var task:Task<Void,Never>?
    func scan(_ container:ModelContainer) {
        guard !running else { return }
        running = true; report = nil; message = nil; progress = "Reading private copies…"
        task = Task {
            do {
                let worker = await Task.detached { DuplicateManager(modelContainer:container) }.value
                report = try await worker.scan { [weak self] value in
                    Task { @MainActor in self?.progress = "\(value.checked) of \(value.total) checked" }
                }
            } catch is CancellationError { message = "Scan cancelled. No files were removed." }
            catch { message = error.localizedDescription }
            running = false
        }
    }
    func cancel() { task?.cancel() }
    func remove(_ container:ModelContainer,playback:PlaybackController) {
        guard !running,let report,report.extraCount > 0 else { return }
        running = true; removing = true; message = nil
        let keep = playback.current?.id
        task = Task {
            do {
                let worker = await Task.detached { DuplicateManager(modelContainer:container) }.value
                let result = try await worker.removeExtras(report,preferKeeping:keep)
                playback.removeLibraryTracks(result.removedIDs)
                self.report = nil
                message = "Removed \(result.removedIDs.count) extra library copies. " + (result.cleanupPending ? "Recovery cleanup is pending; bytes have not been reported as freed." : "Reclaimed \(ByteCountFormatter.string(fromByteCount:result.reclaimedBytes,countStyle:.file)).")
            } catch { message = error.localizedDescription }
            running = false; removing = false
        }
    }
}

struct DuplicateView:View {
    @Environment(\.modelContext) private var context
    @Environment(PlaybackController.self) private var playback
    @State private var controller = DuplicateController()
    @State private var confirm = false
    var body:some View {
        List {
            Section {
                Label("Keep your library, lose the extra copies.",systemImage:"square.on.square").font(.headline)
                Text("Scans actual file bytes across the library. Different encodings, bit depths or metadata are kept. Original Files folders are never deleted.").font(.footnote).foregroundStyle(.secondary)
                Button("Scan library",systemImage:"magnifyingglass") { controller.scan(context.container) }
                    .disabled(controller.running).accessibilityIdentifier("scanDuplicates")
                if controller.running {
                    ProgressView(controller.removing ? "Verifying and removing extra copies…" : controller.progress)
                    if !controller.removing { Button("Cancel scan") { controller.cancel() } }
                }
                if let message = controller.message { Text(message).font(.footnote).accessibilityIdentifier("duplicateResult") }
            }
            if let report = controller.report {
                Section {
                    LabeledContent("Extra copies",value:"\(report.extraCount)").accessibilityIdentifier("duplicateCount")
                    Text("\(report.checked) checked · \(report.skipped) unavailable or unreadable").font(.footnote)
                    if report.pendingRecovery > 0 { Text("\(report.pendingRecovery) recovery files were preserved because existing data differed. Cleanup is blocked to protect those copies.").foregroundStyle(.orange) }
                    if report.extraCount == 0 { Label("No byte-identical duplicates found",systemImage:"checkmark.circle") }
                    else {
                        Button("Remove \(report.extraCount) extra \(report.extraCount == 1 ? "copy" : "copies")",role:.destructive) { confirm = true }
                            .disabled(controller.running || report.pendingRecovery > 0).accessibilityIdentifier("removeDuplicates")
                    }
                } footer: { Text("One copy per group is kept. The current track is preferred; otherwise the oldest record is retained. Favorites and listening history are merged. Files are rechecked before removal.") }
                ForEach(report.groups) { group in
                    Section("\(group.entries.count) identical copies") {
                        ForEach(group.entries) { item in
                            VStack(alignment:.leading,spacing:4) { Text(item.title); Text(item.artist).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }.soundlySurface().navigationTitle("Duplicates")
            .confirmationDialog("Remove extra private copies?",isPresented:$confirm,titleVisibility:.visible) {
                Button("Remove extra copies",role:.destructive) { controller.remove(context.container,playback:playback) }
                Button("Cancel",role:.cancel) {}
            } message: { Text("One verified identical copy per group is retained. Extra app-private copies and their duplicate library rows are removed. Keep your original music files.") }
    }
}
