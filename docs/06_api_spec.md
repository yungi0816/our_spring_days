# API / 외부 연동 명세서

이 앱은 자체 REST 서버 없이 Firebase와 외부 API를 직접 사용합니다.

## 1. Firestore Service

### 미션 목록 구독

```dart
Stream<List<Mission>> getMissionStream()
```

경로:

```text
couples/{coupleId}/missions
```

정렬:

```text
timestamp desc
```

### 미션 등록

```dart
Future<void> addMission(Mission mission)
```

Request model:

```json
{
  "content": "미션 내용",
  "originalImageUrl": "https://...",
  "isCompleted": false,
  "creatorId": "USER_A",
  "timestamp": "Timestamp",
  "deadline": "Timestamp"
}
```

### 장소 저장 / 수정 / 삭제

```dart
Future<void> addDateSpot(DateSpot spot)
Future<void> updateDateSpot(DateSpot spot)
Future<void> deleteDateSpot(String id)
```

### 여행 루트 저장

```dart
Future<void> setTravelRoute(TravelRoute route)
```

특징:

- 최종 저장된 루트는 자동저장이 다시 `recording` 상태로 덮어쓰지 않는다.
- Firestore transaction으로 기존 `endTime`을 확인한다.

### 위치 공유

```dart
Future<void> updateSharedUserLocation(String userId, LatLng position)
```

경로:

```text
couples/{coupleId}/shared_locations/{userId}
```

## 2. Google Places API

### 주변 검색

```http
POST https://places.googleapis.com/v1/places:searchText
```

Header:

```http
X-Goog-Api-Key: ${GOOGLE_MAPS_API_KEY}
X-Goog-FieldMask: places.id,places.displayName,places.formattedAddress,places.location,places.primaryType
```

Request 예시:

```json
{
  "textQuery": "애견 동반 카페",
  "languageCode": "ko",
  "maxResultCount": 10,
  "locationBias": {
    "circle": {
      "center": {
        "latitude": 37.0,
        "longitude": 127.0
      },
      "radius": 50000.0
    }
  }
}
```

## 3. Cloudinary Upload

### 이미지 업로드

```http
POST https://api.cloudinary.com/v1_1/{cloudName}/image/upload
```

Form fields:

| 필드 | 설명 |
|---|---|
| file | 업로드할 이미지 |
| upload_preset | unsigned upload preset |
| folder | 저장 폴더 |
| public_id | 앱에서 생성한 식별자 |
| tags | 관리용 태그 |

Response:

```json
{
  "secure_url": "https://res.cloudinary.com/..."
}
```

## 4. Naver Map URL Scheme

추천 장소 마커를 누르면 네이버지도 앱을 실행합니다.

```text
nmap://place?lat={lat}&lng={lng}&name={name}&appname={packageName}
```

앱 실행 실패 시 웹 검색으로 대체합니다.

```text
https://map.naver.com/p/search/{query}
```
