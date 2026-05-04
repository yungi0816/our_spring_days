import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AlbumEntry {
  final String id;
  final String title;
  final String imageUrl;
  final String creatorId;
  final String? placeName;
  final String? address;
  final LatLng? position;
  final DateTime timestamp;

  AlbumEntry({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.creatorId,
    this.placeName,
    this.address,
    this.position,
    required this.timestamp,
  });

  factory AlbumEntry.fromMap(Map<String, dynamic> map, String id) {
    final latitude = (map['latitude'] as num?)?.toDouble();
    final longitude = (map['longitude'] as num?)?.toDouble();
    final timestamp = map['timestamp'];

    return AlbumEntry(
      id: id,
      title: map['title'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      creatorId: map['creatorId'] ?? '',
      placeName: map['placeName'],
      address: map['address'],
      position: latitude != null && longitude != null
          ? LatLng(latitude, longitude)
          : null,
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'creatorId': creatorId,
      'placeName': placeName,
      'address': address,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
