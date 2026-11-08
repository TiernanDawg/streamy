import SwiftUI
import WebKit
import Observation
import UIKit

@MainActor
@Observable
final class WebViewState {
    var isLoading = true
    var canGoBack = false
    var errorMessage: String?
    @ObservationIgnored weak var webView: WKWebView?

    func goBack() {
        guard let webView, webView.canGoBack else { return }
        webView.goBack()
    }

    func reload() {
        errorMessage = nil
        webView?.reload()
    }
}

struct StreamPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state = WebViewState()
    @State private var showSettings = false
    @AppStorage("streamy.keepAwake") private var keepAwake = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()

            WebContentView(state: state)
                .ignoresSafeArea(.all)

            // Keep native controls off the Xbox page's top navigation and game cards.
            Menu {
                Button {
                    state.goBack()
                } label: {
                    Label("Go Back", systemImage: "chevron.left")
                }
                .disabled(!state.canGoBack)

                Button {
                    state.reload()
                } label: {
                    Label("Reload Xbox", systemImage: "arrow.clockwise")
                }

                Button {
                    showSettings = true
                } label: {
                    Label("Streamy Settings", systemImage: "gearshape")
                }

                Divider()

                Button(role: .destructive) {
                    dismiss()
                } label: {
                    Label("Close Streamy Player", systemImage: "xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .contentShape(Circle())
            }
            .accessibilityLabel("Player controls")
            .padding(.trailing, 14)
            .padding(.bottom, 14)

            if state.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 18)
                    .allowsHitTesting(false)
            }

            if let error = state.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 24))
                    Text("Couldn't load Xbox Cloud Gaming")
                        .font(.system(size: 17, weight: .bold))
                    Text(error)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                    Button("Try again") {
                        state.reload()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.14), in: Capsule())
                }
                .foregroundStyle(.white)
                .padding(20)
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onChange(of: keepAwake) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
    }
}

private struct WebContentView: UIViewRepresentable {
    let state: WebViewState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = GamepadEnabledWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInset = .zero
        webView.scrollView.verticalScrollIndicatorInsets = .zero
        webView.scrollView.horizontalScrollIndicatorInsets = .zero
        state.webView = webView
        webView.becomeFirstResponder()

        let request = URLRequest(
            url: URL(string: "https://www.xbox.com/play")!,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 45
        )
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let state: WebViewState

        init(state: WebViewState) {
            self.state = state
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
            state.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.canGoBack = webView.canGoBack
            webView.becomeFirstResponder()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
            state.errorMessage = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
            state.errorMessage = error.localizedDescription
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let scheme = navigationAction.request.url?.scheme?.lowercased() else {
                decisionHandler(.cancel)
                return
            }

            if scheme == "https" || scheme == "http" {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

private final class GamepadEnabledWebView: WKWebView {
    override var canBecomeFirstResponder: Bool {
        true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
    }
}
