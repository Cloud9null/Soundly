import SwiftUI
import UniformTypeIdentifiers

struct MusicDocumentPicker: UIViewControllerRepresentable {
    let folders: Bool
    let picked: ([URL]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(picked: picked) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: folders ? [.folder] : [.audio], asCopy: false)
        picker.allowsMultipleSelection = !folders
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let picked: ([URL]) -> Void
        init(picked: @escaping ([URL]) -> Void) { self.picked = picked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { picked(urls) }
    }
}
