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
  final bool isDisconnectedCoupleRecord;
  final String? groupId;
  final int? markerColor;
  final int? routeColor;
  final String? markerImageUrl;

  TravelRoute({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.startTime,
    this.endTime,
    required this.totalDistanceMeters,
    required this.points,
    required this.updatedAt,
    this.isDisconnectedCoupleRecord = false,
    this.groupId,
    this.markerColor,
    this.routeColor,
    this.markerImageUrl,
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
      isDisconnectedCoupleRecord:
          map['isDisconnectedCoupleRecord'] as bool? ?? false,
      groupId: map['groupId'],
      markerColor: (map['markerColor'] as num?)?.toInt(),
      routeColor: (map['routeColor'] as num?)?.toInt(),
      markerImageUrl: map['markerImageUrl'],
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
      'isDisconnectedCoupleRecord': isDisconnectedCoupleRecord,
      'groupId': groupId,
      'markerColor': markerColor,
      'routeColor': routeColor,
      'markerImageUrl': markerImageUrl,
    };
  }
}

class RouteComment {
  final String id;
  final String routeId;
  final String authorId;
  final String authorNickname;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;

  RouteComment({
    required this.id,
    required this.routeId,
    required this.authorId,
    required this.authorNickname,
    this.authorPhotoUrl,
    required this.content,
    required this.createdAt,
  });

  factory RouteComment.fromMap(
    Map<String, dynamic> map,
    String id,
    String routeId,
  ) {
    final createdAt = map['createdAt'];
    return RouteComment(
      id: id,
      routeId: routeId,
      authorId: map['authorId'] ?? '',
      authorNickname: map['authorNickname'] ?? map['authorId'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'],
      content: map['content'] ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class RouteGroup {
  final String id;
  final String name;
  final DateTime createdAt;

  RouteGroup({required this.id, required this.name, required this.createdAt});

  factory RouteGroup.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'];
    return RouteGroup(
      id: id,
      name: map['name'] ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'createdAt': Timestamp.fromDate(createdAt)};
  }
}

class SpotComment {
  final String id;
  final String spotId;
  final String authorId;
  final String authorNickname;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;

  SpotComment({
    required this.id,
    required this.spotId,
    required this.authorId,
    required this.authorNickname,
    this.authorPhotoUrl,
    required this.content,
    required this.createdAt,
  });

  factory SpotComment.fromMap(
    Map<String, dynamic> map,
    String id,
    String spotId,
  ) {
    final createdAt = map['createdAt'];
    return SpotComment(
      id: id,
      spotId: spotId,
      authorId: map['authorId'] ?? '',
      authorNickname: map['authorNickname'] ?? map['authorId'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'],
      content: map['content'] ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class AlbumComment {
  final String id;
  final String albumId;
  final String authorId;
  final String authorNickname;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;

  AlbumComment({
    required this.id,
    required this.albumId,
    required this.authorId,
    required this.authorNickname,
    this.authorPhotoUrl,
    required this.content,
    required this.createdAt,
  });

  factory AlbumComment.fromMap(
    Map<String, dynamic> map,
    String id,
    String albumId,
  ) {
    final createdAt = map['createdAt'];
    return AlbumComment(
      id: id,
      albumId: albumId,
      authorId: map['authorId'] ?? '',
      authorNickname: map['authorNickname'] ?? map['authorId'] ?? '',
      authorPhotoUrl: map['authorPhotoUrl'],
      content: map['content'] ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
