import SwiftUI
import UIKit

struct AppIconSettingsView:View {
    @State private var selected = UIApplication.shared.alternateIconName
    @State private var changing = false
    @State private var message:String?
    private let choices = ["Prism","Aurora","Pulse","Orbit"]
    var body:some View {
        List {
            Section("Soundly identity") {
                ForEach(choices,id:\.self) { name in
                    Button { change(name) } label: {
                        HStack(spacing:16) {
                            if name == "Prism" {
                                if let image = primaryImage { Image(uiImage:image).resizable().frame(width:64,height:64).clipShape(RoundedRectangle(cornerRadius:14)) }
                                else { Image(systemName:"play.fill").frame(width:64,height:64).background(.tint.opacity(0.1),in:RoundedRectangle(cornerRadius:14)) }
                            } else { Image("IconPreview-"+name).resizable().frame(width:64,height:64).clipShape(RoundedRectangle(cornerRadius:14)) }
                            Text(name).foregroundStyle(.primary);Spacer()
                            if selected == (name == "Prism" ? nil : "AppIcon-"+name) { Image(systemName:"checkmark.circle.fill").foregroundStyle(.tint) }
                        }.padding(.vertical,4).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(changing || !UIApplication.shared.supportsAlternateIcons)
                }
            } footer: { Text("Changes the actual Home Screen icon using iOS. Prism remains the primary icon. iOS may display a confirmation; changing the icon does not alter your library.") }
            if let message { Text(message).font(.footnote) }
        }.navigationTitle("App Icon").soundlySurface()
    }
    private var primaryImage:UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String:Any],let primary = icons["CFBundlePrimaryIcon"] as? [String:Any],let files = primary["CFBundleIconFiles"] as? [String],let name = files.last else { return nil }
        return UIImage(named:name)
    }
    private func change(_ name:String) {
        changing = true;message = nil
        UIApplication.shared.setAlternateIconName(name == "Prism" ? nil : "AppIcon-"+name) { error in
            let description = error?.localizedDescription
            Task { @MainActor in
                changing = false;selected = UIApplication.shared.alternateIconName
                if let description { message = "iOS could not change the icon: "+description }
            }
        }
    }
}
