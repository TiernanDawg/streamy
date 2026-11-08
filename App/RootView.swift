import SwiftUI

struct RootView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Create", systemImage: "sparkles") }.tag(0)
            NavigationStack { PantryView() }
                .tabItem { Label("Pantry", systemImage: "cabinet") }.tag(1)
            NavigationStack { ShoppingView() }
                .tabItem { Label("Shopping", systemImage: "cart") }.tag(2)
            NavigationStack { SavedRecipesView() }
                .tabItem { Label("Saved", systemImage: "bookmark") }.tag(3)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(4)
        }
        .tint(Color(red: 0.22, green: 0.68, blue: 0.42))
    }
}
