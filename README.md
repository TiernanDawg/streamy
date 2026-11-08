# Streamy

Streamy is a standalone iPhone app shell for Xbox Cloud Gaming. It opens the official Xbox Cloud Gaming experience inside an app-managed `WKWebView`, so you launch from the Home Screen and stay inside Streamy instead of being sent to Safari.

## What it does

- Opens `https://www.xbox.com/play` in a full-screen native app surface.
- Uses the persistent default WebKit website data store so Microsoft sign-in cookies can survive app launches.
- Keeps browser chrome and Safari navigation UI out of the experience.
- Provides native back, reload, loading, and error controls.
- Allows inline media playback and supports landscape orientations.
- Includes a settings screen and a one-tap option to clear Xbox website data.
- Builds an unsigned IPA through GitHub Actions on `xcode-27`.

## Important compatibility boundary

Microsoft's published iOS instructions direct users to Safari for Xbox Cloud Gaming. Streamy uses the official Xbox website in WebKit; Microsoft does not document or guarantee that the full streaming, Microsoft sign-in, and Gamepad API experience works inside a third-party `WKWebView`. Validate sign-in, game launch, controller input, and audio on the physical iPhone before relying on it.

A native client such as RayxCloud/Stratix can avoid the website entirely, but it implements Microsoft's undocumented, proprietary xCloud session and signaling protocol. This project deliberately does not copy or depend on those private endpoints.

## Build locally

1. Install Xcode 27 and Homebrew.
2. Install XcodeGen: `brew install xcodegen`.
3. Generate the project: `xcodegen generate`.
4. Open `Streamy.xcodeproj` and build for an iPhone, or run the same unsigned archive commands used in `.github/workflows/build.yml`.

## Build an IPA

Push to `main` or run **Actions → Build unsigned IPA → Run workflow**. Download the `Streamy-ipa` artifact and sideload the IPA with your signing tool.

The IPA is unsigned. Sign it with SideStore, AltStore, Sideloadly, or another compatible tool before installing.

## Privacy

Streamy has no analytics, ads, app account, or backend. Microsoft sign-in and website data are handled by Microsoft's website and the system WebKit website data store. Clearing website data signs you out of Xbox in Streamy.
