# TCG404 Mobile

Flutter storefront for TCG404, using the shared Express API for products, accounts and orders.

## Requirements

Flutter 3.44.9 / Dart 3.12.2, with Chrome or an Android SDK for the target platform.

## Run

    flutter pub get
    flutter run -d chrome

For Android, use flutter run -d followed by the device ID reported by flutter devices.

Supply a reachable API endpoint with --dart-define=API_BASE_URL=https://YOUR_API_HOST/api. This is a public endpoint; database credentials and provider keys belong only on the server.

The Android emulator development default is http://10.0.2.2:5000/api. Browser development uses http://127.0.0.1:5180; web_dev_config.yaml proxies /api/ to the backend on port 5000. Include http://127.0.0.1:5180 and http://localhost:5180 in the local backend CLIENT_ORIGIN. Restart Flutter after changing development server configuration. Production and physical Android devices require a reachable HTTPS endpoint.

## Features

Collector home, searchable catalog, filter sheets, product details, persistent cart, customer authentication/profile, delivery checkout and order receipts/history. Current prices, inventory and orders are governed by the shared backend.

## Builds

    flutter build web --release --no-web-resources-cdn

    flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST/api

Web output is build/web. APK output is build/app/outputs/flutter-apk/app-release.apk. Configure private Android release signing before distributing the app; the scaffold currently uses debug signing. Keep signing files outside version control.

## Vercel

Import this repository with framework preset Other. The included vercel.json installs Flutter 3.44.9 and builds into build/web. Deploying this web build does not distribute the Android APK.

The included API rewrite points to https://tcg404-api.vercel.app/api. Add the deployed mobile site's exact HTTPS origin to the backend CLIENT_ORIGIN and redeploy the backend. Browser sessions use the same-origin HttpOnly cookie; do not rewrite API requests to index.html.

The backend repository is https://github.com/Zzzz-sudoz/tcg404-api. Mobile and web use the same saved inventory, users and orders.

## Artwork and fonts

Publisher artwork credits are in assets/cards/ATTRIBUTION.md. Barlow Condensed font sources and the SIL Open Font License are in assets/fonts/.
