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

struct CoverView: View {
    var artwork: String? = nil
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.13).fill(.tint.opacity(0.13))
            Image(systemName: "waveform").font(.system(size: size * 0.35)).foregroundStyle(.tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
