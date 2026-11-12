import SwiftUI

enum SoundlyTheme: String, CaseIterable, Identifiable {
    case system, light, dark, oled, ocean, sunset
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; default: .dark }
    }
    var accent: Color {
        switch self { case .ocean: .cyan; case .sunset: .orange; default: .mint }
    }
}

@MainActor
private enum ArtworkCache {
    static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 48; cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
}

struct CoverView: View {
    var artwork: String? = nil
    var size: CGFloat = 56
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.13).fill(.tint.opacity(0.13))
            if let image {
                Image(uiImage:image).resizable().scaledToFill()
            } else {
                Image(systemName: "waveform").font(.system(size: size * 0.35)).foregroundStyle(.tint)
            }
        }
        .frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size * 0.13))
        .accessibilityHidden(true)
        .task(id:artwork) {
            image = nil
            guard let artwork else { return }
            if let cached = ArtworkCache.images.object(forKey:artwork as NSString) { image = cached; return }
            let data = await Task.detached {
                guard let url = try? LibraryPaths.directory("Artwork").appendingPathComponent(artwork) else { return Data?.none }
                return try? Data(contentsOf:url)
            }.value
            guard !Task.isCancelled, let data, let loaded = UIImage(data:data) else { return }
            ArtworkCache.images.setObject(loaded,forKey:artwork as NSString,cost:Int(loaded.size.width * loaded.size.height * 4))
            image = loaded
        }
    }
}
