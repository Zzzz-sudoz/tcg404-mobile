# TCG404 Mobile

Flutter storefront for TCG404, using the shared Express API for products, accounts and orders.

## Requirements

Flutter 3.44.9 / Dart 3.12.2, with Chrome or an Android SDK for the target platform.

## Run

    flutter pub get
    flutter run -d chrome --dart-define=API_BASE_URL=https://YOUR_API_HOST/api

For Android, use flutter run -d followed by the device ID reported by flutter devices.

Supply a reachable API endpoint with --dart-define=API_BASE_URL=https://YOUR_API_HOST/api. This is a public endpoint; database credentials and provider keys belong only on the server.

The Android emulator development default is http://10.0.2.2:5000/api. Web uses its own origin's /api path by default; configure a reverse proxy to the shared backend when using this default. Production and physical Android devices require a reachable HTTPS endpoint.

## Features

Collector home, searchable catalog, filter sheets, product details, persistent cart, customer authentication/profile, delivery checkout and order receipts/history. Current prices, inventory and orders are governed by the shared backend.

## Builds

    flutter build web --release --no-web-resources-cdn

    flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST/api

Web output is build/web. APK output is build/app/outputs/flutter-apk/app-release.apk. Configure private Android release signing before distributing the app; the scaffold currently uses debug signing. Keep signing files outside version control.

## Vercel

Import this repository with framework preset Other. The included vercel.json installs Flutter 3.44.9 and builds into build/web. Deploying this web build does not distribute the Android APK.

Before deployment, configure same-origin /api routing to the actual shared backend and its trusted-origin/cookie settings. Do not rewrite API requests to index.html. Alternatively, supply API_BASE_URL at Flutter build time and verify browser CORS and cookie behavior for that origin. No production API hostname is configured in this repository.

The backend repository is https://github.com/Zzzz-sudoz/tcg404-api. Mobile and web use the same saved inventory, users and orders.

## Artwork and fonts

Publisher artwork credits are in assets/cards/ATTRIBUTION.md. Barlow Condensed font sources and the SIL Open Font License are in assets/fonts/.
