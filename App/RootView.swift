import SwiftUI
import UIKit

private enum StreamyPalette {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.075)
    static let panel = Color(red: 0.085, green: 0.105, blue: 0.155)
    static let accent = Color(red: 0.36, green: 0.88, blue: 0.48)
    static let secondary = Color(red: 0.62, green: 0.68, blue: 0.78)
}

struct RootView: View {
    @AppStorage("streamy.didWelcome") private var didWelcome = false
    @AppStorage("streamy.keepAwake") private var keepAwake = true
    @State private var showPlayer = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if didWelcome {
                home
            } else {
                WelcomeView {
                    withAnimation(.smooth(duration: 0.3)) {
                        didWelcome = true
                    }
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onChange(of: keepAwake) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            StreamPlayerView()
                .preferredColorScheme(.dark)
        }
    }

    private var home: some View {
        ZStack {
            LinearGradient(
                colors: [StreamyPalette.background, Color(red: 0.055, green: 0.10, blue: 0.14), StreamyPalette.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR GAMES.\nONE TAP AWAY.")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .tracking(-1.5)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Launch Xbox Cloud Gaming directly inside Streamy. No Safari tabs or address bar.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(StreamyPalette.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.top, 14)

                    launchCard

                    HStack(spacing: 12) {
                        featureCard(
                            icon: "arrow.up.right.video",
                            title: "Full-screen",
                            detail: "Play inside Streamy"
                        )
                        featureCard(
                            icon: "gamecontroller",
                            title: "Controller",
                            detail: "Use a paired gamepad"
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("How it works", systemImage: "info.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Streamy loads Microsoft's official Xbox Cloud Gaming website in an app-managed WebKit view. Your Game Pass access and Microsoft account are still required.")
                            .font(.system(size: 13))
                            .foregroundStyle(StreamyPalette.secondary)
                            .lineSpacing(3)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StreamyPalette.panel.opacity(0.75), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(StreamyPalette.accent)
                        .frame(width: 38, height: 38)
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.85))
                }

                Text("STREAMY")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var launchCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("XBOX CLOUD GAMING", systemImage: "cloud.fill")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(StreamyPalette.accent)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 68, height: 68)
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Play in the cloud")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your Xbox library, streamed to iPhone")
                        .font(.system(size: 12))
                        .foregroundStyle(StreamyPalette.secondary)
                }
                Spacer(minLength: 0)
            }

            Button {
                showPlayer = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Launch Xbox Cloud Gaming")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(StreamyPalette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.22, blue: 0.25), StreamyPalette.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func featureCard(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(StreamyPalette.accent)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(StreamyPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(16)
        .background(StreamyPalette.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            StreamyPalette.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(StreamyPalette.accent)
                        .frame(width: 104, height: 104)
                    Image(systemName: "play.fill")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.85))
                }

                VStack(spacing: 10) {
                    Text("Meet Streamy")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A cleaner way to get into Xbox Cloud Gaming on your iPhone.")
                        .font(.system(size: 16))
                        .foregroundStyle(StreamyPalette.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Opens Xbox inside the app", systemImage: "rectangle.inset.filled")
                    Label("Keeps your Microsoft session on device", systemImage: "lock.shield")
                    Label("No ads, accounts, or tracking from Streamy", systemImage: "hand.raised")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(StreamyPalette.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Spacer()

                Button(action: onContinue) {
                    Text("Get started")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(StreamyPalette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }
}
