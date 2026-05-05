import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_constants.dart';
import '../providers/route_models.dart';
import 'common_providers.dart';

// 데이트 장소 모델
class DateSpot {
  final String id;
  final String name;
  final String category;
  final String? address;
  final List<String> imageUrls;
  final String markerShape;
  final double markerSize;
  final LatLng position;
  final String creatorId;
  final DateTime timestamp;

  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  DateSpot({
    required this.id,
    required this.name,
    this.category = '데이트',
    this.address,
    String? imageUrl,
    List<String> imageUrls = const [],
    this.markerShape = 'heart',
    this.markerSize = 1.25,
    required this.position,
    required String creatorId,
    required this.timestamp,
  }) : imageUrls = _normalizeImageUrls(imageUrl, imageUrls),
       creatorId = normalizeMapUserId(creatorId);

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
      imageUrls: (map['imageUrls'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      markerShape: map['markerShape']?.toString() ?? 'heart',
      markerSize: (map['markerSize'] as num?)?.toDouble() ?? 1.25,
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
      'imageUrls': imageUrls,
      'markerShape': markerShape,
      'markerSize': markerSize,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'creatorId': normalizeMapUserId(creatorId),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  static List<String> _normalizeImageUrls(
    String? imageUrl,
    List<String> imageUrls,
  ) {
    final urls = <String>[
      ...imageUrls
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
      if (imageUrl != null && imageUrl.trim().isNotEmpty) imageUrl.trim(),
    ];
    return List.unmodifiable(urls.toSet());
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

final spotCommentsProvider = StreamProvider.family<List<SpotComment>, String>((
  ref,
  spotId,
) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getSpotCommentStream(spotId);
});
