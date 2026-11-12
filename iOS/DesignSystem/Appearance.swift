import SwiftUI

enum SoundlyTheme: String, CaseIterable, Identifiable {
    case system, light, dark, oled, ocean, sunset, amethyst, forest, rose, graphite, ivory, midnight
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self { case .system: nil; case .light, .ivory: .light; default: .dark }
    }
    var accent: Color {
        switch self {
        case .ocean: .cyan; case .sunset: .orange; case .amethyst: .purple
        case .forest: .green; case .rose: .pink; case .graphite: .white
        case .ivory: .brown; case .midnight: .indigo; default: .mint
        }
    }
    var surface: Color {
        switch self {
        case .system, .light, .dark: Color(uiColor:.systemBackground)
        case .oled: .black
        case .ocean: Color(red:0.025,green:0.09,blue:0.14)
        case .sunset: Color(red:0.15,green:0.055,blue:0.035)
        case .amethyst: Color(red:0.09,green:0.04,blue:0.16)
        case .forest: Color(red:0.025,green:0.10,blue:0.065)
        case .rose: Color(red:0.15,green:0.035,blue:0.085)
        case .graphite: Color(white:0.08)
        case .ivory: Color(red:0.98,green:0.95,blue:0.88)
        case .midnight: Color(red:0.025,green:0.035,blue:0.11)
        }
    }
}

private struct SoundlySurfaceKey: EnvironmentKey { static let defaultValue = Color(uiColor:.systemBackground) }
extension EnvironmentValues {
    var soundlySurface: Color {
        get { self[SoundlySurfaceKey.self] }
        set { self[SoundlySurfaceKey.self] = newValue }
    }
}
struct SoundlySurface: ViewModifier {
    @Environment(\.soundlySurface) private var surface
    func body(content:Content)->some View { content.scrollContentBackground(.hidden).background(surface) }
}
extension View { func soundlySurface()->some View { modifier(SoundlySurface()) } }

@MainActor
enum ArtworkCache {
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
