import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_constants.dart';
import 'common_providers.dart';

// 데이트 장소 모델
class DateSpot {
  final String id;
  final String name;
  final String category;
  final String? address;
  final String? imageUrl;
  final LatLng position;
  final String creatorId;
  final DateTime timestamp;

  DateSpot({
    required this.id,
    required this.name,
    this.category = '데이트',
    this.address,
    this.imageUrl,
    required this.position,
    required String creatorId,
    required this.timestamp,
  }) : creatorId = normalizeMapUserId(creatorId);

  factory DateSpot.fromMap(Map<String, dynamic> map, String id) {
    final latitude = (map['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (map['longitude'] as num?)?.toDouble() ?? 0;
    final timestamp = map['timestamp'];

    return DateSpot(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '데이트',
      address: map['address'],
      imageUrl: map['imageUrl'],
      position: LatLng(latitude, longitude),
      creatorId: normalizeMapUserId(map['creatorId']),
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'address': address,
      'imageUrl': imageUrl,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'creatorId': normalizeMapUserId(creatorId),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class SharedUserLocation {
  final String userId;
  final LatLng position;
  final DateTime updatedAt;

  SharedUserLocation({
    required this.userId,
    required this.position,
    required this.updatedAt,
  });

  factory SharedUserLocation.fromMap(Map<String, dynamic> map, String id) {
    final latitude = (map['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (map['longitude'] as num?)?.toDouble() ?? 0;
    final updatedAt = map['updatedAt'];

    return SharedUserLocation(
      userId: id,
      position: LatLng(latitude, longitude),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : DateTime.now(),
    );
  }
}

String normalizeMapUserId(Object? value) {
  final raw = (value ?? '').toString().trim();
  final normalized = raw.toUpperCase();
  final partnerA = AppConstants.partnerAId.toUpperCase();
  final partnerB = AppConstants.partnerBId.toUpperCase();

  if (partnerA.isNotEmpty && normalized.contains(partnerA)) {
    return AppConstants.partnerAId;
  }
  if (partnerB.isNotEmpty && normalized.contains(partnerB)) {
    return AppConstants.partnerBId;
  }
  return raw;
}

// -----------------------------------------------------------------------------
// 지도 및 장소 관련 Provider
// -----------------------------------------------------------------------------

// 1. 실시간 장소 스트림 Provider
final dateSpotsStreamProvider = StreamProvider<List<DateSpot>>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getDateSpotStream();
});

final sharedUserLocationsProvider = StreamProvider<List<SharedUserLocation>>((
  ref,
) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getSharedUserLocationStream();
});

// 2. 현재 지도 중심 위치 (AI 채팅용 컨텍스트) - NotifierProvider로 더 안정적으로 변경
class MapLocationNotifier extends Notifier<LatLng> {
  @override
  LatLng build() => const LatLng(33.3617, 126.5292); // 초기 위치: 한라산

  void setLocation(LatLng location) {
    state = location;
  }
}

final currentMapLocationProvider =
    NotifierProvider<MapLocationNotifier, LatLng>(MapLocationNotifier.new);
