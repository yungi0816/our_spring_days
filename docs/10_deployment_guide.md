# 배포 가이드

## 배포 환경

| 항목 | 내용 |
|---|---|
| Flutter | SDK 3.11.x 이상 |
| Android | release APK |
| Backend | Firebase / Cloudinary |
| 지도 | Google Maps / Places API |

## 로컬 설정

공개 저장소에는 실제 값을 넣지 않습니다.

### Android

`android/local.properties`

```properties
GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

`android/app/google-services.json`은 Firebase Console에서 내려받아 로컬에만 둡니다.
Android 패키지명은 공개용 기본값 `com.bibiandus.ourspringdays`입니다. 실제 배포 패키지명을 바꾸면 Firebase Android 앱도 같은 패키지명으로 다시 등록합니다.

### Dart define

```bash
flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY \
  --dart-define=CLOUDINARY_CLOUD_NAME=YOUR_CLOUD_NAME \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=YOUR_UPLOAD_PRESET \
  --dart-define=PARTNER_A_ID=PARTNER_A \
  --dart-define=PARTNER_B_ID=PARTNER_B \
  --dart-define=COUPLE_ID=DEMO_COUPLE \
  --dart-define=APP_PACKAGE_NAME=com.bibiandus.ourspringdays \
  --dart-define=FIREBASE_ANDROID_API_KEY=YOUR_FIREBASE_KEY \
  --dart-define=FIREBASE_ANDROID_APP_ID=YOUR_APP_ID \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID \
  --dart-define=FIREBASE_STORAGE_BUCKET=YOUR_BUCKET
```

## 릴리즈 빌드

```bash
flutter clean
flutter pub get
flutter build apk --release \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY \
  --dart-define=CLOUDINARY_CLOUD_NAME=YOUR_CLOUD_NAME \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=YOUR_UPLOAD_PRESET
```

빌드 결과:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 공개 저장소 제외 대상

`.gitignore`에 아래 항목을 포함합니다.

```gitignore
android/app/google-services.json
android/local.properties
ios/Runner/GoogleService-Info.plist
dart_defines.json
.env
key.properties
*.jks
*.keystore
dist/
*.apk
*.aab
```

## 배포 전 확인

- [ ] API 키가 코드에 하드코딩되어 있지 않은지 확인
- [ ] Firebase 설정 파일이 Git에 포함되지 않았는지 확인
- [ ] APK가 저장소에 포함되지 않았는지 확인
- [ ] 실제 사용자 위치 데이터나 사진이 커밋되지 않았는지 확인
