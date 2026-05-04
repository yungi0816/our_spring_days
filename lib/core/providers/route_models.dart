import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutePoint {
  final LatLng position;
  final DateTime timestamp;
  final double accuracy;

  RoutePoint({
    required this.position,
    required this.timestamp,
    required this.accuracy,
  });

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    final latitude = (map['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (map['longitude'] as num?)?.toDouble() ?? 0;
    final timestamp = map['timestamp'];

    return RoutePoint(
      position: LatLng(latitude, longitude),
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'accuracy': accuracy,
    };
  }
}

class TravelRoute {
  final String id;
  final String title;
  final String creatorId;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistanceMeters;
  final List<RoutePoint> points;
  final DateTime updatedAt;

  TravelRoute({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.startTime,
    this.endTime,
    required this.totalDistanceMeters,
    required this.points,
    required this.updatedAt,
  });

  bool get isRecording => endTime == null;

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  LatLng? get startPosition => points.isEmpty ? null : points.first.position;

  LatLng? get endPosition => points.isEmpty ? null : points.last.position;

  factory TravelRoute.fromMap(Map<String, dynamic> map, String id) {
    final startTime = map['startTime'];
    final endTime = map['endTime'];
    final updatedAt = map['updatedAt'];
    final rawPoints = map['points'] as List<dynamic>? ?? [];

    return TravelRoute(
      id: id,
      title: map['title'] ?? '여행 기록',
      creatorId: map['creatorId'] ?? '',
      startTime: startTime is Timestamp ? startTime.toDate() : DateTime.now(),
      endTime: endTime is Timestamp ? endTime.toDate() : null,
      totalDistanceMeters:
          (map['totalDistanceMeters'] as num?)?.toDouble() ?? 0,
      points: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(RoutePoint.fromMap)
          .toList(),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'creatorId': creatorId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime == null ? null : Timestamp.fromDate(endTime!),
      'totalDistanceMeters': totalDistanceMeters,
      'points': points.map((point) => point.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
