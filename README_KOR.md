# Our Spring Days

[English README](README.md)

`Our Spring Days`는 강아지와 함께 여행하는 커플이 이동 루트, 애견 동반 장소, 사진, 미션을 한곳에 남길 수 있도록 만든 Flutter 앱입니다.

일반 지도 앱은 장소 검색에 강하고, 앨범 앱은 사진 보관에 강하지만 “그날 어디를 걸었고, 강아지와 어디에 들렀고, 어떤 사진을 남겼는지”를 함께 보기 어렵습니다. 이 앱은 여행 이후에도 지도 위에서 그날의 흐름을 다시 볼 수 있게 하는 데 초점을 맞췄습니다.

## 이런 분에게 유용합니다

- 여행 루트, 사진, 미션을 하나의 앱 흐름으로 설계하는 Flutter 예제를 찾는 분
- Google Maps, Places, Firebase, Cloudinary를 앱에서 함께 연결하는 구조가 궁금한 분
- 커플/가족/동행자 단위의 위치 기반 기록 앱을 만들고 싶은 분

## 주요 기능

- 미션 등록, 제한 시간 설정, 사진 인증
- 애견 동반 맛집/카페 검색 및 네이버지도 앱 연동
- 파트너별 하트 마커 저장, 수정, 삭제
- 서로의 현재 위치 공유
- GPS 기반 여행 루트 기록, 거리/시간/방문 후보 장소 확인
- 앨범 사진 다중 업로드와 미션 인증 사진 정리
- 한국어 / 일본어 UI 지원

## 기술 스택

- App: Flutter, Dart, Riverpod, GoRouter
- Backend / Infra: Firebase, Cloud Firestore, Cloudinary, Google Maps SDK, Google Places API
- Device: Geolocator, Image Picker, Local Notifications, Gallery Save

## 실행

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

실제 API Key, Firebase 설정 파일, 위치 기록, 개인 사진, 릴리즈 APK/AAB는 공개 저장소에 올리지 않습니다.

## 문서

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

## 의견과 기여

- 버그나 실행 문제는 [Issues](https://github.com/yungi0816/our_spring_days/issues)에 남겨주세요.
- 기능 제안, 제품 방향, UX 피드백은 [Discussions](https://github.com/yungi0816/our_spring_days/discussions)에 남겨주세요.
- 작은 문서 수정이나 예제 개선 PR은 환영합니다.
