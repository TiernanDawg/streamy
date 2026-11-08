import SwiftUI
import UIKit

struct RootView: View {
    @AppStorage("streamy.keepAwake") private var keepAwake = true

    var body: some View {
        StreamPlayerView()
            .preferredColorScheme(.dark)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = keepAwake
            }
            .onChange(of: keepAwake) { _, newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
    }
}
