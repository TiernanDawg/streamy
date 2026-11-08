# SavorCart

SavorCart is a native iPhone recipe and grocery-cost planner. Describe a meal in plain language, generate a complete recipe with Groq, subtract matching pantry inventory, and build a Walmart-focused shopping list.

## Features

- Native SwiftUI interface designed for iPhone and iOS 27.
- Groq-powered recipes with quantities, serving count, preparation and cooking times, and sequential instructions.
- Groq API key stored in iOS Keychain with device-only accessibility.
- Local recipe library, pantry inventory and shopping list.
- Pantry deduction when ingredient names and units match.
- Practical package-size suggestions and package-count/leftover calculations.
- Walmart product search links with best-effort extraction of public structured product data.
- Manual/unavailable price distinction. Manually entered prices are per package; only confirmed prices contribute to the displayed total.
- ZIP code preference for Walmart search context.
- No app account, subscription, advertising, analytics, backend or third-party SDK.

## Walmart pricing boundary

Walmart's public Marketplace APIs are seller-oriented. Walmart I/O's affiliate and localized commerce APIs require the appropriate partner/affiliate access. This app does not use private endpoints or pretend that inaccessible listings are live data.

The app makes a best-effort request to the public Walmart search page and reads product/price information only when the page exposes usable structured data. Walmart may block automated access, omit local prices, or require location/account context. When that happens, the app opens the Walmart search page and asks the user to confirm the exact product, package size and price. A manually entered price is never labeled as a live verified price.

## Groq setup

1. Create a Groq API key at https://console.groq.com/keys.
2. Open SavorCart → Settings → Groq AI.
3. Paste the key and save it.
4. Generate recipes from the Create tab.

The app sends recipe prompts directly to the Groq chat completions endpoint using the openai/gpt-oss-20b model. No key is embedded in the repository.

## Build

The repository uses XcodeGen and the xcode-27 GitHub Actions runner.

1. Push to main or manually run Actions → Build unsigned IPA.
2. Download the SavorCart-ipa artifact.
3. Extract the artifact and sideload SavorCart.ipa using SideStore, AltStore or another compatible signer.

The IPA is unsigned. Sign it on your own device before installing.

## Privacy

Recipes, pantry inventory and shopping lists are stored locally on the iPhone. The Groq key is stored in Keychain and sent only to Groq for recipe generation. Walmart product search requests go directly to Walmart. No app backend, account, analytics or tracking is included.
