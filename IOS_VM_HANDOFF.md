# iOS VM Handoff

This Flutter project already contains the iOS runner under `ios/`.
Use this checklist after uploading the project archive to a macOS VM.

## Required VM setup

- macOS with Xcode installed
- Flutter stable matching this project: `3.41.6`
- Dart SDK from Flutter: `3.11.4`
- CocoaPods installed
- A real Apple developer team is required for device builds or App Store/TestFlight signing

## Firebase before first run

This app now uses Firestore and Firebase Storage at runtime.
Before running the iOS app, add the real Firebase iOS config file here:

```text
ios/Runner/GoogleService-Info.plist
```

If the Firebase project has not been configured for this Flutter app yet:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Use the iOS bundle identifier shown below when creating the Firebase iOS app.

## First run on macOS

```bash
cd our_spring_days
flutter --version
flutter pub get
cd ios
pod install
cd ..
flutter analyze
flutter run -d ios
```

If the simulator does not appear, open Xcode once, accept licenses, install iOS platform support, then run:

```bash
sudo xcodebuild -license accept
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
flutter doctor
```

## Xcode project

Open this workspace, not the `.xcodeproj` file:

```bash
open ios/Runner.xcworkspace
```

Current bundle identifier:

```text
com.bibiandus.ourSpringDays
```

Change the bundle identifier and signing team in Xcode if the Apple account does not own this identifier.

## Firebase note

There is no `ios/Runner/GoogleService-Info.plist` in this handoff because it contains project credentials.
The VM must add the real file before `flutter run -d ios`.

## iOS permissions already configured

`ios/Runner/Info.plist` contains photo library and camera usage descriptions for `image_picker`.

## Google Maps

`ios/Runner/AppDelegate.swift` initializes the Google Maps SDK with the same API key used by Android and the Places API (New) web service calls. Make sure this key is allowed to use Maps SDK for iOS, Maps SDK for Android, and Places API (New) in Google Cloud.

## Archive contents

The handoff archive should include source and platform folders, but exclude generated caches:

- include: `lib`, `ios`, `android`, `web`, `macos`, `windows`, `linux`, `test`, `pubspec.yaml`, `pubspec.lock`
- exclude: `build`, `.dart_tool`, `.idea`, `.flutter-plugins-dependencies`, platform generated cache folders

