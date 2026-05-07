# Our Spring Days

[한국어 README](README_KOR.md)

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=111827)](https://firebase.google.com/)
[![Google Maps](https://img.shields.io/badge/Google%20Maps-4285F4?style=flat-square&logo=googlemaps&logoColor=white)](https://developers.google.com/maps)

`Our Spring Days` is a Flutter travel memory map for couples who travel with a dog. It brings routes, pet-friendly places, photos, partner markers, and mission records into one app flow.

Most map apps are good at place search, and most album apps are good at storing photos. This project focuses on the missing middle: helping a couple revisit where they walked, where they stopped, what they did, and which memories belong to that trip.

## Who This Is For

- Flutter developers looking for a route, photo, mission, and map app example
- Builders connecting Google Maps, Places, Firebase, Cloudinary, and local device APIs
- Product-minded developers designing location-based memories for couples, families, or travel groups

## Features

- Mission creation with time limits and photo verification
- Pet-friendly restaurant and cafe search with Naver Map deep links
- Partner-specific heart markers with create, edit, and delete flows
- Current location sharing between partners
- GPS route recording with distance, duration, and candidate stop detection
- Multi-photo album upload and mission photo organization
- Korean and Japanese UI support

## Tech Stack

### App

- Flutter
- Dart
- Riverpod
- GoRouter

### Backend / Infra

- Firebase Core
- Cloud Firestore
- Cloudinary unsigned upload preset
- Google Maps SDK
- Google Places API
- Naver Map URL Scheme

### Device

- Geolocator
- Image Picker
- Local Notifications
- Gallery Save

## Project Structure

```text
lib/
├─ core/
│  ├─ constants/
│  ├─ providers/
│  ├─ router/
│  ├─ services/
│  ├─ theme/
│  └─ utils/
├─ features/
│  ├─ album/
│  ├─ map/
│  ├─ mission/
│  ├─ record/
│  └─ route/
└─ shared/
```

## Quick Start

```bash
flutter pub get
flutter test
flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY \
  --dart-define=CLOUDINARY_CLOUD_NAME=YOUR_CLOUD_NAME \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=YOUR_UPLOAD_PRESET \
  --dart-define=PARTNER_A_ID=PARTNER_A \
  --dart-define=PARTNER_B_ID=PARTNER_B \
  --dart-define=COUPLE_ID=DEMO_COUPLE \
  --dart-define=APP_PACKAGE_NAME=com.bibiandus.ourspringdays
```

For Android, add the Google Maps key to `android/local.properties`.

```properties
GOOGLE_MAPS_API_KEY=YOUR_KEY
```

`android/local.properties` is local configuration and should not be committed.

Firebase Android config should be stored locally at `android/app/google-services.json`. Do not commit that file to a public repository.

## Public Repository Safety

Do not commit:

- Firebase project IDs, app IDs, or API keys
- Google Maps / Places API keys
- Cloudinary cloud names or upload presets
- Real user identifiers, private location history, or personal photos
- Release APK or AAB files

Example build configuration is documented in [dart_defines.example.json](dart_defines.example.json).

## Documentation

- [Project overview](docs/00_project_overview.md)
- [Requirements](docs/01_requirements.md)
- [User scenarios](docs/02_user_scenarios.md)
- [Feature specification](docs/03_feature_spec.md)
- [Architecture](docs/04_architecture.md)
- [Database design](docs/05_database_design.md)
- [API / integration spec](docs/06_api_spec.md)
- [UI / UX design](docs/07_ui_ux_design.md)
- [Development plan](docs/08_development_plan.md)
- [Test plan](docs/09_test_plan.md)
- [Deployment guide](docs/10_deployment_guide.md)
- [Troubleshooting](docs/11_troubleshooting.md)
- [Retrospective](docs/12_retrospective.md)

## Verification

```bash
flutter analyze
flutter test
flutter build apk --release
```

Current tests focus on provider behavior and app-load smoke coverage.

## Roadmap

See [TODO.md](TODO.md) for planned improvements.

## Contributing

- Report bugs or setup problems in [Issues](https://github.com/yungi0816/our_spring_days/issues).
- Share product direction, UX feedback, or feature ideas in [Discussions](https://github.com/yungi0816/our_spring_days/discussions).
- Small documentation fixes and focused example improvements are welcome as pull requests.

## License

No explicit license is currently provided. If this project is intended for open reuse, adding MIT or Apache-2.0 is recommended.
