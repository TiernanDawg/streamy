# FrugalFork

FrugalFork is a native iPhone recipe and grocery-cost planner. Describe a meal in plain language, generate a complete recipe with Groq, subtract matching pantry inventory, and build a Walmart-focused shopping list.

## Features

- Native SwiftUI interface designed for iPhone and iOS 27.
- Groq-powered recipes with quantities, servings, preparation and cooking times, and sequential instructions.
- Strict structured-output requests with local validation and a one-time recovery retry.
- Groq API key stored in iOS Keychain with device-only accessibility; test a newly entered key before saving it.
- Local recipe library, pantry inventory and shopping list.
- Pantry deduction when ingredient names and units match.
- Package-size suggestions and package-count/leftover calculations.
- Walmart product search links with best-effort extraction of public structured product data.
- Manual/unavailable price distinction. Manually entered prices are per package; only confirmed prices contribute to the displayed total.
- Saved ZIP-code preference; Walmart may still require the user to choose a store or delivery location on its website.
- No app account, subscription, advertising, analytics, backend or third-party SDK.

## Walmart pricing boundary

Walmart's public Marketplace APIs are seller-oriented. Walmart I/O's affiliate and localized commerce APIs require the appropriate partner or affiliate access. This app does not use private endpoints or pretend that inaccessible listings are live data.

The app makes a best-effort request to the public Walmart search page and reads product or price information only when the page exposes usable structured data. Walmart may block automated access, omit local prices, or require location/account context. The saved ZIP is a reminder only; the app cannot set the location in a Walmart account or guarantee store-specific availability. When page data is unavailable, the app opens Walmart search and asks the user to confirm the exact product, package size and price. Package sizes are AI suggestions until checked against the actual listing.

## Groq setup and troubleshooting

1. Create an API key at https://console.groq.com/keys.
2. Open FrugalFork → Settings → Groq AI.
3. Paste the key and tap Test API key. The test calls the same Groq model used for recipes without relying on JSON formatting.
4. If the test succeeds, tap Save API key.
5. Generate a recipe from the Create tab.

Recipe requests use the openai/gpt-oss-20b model and strict structured outputs. If Groq rejects the structured response format, the app retries once without server-side schema enforcement and validates the returned JSON locally. Missing optional cooking notes are accepted; malformed or incomplete recipes are not saved.

The API key is never embedded in the repository. It is sent directly from the iPhone to Groq.

## Build

The repository uses XcodeGen and the xcode-27 GitHub Actions runner.

1. Push to main or manually run Actions → Build unsigned IPA.
2. Download the FrugalFork-ipa artifact.
3. Extract the artifact and sideload FrugalFork.ipa using SideStore, AltStore or another compatible signer.

The IPA is unsigned. Sign it on your own device before installing.

## Privacy

Recipes, pantry inventory and shopping lists are stored locally on the iPhone. The Groq key is stored in Keychain and sent only to Groq for recipe generation. Walmart product search requests go directly to Walmart. No app backend, account, analytics or tracking is included.
