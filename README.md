# 비비랑 우리

강아지와 함께 여행하는 커플이 이동 루트, 애견 동반 장소, 사진, 미션을 한곳에 남길 수 있도록 만든 Flutter 앱입니다.

일반 지도 앱은 장소 검색에 강하고, 앨범 앱은 사진 보관에 강하지만 “그날 어디를 걸었고, 강아지와 어디에 들렀고, 어떤 사진을 남겼는지”를 같이 보기 어렵습니다. 이 앱은 커플이 여행을 다녀온 뒤에도 지도 위에서 그날의 흐름을 다시 볼 수 있게 하는 데 초점을 맞췄습니다.

## ✨ 주요 기능

- 🎯 미션 등록, 제한 시간 설정, 사진 인증
- 🐶 애견 동반 맛집·카페 검색 및 네이버지도 앱 연동
- 💙❤️ 파트너별 하트 마커 저장, 수정, 삭제
- 📍 서로의 현재 위치 공유
- 🧭 GPS 기반 여행 루트 기록, 거리·시간·방문 후보 장소 확인
- 🖼️ 앨범 사진 다중 업로드, 미션 인증 사진 자동 정리
- 🇰🇷🇯🇵 한국어 / 일본어 UI 지원

## 🛠️ 기술 스택

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

## 📁 프로젝트 구조

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

## 🚀 실행 방법

```bash
flutter pub get
flutter test
flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY \
  --dart-define=CLOUDINARY_CLOUD_NAME=YOUR_CLOUD_NAME \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=YOUR_UPLOAD_PRESET \
  --dart-define=PARTNER_A_ID=PARTNER_A \
  --dart-define=PARTNER_B_ID=PARTNER_B \
  --dart-define=COUPLE_ID=DEMO_COUPLE
```

Android에서는 `android/local.properties`에 아래 값을 추가합니다.

```properties
GOOGLE_MAPS_API_KEY=YOUR_KEY
```

`android/local.properties`도 로컬 설정 파일이라 커밋하지 않습니다.

Firebase Android 설정은 `android/app/google-services.json`을 로컬에만 둡니다. 이 파일은 공개 저장소에 올리지 않습니다.

## 🔐 공개 저장소 주의사항

아래 값은 GitHub에 올리지 않습니다.

- Firebase 프로젝트 ID, 앱 ID, API Key
- Google Maps / Places API Key
- Cloudinary Cloud Name, Upload Preset
- 실제 사용자 식별값, 개인 위치 기록, 실사용 사진
- 릴리즈 APK, AAB 파일

예시 설정은 문서에만 남기고 실제 값은 `--dart-define`, `local.properties`, Firebase 설정 파일로 주입합니다.
빌드 설정 예시는 [dart_defines.example.json](dart_defines.example.json)에 정리했습니다.

## 📚 문서

- [프로젝트 개요](docs/00_project_overview.md)
- [요구사항 정의서](docs/01_requirements.md)
- [사용자 시나리오](docs/02_user_scenarios.md)
- [기능 명세서](docs/03_feature_spec.md)
- [시스템 아키텍처](docs/04_architecture.md)
- [데이터베이스 설계서](docs/05_database_design.md)
- [API / 외부 연동 명세서](docs/06_api_spec.md)
- [UI / UX 설계서](docs/07_ui_ux_design.md)
- [개발 계획서](docs/08_development_plan.md)
- [테스트 계획서](docs/09_test_plan.md)
- [배포 가이드](docs/10_deployment_guide.md)
- [트러블슈팅](docs/11_troubleshooting.md)
- [프로젝트 회고](docs/12_retrospective.md)

## ✅ 검증

```bash
flutter analyze
flutter test
flutter build apk --release
```

현재 테스트는 Provider 동작과 앱 로드 스모크 테스트를 중심으로 구성되어 있습니다.

## 📌 앞으로 할 일

자세한 항목은 [TODO.md](TODO.md)에 정리했습니다.
