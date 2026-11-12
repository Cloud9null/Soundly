import SwiftUI

struct RootView: View {
    @AppStorage("theme") private var theme = SoundlyTheme.system.rawValue
    @State private var nowPlaying = false
    private var appearance: SoundlyTheme { SoundlyTheme(rawValue: theme) ?? .system }
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { NavigationStack { HomeView() } }
            Tab("Library", systemImage: "square.stack") { NavigationStack { LibraryView() } }
            Tab("Settings", systemImage: "slider.horizontal.3") { NavigationStack { SettingsView() } }
        }
        .tabViewBottomAccessory {
            Button { nowPlaying = true } label: {
                HStack(spacing: 12) {
                    CoverView(size: 36)
                    VStack(alignment: .leading) {
                        Text("Your music awaits").font(.subheadline.weight(.semibold))
                        Text("No track selected").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "music.note")
                }.padding(.horizontal).padding(.vertical, 8).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Open Now Playing. No track selected")
        }
        .sheet(isPresented: $nowPlaying) { NowPlayingView() }
        .tint(appearance.accent).preferredColorScheme(appearance.scheme)
        .background(appearance == .oled ? Color.black : Color.clear)
    }
}

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SOUNDLY").font(.caption.weight(.bold)).tracking(4).foregroundStyle(.tint)
                    Text("A space for\nyour sound.").font(.largeTitle.bold())
                    Text("Your music. Your files. Your sound.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 28))
                ContentUnavailableView("Make yourself at home", systemImage: "opticaldisc",
                    description: Text("Your albums, favorites and listening history will live here. Add your own files to begin."))
                Label("Private by design · Offline by default", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("Listen")
    }
}

struct LibraryView: View {
    var body: some View {
        ContentUnavailableView("Your library", systemImage: "music.note.list",
            description: Text("No music imported yet. Files import arrives in Phase 2."))
            .navigationTitle("Library")
    }
}

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CoverView(size: 260)
                    Text("Nothing playing").font(.title2.bold())
                    Text("Choose a song from your library. Playback controls become available when the audio engine is implemented.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Label("Not Bit-Verified", systemImage: "info.circle").padding().glassEffect()
                }.padding(24)
            }.navigationTitle("Now Playing").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct SettingsView: View {
    @AppStorage("theme") private var theme = SoundlyTheme.system.rawValue
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    ForEach(SoundlyTheme.allCases) { Text($0.name).tag($0.rawValue) }
                }.accessibilityIdentifier("themePicker")
            }
            Section("Audio") {
                Text("Audio engine pending Phase 3").foregroundStyle(.secondary)
                Text("No output route or effective sample rate has been measured.").font(.footnote)
            }
            Section("Privacy") {
                Label("No accounts, analytics or trackers", systemImage: "lock.shield")
                Text("Music stays on this device. No external artwork or metadata lookups.").font(.footnote)
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0 (1)")
                Text("Built with Apple frameworks. No third-party runtime code.")
            }
        }.navigationTitle("Settings")
    }
}
