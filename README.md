# Shopping List

A shopping list app for iOS and the web. Build lists, tick items off as you
shop, and share a list with someone as a link over SMS, Messages or Mail.

## Features

- **Multiple named lists** with rename, duplicate, archive and restore
- **Nine categories** with icons, plus filters by to-buy / in-cart and category
- **Progress tracking** per list, with a completion indicator
- **Swipe to delete**, quantity steppers, and haptic feedback
- **Share as a link** over SMS, Messages or Mail — no account or server needed
- **Bluetooth sharing** between nearby devices (iOS only, requires two devices)
- **Offline** — the web build works as an installable PWA
- **Light and dark mode**

## How link sharing works

The whole list is serialised to JSON, gzip-compressed, and base64url-encoded
into a single URL:

```
shoppinglist://import?d=H4sIAAAAAAAAE23MsQ6CMBSF4Vdpz...
```

That means the link is completely self-contained. There is no backend, no
account, and nothing to host — the recipient only needs the app (or the web
app) to open it. Re-importing the same link updates the existing list rather
than creating a duplicate.

A typical list fits comfortably in one SMS. The UI warns when a link grows
long enough to be split across messages.

## Getting started

```sh
flutter pub get

# iOS
flutter run -d <device-id>

# Web
flutter run -d chrome
```

## Building

```sh
# iOS device build (requires an Apple ID / developer team)
flutter build ios --release

# Web, hosted at a sub-path such as GitHub Pages /ShoppingList/
flutter build web --release --base-href=/ShoppingList/
```

Deploying to GitHub Pages happens automatically on every push to `main` via
`.github/workflows/pages.yml`.

## Installing the web app on iOS

Open the deployed URL in **Safari**, tap **Share**, then **Add to Home
Screen**. It launches fullscreen from its own icon.

> Note: iOS only installs web apps from Safari, not Chrome.

## Architecture

```
lib/
  data/       list_storage.dart          JSON persistence + legacy migration
  models/     shopping_item.dart         Item and Category
              shopping_list.dart         List with derived progress
  providers/  shopping_lists_provider.dart  Single source of truth
  screens/    lists_home, list_detail, archive, share_sheet,
              receive_screen, add_item_sheet, link_import_screen
  services/   link_codec.dart            Versioned link payload encode/decode
              deep_link_service.dart     Cold and warm link routing
              share_service.dart         Bluetooth peer discovery
              list_sharing.dart          Share sheet integration
  theme/      app_theme.dart             Design tokens, light and dark
  widgets/    list_card, item_tile, empty_state
packages/
  multipeer_bridge/                      Native MultipeerConnectivity bridge
```

State is managed with `Provider`. The link payload format is versioned so it
can evolve independently of the app's models, and remains byte-compatible
across the iOS and web builds.

## Platform notes

| Feature | iOS | Web |
| --- | --- | --- |
| Link sharing over SMS | Yes | Yes |
| Bluetooth peer-to-peer | Yes | Not possible |
| Home-screen icon | App Store install | Add to Home Screen |
| Expiry | 7 days on a free Apple ID | Never |
| Offline | Yes | Yes (service worker) |

Bluetooth sharing requires two physical devices — MultipeerConnectivity does
not work in the iOS simulator.

## Tests

```sh
flutter test
```

Covers the models, provider, persistence and migration, filtering, archiving,
link encode/decode (including cross-compatibility between the iOS and web
encoders), and the import flow.
