import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AlbumEntry {
  final String id;
  final String title;
  final List<String> imageUrls;
  final String creatorId;
  final String? placeName;
  final String? address;
  final LatLng? position;
  final String sourceType;
  final String? sourceId;
  final DateTime timestamp;
  final bool isDisconnectedCoupleRecord;

  String get imageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  AlbumEntry({
    required this.id,
    required this.title,
    String? imageUrl,
    List<String> imageUrls = const [],
    required this.creatorId,
    this.placeName,
    this.address,
    this.position,
    this.sourceType = 'album',
    this.sourceId,
    required this.timestamp,
    this.isDisconnectedCoupleRecord = false,
  }) : imageUrls = _normalizeImageUrls(imageUrl, imageUrls);

  factory AlbumEntry.fromMap(Map<String, dynamic> map, String id) {
    final latitude = (map['latitude'] as num?)?.toDouble();
    final longitude = (map['longitude'] as num?)?.toDouble();
    final timestamp = map['timestamp'];

    return AlbumEntry(
      id: id,
      title: map['title'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: (map['imageUrls'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      creatorId: map['creatorId'] ?? '',
      placeName: map['placeName'],
      address: map['address'],
      position: latitude != null && longitude != null
          ? LatLng(latitude, longitude)
          : null,
      sourceType: map['sourceType']?.toString() ?? 'album',
      sourceId: map['sourceId'],
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      isDisconnectedCoupleRecord:
          map['isDisconnectedCoupleRecord'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'creatorId': creatorId,
      'placeName': placeName,
      'address': address,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isDisconnectedCoupleRecord': isDisconnectedCoupleRecord,
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
