import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../providers/album_provider.dart';
import '../providers/mission_provider.dart';
import '../providers/map_provider.dart';
import '../providers/route_models.dart';

class PhotoUploadException implements Exception {
  final String message;
  final Object? cause;

  const PhotoUploadException(this.message, [this.cause]);

  @override
  String toString() => message;
}

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String _cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );
  static const String _cloudinaryFolder = String.fromEnvironment(
    'CLOUDINARY_FOLDER',
    defaultValue: 'our_spring_days',
  );

  final String coupleId = AppConstants.coupleId;

  // --- 미션 관련 로직 ---
  Stream<List<Mission>> getMissionStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Mission.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> addMission(Mission mission) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(mission.id)
        .set(mission.toMap());
  }

  Future<void> updateMission(
    String id,
    String newContent,
    DateTime? deadline,
  ) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(id)
        .update({
          'content': newContent,
          'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
        });
  }

  Future<void> deleteMission(String id) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(id)
        .delete();
  }

  Future<void> completeMission(
    String id,
    String proofImageUrl,
    String userId,
  ) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(id)
        .update({
          'isCompleted': true,
          'proofImageUrl': proofImageUrl,
          'winnerId': userId,
          'completedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  // --- 지도(장소) 관련 로직 ---
  Future<void> addDateSpot(DateSpot spot) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(spot.id)
        .set(spot.toMap());
  }

  Future<void> updateDateSpot(DateSpot spot) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(spot.id)
        .set(spot.toMap());
  }

  Future<void> deleteDateSpot(String id) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(id)
        .delete();
  }

  Stream<List<DateSpot>> getDateSpotStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DateSpot.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> updateSharedUserLocation(String userId, LatLng position) async {
    final normalizedUserId = normalizeMapUserId(userId);
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_locations')
        .doc(normalizedUserId)
        .set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
  }

  Stream<List<SharedUserLocation>> getSharedUserLocationStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_locations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SharedUserLocation.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // --- 여행 루트 기록 로직 ---
  Future<void> setTravelRoute(TravelRoute route) async {
    final ref = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(route.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = snapshot.data();

      if (existing != null &&
          existing['endTime'] != null &&
          route.endTime == null) {
        return;
      }

      transaction.set(ref, route.toMap());
    });
  }

  Future<void> deleteTravelRoute(String id) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(id)
        .delete();
  }

  Stream<List<TravelRoute>> getTravelRouteStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TravelRoute.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // --- 앨범 관련 로직 ---
  Stream<List<AlbumEntry>> getAlbumStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AlbumEntry.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> addAlbumEntry(AlbumEntry entry) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .doc(entry.id)
        .set(entry.toMap());
  }

  // --- 사용자 프로필 로직 ---
  Stream<Map<String, dynamic>> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> resetUserProfilePhoto(String userId) async {
    await _firestore.collection('users').doc(userId).set({
      'photoUrl': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // --- 공통 업로드 로직 ---
  Future<String> uploadImage(File file, String path) async {
    if (!await file.exists()) {
      throw const PhotoUploadException('Selected image file was not found.');
    }
    if (_cloudinaryCloudName.isEmpty || _cloudinaryUploadPreset.isEmpty) {
      throw const PhotoUploadException(
        'Image upload is not configured. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final normalizedPath = _normalizeStoragePath(path);
    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$_cloudinaryCloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..fields['folder'] = _cloudinaryFolder
      ..fields['public_id'] = _cloudinaryPublicId(normalizedPath)
      ..fields['tags'] = 'our_spring_days,$coupleId'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final response = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PhotoUploadException(
          'Cloudinary upload failed: ${_cloudinaryErrorMessage(data)}',
        );
      }

      final secureUrl = data['secure_url']?.toString();
      if (secureUrl == null || secureUrl.isEmpty) {
        throw const PhotoUploadException(
          'Cloudinary upload succeeded but no image URL was returned.',
        );
      }

      return secureUrl;
    } on PhotoUploadException {
      rethrow;
    } on TimeoutException catch (e) {
      throw PhotoUploadException('Cloudinary upload timed out.', e);
    } on FormatException catch (e) {
      throw PhotoUploadException('Cloudinary returned an invalid response.', e);
    } catch (e) {
      throw PhotoUploadException('Cloudinary upload failed: $e', e);
    }
  }

  String _normalizeStoragePath(String path) {
    return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  }

  String _cloudinaryPublicId(String path) {
    final withoutExtension = path.replaceFirst(RegExp(r'\.[^./]+$'), '');
    final safePath = withoutExtension
        .replaceAll(RegExp(r'[^A-Za-z0-9/_-]+'), '_')
        .replaceAll(RegExp(r'/+'), '_');
    return 'couples_${coupleId}_$safePath';
  }

  String _cloudinaryErrorMessage(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return error['message']?.toString() ?? data.toString();
    }
    return data.toString();
  }
}
