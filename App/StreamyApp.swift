import SwiftUI

@main
struct StreamyApp: App {
    @State private var model = AppModel()
    @AppStorage("frugalfork.appearance") private var appearance = "system"

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(preferredScheme)
        }
    }
}
