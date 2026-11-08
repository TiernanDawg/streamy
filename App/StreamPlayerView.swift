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

    func goToXboxHome() {
        errorMessage = nil
        webView?.load(URLRequest(url: URL(string: "https://www.xbox.com/play")!))
    }
}

struct StreamPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state = WebViewState()
    @AppStorage("streamy.keepAwake") private var keepAwake = true

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            WebContentView(state: state)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close Xbox Cloud Gaming")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("XBOX CLOUD GAMING")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(state.isLoading ? "Connecting…" : "Running inside Streamy")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button {
                        state.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(state.canGoBack ? .white : .white.opacity(0.35))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(!state.canGoBack)
                    .accessibilityLabel("Go back")

                    Button {
                        state.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Reload Xbox Cloud Gaming")
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)

                if state.isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 12)
                }

                Spacer()

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
                    .padding(.bottom, 28)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
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
